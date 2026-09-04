public import RFC_9110

extension RFC_9112.Connection {

    public struct Client: Equatable {

        public private(set) var state: State

        public private(set) var expected: [RFC_9110.Method]

        public private(set) var closesAfterMessage: Bool

        public private(set) var closed: Bool

        public init() {
            self.state = .head
            self.expected = []
            self.closesAfterMessage = false
            self.closed = false
        }
    }
}

extension RFC_9112.Connection.Client {

    public var answering: RFC_9110.Method? {
        expected.first
    }

    public var outstanding: Int {
        expected.count
    }

    public var isReusable: Bool {
        switch state {
        case .head, .body: true
        case .tunnelled, .finished: false
        }
    }
}

extension RFC_9112.Connection.Client {

    public mutating func expect(_ method: RFC_9110.Method) {
        expected.append(method)
    }

    public mutating func apply(_ event: Event) throws(Error) {
        switch event {
        case .head(let head, let connection):
            guard case .head = state else { throw .unexpectedHead }
            guard !expected.isEmpty else { throw .responseWithoutRequest }
            expected.removeFirst()
            closesAfterMessage = connection?.hasClose ?? false
            state = head.length == .tunnel ? .tunnelled : .body(head.length)

        case .end:
            guard case .body = state else { throw .unexpectedEnd }
            state = closesAfterMessage ? .finished : .head
            closesAfterMessage = false

        case .close:
            closed = true
            if case .body(.untilClose) = state {
                state = .finished
            }
        }
    }
}
