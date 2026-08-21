public import Byte_Primitives

extension RFC_9110.Framing.Connection {

    public struct Server: ~Copyable {

        private var framer: RFC_9110.Framing.Framer

        private var state: State

        private var pending: Event?

        private var closeAfterMessage: Bool

        public init(limits: RFC_9110.Framing.Limits = .default) {
            self.framer = RFC_9110.Framing.Framer(limits: limits)
            self.state = .head
            self.pending = nil
            self.closeAfterMessage = false
        }
    }
}

extension RFC_9110.Framing.Connection.Server {

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

extension RFC_9110.Framing.Connection.Server {

    public mutating func receive(_ bytes: [Byte]) throws(RFC_9110.Framing.Error) {
        try framer.append(bytes, accumulating: state.phase)
    }
}

extension RFC_9110.Framing.Connection.Server {

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

    private mutating func nextBody(
        _ bodyLength: RFC_9110.Framing.BodyLength
    ) throws(RFC_9110.Framing.Error) -> RFC_9110.Framing.Connection.Server.Event? {
        switch bodyLength {
        case .untilClose, .tunnel:

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

    private static func requestsClose(_ headers: RFC_9110.Headers) -> Bool {
        headers.values("Connection")
            .compactMap { RFC_9110.Connection.parse($0.description) }
            .contains { $0.hasClose }
    }
}

extension RFC_9110.Framing.Connection.Server {

    public consuming func finish() throws(RFC_9110.Framing.Error)
        -> RFC_9110.Framing.Terminal
    {
        try framer.finish()
    }
}
