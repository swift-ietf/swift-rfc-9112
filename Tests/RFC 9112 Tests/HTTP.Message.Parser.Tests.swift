// HTTP.Message.Parser.Tests.swift
// swift-rfc-9112

import Testing

@testable import RFC_9112

@Suite
struct `HTTP.Message.Parser Tests` {

    @Test
    func `Parse lines with CRLF terminators`() async throws {
        let data = Data("Line 1\r\nLine 2\r\nLine 3\r\n".utf8)
        let lines = try RFC_9110.MessageParser.parseLines(from: data)

        #expect(lines.count == 3)
        #expect(lines[0].string == "Line 1")
        #expect(lines[0].terminator == .crlf)
        #expect(lines[1].string == "Line 2")
        #expect(lines[1].terminator == .crlf)
        #expect(lines[2].string == "Line 3")
        #expect(lines[2].terminator == .crlf)
    }

    @Test
    func `Parse lines with LF terminators`() async throws {
        let data = Data("Line 1\nLine 2\nLine 3\n".utf8)
        let lines = try RFC_9110.MessageParser.parseLines(from: data)

        #expect(lines.count == 3)
        #expect(lines[0].string == "Line 1")
        #expect(lines[0].terminator == .lf)
        #expect(lines[1].string == "Line 2")
        #expect(lines[1].terminator == .lf)
    }

    @Test
    func `Parse lines with mixed terminators`() async throws {
        let data = Data("Line 1\r\nLine 2\nLine 3\r\n".utf8)
        let lines = try RFC_9110.MessageParser.parseLines(from: data)

        #expect(lines.count == 3)
        #expect(lines[0].terminator == .crlf)
        #expect(lines[1].terminator == .lf)
        #expect(lines[2].terminator == .crlf)
    }

    @Test
    func `Parse empty line (CRLF only)`() async throws {
        let data = Data("\r\n".utf8)
        let lines = try RFC_9110.MessageParser.parseLines(from: data)

        #expect(lines.count == 1)
        #expect(lines[0].string.isEmpty)
        #expect(lines[0].terminator == .crlf)
    }

    @Test
    func `Parse empty line (LF only)`() async throws {
        let data = Data("\n".utf8)
        let lines = try RFC_9110.MessageParser.parseLines(from: data)

        #expect(lines.count == 1)
        #expect(lines[0].string.isEmpty)
        #expect(lines[0].terminator == .lf)
    }

    @Test
    func `Parse last line without terminator`() async throws {
        let data = Data("Line 1\r\nLine 2".utf8)
        let lines = try RFC_9110.MessageParser.parseLines(from: data)

        #expect(lines.count == 2)
        #expect(lines[0].string == "Line 1")
        #expect(lines[0].terminator == .crlf)
        #expect(lines[1].string == "Line 2")
        #expect(lines[1].terminator == .none)
    }

    @Test
    func `Parse bare CR rejection`() async throws {
        // Bare CR (CR not followed by LF) should be rejected per RFC 9112 Section 2.2
        let data = Data("Line 1\rLine 2\r\n".utf8)

        #expect(throws: RFC_9110.MessageParser.ParsingError.self) {
            try RFC_9110.MessageParser.parseLines(from: data)
        }
    }

    @Test
    func `Find header-body separator`() async throws {
        let data = Data("Line 1\r\nLine 2\r\n\r\nBody".utf8)
        let lines = try RFC_9110.MessageParser.parseLines(from: data)

        let separatorIndex = RFC_9110.MessageParser.findHeaderBodySeparator(in: lines)

        #expect(separatorIndex == 2)
        #expect(lines[2].string.isEmpty)
    }

    @Test
    func `Find header-body separator - not found`() async throws {
        let data = Data("Line 1\r\nLine 2\r\nLine 3".utf8)
        let lines = try RFC_9110.MessageParser.parseLines(from: data)

        let separatorIndex = RFC_9110.MessageParser.findHeaderBodySeparator(in: lines)

        #expect(separatorIndex == nil)
    }

    @Test
    func `Parse HTTP request with headers and body`() async throws {
        let request = Data(
            "GET /path HTTP/1.1\r\nHost: example.com\r\nContent-Length: 5\r\n\r\nHello".utf8
        )
        let lines = try RFC_9110.MessageParser.parseLines(from: request)

        #expect(lines.count >= 4)
        #expect(lines[0].string == "GET /path HTTP/1.1")
        #expect(lines[1].string == "Host: example.com")
        #expect(lines[2].string == "Content-Length: 5")
        #expect(lines[3].string.isEmpty)

        let separatorIndex = RFC_9110.MessageParser.findHeaderBodySeparator(in: lines)
        #expect(separatorIndex == 3)
    }

    @Test
    func `Parse HTTP response with headers`() async throws {
        let response = Data("HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\n\r\n".utf8)
        let lines = try RFC_9110.MessageParser.parseLines(from: response)

        #expect(lines.count == 3)
        #expect(lines[0].string == "HTTP/1.1 200 OK")
        #expect(lines[1].string == "Content-Type: text/plain")
        #expect(lines[2].string.isEmpty)
    }

    @Test
    func `Parse empty data`() async throws {
        let data = Data()
        let lines = try RFC_9110.MessageParser.parseLines(from: data)

        #expect(lines.isEmpty)
    }

    @Test
    func `Line numbers are assigned correctly`() async throws {
        let data = Data("Line 1\r\nLine 2\r\nLine 3\r\n".utf8)
        let lines = try RFC_9110.MessageParser.parseLines(from: data)

        #expect(lines[0].lineNumber == 1)
        #expect(lines[1].lineNumber == 2)
        #expect(lines[2].lineNumber == 3)
    }

    @Test
    func `Parse long line`() async throws {
        let longLine = String(repeating: "a", count: 10000)
        let data = Data("\(longLine)\r\n".utf8)
        let lines = try RFC_9110.MessageParser.parseLines(from: data)

        #expect(lines.count == 1)
        #expect(lines[0].string == longLine)
    }

    @Test
    func `Parse UTF-8 content`() async throws {
        let data = Data("Header: 日本語\r\n\r\n".utf8)
        let lines = try RFC_9110.MessageParser.parseLines(from: data)

        #expect(lines.count == 2)
        #expect(lines[0].string == "Header: 日本語")
    }

    @Test
    func `Parse binary data with valid terminators`() async throws {
        var data = Data()
        data.append(contentsOf: [0xFF, 0xFE, 0xFD])  // Binary content
        data.append(contentsOf: [0x0D, 0x0A])  // CRLF
        data.append(contentsOf: [0x00, 0x01, 0x02])  // More binary
        data.append(contentsOf: [0x0D, 0x0A])  // CRLF

        let lines = try RFC_9110.MessageParser.parseLines(from: data)

        #expect(lines.count == 2)
        #expect(lines[0].content == [UInt8]([0xFF, 0xFE, 0xFD]))
        #expect(lines[0].terminator == .crlf)
        #expect(lines[1].content == [UInt8]([0x00, 0x01, 0x02]))
        #expect(lines[1].terminator == .crlf)
    }

    @Test
    func `LineTerminator equality`() async throws {
        #expect(RFC_9110.MessageParser.LineTerminator.crlf == .crlf)
        #expect(RFC_9110.MessageParser.LineTerminator.lf == .lf)
        #expect(RFC_9110.MessageParser.LineTerminator.none == .none)

        #expect(RFC_9110.MessageParser.LineTerminator.crlf != .lf)
        #expect(RFC_9110.MessageParser.LineTerminator.lf != .none)
    }

    @Test
    func `Line sendable conformance`() async throws {
        let line = RFC_9110.MessageParser.Line(
            content: Data("test".utf8),
            terminator: .crlf,
            lineNumber: 1
        )

        // Verify Line can be safely sent across concurrency boundaries
        await Task {
            _ = line
        }.value
    }

    @Test
    func `Multiple consecutive empty lines`() async throws {
        let data = Data("\r\n\r\n\r\n".utf8)
        let lines = try RFC_9110.MessageParser.parseLines(from: data)

        #expect(lines.count == 3)
        #expect(lines.allSatisfy { $0.string.isEmpty })
        #expect(lines.allSatisfy { $0.terminator == .crlf })
    }
}
