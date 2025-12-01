// HTTP.Pipeline.swift
// swift-rfc-9112

import StandardTime

extension RFC_9110 {
    /// HTTP/1.1 request/response pipelining support
    /// RFC 9112 Section 9.4: Pipelining
    ///
    /// HTTP pipelining allows clients to send multiple requests without waiting for each response.
    /// Responses must be sent in the same order as requests.
    public actor Pipeline {

        /// Pending request information
        private struct PendingRequest: Sendable {
            let method: RFC_9110.Method
            let timestamp: HTTP.Date

            init(method: RFC_9110.Method) {
                self.method = method
                fatalError()
                // TODO: fix .now for HTTP.Date()
//                self.timestamp = HTTP.Date()
            }
        }

        private var pendingRequests: [PendingRequest] = []
        private var allowPipelining: Bool

        public init(allowPipelining: Bool = true) {
            self.allowPipelining = allowPipelining
        }

        // MARK: - Request Management

        /// Add a request to the pipeline
        /// Returns: true if request can be pipelined, false otherwise
        public func addRequest(_ request: RFC_9110.Request) -> Bool {
            // RFC 9112 Section 9.4: "Clients SHOULD NOT pipeline requests after a
            // non-idempotent method, until the final response status code for that method
            // has been received"
            if !allowPipelining {
                // If pipelining disabled, only allow if no pending requests
                guard pendingRequests.isEmpty else {
                    return false
                }
            }

            // Check if we should allow pipelining after the last request
            if let last = pendingRequests.last {
                // Don't pipeline after non-idempotent methods
                if !last.method.isIdempotent {
                    return false
                }
            }

            pendingRequests.append(PendingRequest(method: request.method))
            return true
        }

        /// Remove the oldest pending request (when response received)
        /// Returns: The method of the request that was removed
        public func removeOldestRequest() -> RFC_9110.Method? {
            guard !pendingRequests.isEmpty else {
                return nil
            }
            let removed = pendingRequests.removeFirst()
            return removed.method
        }

        /// Get the method of the next expected response
        /// This is needed for proper message body length determination
        public func nextExpectedMethod() -> RFC_9110.Method? {
            pendingRequests.first?.method
        }

        /// Get count of pending requests
        public func pendingCount() -> Int {
            pendingRequests.count
        }

        /// Clear all pending requests
        public func clear() {
            pendingRequests.removeAll()
        }

        /// Check if pipelining is allowed
        public func canPipeline() -> Bool {
            allowPipelining
        }

        /// Enable or disable pipelining
        public func setPipelining(enabled: Bool) {
            allowPipelining = enabled
        }

        // MARK: - Safety Checks

        /// Check if it's safe to pipeline after this method
        /// RFC 9112: Don't pipeline after non-idempotent methods
        public static func isSafeToPipelineAfter(method: RFC_9110.Method) -> Bool {
            method.isIdempotent
        }

        /// Check if request should wait for response before sending next
        public func shouldWaitForResponse(after request: RFC_9110.Request) -> Bool {
            // Always wait after non-idempotent methods
            !request.method.isIdempotent
        }

        // MARK: - Timeout Management

        /// Get age of oldest pending request in seconds
        public func oldestRequestAge() -> Int? {
            guard let oldest = pendingRequests.first else {
                return nil
            }
            return HTTP.Date.now.secondsSinceEpoch - oldest.timestamp.secondsSinceEpoch
        }

        /// Check if any request has exceeded timeout
        public func hasTimedOut(timeoutSeconds: Int) -> Bool {
            guard let age = oldestRequestAge() else {
                return false
            }
            return age > timeoutSeconds
        }
    }
}
