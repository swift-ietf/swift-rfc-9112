extension RFC_9112.Message {
    public struct Request<Content> {
        public var version: RFC_9110.Version
        public var method: RFC_9110.Method
        public var target: RFC_9112.Request.Target
        public var headers: RFC_9110.Message.Headers
        public var content: Content?
        public var trailers: RFC_9110.Message.Trailers

        public init(
            version: RFC_9110.Version = RFC_9112.Version.value,
            method: RFC_9110.Method,
            target: RFC_9112.Request.Target,
            headers: RFC_9110.Message.Headers = [],
            content: Content? = nil,
            trailers: RFC_9110.Message.Trailers = []
        ) {
            self.version = version
            self.method = method
            self.target = target
            self.headers = headers
            self.content = content
            self.trailers = trailers
        }
    }
}

extension RFC_9112.Message.Request: Equatable where Content: Equatable {}
extension RFC_9112.Message.Request: Hashable where Content: Hashable {}

extension RFC_9112.Message.Request {
    public init(
        _ request: RFC_9110.Message.Request<Content>,
        version: RFC_9110.Version = RFC_9112.Version.value
    ) throws(RFC_9112.Request.Target.Error) {
        self.init(
            version: version,
            method: request.method,
            target: try RFC_9112.Request.Target(request.target),
            headers: request.headers,
            content: request.content,
            trailers: request.trailers
        )
    }

    public var semantic: RFC_9110.Message.Request<Content> {
        .init(
            method: method,
            target: target.semantic,
            headers: headers,
            content: content,
            trailers: trailers
        )
    }
}
