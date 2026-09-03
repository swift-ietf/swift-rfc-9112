public import RFC_9110

extension RFC_9112.Connection {

    public actor State {
        package var shouldPersist: Bool
        package var version: RFC_9110.Version
        package var closeRequested: Bool

        public init(version: RFC_9110.Version = RFC_9112.Version.value) {
            self.version = version

            self.shouldPersist = version >= RFC_9112.Version.value
            self.closeRequested = false
        }
    }
}
