public import Byte
public import RFC_9110

extension RFC_9112.Message {

    public struct Body: Equatable {

        public let content: [Byte]

        public let trailers: RFC_9110.Message.Trailers

        public init(content: [Byte], trailers: RFC_9110.Message.Trailers = .init()) {
            self.content = content
            self.trailers = trailers
        }
    }
}
