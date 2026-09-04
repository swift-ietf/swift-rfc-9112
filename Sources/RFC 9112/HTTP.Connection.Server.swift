extension RFC_9112.Connection {

    public struct Server: Equatable {

        public private(set) var state: State

        public private(set) var closesAfterMessage: Bool

        public private(set) var closed: Bool

        public init() {
            self.state = .head
            self.closesAfterMessage = false
            self.closed = false
        }
    }
}

extension RFC_9112.Connection.Server {

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

extension RFC_9112.Connection.Server {

    public mutating func apply(_ event: Event) throws(Error) {
        switch event {
        case .head(let head, let connection):
            guard case .head = state else { throw .unexpectedHead }
            switch head.length {
            case .untilClose, .tunnel: throw .closeDelimitedRequest
            case .none, .length, .chunked: break
            }
            closesAfterMessage = connection?.hasClose ?? false
            state = .body(head.length)

        case .end:
            guard case .body = state else { throw .unexpectedEnd }
            state = closesAfterMessage ? .finished : .head
            closesAfterMessage = false

        case .close:
            closed = true
            state = .finished
        }
    }
}
