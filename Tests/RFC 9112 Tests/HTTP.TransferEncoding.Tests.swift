// HTTP.TransferEncoding.Tests.swift
// swift-rfc-9112

import Testing
@testable import RFC_9112

@Suite("HTTP.TransferEncoding Tests")
struct HTTPTransferEncodingTests {

    @Test("TransferEncoding - chunked")
    func transferEncodingChunked() async throws {
        let te = HTTP.TransferEncoding.chunked

        #expect(te.headerValue == "chunked")
        #expect(te.isChunked == true)
        #expect(te.hasChunked == true)
        #expect(te.isChunkedFinal == true)
    }

    @Test("TransferEncoding - gzip")
    func transferEncodingGzip() async throws {
        let te = HTTP.TransferEncoding.gzip

        #expect(te.headerValue == "gzip")
        #expect(te.isChunked == false)
        #expect(te.hasChunked == false)
    }

    @Test("TransferEncoding - compress")
    func transferEncodingCompress() async throws {
        let te = HTTP.TransferEncoding.compress

        #expect(te.headerValue == "compress")
    }

    @Test("TransferEncoding - deflate")
    func transferEncodingDeflate() async throws {
        let te = HTTP.TransferEncoding.deflate

        #expect(te.headerValue == "deflate")
    }

    @Test("TransferEncoding - custom")
    func transferEncodingCustom() async throws {
        let te = HTTP.TransferEncoding.custom("custom-encoding")

        #expect(te.headerValue == "custom-encoding")
    }

    @Test("TransferEncoding - list")
    func transferEncodingList() async throws {
        let te = HTTP.TransferEncoding.list([.gzip, .chunked])

        #expect(te.headerValue == "gzip, chunked")
        #expect(te.hasChunked == true)
        #expect(te.isChunkedFinal == true)
    }

    @Test("TransferEncoding - list with chunked not final")
    func transferEncodingListChunkedNotFinal() async throws {
        let te = HTTP.TransferEncoding.list([.chunked, .gzip])

        #expect(te.hasChunked == true)
        #expect(te.isChunkedFinal == false) // Invalid per RFC 9112
    }

    @Test("Parse - chunked")
    func parseChunked() async throws {
        let parsed = HTTP.TransferEncoding.parse("chunked")

        #expect(parsed == .chunked)
    }

    @Test("Parse - gzip, chunked")
    func parseGzipChunked() async throws {
        let parsed = HTTP.TransferEncoding.parse("gzip, chunked")

        #expect(parsed == .list([.gzip, .chunked]))
    }

    @Test("Parse - case insensitive")
    func parseCaseInsensitive() async throws {
        let parsed = HTTP.TransferEncoding.parse("CHUNKED")

        #expect(parsed == .chunked)
    }

    @Test("Parse - with whitespace")
    func parseWithWhitespace() async throws {
        let parsed = HTTP.TransferEncoding.parse("  gzip  ,  chunked  ")

        #expect(parsed == .list([.gzip, .chunked]))
    }

    @Test("Parse - x-compress")
    func parseXCompress() async throws {
        let parsed = HTTP.TransferEncoding.parse("x-compress")

        #expect(parsed == .compress)
    }

    @Test("Parse - empty")
    func parseEmpty() async throws {
        #expect(HTTP.TransferEncoding.parse("") == nil)
        #expect(HTTP.TransferEncoding.parse("  ") == nil)
    }

    @Test("Equality")
    func equality() async throws {
        #expect(HTTP.TransferEncoding.chunked == .chunked)
        #expect(HTTP.TransferEncoding.gzip != .chunked)
        #expect(HTTP.TransferEncoding.list([.gzip, .chunked]) == .list([.gzip, .chunked]))
    }

    @Test("Hashable")
    func hashable() async throws {
        var set: Set<HTTP.TransferEncoding> = []

        set.insert(.chunked)
        set.insert(.chunked) // Duplicate
        set.insert(.gzip)

        #expect(set.count == 2)
    }

    @Test("Codable")
    func codable() async throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let te = HTTP.TransferEncoding.list([.gzip, .chunked])
        let encoded = try encoder.encode(te)
        let decoded = try decoder.decode(HTTP.TransferEncoding.self, from: encoded)

        #expect(decoded == te)
    }

    @Test("Description")
    func description() async throws {
        let te = HTTP.TransferEncoding.chunked

        #expect(te.description == "chunked")
    }

    @Test("LosslessStringConvertible")
    func losslessStringConvertible() async throws {
        let te: HTTP.TransferEncoding? = HTTP.TransferEncoding("chunked")

        #expect(te != nil)
        #expect(te == .chunked)
    }

    @Test("ExpressibleByStringLiteral")
    func expressibleByStringLiteral() async throws {
        let te: HTTP.TransferEncoding = "chunked"

        #expect(te == .chunked)
    }

    @Test("Round trip - format and parse")
    func roundTrip() async throws {
        let original = HTTP.TransferEncoding.list([.gzip, .chunked])
        let headerValue = original.headerValue
        let parsed = HTTP.TransferEncoding.parse(headerValue)

        #expect(parsed == original)
    }
}
