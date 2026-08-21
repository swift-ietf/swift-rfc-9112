extension RFC_9110.Framing {

    public struct RequestHead: Sendable, Equatable {

        public let line: RFC_9110.Request.Line

        public let headers: RFC_9110.Headers

        public let bodyLength: BodyLength

        public let octets: Int

        public init(
            line: RFC_9110.Request.Line,
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
