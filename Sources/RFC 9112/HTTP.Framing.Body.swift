public import Byte_Primitives

extension RFC_9110.Framing {

    public struct Body: Sendable, Equatable {

        public let content: [Byte]

        public let octets: Int

        public let trailers: RFC_9110.Headers

        public init(content: [Byte], octets: Int, trailers: RFC_9110.Headers) {
            self.content = content
            self.octets = octets
            self.trailers = trailers
        }
    }
}
