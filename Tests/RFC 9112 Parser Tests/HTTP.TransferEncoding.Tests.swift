import RFC_9110
import Foundation
import Testing

@testable import RFC_9112
@testable import RFC_9112_Parser
@testable import RFC_9112_Serializer

@Suite
struct `HTTP.Transfer.Encoding Tests` {
    @Suite struct Unit {}
    @Suite struct `Edge Case` {}
    @Suite struct Integration {}

    @Test
    func `TransferEncoding - chunked`() async throws {
        let te = HTTP.Transfer.Encoding.chunked

        #expect(te.headerValue == "chunked")
        #expect(te.isChunked == true)
        #expect(te.hasChunked == true)
        #expect(te.isChunkedFinal == true)
    }

    @Test
    func `TransferEncoding - gzip`() async throws {
        let te = HTTP.Transfer.Encoding.gzip

        #expect(te.headerValue == "gzip")
        #expect(te.isChunked == false)
        #expect(te.hasChunked == false)
    }

    @Test
    func `TransferEncoding - compress`() async throws {
        let te = HTTP.Transfer.Encoding.compress

        #expect(te.headerValue == "compress")
    }

    @Test
    func `TransferEncoding - deflate`() async throws {
        let te = HTTP.Transfer.Encoding.deflate

        #expect(te.headerValue == "deflate")
    }

    @Test
    func `TransferEncoding - custom`() async throws {
        let te = HTTP.Transfer.Encoding(codingName: "custom-encoding")

        #expect(te.headerValue == "custom-encoding")
    }

    @Test
    func `TransferEncoding - list`() async throws {
        let te = HTTP.Transfer.Encoding.list([.gzip, .chunked])

        #expect(te.headerValue == "gzip, chunked")
        #expect(te.hasChunked == true)
        #expect(te.isChunkedFinal == true)
    }

    @Test
    func `TransferEncoding - list with chunked not final`() async throws {
        let te = HTTP.Transfer.Encoding.list([.chunked, .gzip])

        #expect(te.hasChunked == true)
        #expect(te.isChunkedFinal == false)
    }

    @Test
    func `Parse - chunked`() async throws {
        let parsed = HTTP.Transfer.Encoding.parse("chunked")

        #expect(parsed == .chunked)
    }

    @Test
    func `Parse - gzip, chunked`() async throws {
        let parsed = HTTP.Transfer.Encoding.parse("gzip, chunked")

        #expect(parsed == .list([.gzip, .chunked]))
    }

    @Test
    func `Parse - case insensitive`() async throws {
        let parsed = HTTP.Transfer.Encoding.parse("CHUNKED")

        #expect(parsed == .chunked)
    }

    @Test
    func `Parse - with whitespace`() async throws {
        let parsed = HTTP.Transfer.Encoding.parse("  gzip  ,  chunked  ")

        #expect(parsed == .list([.gzip, .chunked]))
    }

    @Test
    func `Parse - x-compress`() async throws {
        let parsed = HTTP.Transfer.Encoding.parse("x-compress")

        #expect(parsed == .compress)
    }

    @Test
    func `Parse - empty`() async throws {
        #expect(HTTP.Transfer.Encoding.parse("") == nil)
        #expect(HTTP.Transfer.Encoding.parse("  ") == nil)
    }

    @Test
    func `Equality`() async throws {
        #expect(HTTP.Transfer.Encoding.chunked == .chunked)
        #expect(HTTP.Transfer.Encoding.gzip != .chunked)
        #expect(HTTP.Transfer.Encoding.list([.gzip, .chunked]) == .list([.gzip, .chunked]))
    }

    @Test
    func `Hashable`() async throws {
        var set: Set<HTTP.Transfer.Encoding> = []

        set.insert(.chunked)
        set.insert(.chunked)
        set.insert(.gzip)

        #expect(set.count == 2)
    }

    @Test
    func `Codable`() async throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let te = HTTP.Transfer.Encoding.list([.gzip, .chunked])
        let encoded = try encoder.encode(te)
        let decoded = try decoder.decode(HTTP.Transfer.Encoding.self, from: encoded)

        #expect(decoded == te)
    }

    @Test
    func `Description`() async throws {
        let te = HTTP.Transfer.Encoding.chunked

        #expect(te.description == "chunked")
    }

    @Test
    func `LosslessStringConvertible`() async throws {
        let te: HTTP.Transfer.Encoding? = HTTP.Transfer.Encoding("chunked")

        #expect(te != nil)
        #expect(te == .chunked)
    }

    @Test
    func `ExpressibleByStringLiteral`() async throws {
        let te: HTTP.Transfer.Encoding = "chunked"

        #expect(te == .chunked)
    }

    @Test
    func `Round trip - format and parse`() async throws {
        let original = HTTP.Transfer.Encoding.list([.gzip, .chunked])
        let headerValue = original.headerValue
        let parsed = HTTP.Transfer.Encoding.parse(headerValue)

        #expect(parsed == original)
    }
}
