// HTTP.Request.Line.Tests.swift
// swift-rfc-9112

import Testing

@testable import RFC_9112

@Suite
struct `HTTP.Request.Line Tests` {

    @Test
    func `Parse valid request line`() async throws {
        let line = "GET /path HTTP/1.1"
        let parsed = try RFC_9110.Request.Line.parse(line)

        #expect(parsed.method == .get)
        #expect(parsed.target == "/path")
        #expect(parsed.version == .http11)
    }

    @Test
    func `Parse with query`() async throws {
        let line = "POST /api/users?page=1 HTTP/1.1"
        let parsed = try RFC_9110.Request.Line.parse(line)

        #expect(parsed.method == .post)
        #expect(parsed.target == "/api/users?page=1")
        #expect(parsed.version == .http11)
    }

    @Test
    func `Parse HTTP/1.0`() async throws {
        let line = "GET / HTTP/1.0"
        let parsed = try RFC_9110.Request.Line.parse(line)

        #expect(parsed.version.isHTTP10)
        #expect(!parsed.version.isHTTP11)
    }

    @Test
    func `Parse custom method`() async throws {
        let line = "CUSTOM /path HTTP/1.1"
        let parsed = try RFC_9110.Request.Line.parse(line)

        #expect(parsed.method.rawValue == "CUSTOM")
    }

    @Test
    func `Format request line`() async throws {
        let line = RFC_9110.Request.Line(
            method: .get,
            target: "/path?query=value",
            version: .http11
        )

        #expect(line.formatted == "GET /path?query=value HTTP/1.1")
    }

    @Test
    func `Parse - invalid format`() async throws {
        #expect(throws: RFC_9110.Request.Line.ParsingError.self) {
            try RFC_9110.Request.Line.parse("GET /path")  // Missing version
        }
    }

    @Test
    func `Parse - empty method`() async throws {
        #expect(throws: RFC_9110.Request.Line.ParsingError.emptyMethod) {
            try RFC_9110.Request.Line.parse(" /path HTTP/1.1")
        }
    }

    @Test
    func `Parse - empty target`() async throws {
        #expect(throws: RFC_9110.Request.Line.ParsingError.emptyTarget) {
            try RFC_9110.Request.Line.parse("GET  HTTP/1.1")
        }
    }

    @Test
    func `Parse - whitespace in target`() async throws {
        #expect(throws: RFC_9110.Request.Line.ParsingError.targetContainsWhitespace) {
            try RFC_9110.Request.Line.parse("GET /path with spaces HTTP/1.1")
        }
    }

    @Test
    func `Validate - line too long`() async throws {
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
