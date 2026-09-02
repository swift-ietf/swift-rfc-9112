import RFC_9110
import Byte
import Byte_Standard_Library_Integration
import Testing

@testable import RFC_9112

@Suite
struct `HTTP.Transfer.Coding.Chunked Tests` {

    @Suite
    struct Unit {
        @Test
        func `Encode - simple data`() async throws {
            let data = Array("Hello, World!".utf8).map { Byte(bitPattern: $0) }
            let chunked = HTTP.Transfer.Coding.Chunked.encode(data)

            let expected = "d\r\nHello, World!\r\n0\r\n\r\n"
            #expect(String(decoding: chunked, as: UTF8.self) == expected)
        }

        @Test
        func `Encode - empty data`() async throws {
            let data = [Byte]()
            let chunked = HTTP.Transfer.Coding.Chunked.encode(data)

            let expected = "0\r\n\r\n"
            #expect(String(decoding: chunked, as: UTF8.self) == expected)
        }

        @Test
        func `Decode - simple data`() async throws {
            let chunked = Array("d\r\nHello, World!\r\n0\r\n\r\n".utf8).map { Byte(bitPattern: $0) }
            let result = try HTTP.Transfer.Coding.Chunked.decode(chunked)
            let decoded = result.data
            let trailers = result.trailers

            #expect(String(decoding: decoded, as: UTF8.self) == "Hello, World!")
            #expect(trailers.isEmpty)
        }

        @Test
        func `Decode - empty data`() async throws {
            let chunked = Array("0\r\n\r\n".utf8).map { Byte(bitPattern: $0) }
            let result = try HTTP.Transfer.Coding.Chunked.decode(chunked)
            let decoded = result.data
            let trailers = result.trailers

            #expect(decoded.isEmpty)
            #expect(trailers.isEmpty)
        }

        @Test
        func `ChunkedDecodingError - Equatable`() async throws {
            #expect(HTTP.Transfer.Coding.Chunked.Error.invalidFormat == .invalidFormat)
            #expect(HTTP.Transfer.Coding.Chunked.Error.invalidFormat != .invalidChunkSize)
        }
    }

    @Suite
    struct `Edge Case` {
        @Test
        func `Encode - multiple chunks`() async throws {
            let data = Array("Hello, World! This is a longer message.".utf8).map { Byte(bitPattern: $0) }
            let chunked = HTTP.Transfer.Coding.Chunked.encode(data, chunkSize: 10)

            let decoded = try HTTP.Transfer.Coding.Chunked.decode(chunked)
            #expect(decoded.data == data)
        }

        @Test
        func `Encode - with trailers`() async throws {
            let data = Array("Hello".utf8).map { Byte(bitPattern: $0) }
            let trailers = [
                try RFC_9110.Field(name: "X-Checksum", value: "abc123")
            ]
            let chunked = HTTP.Transfer.Coding.Chunked.encode(data, trailers: trailers)

            let decoded = try HTTP.Transfer.Coding.Chunked.decode(chunked)
            #expect(decoded.data == data)
            #expect(decoded.trailers.count == 1)
            #expect(decoded.trailers[0].name.description == "X-Checksum")
        }

        @Test
        func `Decode - multiple chunks`() async throws {
            let chunked = Array("5\r\nHello\r\n8\r\n, World!\r\n0\r\n\r\n".utf8).map { Byte(bitPattern: $0) }
            let result = try HTTP.Transfer.Coding.Chunked.decode(chunked)
            let decoded = result.data
            let trailers = result.trailers

            #expect(String(decoding: decoded, as: UTF8.self) == "Hello, World!")
            #expect(trailers.isEmpty)
        }

        @Test
        func `Decode - with trailers`() async throws {
            let chunked = Array("5\r\nHello\r\n0\r\nX-Checksum: abc123\r\n\r\n".utf8).map {
                Byte(bitPattern: $0)
            }
            let result = try HTTP.Transfer.Coding.Chunked.decode(chunked)
            let decoded = result.data
            let trailers = result.trailers

            #expect(String(decoding: decoded, as: UTF8.self) == "Hello")
            #expect(trailers.count == 1)
            #expect(trailers[0].name.description == "X-Checksum")
            #expect(trailers[0].value.description == "abc123")
        }

        @Test
        func `Decode - multiple trailers`() async throws {
            let chunked = Array(
                "5\r\nHello\r\n0\r\nX-Checksum: abc123\r\nX-Signature: xyz\r\n\r\n".utf8
            ).map { Byte(bitPattern: $0) }
            let result = try HTTP.Transfer.Coding.Chunked.decode(chunked)
            let decoded = result.data
            let trailers = result.trailers

            #expect(String(decoding: decoded, as: UTF8.self) == "Hello")
            #expect(trailers.count == 2)
        }

        @Test
        func `Decode - invalid format`() async throws {
            let chunked = Array("invalid".utf8).map { Byte(bitPattern: $0) }

            #expect(throws: HTTP.Transfer.Coding.Chunked.Error.invalidFormat) {
                try HTTP.Transfer.Coding.Chunked.decode(chunked)
            }
        }

        @Test
        func `Decode - invalid chunk size`() async throws {
            let chunked = Array("xyz\r\ndata\r\n0\r\n\r\n".utf8).map { Byte(bitPattern: $0) }

            #expect(throws: HTTP.Transfer.Coding.Chunked.Error.invalidChunkSize) {
                try HTTP.Transfer.Coding.Chunked.decode(chunked)
            }
        }

        @Test
        func `Decode - incomplete chunk`() async throws {

            let chunked = Array("10\r\nshort".utf8).map { Byte(bitPattern: $0) }

            #expect(throws: HTTP.Transfer.Coding.Chunked.Error.incompleteChunk) {
                try HTTP.Transfer.Coding.Chunked.decode(chunked)
            }
        }

        @Test
        func `Decode - missing CRLF`() async throws {

            let chunked = Array("5\r\nHelloXX0\r\n\r\n".utf8).map { Byte(bitPattern: $0) }

            #expect(throws: HTTP.Transfer.Coding.Chunked.Error.missingCRLF) {
                try HTTP.Transfer.Coding.Chunked.decode(chunked)
            }
        }
    }

    @Suite
    struct Integration {
        @Test
        func `Round trip - simple`() async throws {
            let original = Array("Hello, World!".utf8).map { Byte(bitPattern: $0) }
            let chunked = HTTP.Transfer.Coding.Chunked.encode(original)
            let decoded = try HTTP.Transfer.Coding.Chunked.decode(chunked).data

            #expect(decoded == original)
        }

        @Test
        func `Round trip - large data`() async throws {
            let original = [Byte](repeating: Byte(bitPattern: 0x41), count: 100000)
            let chunked = HTTP.Transfer.Coding.Chunked.encode(original, chunkSize: 8192)
            let decoded = try HTTP.Transfer.Coding.Chunked.decode(chunked).data

            #expect(decoded == original)
        }

        @Test
        func `Round trip - with trailers`() async throws {
            let original = Array("Test data".utf8).map { Byte(bitPattern: $0) }
            let originalTrailers = [
                try RFC_9110.Field(name: "X-Test", value: "value")
            ]

            let chunked = HTTP.Transfer.Coding.Chunked.encode(original, trailers: originalTrailers)
            let result = try HTTP.Transfer.Coding.Chunked.decode(chunked)
            let decoded = result.data
            let decodedTrailers = result.trailers

            #expect(decoded == original)
            #expect(decodedTrailers.count == originalTrailers.count)
        }
    }
}
