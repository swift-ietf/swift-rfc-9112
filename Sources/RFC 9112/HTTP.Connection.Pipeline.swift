public import RFC_5322
public import RFC_9110

extension RFC_9112.Connection {

    public struct Pipeline: Equatable {

        public private(set) var pending: [Pending]

        public var allowsPipelining: Bool

        public init(allowsPipelining: Bool = true) {
            self.pending = []
            self.allowsPipelining = allowsPipelining
        }
    }
}

extension RFC_9112.Connection.Pipeline {

    public var count: Int {
        pending.count
    }

    public var next: RFC_9110.Method? {
        pending.first?.method
    }

    public var waits: Bool {
        guard let last = pending.last else { return false }
        return !last.method.isIdempotent
    }
}

extension RFC_9112.Connection.Pipeline {

    public mutating func append<Content>(
        _ request: RFC_9112.Message.Request<Content>,
        at moment: RFC_9110.Date
    ) -> Bool {
        if !allowsPipelining, !pending.isEmpty { return false }
        if waits { return false }

        pending.append(Pending(method: request.method, moment: moment))
        return true
    }

    public mutating func removeFirst() -> RFC_9110.Method? {
        guard !pending.isEmpty else { return nil }
        return pending.removeFirst().method
    }

    public mutating func removeAll() {
        pending.removeAll()
    }
}

extension RFC_9112.Connection.Pipeline {

    public func age(at moment: RFC_9110.Date) -> Int? {
        guard let oldest = pending.first else { return nil }
        return moment.secondsSinceEpoch - oldest.moment.secondsSinceEpoch
    }

    public func hasTimedOut(at moment: RFC_9110.Date, after seconds: Int) -> Bool {
        guard let age = age(at: moment) else { return false }
        return age > seconds
    }
}
