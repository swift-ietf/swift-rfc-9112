extension RFC_9112.Framing.Response {
    public struct Head: Equatable {

        public let line: RFC_9112.Response.Line

        public let headers: RFC_9110.Message.Headers

        public let length: RFC_9112.Framing.Body.Length

        public let octets: Int

        public init(
            line: RFC_9112.Response.Line,
            headers: RFC_9110.Message.Headers,
            length: RFC_9112.Framing.Body.Length,
            octets: Int
        ) {
            self.line = line
            self.headers = headers
            self.length = length
            self.octets = octets
        }
    }
}
