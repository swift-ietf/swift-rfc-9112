public import RFC_9110

extension RFC_9112.Response {

    public struct Head: Equatable {

        public let line: RFC_9112.Response.Line

        public let headers: RFC_9110.Message.Headers

        public let length: RFC_9112.Message.Body.Length

        public init(
            line: RFC_9112.Response.Line,
            headers: RFC_9110.Message.Headers = [],
            length: RFC_9112.Message.Body.Length = .none
        ) {
            self.line = line
            self.headers = headers
            self.length = length
        }
    }
}
