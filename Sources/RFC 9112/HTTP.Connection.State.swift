// HTTP.Connection.State.swift
// swift-rfc-9112

extension RFC_9110.Connection {
    /// Connection state machine for HTTP/1.1 persistence tracking
    /// RFC 9112 Section 9.3: Persistence
    public actor State {
        private var shouldPersist: Bool
        private var version: RFC_9110.Version
        private var closeRequested: Bool

        public init(version: RFC_9110.Version = .http11) {
            self.version = version
            // HTTP/1.1 defaults to persistent
            self.shouldPersist = version.isHTTP11OrHigher
            self.closeRequested = false
        }

        // MARK: - State Queries

        /// Check if connection should persist
        public func isPersistent() -> Bool {
            !closeRequested && shouldPersist
        }

        /// Get current HTTP version
        public func getVersion() -> RFC_9110.Version {
            version
        }

        // MARK: - State Updates

        /// Update connection state based on request
        /// RFC 9112 Section 9.3.1: "close" connection option
        public func processRequest(_ request: RFC_9110.Request) {
            // Check for Connection header
            let connectionHeaders = request.headers.filter {
                $0.name.rawValue.lowercased() == "connection"
            }

            for header in connectionHeaders {
                if let conn = RFC_9110.Connection.parse(header.value.rawValue) {
                    if conn.hasClose {
                        closeRequested = true
                        shouldPersist = false
                    }
                }
            }
        }

        /// Update connection state based on response
        /// RFC 9112 Section 9.3: Persistence is determined by most recent message
        public func processResponse(_ response: RFC_9110.Response) {
            // Check for Connection header
            let connectionHeaders = response.headers.filter {
                $0.name.rawValue.lowercased() == "connection"
            }

            for header in connectionHeaders {
                if let conn = RFC_9110.Connection.parse(header.value.rawValue) {
                    if conn.hasClose {
                        closeRequested = true
                        shouldPersist = false
                    } else if conn.hasKeepAlive && version.isHTTP10 {
                        // HTTP/1.0 with keep-alive
                        shouldPersist = true
                    }
                }
            }
        }

        /// Mark connection for closure
        public func close() {
            closeRequested = true
            shouldPersist = false
        }

        /// Reset connection state (for reuse after closure)
        public func reset(version: RFC_9110.Version = .http11) {
            self.version = version
            self.shouldPersist = version.isHTTP11OrHigher
            self.closeRequested = false
        }

        // MARK: - Upgrade Support

        /// Check if upgrade is requested
        /// RFC 9112 Section 9.7: Upgrade
        public func isUpgradeRequested(in request: RFC_9110.Request) -> Bool {
            request.headers.contains { $0.name.rawValue.lowercased() == "upgrade" }
        }

        /// Check if upgrade was accepted
        public func isUpgradeAccepted(in response: RFC_9110.Response) -> Bool {
            // 101 Switching Protocols
            response.status.code == 101
        }
    }
}
