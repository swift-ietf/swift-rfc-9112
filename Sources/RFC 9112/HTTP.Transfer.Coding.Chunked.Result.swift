public import Byte
public import RFC_9110

extension RFC_9112.Transfer.Coding.Chunked {

    public struct Result: Equatable {
        public let data: [Byte]
        public let extensions: [[Extension]]
        public let trailers: [RFC_9110.Field]

        public init(
            data: [Byte],
            extensions: [[Extension]],
            trailers: [RFC_9110.Field]
        ) {
            self.data = data
            self.extensions = extensions
            self.trailers = trailers
        }
    }
}
