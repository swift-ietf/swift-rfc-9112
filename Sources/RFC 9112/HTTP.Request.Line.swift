public import RFC_9110

extension RFC_9112.Request {
    public struct Line: Equatable {
        public let method: RFC_9110.Method
        public let target: RFC_9112.Request.Target
        public let version: RFC_9110.Version

        public init(
            method: RFC_9110.Method,
            target: RFC_9112.Request.Target,
            version: RFC_9110.Version = RFC_9112.Version.value
        ) {
            self.method = method
            self.target = target
            self.version = version
        }
    }
}
