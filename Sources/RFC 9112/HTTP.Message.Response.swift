extension RFC_9112.Message {
    public struct Response<Content> {
        public var version: RFC_9110.Version
        public var status: RFC_9110.Status
        public var reason: RFC_9110.Status.Reason?
        public var headers: RFC_9110.Message.Headers
        public var content: Content?
        public var trailers: RFC_9110.Message.Trailers

        public init(
            version: RFC_9110.Version = RFC_9112.Version.value,
            status: RFC_9110.Status,
            reason: RFC_9110.Status.Reason? = nil,
            headers: RFC_9110.Message.Headers = [],
            content: Content? = nil,
            trailers: RFC_9110.Message.Trailers = []
        ) {
            self.version = version
            self.status = status
            self.reason = reason
            self.headers = headers
            self.content = content
            self.trailers = trailers
        }
    }
}

extension RFC_9112.Message.Response: Equatable where Content: Equatable {}
extension RFC_9112.Message.Response: Hashable where Content: Hashable {}

extension RFC_9112.Message.Response {
    public init(
        _ response: RFC_9110.Message.Response<Content>,
        version: RFC_9110.Version = RFC_9112.Version.value
    ) {
        self.init(
            version: version,
            status: response.status,
            reason: response.reason,
            headers: response.headers,
            content: response.content,
            trailers: response.trailers
        )
    }

    public var semantic: RFC_9110.Message.Response<Content> {
        .init(
            status: status,
            reason: reason,
            headers: headers,
            content: content,
            trailers: trailers
        )
    }
}
