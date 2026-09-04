public import RFC_9110

extension RFC_9112.Connection {

    public struct State: Equatable, Hashable {

        public private(set) var version: RFC_9110.Version

        public private(set) var persists: Bool

        public private(set) var closeRequested: Bool

        public init(version: RFC_9110.Version = RFC_9112.Version.value) {
            self.version = version
            self.persists = version >= RFC_9112.Version.value
            self.closeRequested = false
        }
    }
}

extension RFC_9112.Connection.State {

    public var isPersistent: Bool {
        !closeRequested && persists
    }

    public mutating func apply(_ connection: RFC_9112.Connection) {
        if connection.hasClose {
            closeRequested = true
            persists = false
            return
        }

        if connection.hasKeepAlive, version < RFC_9112.Version.value {
            persists = true
        }
    }

    public mutating func close() {
        closeRequested = true
        persists = false
    }

    public mutating func reset(version: RFC_9110.Version = RFC_9112.Version.value) {
        self = Self(version: version)
    }
}
