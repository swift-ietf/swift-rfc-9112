extension RFC_9110.Connection {

    public actor State {
        private var shouldPersist: Bool
        private var version: RFC_9110.Version
        private var closeRequested: Bool

        public init(version: RFC_9110.Version = .http11) {
            self.version = version

            self.shouldPersist = version.isHTTP11OrHigher
            self.closeRequested = false
        }
    }
}

extension RFC_9110.Connection.State {

    public func isPersistent() -> Bool {
        !closeRequested && shouldPersist
    }

    public func getVersion() -> RFC_9110.Version {
        version
    }

    public func processRequest(_ request: RFC_9110.Request) {

        let connectionHeaders = request.headers.filter {
            $0.name.description.lowercased() == "connection"
        }

        for header in connectionHeaders {
            if let conn = RFC_9110.Connection.parse(header.value.description) {
                if conn.hasClose {
                    closeRequested = true
                    shouldPersist = false
                }
            }
        }
    }

    public func processResponse(_ response: RFC_9110.Response) {

        let connectionHeaders = response.headers.filter {
            $0.name.description.lowercased() == "connection"
        }

        for header in connectionHeaders {
            if let conn = RFC_9110.Connection.parse(header.value.description) {
                if conn.hasClose {
                    closeRequested = true
                    shouldPersist = false
                } else if conn.hasKeepAlive && version.isHTTP10 {

                    shouldPersist = true
                }
            }
        }
    }

    public func close() {
        closeRequested = true
        shouldPersist = false
    }

    public func reset(version: RFC_9110.Version = .http11) {
        self.version = version
        self.shouldPersist = version.isHTTP11OrHigher
        self.closeRequested = false
    }

    public func isUpgradeRequested(in request: RFC_9110.Request) -> Bool {
        request.headers.contains { $0.name.description.lowercased() == "upgrade" }
    }

    public func isUpgradeAccepted(in response: RFC_9110.Response) -> Bool {

        response.status.code == 101
    }
}
