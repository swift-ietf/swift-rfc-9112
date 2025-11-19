// HTTP.Response.Line.Tests.swift
// swift-rfc-9112

import Testing
@testable import RFC_9112

@Suite
struct `HTTP.Response.Line Tests` {

    @Test
    func `Parse valid status line with reason phrase`() async throws {
        let line = "HTTP/1.1 200 OK"
        let parsed = try RFC_9110.Response.Line.parse(line)

        #expect(parsed.version == .http11)
        #expect(parsed.statusCode == 200)
        #expect(parsed.reasonPhrase == "OK")
    }

    @Test
    func `Parse valid status line without reason phrase`() async throws {
        let line = "HTTP/1.1 200 "
        let parsed = try RFC_9110.Response.Line.parse(line)

        #expect(parsed.version == .http11)
        #expect(parsed.statusCode == 200)
        #expect(parsed.reasonPhrase == nil)
    }

    @Test
    func `Parse 404 Not Found`() async throws {
        let line = "HTTP/1.1 404 Not Found"
        let parsed = try RFC_9110.Response.Line.parse(line)

        #expect(parsed.version == .http11)
        #expect(parsed.statusCode == 404)
        #expect(parsed.reasonPhrase == "Not Found")
    }

    @Test
    func `Parse 500 Internal Server Error`() async throws {
        let line = "HTTP/1.1 500 Internal Server Error"
        let parsed = try RFC_9110.Response.Line.parse(line)

        #expect(parsed.statusCode == 500)
        #expect(parsed.reasonPhrase == "Internal Server Error")
    }

    @Test
    func `Parse HTTP/1.0 response`() async throws {
        let line = "HTTP/1.0 200 OK"
        let parsed = try RFC_9110.Response.Line.parse(line)

        #expect(parsed.version.isHTTP10)
        #expect(!parsed.version.isHTTP11)
        #expect(parsed.statusCode == 200)
    }

    @Test
    func `Parse 101 Switching Protocols`() async throws {
        let line = "HTTP/1.1 101 Switching Protocols"
        let parsed = try RFC_9110.Response.Line.parse(line)

        #expect(parsed.statusCode == 101)
        #expect(parsed.reasonPhrase == "Switching Protocols")
    }

    @Test
    func `Parse 204 No Content`() async throws {
        let line = "HTTP/1.1 204 No Content"
        let parsed = try RFC_9110.Response.Line.parse(line)

        #expect(parsed.statusCode == 204)
        #expect(parsed.reasonPhrase == "No Content")
    }

    @Test
    func `Parse 304 Not Modified`() async throws {
        let line = "HTTP/1.1 304 Not Modified"
        let parsed = try RFC_9110.Response.Line.parse(line)

        #expect(parsed.statusCode == 304)
        #expect(parsed.reasonPhrase == "Not Modified")
    }

    @Test
    func `Parse custom status code`() async throws {
        let line = "HTTP/1.1 999 Custom Status"
        let parsed = try RFC_9110.Response.Line.parse(line)

        #expect(parsed.statusCode == 999)
        #expect(parsed.reasonPhrase == "Custom Status")
    }

    @Test
    func `Format status line with reason phrase`() async throws {
        let line = RFC_9110.Response.Line(
            version: .http11,
            statusCode: 200,
            reasonPhrase: "OK"
        )

        #expect(line.formatted == "HTTP/1.1 200 OK")
    }

    @Test
    func `Format status line without reason phrase`() async throws {
        let line = RFC_9110.Response.Line(
            version: .http11,
            statusCode: 200,
            reasonPhrase: nil
        )

        #expect(line.formatted == "HTTP/1.1 200 ")
    }

    @Test
    func `Parse - invalid format (missing status)`() async throws {
        #expect(throws: RFC_9110.Response.Line.ParsingError.self) {
            try RFC_9110.Response.Line.parse("HTTP/1.1")
        }
    }

    @Test
    func `Parse - invalid format (missing version)`() async throws {
        #expect(throws: RFC_9110.Version.ParsingError.self) {
            try RFC_9110.Response.Line.parse("200 OK")
        }
    }

    @Test
    func `Parse - invalid status code (non-numeric)`() async throws {
        #expect(throws: RFC_9110.Response.Line.ParsingError.self) {
            try RFC_9110.Response.Line.parse("HTTP/1.1 ABC OK")
        }
    }

    @Test
    func `Parse - invalid version`() async throws {
        #expect(throws: RFC_9110.Version.ParsingError.self) {
            try RFC_9110.Response.Line.parse("HTTP/X.Y 200 OK")
        }
    }

    @Test
    func `Parse - reason phrase with multiple spaces`() async throws {
        let line = "HTTP/1.1 200 This Is A Long Reason Phrase"
        let parsed = try RFC_9110.Response.Line.parse(line)

        #expect(parsed.reasonPhrase == "This Is A Long Reason Phrase")
    }

    @Test
    func `Validate - status code range`() async throws {
        // Valid status codes are 100-599
        let valid = RFC_9110.Response.Line(
            version: .http11,
            statusCode: 200,
            reasonPhrase: "OK"
        )

        #expect(valid.statusCode >= 100)
        #expect(valid.statusCode < 600)
    }
}
