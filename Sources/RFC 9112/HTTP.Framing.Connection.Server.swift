// HTTP.Framing.Connection.Server.swift
// swift-rfc-9112
//
// RFC 9112 Section 9: Connection Management
// RFC 9112 Section 9.3: Persistence
// https://www.rfc-editor.org/rfc/rfc9112.html#section-9.3
//
// The request-reading side of a connection.

public import Byte_Primitives

extension RFC_9110.Framing.Connection {
    /// Reads requests off a connection.
    ///
    /// Sans-I/O: it never reads a socket, it is fed by one. Feed octets with
    /// `receive(_:)`, drain events with `next()` until it returns `nil`, and
    /// `finish()` to learn whether the stream ended cleanly.
    ///
    /// ## Pipelining
    ///
    /// RFC 9112 Section 9.3.2 lets a client send several requests without
    /// waiting, so a single read can carry the tail of one request and the whole
    /// of the next. Nothing special is needed for that here, and the reason is
    /// the framer's: it consumes **exactly** each message's octets and leaves the
    /// remainder untouched, so the next request begins at the head of the buffer.
    /// The drive adds only the message-boundary discipline — it will not frame a
    /// head while a body is outstanding, because until the body is consumed the
    /// octets after it are not a head.
    ///
    /// Unlike `Client` there is no method queue: a request's framing depends on
    /// nothing outside itself.
    public struct Server: ~Copyable {
        /// The message framer this drive feeds and reads.
        private var framer: RFC_9110.Framing.Framer

        /// Where in the current message the drive is.
        private var state: State

        /// An event produced but not yet handed out.
        private var pending: Event?

        /// Whether the message in progress asked for the connection to close.
        ///
        /// Recorded when the head frames and acted on when the body ends: RFC
        /// 9112 Section 9.6 closes the connection *after* the current message.
        private var closeAfterMessage: Bool

        public init(limits: RFC_9110.Framing.Limits = .default) {
            self.framer = RFC_9110.Framing.Framer(limits: limits)
            self.state = .head
            self.pending = nil
            self.closeAfterMessage = false
        }
    }
}

// MARK: - Driving the exchange

extension RFC_9110.Framing.Connection.Server {
    /// Octets received and not yet consumed by a framed message.
    public var unconsumed: Int { framer.unconsumed }

    /// Whether the connection can still carry a request.
    ///
    /// False once a request declared `Connection: close` (RFC 9112 Section 9.6).
    public var isReusable: Bool {
        switch state {
        case .head, .body: true
        case .finished: false
        }
    }

    /// Whether a body is part-way through being read.
    ///
    /// While this is true the octets in the buffer are body, not the next
    /// request — which is why the drive will not frame a head here.
    public var isReadingBody: Bool {
        switch state {
        case .body: true
        case .head, .finished: false
        }
    }
}

// MARK: - Feeding

extension RFC_9110.Framing.Connection.Server {
    /// Accepts received octets under the budget for the phase the drive is in.
    ///
    /// The head budget applies while a head is accumulating and `Limits.body`
    /// applies while a body is, each checked **before** the octets are retained.
    ///
    /// - Throws: `bodyTooLong` or `headSectionTooLong`, leaving the buffer
    ///   unchanged.
    public mutating func receive(_ bytes: [Byte]) throws(RFC_9110.Framing.Error) {
        try framer.append(bytes, accumulating: state.phase)
    }
}

// MARK: - Framing

extension RFC_9110.Framing.Connection.Server {
    /// Yields the next event, or `nil` when more octets are needed.
    ///
    /// - Throws: any framing failure.
    public mutating func next() throws(RFC_9110.Framing.Error)
        -> RFC_9110.Framing.Connection.Server.Event?
    {
        if let queued = pending {
            pending = nil
            return queued
        }

        switch state {
        case .finished:
            return nil

        case .head:
            guard let head = try framer.nextRequestHead() else { return nil }
            closeAfterMessage = Self.requestsClose(head.headers)
            state = .body(head.bodyLength)
            return .head(head)

        case .body(let bodyLength):
            return try nextBody(bodyLength)
        }
    }

    /// Delivers the body of the request whose head has been yielded.
    private mutating func nextBody(
        _ bodyLength: RFC_9110.Framing.BodyLength
    ) throws(RFC_9110.Framing.Error) -> RFC_9110.Framing.Connection.Server.Event? {
        switch bodyLength {
        case .untilClose, .tunnel:
            // Structurally unreachable: Section 6.3 gives these to responses
            // only. Reported rather than coerced — a total signature over a
            // partial operation relocates its failure instead of removing it.
            throw .closeDelimitedRequest

        case .none, .length, .chunked:
            guard let body = try framer.nextBody(bodyLength) else { return nil }
            let end = Event.end(trailers: body.trailers, octets: body.octets)
            state = closeAfterMessage ? .finished : .head
            closeAfterMessage = false
            guard !body.content.isEmpty else { return end }
            pending = end
            return .body(body.content)
        }
    }

    /// Whether a field section carries `Connection: close` (RFC 9112 Section
    /// 9.6).
    ///
    /// ⚠️ `RFC_9110.Connection` is spelled in full deliberately: inside this type
    /// the bare name `Connection` resolves to `RFC_9110.Framing.Connection`, the
    /// drive namespace, not the header field.
    private static func requestsClose(_ headers: RFC_9110.Headers) -> Bool {
        headers.values("Connection")
            .compactMap { RFC_9110.Connection.parse($0.description) }
            .contains { $0.hasClose }
    }
}

// MARK: - Termination

extension RFC_9110.Framing.Connection.Server {
    /// Declares the stream ended and reports how.
    ///
    /// `consuming`, so a drive cannot be fed after its stream is over. RFC 9112
    /// Section 8 governs incomplete messages, and distinguishing a clean close
    /// from a truncated one is what a `nil` from `next()` cannot express.
    public consuming func finish() throws(RFC_9110.Framing.Error)
        -> RFC_9110.Framing.Terminal
    {
        try framer.finish()
    }
}
