public import RFC_9112
import RFC_9112_Parser
public import RFC_9110

public import Byte

extension RFC_9112.Framing.Connection {

    public struct Client: ~Copyable {

        private var framer: RFC_9112.Framing.Framer

        private var state: State

        private var expected: [RFC_9110.Method]

        private var closed: Bool

        private var pending: Event?

        private var delivered: Int

        private var closeAfterMessage: Bool

        public init(limits: RFC_9112.Framing.Limits = .default) {
            self.framer = RFC_9112.Framing.Framer(limits: limits)
            self.state = .head
            self.expected = []
            self.closed = false
            self.pending = nil
            self.delivered = 0
            self.closeAfterMessage = false
        }
    }
}

extension RFC_9112.Framing.Connection.Client {

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

extension RFC_9112.Framing.Connection.Client {

    public mutating func receive(_ bytes: [Byte]) throws(RFC_9112.Framing.Error) {
        try framer.append(bytes, accumulating: state.phase)
    }

    public mutating func peerClosed() {
        closed = true
    }
}

extension RFC_9112.Framing.Connection.Client {

    public mutating func next() throws(RFC_9112.Framing.Error)
        -> RFC_9112.Framing.Connection.Client.Event?
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

    private mutating func nextHead() throws(RFC_9112.Framing.Error)
        -> RFC_9112.Framing.Connection.Client.Event?
    {
        guard let method = expected.first else {
            throw .responseWithoutRequest
        }

        guard let head = try framer.nextResponseHead(answering: method) else { return nil }
        expected.removeFirst()

        delivered = 0
        closeAfterMessage = Self.requestsClose(head.headers)
        state = .body(head.length)
        return .head(head)
    }

    private static func requestsClose(_ headers: RFC_9110.Message.Headers) -> Bool {

        headers.values(.connection)
            .compactMap { RFC_9112.Connection.parse($0.description) }
            .contains { $0.hasClose }
    }

    private mutating func nextBody(
        _ length: RFC_9112.Framing.Body.Length
    ) throws(RFC_9112.Framing.Error) -> RFC_9112.Framing.Connection.Client.Event? {
        switch length {
        case .tunnel:

            state = .tunnelled
            return .tunnel

        case .untilClose:
            return deliverUntilClose()

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

    private mutating func deliverUntilClose()
        -> RFC_9112.Framing.Connection.Client.Event?
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
        return .end(trailers: RFC_9110.Message.Trailers(), octets: octets)
    }
}

extension RFC_9112.Framing.Connection.Client {

    public consuming func surrenderTunnel() -> [Byte] {
        framer.surrenderUnconsumed()
    }

    public consuming func finish() throws(RFC_9112.Framing.Error)
        -> RFC_9112.Framing.Terminal
    {
        try framer.finish()
    }
}
