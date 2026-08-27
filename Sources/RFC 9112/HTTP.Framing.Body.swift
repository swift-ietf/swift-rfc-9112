public import Byte_Primitives

extension RFC_9112.Framing {

    public struct Body: Equatable {

        public let content: [Byte]

        public let octets: Int

        public let trailers: RFC_9110.Message.Trailers

        public init(content: [Byte], octets: Int, trailers: RFC_9110.Message.Trailers) {
            self.content = content
            self.octets = octets
            self.trailers = trailers
        }
    }
}
