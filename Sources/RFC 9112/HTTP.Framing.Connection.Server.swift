import RFC_9110

public import Byte_Primitives

extension RFC_9112.Framing.Connection {

    public struct Server: ~Copyable {

        private var framer: RFC_9112.Framing.Framer

        private var state: State

        private var pending: Event?

        private var closeAfterMessage: Bool

        public init(limits: RFC_9112.Framing.Limits = .default) {
            self.framer = RFC_9112.Framing.Framer(limits: limits)
            self.state = .head
            self.pending = nil
            self.closeAfterMessage = false
        }
    }
}

extension RFC_9112.Framing.Connection.Server {

    public var unconsumed: Int { framer.unconsumed }

    public var isReusable: Bool {
        switch state {
        case .head, .body: true
        case .finished: false
        }
    }

    public var isReadingBody: Bool {
        switch state {
        case .body: true
        case .head, .finished: false
        }
    }
}

extension RFC_9112.Framing.Connection.Server {

    public mutating func receive(_ bytes: [Byte]) throws(RFC_9112.Framing.Error) {
        try framer.append(bytes, accumulating: state.phase)
    }
}

extension RFC_9112.Framing.Connection.Server {

    public mutating func next() throws(RFC_9112.Framing.Error)
        -> RFC_9112.Framing.Connection.Server.Event?
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
            state = .body(head.length)
            return .head(head)

        case .body(let bodyLength):
            return try nextBody(bodyLength)
        }
    }

    private mutating func nextBody(
        _ length: RFC_9112.Framing.Body.Length
    ) throws(RFC_9112.Framing.Error) -> RFC_9112.Framing.Connection.Server.Event? {
        switch length {
        case .untilClose, .tunnel:

            throw .closeDelimitedRequest

        case .none, .length, .chunked:
            guard let body = try framer.nextBody(length) else { return nil }
            let end = Event.end(trailers: body.trailers, octets: body.octets)
            state = closeAfterMessage ? .finished : .head
            closeAfterMessage = false
            guard !body.content.isEmpty else { return end }
            pending = end
            return .body(body.content)
        }
    }

    private static func requestsClose(_ headers: RFC_9110.Message.Headers) -> Bool {
        headers.values(.connection)
            .compactMap { RFC_9112.Connection.parse($0.description) }
            .contains { $0.hasClose }
    }
}

extension RFC_9112.Framing.Connection.Server {

    public consuming func finish() throws(RFC_9112.Framing.Error)
        -> RFC_9112.Framing.Terminal
    {
        try framer.finish()
    }
}
