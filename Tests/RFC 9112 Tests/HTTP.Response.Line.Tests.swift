// HTTP.Response.Line.Tests.swift
// swift-rfc-9112

import Testing
@testable import RFC_9112

@Suite("HTTP.Response.Line Tests")
struct HTTPResponseLineTests {

    @Test("Parse valid status line with reason phrase")
    func parseValidWithReasonPhrase() async throws {
        let line = "HTTP/1.1 200 OK"
        let parsed = try RFC_9110.Response.Line.parse(line)

        #expect(parsed.version == .http11)
        #expect(parsed.statusCode == 200)
        #expect(parsed.reasonPhrase == "OK")
    }

    @Test("Parse valid status line without reason phrase")
    func parseValidWithoutReasonPhrase() async throws {
        let line = "HTTP/1.1 200 "
        let parsed = try RFC_9110.Response.Line.parse(line)

        #expect(parsed.version == .http11)
        #expect(parsed.statusCode == 200)
        #expect(parsed.reasonPhrase == nil)
    }

    @Test("Parse 404 Not Found")
    func parse404() async throws {
        let line = "HTTP/1.1 404 Not Found"
        let parsed = try RFC_9110.Response.Line.parse(line)

        #expect(parsed.version == .http11)
        #expect(parsed.statusCode == 404)
        #expect(parsed.reasonPhrase == "Not Found")
    }

    @Test("Parse 500 Internal Server Error")
    func parse500() async throws {
        let line = "HTTP/1.1 500 Internal Server Error"
        let parsed = try RFC_9110.Response.Line.parse(line)

        #expect(parsed.statusCode == 500)
        #expect(parsed.reasonPhrase == "Internal Server Error")
    }

    @Test("Parse HTTP/1.0 response")
    func parseHTTP10() async throws {
        let line = "HTTP/1.0 200 OK"
        let parsed = try RFC_9110.Response.Line.parse(line)

        #expect(parsed.version.isHTTP10)
        #expect(!parsed.version.isHTTP11)
        #expect(parsed.statusCode == 200)
    }

    @Test("Parse 101 Switching Protocols")
    func parse101() async throws {
        let line = "HTTP/1.1 101 Switching Protocols"
        let parsed = try RFC_9110.Response.Line.parse(line)

        #expect(parsed.statusCode == 101)
        #expect(parsed.reasonPhrase == "Switching Protocols")
    }

    @Test("Parse 204 No Content")
    func parse204() async throws {
        let line = "HTTP/1.1 204 No Content"
        let parsed = try RFC_9110.Response.Line.parse(line)

        #expect(parsed.statusCode == 204)
        #expect(parsed.reasonPhrase == "No Content")
    }

    @Test("Parse 304 Not Modified")
    func parse304() async throws {
        let line = "HTTP/1.1 304 Not Modified"
        let parsed = try RFC_9110.Response.Line.parse(line)

        #expect(parsed.statusCode == 304)
        #expect(parsed.reasonPhrase == "Not Modified")
    }

    @Test("Parse custom status code")
    func parseCustomStatusCode() async throws {
        let line = "HTTP/1.1 999 Custom Status"
        let parsed = try RFC_9110.Response.Line.parse(line)

        #expect(parsed.statusCode == 999)
        #expect(parsed.reasonPhrase == "Custom Status")
    }

    @Test("Format status line with reason phrase")
    func formatWithReasonPhrase() async throws {
        let line = RFC_9110.Response.Line(
            version: .http11,
            statusCode: 200,
            reasonPhrase: "OK"
        )

        #expect(line.formatted == "HTTP/1.1 200 OK")
    }

    @Test("Format status line without reason phrase")
    func formatWithoutReasonPhrase() async throws {
        let line = RFC_9110.Response.Line(
            version: .http11,
            statusCode: 200,
            reasonPhrase: nil
        )

        #expect(line.formatted == "HTTP/1.1 200 ")
    }

    @Test("Parse - invalid format (missing status)")
    func parseInvalidFormat() async throws {
        #expect(throws: RFC_9110.Response.Line.ParsingError.self) {
            try RFC_9110.Response.Line.parse("HTTP/1.1")
        }
    }

    @Test("Parse - invalid format (missing version)")
    func parseInvalidFormatMissingVersion() async throws {
        #expect(throws: RFC_9110.Version.ParsingError.self) {
            try RFC_9110.Response.Line.parse("200 OK")
        }
    }

    @Test("Parse - invalid status code (non-numeric)")
    func parseInvalidStatusCode() async throws {
        #expect(throws: RFC_9110.Response.Line.ParsingError.self) {
            try RFC_9110.Response.Line.parse("HTTP/1.1 ABC OK")
        }
    }

    @Test("Parse - invalid version")
    func parseInvalidVersion() async throws {
        #expect(throws: RFC_9110.Version.ParsingError.self) {
            try RFC_9110.Response.Line.parse("HTTP/X.Y 200 OK")
        }
    }

    @Test("Parse - reason phrase with multiple spaces")
    func parseReasonPhraseWithSpaces() async throws {
        let line = "HTTP/1.1 200 This Is A Long Reason Phrase"
        let parsed = try RFC_9110.Response.Line.parse(line)

        #expect(parsed.reasonPhrase == "This Is A Long Reason Phrase")
    }

    @Test("Validate - status code range")
    func validateStatusCodeRange() async throws {
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
