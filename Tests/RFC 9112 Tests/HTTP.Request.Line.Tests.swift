// HTTP.Request.Line.Tests.swift
// swift-rfc-9112

import Testing
@testable import RFC_9112

@Suite("HTTP.Request.Line Tests")
struct HTTPRequestLineTests {

    @Test("Parse valid request line")
    func parseValid() async throws {
        let line = "GET /path HTTP/1.1"
        let parsed = try RFC_9110.Request.Line.parse(line)

        #expect(parsed.method == .get)
        #expect(parsed.target == "/path")
        #expect(parsed.version == .http11)
    }

    @Test("Parse with query")
    func parseWithQuery() async throws {
        let line = "POST /api/users?page=1 HTTP/1.1"
        let parsed = try RFC_9110.Request.Line.parse(line)

        #expect(parsed.method == .post)
        #expect(parsed.target == "/api/users?page=1")
        #expect(parsed.version == .http11)
    }

    @Test("Parse HTTP/1.0")
    func parseHTTP10() async throws {
        let line = "GET / HTTP/1.0"
        let parsed = try RFC_9110.Request.Line.parse(line)

        #expect(parsed.version.isHTTP10)
        #expect(!parsed.version.isHTTP11)
    }

    @Test("Parse custom method")
    func parseCustomMethod() async throws {
        let line = "CUSTOM /path HTTP/1.1"
        let parsed = try RFC_9110.Request.Line.parse(line)

        #expect(parsed.method.rawValue == "CUSTOM")
    }

    @Test("Format request line")
    func format() async throws {
        let line = RFC_9110.Request.Line(
            method: .get,
            target: "/path?query=value",
            version: .http11
        )

        #expect(line.formatted == "GET /path?query=value HTTP/1.1")
    }

    @Test("Parse - invalid format")
    func parseInvalidFormat() async throws {
        #expect(throws: RFC_9110.Request.Line.ParsingError.self) {
            try RFC_9110.Request.Line.parse("GET /path")  // Missing version
        }
    }

    @Test("Parse - empty method")
    func parseEmptyMethod() async throws {
        #expect(throws: RFC_9110.Request.Line.ParsingError.emptyMethod) {
            try RFC_9110.Request.Line.parse(" /path HTTP/1.1")
        }
    }

    @Test("Parse - empty target")
    func parseEmptyTarget() async throws {
        #expect(throws: RFC_9110.Request.Line.ParsingError.emptyTarget) {
            try RFC_9110.Request.Line.parse("GET  HTTP/1.1")
        }
    }

    @Test("Parse - whitespace in target")
    func parseWhitespaceInTarget() async throws {
        #expect(throws: RFC_9110.Request.Line.ParsingError.targetContainsWhitespace) {
            try RFC_9110.Request.Line.parse("GET /path with spaces HTTP/1.1")
        }
    }

    @Test("Validate - line too long")
    func validateLineTooLong() async throws {
        let longTarget = String(repeating: "a", count: 9000)
        let line = RFC_9110.Request.Line(
            method: .get,
            target: longTarget,
            version: .http11
        )

        #expect(throws: RFC_9110.Request.Line.ValidationError.self) {
            try line.validate(maxLength: 8000)
        }
    }
}
