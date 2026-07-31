// HTTP.ChunkedEncoding.ChunkedDecodingError.swift
// swift-rfc-9112
//
// RFC 9112 Section 7.1: Chunked Transfer Coding
// https://www.rfc-editor.org/rfc/rfc9112.html#section-7.1

extension RFC_9110.ChunkedEncoding {
    /// Errors that can occur during chunked decoding
    public enum ChunkedDecodingError: Swift.Error, Sendable, Equatable {
        /// Invalid chunked encoding format
        case invalidFormat

        /// Invalid chunk size value
        case invalidChunkSize

        /// Incomplete chunk data
        case incompleteChunk

        /// Missing CRLF after chunk data
        case missingCRLF
    }
}
