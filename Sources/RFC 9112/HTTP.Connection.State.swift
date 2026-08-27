extension RFC_9112.Connection {

    public actor State {
        private var shouldPersist: Bool
        private var version: RFC_9110.Version
        private var closeRequested: Bool

        public init(version: RFC_9110.Version = RFC_9112.Version.value) {
            self.version = version

            self.shouldPersist = version >= RFC_9112.Version.value
            self.closeRequested = false
        }
    }
}

extension RFC_9112.Connection.State {

    public func isPersistent() -> Bool {
        !closeRequested && shouldPersist
    }

    public func getVersion() -> RFC_9110.Version {
        version
    }

    public func process<Content>(_ request: RFC_9112.Message.Request<Content>) {

        let connectionHeaders = request.headers.filter {
            $0.name.description.lowercased() == "connection"
        }

        for header in connectionHeaders {
            if let conn = RFC_9112.Connection.parse(header.value.description) {
                if conn.hasClose {
                    closeRequested = true
                    shouldPersist = false
                }
            }
        }
    }

    public func process<Content>(_ response: RFC_9112.Message.Response<Content>) {

        let connectionHeaders = response.headers.filter {
            $0.name.description.lowercased() == "connection"
        }

        for header in connectionHeaders {
            if let conn = RFC_9112.Connection.parse(header.value.description) {
                if conn.hasClose {
                    closeRequested = true
                    shouldPersist = false
                } else if conn.hasKeepAlive && version.major == 1 && version.minor == 0 {

                    shouldPersist = true
                }
            }
        }
    }

    public func close() {
        closeRequested = true
        shouldPersist = false
    }

    public func reset(version: RFC_9110.Version = RFC_9112.Version.value) {
        self.version = version
        self.shouldPersist = version >= RFC_9112.Version.value
        self.closeRequested = false
    }

    public func requestsUpgrade<Content>(
        _ request: RFC_9112.Message.Request<Content>
    ) -> Bool {
        request.headers.contains { $0.name.description.lowercased() == "upgrade" }
    }

    public func acceptsUpgrade<Content>(
        _ response: RFC_9112.Message.Response<Content>
    ) -> Bool {

        response.status.code == 101
    }
}
