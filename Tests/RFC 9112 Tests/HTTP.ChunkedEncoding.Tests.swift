// HTTP.ChunkedEncoding.Tests.swift
// swift-rfc-9112

import Testing

import Byte_Primitives
import Byte_Primitives_Standard_Library_Integration
@testable import RFC_9112

@Suite
struct `HTTP.ChunkedEncoding Tests` {

    @Test
    func `Encode - simple data`() async throws {
        let data = Array("Hello, World!".utf8).map { Byte($0) }
        let chunked = HTTP.ChunkedEncoding.encode(data)

        let expected = "d\r\nHello, World!\r\n0\r\n\r\n"
        #expect(String(decoding:chunked, as: UTF8.self) == expected)
    }

    @Test
    func `Encode - empty data`() async throws {
        let data = [Byte]()
        let chunked = HTTP.ChunkedEncoding.encode(data)

        let expected = "0\r\n\r\n"
        #expect(String(decoding:chunked, as: UTF8.self) == expected)
    }

    @Test
    func `Encode - multiple chunks`() async throws {
        let data = Array("Hello, World! This is a longer message.".utf8).map { Byte($0) }
        let chunked = HTTP.ChunkedEncoding.encode(data, chunkSize: 10)

        let decoded = try HTTP.ChunkedEncoding.decode(chunked)
        #expect(decoded.data == data)
    }

    @Test
    func `Encode - with trailers`() async throws {
        let data = Array("Hello".utf8).map { Byte($0) }
        let trailers = [
            try HTTP.Header.Field(name: "X-Checksum", value: "abc123")
        ]
        let chunked = HTTP.ChunkedEncoding.encode(data, trailers: trailers)

        let decoded = try HTTP.ChunkedEncoding.decode(chunked)
        #expect(decoded.data == data)
        #expect(decoded.trailers.count == 1)
        #expect(decoded.trailers[0].name.rawValue == "X-Checksum")
    }

    @Test
    func `Decode - simple data`() async throws {
        let chunked = Array("d\r\nHello, World!\r\n0\r\n\r\n".utf8).map { Byte($0) }
        let result = try HTTP.ChunkedEncoding.decode(chunked)
        let decoded = result.data
        let trailers = result.trailers

        #expect(String(decoding:decoded, as: UTF8.self) == "Hello, World!")
        #expect(trailers.isEmpty)
    }

    @Test
    func `Decode - empty data`() async throws {
        let chunked = Array("0\r\n\r\n".utf8).map { Byte($0) }
        let result = try HTTP.ChunkedEncoding.decode(chunked)
        let decoded = result.data
        let trailers = result.trailers

        #expect(decoded.isEmpty)
        #expect(trailers.isEmpty)
    }

    @Test
    func `Decode - multiple chunks`() async throws {
        let chunked = Array("5\r\nHello\r\n8\r\n, World!\r\n0\r\n\r\n".utf8).map { Byte($0) }
        let result = try HTTP.ChunkedEncoding.decode(chunked)
        let decoded = result.data
        let trailers = result.trailers

        #expect(String(decoding:decoded, as: UTF8.self) == "Hello, World!")
        #expect(trailers.isEmpty)
    }

    @Test
    func `Decode - with trailers`() async throws {
        let chunked = Array("5\r\nHello\r\n0\r\nX-Checksum: abc123\r\n\r\n".utf8).map { Byte($0) }
        let result = try HTTP.ChunkedEncoding.decode(chunked)
        let decoded = result.data
        let trailers = result.trailers

        #expect(String(decoding:decoded, as: UTF8.self) == "Hello")
        #expect(trailers.count == 1)
        #expect(trailers[0].name.rawValue == "X-Checksum")
        #expect(trailers[0].value.rawValue == "abc123")
    }

    @Test
    func `Decode - multiple trailers`() async throws {
        let chunked = Array("5\r\nHello\r\n0\r\nX-Checksum: abc123\r\nX-Signature: xyz\r\n\r\n".utf8).map { Byte($0) }
        let result = try HTTP.ChunkedEncoding.decode(chunked)
        let decoded = result.data
        let trailers = result.trailers

        #expect(String(decoding:decoded, as: UTF8.self) == "Hello")
        #expect(trailers.count == 2)
    }

    @Test
    func `Decode - invalid format`() async throws {
        let chunked = Array("invalid".utf8).map { Byte($0) }

        #expect(throws: HTTP.ChunkedEncoding.ChunkedDecodingError.invalidFormat) {
            try HTTP.ChunkedEncoding.decode(chunked)
        }
    }

    @Test
    func `Decode - invalid chunk size`() async throws {
        let chunked = Array("xyz\r\ndata\r\n0\r\n\r\n".utf8).map { Byte($0) }

        #expect(throws: HTTP.ChunkedEncoding.ChunkedDecodingError.invalidChunkSize) {
            try HTTP.ChunkedEncoding.decode(chunked)
        }
    }

    @Test
    func `Decode - incomplete chunk`() async throws {
        let chunked = Array("10\r\nshort".utf8).map { Byte($0) }  // Says 16 bytes but only has 5

        #expect(throws: HTTP.ChunkedEncoding.ChunkedDecodingError.incompleteChunk) {
            try HTTP.ChunkedEncoding.decode(chunked)
        }
    }

    @Test
    func `Decode - missing CRLF`() async throws {
        let chunked = Array("5\r\nHelloXX0\r\n\r\n".utf8).map { Byte($0) }  // Missing CRLF after chunk

        #expect(throws: HTTP.ChunkedEncoding.ChunkedDecodingError.missingCRLF) {
            try HTTP.ChunkedEncoding.decode(chunked)
        }
    }

    @Test
    func `Round trip - simple`() async throws {
        let original = Array("Hello, World!".utf8).map { Byte($0) }
        let chunked = HTTP.ChunkedEncoding.encode(original)
        let decoded = try HTTP.ChunkedEncoding.decode(chunked).data

        #expect(decoded == original)
    }

    @Test
    func `Round trip - large data`() async throws {
        let original = [Byte](repeating: 0x41, count: 100000)  // 100KB of 'A'
        let chunked = HTTP.ChunkedEncoding.encode(original, chunkSize: 8192)
        let decoded = try HTTP.ChunkedEncoding.decode(chunked).data

        #expect(decoded == original)
    }

    @Test
    func `Round trip - with trailers`() async throws {
        let original = Array("Test data".utf8).map { Byte($0) }
        let originalTrailers = [
            try HTTP.Header.Field(name: "X-Test", value: "value")
        ]

        let chunked = HTTP.ChunkedEncoding.encode(original, trailers: originalTrailers)
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
