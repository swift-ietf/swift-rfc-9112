// HTTP.ChunkedEncoding.Tests.swift
// swift-rfc-9112

import Testing
@testable import RFC_9112

@Suite
struct `HTTP.ChunkedEncoding Tests` {

    @Test
    func `Encode - simple data`() async throws {
        let data = Data("Hello, World!".utf8)
        let chunked = try HTTP.ChunkedEncoding.encode(data)

        let expected = "d\r\nHello, World!\r\n0\r\n\r\n"
        #expect(String(data: chunked, encoding: .utf8) == expected)
    }

    @Test
    func `Encode - empty data`() async throws {
        let data = Data()
        let chunked = try HTTP.ChunkedEncoding.encode(data)

        let expected = "0\r\n\r\n"
        #expect(String(data: chunked, encoding: .utf8) == expected)
    }

    @Test
    func `Encode - multiple chunks`() async throws {
        let data = Data("Hello, World! This is a longer message.".utf8)
        let chunked = try HTTP.ChunkedEncoding.encode(data, chunkSize: 10)

        let decoded = try HTTP.ChunkedEncoding.decode(chunked)
        #expect(decoded.data == data)
    }

    @Test
    func `Encode - with trailers`() async throws {
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

    @Test
    func `Decode - simple data`() async throws {
        let chunked = Data("d\r\nHello, World!\r\n0\r\n\r\n".utf8)
        let result = try HTTP.ChunkedEncoding.decode(chunked)
        let decoded = result.data
        let trailers = result.trailers

        #expect(String(data: decoded, encoding: .utf8) == "Hello, World!")
        #expect(trailers.isEmpty)
    }

    @Test
    func `Decode - empty data`() async throws {
        let chunked = Data("0\r\n\r\n".utf8)
        let result = try HTTP.ChunkedEncoding.decode(chunked)
        let decoded = result.data
        let trailers = result.trailers

        #expect(decoded.isEmpty)
        #expect(trailers.isEmpty)
    }

    @Test
    func `Decode - multiple chunks`() async throws {
        let chunked = Data("5\r\nHello\r\n8\r\n, World!\r\n0\r\n\r\n".utf8)
        let result = try HTTP.ChunkedEncoding.decode(chunked)
        let decoded = result.data
        let trailers = result.trailers

        #expect(String(data: decoded, encoding: .utf8) == "Hello, World!")
        #expect(trailers.isEmpty)
    }

    @Test
    func `Decode - with trailers`() async throws {
        let chunked = Data("5\r\nHello\r\n0\r\nX-Checksum: abc123\r\n\r\n".utf8)
        let result = try HTTP.ChunkedEncoding.decode(chunked)
        let decoded = result.data
        let trailers = result.trailers

        #expect(String(data: decoded, encoding: .utf8) == "Hello")
        #expect(trailers.count == 1)
        #expect(trailers[0].name.rawValue == "X-Checksum")
        #expect(trailers[0].value.rawValue == "abc123")
    }

    @Test
    func `Decode - multiple trailers`() async throws {
        let chunked = Data("5\r\nHello\r\n0\r\nX-Checksum: abc123\r\nX-Signature: xyz\r\n\r\n".utf8)
        let result = try HTTP.ChunkedEncoding.decode(chunked)
        let decoded = result.data
        let trailers = result.trailers

        #expect(String(data: decoded, encoding: .utf8) == "Hello")
        #expect(trailers.count == 2)
    }

    @Test
    func `Decode - invalid format`() async throws {
        let chunked = Data("invalid".utf8)

        #expect(throws: HTTP.ChunkedEncoding.ChunkedDecodingError.invalidFormat) {
            try HTTP.ChunkedEncoding.decode(chunked)
        }
    }

    @Test
    func `Decode - invalid chunk size`() async throws {
        let chunked = Data("xyz\r\ndata\r\n0\r\n\r\n".utf8)

        #expect(throws: HTTP.ChunkedEncoding.ChunkedDecodingError.invalidChunkSize) {
            try HTTP.ChunkedEncoding.decode(chunked)
        }
    }

    @Test
    func `Decode - incomplete chunk`() async throws {
        let chunked = Data("10\r\nshort".utf8) // Says 16 bytes but only has 5

        #expect(throws: HTTP.ChunkedEncoding.ChunkedDecodingError.incompleteChunk) {
            try HTTP.ChunkedEncoding.decode(chunked)
        }
    }

    @Test
    func `Decode - missing CRLF`() async throws {
        let chunked = Data("5\r\nHelloXX0\r\n\r\n".utf8) // Missing CRLF after chunk

        #expect(throws: HTTP.ChunkedEncoding.ChunkedDecodingError.missingCRLF) {
            try HTTP.ChunkedEncoding.decode(chunked)
        }
    }

    @Test
    func `Round trip - simple`() async throws {
        let original = Data("Hello, World!".utf8)
        let chunked = try HTTP.ChunkedEncoding.encode(original)
        let decoded = try HTTP.ChunkedEncoding.decode(chunked).data

        #expect(decoded == original)
    }

    @Test
    func `Round trip - large data`() async throws {
        let original = Data(repeating: 0x41, count: 100000) // 100KB of 'A'
        let chunked = try HTTP.ChunkedEncoding.encode(original, chunkSize: 8192)
        let decoded = try HTTP.ChunkedEncoding.decode(chunked).data

        #expect(decoded == original)
    }

    @Test
    func `Round trip - with trailers`() async throws {
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

    @Test
    func `ChunkedDecodingError - Equatable`() async throws {
        #expect(HTTP.ChunkedEncoding.ChunkedDecodingError.invalidFormat == .invalidFormat)
        #expect(HTTP.ChunkedEncoding.ChunkedDecodingError.invalidFormat != .invalidChunkSize)
    }
}
