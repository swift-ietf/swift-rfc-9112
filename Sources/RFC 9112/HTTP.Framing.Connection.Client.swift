public import Byte_Primitives

extension RFC_9110.Framing.Connection {

    public struct Client: ~Copyable {

        private var framer: RFC_9110.Framing.Framer

        private var state: State

        private var expected: [RFC_9110.Method]

        private var closed: Bool

        private var pending: Event?

        private var delivered: Int

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

extension RFC_9110.Framing.Connection.Client {

    public mutating func expect(_ method: RFC_9110.Method) {
        expected.append(method)
    }

    public var outstanding: Int { expected.count }

    public var unconsumed: Int { framer.unconsumed }

    public var isReusable: Bool {
        switch state {
        case .head, .body: true
        case .tunnelled, .finished: false
        }
    }
}

extension RFC_9110.Framing.Connection.Client {

    public mutating func receive(_ bytes: [Byte]) throws(RFC_9110.Framing.Error) {
        try framer.append(bytes, accumulating: state.phase)
    }

    public mutating func peerClosed() {
        closed = true
    }
}

extension RFC_9110.Framing.Connection.Client {

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

    private mutating func nextHead() throws(RFC_9110.Framing.Error)
        -> RFC_9110.Framing.Connection.Client.Event?
    {
        guard let method = expected.first else {
            throw .responseWithoutRequest
        }

        guard let head = try framer.nextResponseHead(answering: method) else { return nil }
        expected.removeFirst()

        delivered = 0
        closeAfterMessage = Self.requestsClose(head.headers)
        state = .body(head.bodyLength)
        return .head(head)
    }

    private static func requestsClose(_ headers: RFC_9110.Headers) -> Bool {

        headers.values("Connection")
            .compactMap { RFC_9110.Connection.parse($0.description) }
            .contains { $0.hasClose }
    }

    private mutating func nextBody(
        _ bodyLength: RFC_9110.Framing.BodyLength
    ) throws(RFC_9110.Framing.Error) -> RFC_9110.Framing.Connection.Client.Event? {
        switch bodyLength {
        case .tunnel:

            state = .tunnelled
            return .tunnel

        case .untilClose:
            return deliverUntilClose()

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

        state = .finished
        return .end(trailers: RFC_9110.Headers([]), octets: octets)
    }
}

extension RFC_9110.Framing.Connection.Client {

    public consuming func surrenderTunnel() -> [Byte] {
        framer.surrenderUnconsumed()
    }

    public consuming func finish() throws(RFC_9110.Framing.Error)
        -> RFC_9110.Framing.Terminal
    {
        try framer.finish()
    }
}
