// HTTP.Header.Parser.Tests.swift
// swift-rfc-9112

import Testing
@testable import RFC_9112

@Suite
struct `HTTP.Header.Parser Tests` {

    @Test
    func `Parse simple field line`() async throws {
        let line = "Content-Type: text/plain"
        let (name, value) = try RFC_9110.Header.Parser.parseFieldLine(line)

        #expect(name == "Content-Type")
        #expect(value == "text/plain")
    }

    @Test
    func `Parse field with whitespace`() async throws {
        let line = "Content-Type:   text/plain  "
        let (name, value) = try RFC_9110.Header.Parser.parseFieldLine(line)

        #expect(name == "Content-Type")
        #expect(value == "text/plain")
    }

    @Test
    func `Parse field with no value`() async throws {
        let line = "X-Custom-Header:"
        let (name, value) = try RFC_9110.Header.Parser.parseFieldLine(line)

        #expect(name == "X-Custom-Header")
        #expect(value == "")
    }

    @Test
    func `Parse field with colon in value`() async throws {
        let line = "WWW-Authenticate: Bearer realm=\"api\", charset=\"UTF-8\""
        let (name, value) = try RFC_9110.Header.Parser.parseFieldLine(line)

        #expect(name == "WWW-Authenticate")
        #expect(value == "Bearer realm=\"api\", charset=\"UTF-8\"")
    }

    @Test
    func `Parse multiple field lines`() async throws {
        let lines = [
            "Content-Type: text/html",
            "Content-Length: 1234",
            "Cache-Control: max-age=3600"
        ]

        let fields = try RFC_9110.Header.Parser.parseFieldLines(lines)

        #expect(fields.count == 3)
        #expect(fields[0].name == "Content-Type")
        #expect(fields[0].value == "text/html")
        #expect(fields[1].name == "Content-Length")
        #expect(fields[1].value == "1234")
        #expect(fields[2].name == "Cache-Control")
        #expect(fields[2].value == "max-age=3600")
    }

    @Test
    func `Parse obs-fold with space - replace policy`() async throws {
        let lines = ["Content-Type: text/plain", " continuation"]

        let fields = try RFC_9110.Header.Parser.parseFieldLines(
            lines,
            obsFoldPolicy: .replaceWithSpace
        )

        #expect(fields.count == 1)
        #expect(fields[0].name == "Content-Type")
        #expect(fields[0].value == "text/plain continuation")
    }

    @Test
    func `Parse obs-fold with tab - replace policy`() async throws {
        let lines = ["Content-Type: text/plain", "\tcontinuation"]

        let fields = try RFC_9110.Header.Parser.parseFieldLines(
            lines,
            obsFoldPolicy: .replaceWithSpace
        )

        #expect(fields.count == 1)
        #expect(fields[0].name == "Content-Type")
        #expect(fields[0].value == "text/plain continuation")
    }

    @Test
    func `Parse obs-fold - discard policy`() async throws {
        let lines = ["Content-Type: text/plain", " continuation"]

        let fields = try RFC_9110.Header.Parser.parseFieldLines(
            lines,
            obsFoldPolicy: .discard
        )

        #expect(fields.count == 1)
        #expect(fields[0].name == "Content-Type")
        #expect(fields[0].value == "text/plain")
    }

    @Test
    func `Parse obs-fold without preceding field`() async throws {
        let lines = [" continuation", "Content-Type: text/plain"]

        #expect(throws: RFC_9110.Header.Parser.ParsingError.self) {
            try RFC_9110.Header.Parser.parseFieldLines(lines)
        }
    }

    @Test
    func `Parse - missing colon`() async throws {
        let line = "InvalidHeaderLine"

        #expect(throws: RFC_9110.Header.Parser.ParsingError.missingColon) {
            try RFC_9110.Header.Parser.parseFieldLine(line)
        }
    }

    @Test
    func `Parse - empty name`() async throws {
        let line = ": value"

        #expect(throws: RFC_9110.Header.Parser.ParsingError.emptyFieldName) {
            try RFC_9110.Header.Parser.parseFieldLine(line)
        }
    }

    @Test
    func `Parse - whitespace before colon`() async throws {
        let line = "Content-Type : text/plain"

        #expect(throws: RFC_9110.Header.Parser.ParsingError.whitespaceBeforeColon) {
            try RFC_9110.Header.Parser.parseFieldLine(line)
        }
    }

    @Test
    func `Parse field with UTF-8 value`() async throws {
        let line = "X-Custom: 日本語"
        let (name, value) = try RFC_9110.Header.Parser.parseFieldLine(line)

        #expect(name == "X-Custom")
        #expect(value == "日本語")
    }

    @Test
    func `Parse field with quoted value`() async throws {
        let line = "Content-Disposition: attachment; filename=\"document.pdf\""
        let (name, value) = try RFC_9110.Header.Parser.parseFieldLine(line)

        #expect(name == "Content-Disposition")
        #expect(value == "attachment; filename=\"document.pdf\"")
    }

    @Test
    func `Parse field with comma-separated values`() async throws {
        let line = "Accept: text/html, application/json, */*"
        let (name, value) = try RFC_9110.Header.Parser.parseFieldLine(line)

        #expect(name == "Accept")
        #expect(value == "text/html, application/json, */*")
    }

    @Test
    func `Parse case-sensitive field name`() async throws {
        let line = "content-type: text/plain"
        let (name, value) = try RFC_9110.Header.Parser.parseFieldLine(line)

        // Field names should preserve case
        #expect(name == "content-type")
        #expect(value == "text/plain")
    }

    @Test
    func `Parse multiple obs-fold lines`() async throws {
        let lines = ["Content-Type: text/plain", " line1", " line2", " line3"]

        let fields = try RFC_9110.Header.Parser.parseFieldLines(
            lines,
            obsFoldPolicy: .replaceWithSpace
        )

        #expect(fields.count == 1)
        #expect(fields[0].name == "Content-Type")
        #expect(fields[0].value == "text/plain line1 line2 line3")
    }

    @Test
    func `Parse empty field lines array`() async throws {
        let lines: [String] = []
        let fields = try RFC_9110.Header.Parser.parseFieldLines(lines)

        #expect(fields.isEmpty)
    }

    @Test
    func `Parse field lines with error in middle`() async throws {
        let lines = [
            "Content-Type: text/html",
            "InvalidLine",
            "Content-Length: 1234"
        ]

        #expect(throws: RFC_9110.Header.Parser.ParsingError.missingColon) {
            try RFC_9110.Header.Parser.parseFieldLines(lines)
        }
    }

    @Test
    func `Parse very long field value`() async throws {
        let longValue = String(repeating: "a", count: 10000)
        let line = "X-Long-Header: \(longValue)"
        let (name, value) = try RFC_9110.Header.Parser.parseFieldLine(line)

        #expect(name == "X-Long-Header")
        #expect(value == longValue)
    }

    @Test
    func `Parse field with leading/trailing whitespace in value`() async throws {
        let line = "X-Custom:   value with spaces   "
        let (name, value) = try RFC_9110.Header.Parser.parseFieldLine(line)

        #expect(name == "X-Custom")
        // Leading/trailing whitespace should be trimmed
        #expect(value == "value with spaces")
    }

    @Test
    func `Parse field with only whitespace value`() async throws {
        let line = "X-Custom:     "
        let (name, value) = try RFC_9110.Header.Parser.parseFieldLine(line)

        #expect(name == "X-Custom")
        #expect(value == "")
    }

    @Test
    func `Parse standard HTTP headers`() async throws {
        let lines = [
            "Host: example.com",
            "User-Agent: Mozilla/5.0",
            "Accept: text/html",
            "Accept-Language: en-US,en;q=0.9",
            "Accept-Encoding: gzip, deflate, br",
            "Connection: keep-alive"
        ]

        let fields = try RFC_9110.Header.Parser.parseFieldLines(lines)

        #expect(fields.count == 6)
        #expect(fields[0].name == "Host")
        #expect(fields[0].value == "example.com")
        #expect(fields[5].name == "Connection")
        #expect(fields[5].value == "keep-alive")
    }

    @Test
    func `Parse Set-Cookie header`() async throws {
        let line = "Set-Cookie: sessionid=abc123; Path=/; HttpOnly; Secure"
        let (name, value) = try RFC_9110.Header.Parser.parseFieldLine(line)

        #expect(name == "Set-Cookie")
        #expect(value == "sessionid=abc123; Path=/; HttpOnly; Secure")
    }

    @Test
    func `Parse Authorization header`() async throws {
        let line = "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"
        let (name, value) = try RFC_9110.Header.Parser.parseFieldLine(line)

        #expect(name == "Authorization")
        #expect(value == "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9")
    }

    @Test
    func `ObsFoldPolicy sendable conformance`() async throws {
        let policy = RFC_9110.Header.Parser.ObsFoldPolicy.replaceWithSpace

        // Verify policy can be safely sent across concurrency boundaries
        await Task {
            _ = policy
        }.value
    }
}
