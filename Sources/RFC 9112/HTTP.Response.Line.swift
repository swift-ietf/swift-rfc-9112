public import RFC_9110

extension RFC_9112.Response {
    public struct Line: Equatable {
        public let version: RFC_9110.Version
        public let status: RFC_9110.Status
        public let reason: RFC_9110.Status.Reason?

        public init(
            version: RFC_9110.Version = RFC_9112.Version.value,
            status: RFC_9110.Status,
            reason: RFC_9110.Status.Reason? = nil
        ) {
            self.version = version
            self.status = status
            self.reason = reason
        }
    }
}
