public import Byte_Primitives

extension RFC_9110.ChunkedEncoding {

    public struct DecodeResult: Sendable, Equatable {
        public let data: [Byte]
        public let chunkExtensions: [[Extension]]
        public let trailers: [RFC_9110.Header.Field]

        public init(
            data: [Byte],
            chunkExtensions: [[Extension]],
            trailers: [RFC_9110.Header.Field]
        ) {
            self.data = data
            self.chunkExtensions = chunkExtensions
            self.trailers = trailers
        }
    }
}
