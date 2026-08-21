public import RFC_5322

extension RFC_9110 {

    public actor Pipeline {
        private var pendingRequests: [PendingRequest] = []
        private var allowPipelining: Bool

        public init(allowPipelining: Bool = true) {
            self.allowPipelining = allowPipelining
        }
    }
}

extension RFC_9110.Pipeline {

    public func addRequest(_ request: RFC_9110.Request, now: RFC_9110.Date) -> Bool {

        if !allowPipelining {

            guard pendingRequests.isEmpty else {
                return false
            }
        }

        if let last = pendingRequests.last {

            if !last.method.isIdempotent {
                return false
            }
        }

        pendingRequests.append(PendingRequest(method: request.method, timestamp: now))
        return true
    }

    public func removeOldestRequest() -> RFC_9110.Method? {
        guard !pendingRequests.isEmpty else {
            return nil
        }
        let removed = pendingRequests.removeFirst()
        return removed.method
    }

    public func nextExpectedMethod() -> RFC_9110.Method? {
        pendingRequests.first?.method
    }

    public func pendingCount() -> Int {
        pendingRequests.count
    }

    public func clear() {
        pendingRequests.removeAll()
    }

    public func canPipeline() -> Bool {
        allowPipelining
    }

    public func setPipelining(enabled: Bool) {
        allowPipelining = enabled
    }

    public static func isSafeToPipelineAfter(method: RFC_9110.Method) -> Bool {
        method.isIdempotent
    }

    public func shouldWaitForResponse(after request: RFC_9110.Request) -> Bool {

        !request.method.isIdempotent
    }

    public func oldestRequestAge(now: RFC_9110.Date) -> Int? {
        guard let oldest = pendingRequests.first else {
            return nil
        }
        return now.secondsSinceEpoch - oldest.timestamp.secondsSinceEpoch
    }

    public func hasTimedOut(now: RFC_9110.Date, timeoutSeconds: Int) -> Bool {
        guard let age = oldestRequestAge(now: now) else {
            return false
        }
        return age > timeoutSeconds
    }
}
