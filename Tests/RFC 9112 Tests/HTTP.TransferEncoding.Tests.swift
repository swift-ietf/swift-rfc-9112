// HTTP.TransferEncoding.Tests.swift
// swift-rfc-9112

import Testing
@testable import RFC_9112

@Suite
struct `HTTP.TransferEncoding Tests` {

    @Test
    func `TransferEncoding - chunked`() async throws {
        let te = HTTP.TransferEncoding.chunked

        #expect(te.headerValue == "chunked")
        #expect(te.isChunked == true)
        #expect(te.hasChunked == true)
        #expect(te.isChunkedFinal == true)
    }

    @Test
    func `TransferEncoding - gzip`() async throws {
        let te = HTTP.TransferEncoding.gzip

        #expect(te.headerValue == "gzip")
        #expect(te.isChunked == false)
        #expect(te.hasChunked == false)
    }

    @Test
    func `TransferEncoding - compress`() async throws {
        let te = HTTP.TransferEncoding.compress

        #expect(te.headerValue == "compress")
    }

    @Test
    func `TransferEncoding - deflate`() async throws {
        let te = HTTP.TransferEncoding.deflate

        #expect(te.headerValue == "deflate")
    }

    @Test
    func `TransferEncoding - custom`() async throws {
        let te = HTTP.TransferEncoding.custom("custom-encoding")

        #expect(te.headerValue == "custom-encoding")
    }

    @Test
    func `TransferEncoding - list`() async throws {
        let te = HTTP.TransferEncoding.list([.gzip, .chunked])

        #expect(te.headerValue == "gzip, chunked")
        #expect(te.hasChunked == true)
        #expect(te.isChunkedFinal == true)
    }

    @Test
    func `TransferEncoding - list with chunked not final`() async throws {
        let te = HTTP.TransferEncoding.list([.chunked, .gzip])

        #expect(te.hasChunked == true)
        #expect(te.isChunkedFinal == false) // Invalid per RFC 9112
    }

    @Test
    func `Parse - chunked`() async throws {
        let parsed = HTTP.TransferEncoding.parse("chunked")

        #expect(parsed == .chunked)
    }

    @Test
    func `Parse - gzip, chunked`() async throws {
        let parsed = HTTP.TransferEncoding.parse("gzip, chunked")

        #expect(parsed == .list([.gzip, .chunked]))
    }

    @Test
    func `Parse - case insensitive`() async throws {
        let parsed = HTTP.TransferEncoding.parse("CHUNKED")

        #expect(parsed == .chunked)
    }

    @Test
    func `Parse - with whitespace`() async throws {
        let parsed = HTTP.TransferEncoding.parse("  gzip  ,  chunked  ")

        #expect(parsed == .list([.gzip, .chunked]))
    }

    @Test
    func `Parse - x-compress`() async throws {
        let parsed = HTTP.TransferEncoding.parse("x-compress")

        #expect(parsed == .compress)
    }

    @Test
    func `Parse - empty`() async throws {
        #expect(HTTP.TransferEncoding.parse("") == nil)
        #expect(HTTP.TransferEncoding.parse("  ") == nil)
    }

    @Test
    func `Equality`() async throws {
        #expect(HTTP.TransferEncoding.chunked == .chunked)
        #expect(HTTP.TransferEncoding.gzip != .chunked)
        #expect(HTTP.TransferEncoding.list([.gzip, .chunked]) == .list([.gzip, .chunked]))
    }

    @Test
    func `Hashable`() async throws {
        var set: Set<HTTP.TransferEncoding> = []

        set.insert(.chunked)
        set.insert(.chunked) // Duplicate
        set.insert(.gzip)

        #expect(set.count == 2)
    }

    @Test
    func `Codable`() async throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let te = HTTP.TransferEncoding.list([.gzip, .chunked])
        let encoded = try encoder.encode(te)
        let decoded = try decoder.decode(HTTP.TransferEncoding.self, from: encoded)

        #expect(decoded == te)
    }

    @Test
    func `Description`() async throws {
        let te = HTTP.TransferEncoding.chunked

        #expect(te.description == "chunked")
    }

    @Test
    func `LosslessStringConvertible`() async throws {
        let te: HTTP.TransferEncoding? = HTTP.TransferEncoding("chunked")

        #expect(te != nil)
        #expect(te == .chunked)
    }

    @Test
    func `ExpressibleByStringLiteral`() async throws {
        let te: HTTP.TransferEncoding = "chunked"

        #expect(te == .chunked)
    }

    @Test
    func `Round trip - format and parse`() async throws {
        let original = HTTP.TransferEncoding.list([.gzip, .chunked])
        let headerValue = original.headerValue
        let parsed = HTTP.TransferEncoding.parse(headerValue)

        #expect(parsed == original)
    }
}
