extension RFC_9110.Framing {

    public struct ResponseHead: Sendable, Equatable {

        public let line: RFC_9110.Response.Line

        public let headers: RFC_9110.Headers

        public let bodyLength: BodyLength

        public let octets: Int

        public init(
            line: RFC_9110.Response.Line,
            headers: RFC_9110.Headers,
            bodyLength: BodyLength,
            octets: Int
        ) {
            self.line = line
            self.headers = headers
            self.bodyLength = bodyLength
            self.octets = octets
        }
    }
}
