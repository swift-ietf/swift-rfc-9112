// HTTP.Framing.Connection.Client.swift
// swift-rfc-9112
//
// RFC 9112 Section 9: Connection Management
// RFC 9112 Section 9.3.2: Pipelining
// https://www.rfc-editor.org/rfc/rfc9112.html#section-9.3.2
//
// The response-reading side of a connection.

public import Byte_Primitives

extension RFC_9110.Framing.Connection {
    /// Reads responses off a connection.
    ///
    /// Sans-I/O: it never reads a socket, it is fed by one. Feed octets with
    /// `receive(_:)`, drain events with `next()` until it returns `nil`, tell it
    /// `peerClosed()` when the connection ends, and `finish()` to learn whether
    /// the stream ended cleanly.
    ///
    /// ## The method queue
    ///
    /// A response's framing depends on the method of the request it answers
    /// (RFC 9112 Section 6.3 rules 1 and 2), and responses arrive in the order
    /// their requests were sent (Section 9.3.2). So the drive keeps a FIFO of
    /// methods: `expect(_:)` on send, popped as each response head frames.
    ///
    /// **This is the framing-critical half of pipelining, and getting it wrong
    /// is a smuggling defect rather than a bookkeeping one.** A response to
    /// `HEAD` has no body however large its `Content-Length` — so if the queue
    /// pops out of order, the drive reads a body that is not there and the next
    /// response is framed from octets in the middle of the stream.
    ///
    /// Related but separate: `RFC_9110.Pipeline` tracks pending requests too,
    /// via `nextExpectedMethod()`. It is an actor holding *scheduling and
    /// timeout policy* — whether to pipeline after a non-idempotent method, how
    /// long a request has been outstanding. This queue exists because framing
    /// cannot proceed without it and must be synchronous and I/O-free. The
    /// overlap is real and deliberate; consolidating them is its own change.
    public struct Client: ~Copyable {
        /// The message framer this drive feeds and reads.
        private var framer: RFC_9110.Framing.Framer

        /// Where in the current message the drive is.
        private var state: State

        /// Methods of requests sent and not yet answered, oldest first.
        private var expected: [RFC_9110.Method]

        /// Whether the peer has closed its side of the connection.
        private var closed: Bool

        /// An event produced but not yet handed out.
        ///
        /// One framing call can yield two events — payload, then the end of the
        /// body — and `next()` hands out one at a time.
        private var pending: Event?

        /// Octets of the body in progress delivered so far.
        ///
        /// Only meaningful for a close-delimited body, whose length no header
        /// declares and which the framer therefore cannot report.
        private var delivered: Int

        /// Whether the message in progress asked for the connection to close.
        ///
        /// Recorded when the head frames and acted on when the body ends: RFC
        /// 9112 Section 9.6 closes the connection *after* the current message,
        /// not on sight of the field.
        private var closeAfterMessage: Bool

        public init(limits: RFC_9110.Framing.Limits = .default) {
            self.framer = RFC_9110.Framing.Framer(limits: limits)
            self.state = .head
            self.expected = []
            self.closed = false
            self.pending = nil
            self.delivered = 0
            self.closeAfterMessage = false
        }
    }
}

// MARK: - Driving the exchange

extension RFC_9110.Framing.Connection.Client {
    /// Records that a request with this method has been sent.
    ///
    /// Call once per request, in send order.
    public mutating func expect(_ method: RFC_9110.Method) {
        expected.append(method)
    }

    /// Requests sent and not yet answered.
    public var outstanding: Int { expected.count }

    /// Octets received and not yet consumed by a framed message.
    public var unconsumed: Int { framer.unconsumed }

    /// Whether the connection can still carry a message.
    ///
    /// False once a close-delimited body has ended, a tunnel was established, or
    /// a message declared `Connection: close` (RFC 9112 Section 9.6).
    public var isReusable: Bool {
        switch state {
        case .head, .body: true
        case .tunnelled, .finished: false
        }
    }
}

// MARK: - Feeding

extension RFC_9110.Framing.Connection.Client {
    /// Accepts received octets under the budget for the phase the drive is in.
    ///
    /// This is the whole reason the drive holds phase state: the framer is told
    /// which budget applies instead of inferring it, so a body is bounded by
    /// `Limits.body` and a head by `Limits.headSection`, each **before** the
    /// octets are retained.
    ///
    /// - Throws: `bodyTooLong` or `headSectionTooLong`, leaving the buffer
    ///   unchanged.
    public mutating func receive(_ bytes: [Byte]) throws(RFC_9110.Framing.Error) {
        try framer.append(bytes, accumulating: state.phase)
    }

    /// Records that the peer closed its side of the connection.
    ///
    /// This is the **terminator** for a close-delimited body (RFC 9112 Section
    /// 6.3 rule 8), not merely a notification: until it arrives, such a body has
    /// no end, which is why `Framer.nextBody(_:)` cannot deliver one.
    public mutating func peerClosed() {
        closed = true
    }
}

// MARK: - Framing

extension RFC_9110.Framing.Connection.Client {
    /// Yields the next event, or `nil` when more octets are needed.
    ///
    /// `nil` is the ordinary path on a partial read, not an error, and it does
    /// not distinguish "incomplete" from "the peer closed mid-message" — that is
    /// what `finish()` is for.
    ///
    /// - Throws: any framing failure, plus `responseWithoutRequest` if a
    ///   response arrives with nothing queued to answer.
    public mutating func next() throws(RFC_9110.Framing.Error)
        -> RFC_9110.Framing.Connection.Client.Event?
    {
        if let queued = pending {
            pending = nil
            return queued
        }

        switch state {
        case .tunnelled, .finished:
            return nil

        case .head:
            return try nextHead()

        case .body(let bodyLength):
            return try nextBody(bodyLength)
        }
    }

    /// Frames a response head against the method it answers.
    private mutating func nextHead() throws(RFC_9110.Framing.Error)
        -> RFC_9110.Framing.Connection.Client.Event?
    {
        guard let method = expected.first else {
            throw .responseWithoutRequest
        }
        // The queue is popped only on success. A throw or a `nil` must leave the
        // drive exactly as it was, or a retry would frame the next response
        // against the wrong request — the same discipline that makes the
        // framer's reject path leave its buffer byte-for-byte unadvanced.
        guard let head = try framer.nextResponseHead(answering: method) else { return nil }
        expected.removeFirst()

        delivered = 0
        closeAfterMessage = Self.requestsClose(head.headers)
        state = .body(head.bodyLength)
        return .head(head)
    }

    /// Whether a field section carries `Connection: close` (RFC 9112 Section
    /// 9.6).
    ///
    /// ⚠️ `RFC_9110.Connection` is spelled in full deliberately. Inside this
    /// type the bare name `Connection` resolves to `RFC_9110.Framing.Connection`
    /// — the drive namespace, not the header field. This is the shadowing
    /// documented on both types.
    private static func requestsClose(_ headers: RFC_9110.Headers) -> Bool {
        // `description`, not `.rawValue`: this is a consumer call site in a
        // different package, and the brand-newtype's raw accessor is reserved
        // for its own boundary. The two return the same octets.
        headers.values("Connection")
            .compactMap { RFC_9110.Connection.parse($0.description) }
            .contains { $0.hasClose }
    }

    /// Delivers the body of the message whose head has been yielded.
    private mutating func nextBody(
        _ bodyLength: RFC_9110.Framing.BodyLength
    ) throws(RFC_9110.Framing.Error) -> RFC_9110.Framing.Connection.Client.Event? {
        switch bodyLength {
        case .tunnel:
            // RFC 9112 Section 9.3.3: after a successful CONNECT the octets are
            // no longer HTTP messages, so framing stops rather than continues.
            state = .tunnelled
            return .tunnel

        case .untilClose:
            return deliverUntilClose()

        case .none, .length, .chunked:
            // Self-delimiting: the framer owns this entirely, including the
            // consumed count. The drive adds nothing and must not.
            guard let body = try framer.nextBody(bodyLength) else { return nil }
            let end = Event.end(trailers: body.trailers, octets: body.octets)
            state = closeAfterMessage ? .finished : .head
            closeAfterMessage = false
            guard !body.content.isEmpty else { return end }
            pending = end
            return .body(body.content)
        }
    }

    /// Streams a body delimited by the connection closing.
    ///
    /// The one framing the framer cannot deliver: there is no boundary in the
    /// byte stream to find, so the drive hands over whatever has arrived and
    /// ends the body when the peer closes. Streaming rather than accumulating is
    /// what keeps an unbounded body from being an unbounded allocation.
    private mutating func deliverUntilClose()
        -> RFC_9110.Framing.Connection.Client.Event?
    {
        let chunk = framer.takeBuffered()
        if !chunk.isEmpty {
            delivered += chunk.count
            return .body(chunk)
        }
        guard closed else { return nil }

        let octets = delivered
        delivered = 0
        // The close both ended the body and ended the connection.
        state = .finished
        return .end(trailers: RFC_9110.Headers([]), octets: octets)
    }
}

// MARK: - Termination

extension RFC_9110.Framing.Connection.Client {
    /// Surrenders the octets buffered behind an established tunnel.
    ///
    /// `consuming`: once the connection is a tunnel there is nothing further to
    /// frame, and the remaining octets belong to whatever takes it over.
    public consuming func surrenderTunnel() -> [Byte] {
        framer.surrenderUnconsumed()
    }

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
