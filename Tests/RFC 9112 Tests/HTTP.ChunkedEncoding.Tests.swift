// HTTP.ChunkedEncoding.Tests.swift
// swift-rfc-9112

import Testing
@testable import RFC_9112

@Suite("HTTP.ChunkedEncoding Tests")
struct HTTPChunkedEncodingTests {

    @Test("Encode - simple data")
    func encodeSimple() async throws {
        let data = Data("Hello, World!".utf8)
        let chunked = try HTTP.ChunkedEncoding.encode(data)

        let expected = "d\r\nHello, World!\r\n0\r\n\r\n"
        #expect(String(data: chunked, encoding: .utf8) == expected)
    }

    @Test("Encode - empty data")
    func encodeEmpty() async throws {
        let data = Data()
        let chunked = try HTTP.ChunkedEncoding.encode(data)

        let expected = "0\r\n\r\n"
        #expect(String(data: chunked, encoding: .utf8) == expected)
    }

    @Test("Encode - multiple chunks")
    func encodeMultipleChunks() async throws {
        let data = Data("Hello, World! This is a longer message.".utf8)
        let chunked = try HTTP.ChunkedEncoding.encode(data, chunkSize: 10)

        let decoded = try HTTP.ChunkedEncoding.decode(chunked)
        #expect(decoded.data == data)
    }

    @Test("Encode - with trailers")
    func encodeWithTrailers() async throws {
        let data = Data("Hello".utf8)
        let trailers = [
            try HTTP.Header.Field(name: "X-Checksum", value: "abc123")
        ]
        let chunked = try HTTP.ChunkedEncoding.encode(data, trailers: trailers)

        let decoded = try HTTP.ChunkedEncoding.decode(chunked)
        #expect(decoded.data == data)
        #expect(decoded.trailers.count == 1)
        #expect(decoded.trailers[0].name.rawValue == "X-Checksum")
    }

    @Test("Decode - simple data")
    func decodeSimple() async throws {
        let chunked = Data("d\r\nHello, World!\r\n0\r\n\r\n".utf8)
        let result = try HTTP.ChunkedEncoding.decode(chunked)
        let decoded = result.data
        let trailers = result.trailers

        #expect(String(data: decoded, encoding: .utf8) == "Hello, World!")
        #expect(trailers.isEmpty)
    }

    @Test("Decode - empty data")
    func decodeEmpty() async throws {
        let chunked = Data("0\r\n\r\n".utf8)
        let result = try HTTP.ChunkedEncoding.decode(chunked)
        let decoded = result.data
        let trailers = result.trailers

        #expect(decoded.isEmpty)
        #expect(trailers.isEmpty)
    }

    @Test("Decode - multiple chunks")
    func decodeMultipleChunks() async throws {
        let chunked = Data("5\r\nHello\r\n8\r\n, World!\r\n0\r\n\r\n".utf8)
        let result = try HTTP.ChunkedEncoding.decode(chunked)
        let decoded = result.data
        let trailers = result.trailers

        #expect(String(data: decoded, encoding: .utf8) == "Hello, World!")
        #expect(trailers.isEmpty)
    }

    @Test("Decode - with trailers")
    func decodeWithTrailers() async throws {
        let chunked = Data("5\r\nHello\r\n0\r\nX-Checksum: abc123\r\n\r\n".utf8)
        let result = try HTTP.ChunkedEncoding.decode(chunked)
        let decoded = result.data
        let trailers = result.trailers

        #expect(String(data: decoded, encoding: .utf8) == "Hello")
        #expect(trailers.count == 1)
        #expect(trailers[0].name.rawValue == "X-Checksum")
        #expect(trailers[0].value.rawValue == "abc123")
    }

    @Test("Decode - multiple trailers")
    func decodeMultipleTrailers() async throws {
        let chunked = Data("5\r\nHello\r\n0\r\nX-Checksum: abc123\r\nX-Signature: xyz\r\n\r\n".utf8)
        let result = try HTTP.ChunkedEncoding.decode(chunked)
        let decoded = result.data
        let trailers = result.trailers

        #expect(String(data: decoded, encoding: .utf8) == "Hello")
        #expect(trailers.count == 2)
    }

    @Test("Decode - invalid format")
    func decodeInvalidFormat() async throws {
        let chunked = Data("invalid".utf8)

        #expect(throws: HTTP.ChunkedEncoding.ChunkedDecodingError.invalidFormat) {
            try HTTP.ChunkedEncoding.decode(chunked)
        }
    }

    @Test("Decode - invalid chunk size")
    func decodeInvalidChunkSize() async throws {
        let chunked = Data("xyz\r\ndata\r\n0\r\n\r\n".utf8)

        #expect(throws: HTTP.ChunkedEncoding.ChunkedDecodingError.invalidChunkSize) {
            try HTTP.ChunkedEncoding.decode(chunked)
        }
    }

    @Test("Decode - incomplete chunk")
    func decodeIncompleteChunk() async throws {
        let chunked = Data("10\r\nshort".utf8) // Says 16 bytes but only has 5

        #expect(throws: HTTP.ChunkedEncoding.ChunkedDecodingError.incompleteChunk) {
            try HTTP.ChunkedEncoding.decode(chunked)
        }
    }

    @Test("Decode - missing CRLF")
    func decodeMissingCRLF() async throws {
        let chunked = Data("5\r\nHelloXX0\r\n\r\n".utf8) // Missing CRLF after chunk

        #expect(throws: HTTP.ChunkedEncoding.ChunkedDecodingError.missingCRLF) {
            try HTTP.ChunkedEncoding.decode(chunked)
        }
    }

    @Test("Round trip - simple")
    func roundTripSimple() async throws {
        let original = Data("Hello, World!".utf8)
        let chunked = try HTTP.ChunkedEncoding.encode(original)
        let decoded = try HTTP.ChunkedEncoding.decode(chunked).data

        #expect(decoded == original)
    }

    @Test("Round trip - large data")
    func roundTripLarge() async throws {
        let original = Data(repeating: 0x41, count: 100000) // 100KB of 'A'
        let chunked = try HTTP.ChunkedEncoding.encode(original, chunkSize: 8192)
        let decoded = try HTTP.ChunkedEncoding.decode(chunked).data

        #expect(decoded == original)
    }

    @Test("Round trip - with trailers")
    func roundTripWithTrailers() async throws {
        let original = Data("Test data".utf8)
        let originalTrailers = [
            try HTTP.Header.Field(name: "X-Test", value: "value")
        ]

        let chunked = try HTTP.ChunkedEncoding.encode(original, trailers: originalTrailers)
        let result = try HTTP.ChunkedEncoding.decode(chunked)
        let decoded = result.data
        let decodedTrailers = result.trailers

        #expect(decoded == original)
        #expect(decodedTrailers.count == originalTrailers.count)
    }

    @Test("ChunkedDecodingError - Equatable")
    func chunkedDecodingErrorEquatable() async throws {
        #expect(HTTP.ChunkedEncoding.ChunkedDecodingError.invalidFormat == .invalidFormat)
        #expect(HTTP.ChunkedEncoding.ChunkedDecodingError.invalidFormat != .invalidChunkSize)
    }
}
