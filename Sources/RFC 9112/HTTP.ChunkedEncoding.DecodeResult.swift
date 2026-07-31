// HTTP.ChunkedEncoding.DecodeResult.swift
// swift-rfc-9112
//
// RFC 9112 Section 7.1: Chunked Transfer Coding
// https://www.rfc-editor.org/rfc/rfc9112.html#section-7.1

public import Byte_Primitives

extension RFC_9110.ChunkedEncoding {
    /// Result of decoding chunked data
    public struct DecodeResult: Sendable, Equatable {
        public let data: [Byte]
        public let chunkExtensions: [[Extension]]  // Extensions for each chunk
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
