// HTTP.Connection.Tests.swift
// swift-rfc-9112

import Testing
@testable import RFC_9112

@Suite
struct `HTTP.Connection Tests` {

    @Test
    func `Connection - close`() async throws {
        let conn = HTTP.Connection.close

        #expect(conn.headerValue == "close")
        #expect(conn.hasClose == true)
        #expect(conn.hasKeepAlive == false)
        #expect(conn.shouldPersist() == false)
    }

    @Test
    func `Connection - keep-alive`() async throws {
        let conn = HTTP.Connection.keepAlive

        #expect(conn.headerValue == "keep-alive")
        #expect(conn.hasClose == false)
        #expect(conn.hasKeepAlive == true)
        #expect(conn.shouldPersist() == true)
    }

    @Test
    func `Connection - multiple options`() async throws {
        let conn = HTTP.Connection(options: ["close", "custom"])

        let value = conn.headerValue
        #expect(value.contains("close"))
        #expect(value.contains("custom"))
    }

    @Test
    func `Parse - close`() async throws {
        let parsed = HTTP.Connection.parse("close")

        #expect(parsed == .close)
    }

    @Test
    func `Parse - keep-alive`() async throws {
        let parsed = HTTP.Connection.parse("keep-alive")

        #expect(parsed == .keepAlive)
    }

    @Test
    func `Parse - multiple options`() async throws {
        let parsed = HTTP.Connection.parse("close, custom")

        #expect(parsed?.options == Set(["close", "custom"]))
    }

    @Test
    func `Parse - case insensitive`() async throws {
        let parsed = HTTP.Connection.parse("CLOSE")

        #expect(parsed == .close)
    }

    @Test
    func `Parse - with whitespace`() async throws {
        let parsed = HTTP.Connection.parse("  close  ,  custom  ")

        #expect(parsed?.options == Set(["close", "custom"]))
    }

    @Test
    func `Parse - empty`() async throws {
        #expect(HTTP.Connection.parse("") == nil)
        #expect(HTTP.Connection.parse("  ") == nil)
    }

    @Test
    func `shouldPersist - HTTP/1.1 defaults to true`() async throws {
        let conn = HTTP.Connection(options: [])

        #expect(conn.shouldPersist(version: "HTTP/1.1") == true)
    }

    @Test
    func `shouldPersist - HTTP/1.1 with close`() async throws {
        let conn = HTTP.Connection.close

        #expect(conn.shouldPersist(version: "HTTP/1.1") == false)
    }

    @Test
    func `shouldPersist - HTTP/1.0 defaults to false`() async throws {
        let conn = HTTP.Connection(options: [])

        #expect(conn.shouldPersist(version: "HTTP/1.0") == false)
    }

    @Test
    func `shouldPersist - HTTP/1.0 with keep-alive`() async throws {
        let conn = HTTP.Connection.keepAlive

        #expect(conn.shouldPersist(version: "HTTP/1.0") == true)
    }

    @Test
    func `Equality`() async throws {
        #expect(HTTP.Connection.close == .close)
        #expect(HTTP.Connection.keepAlive != .close)
        #expect(HTTP.Connection(options: ["close"]) == .close)
    }

    @Test
    func `Hashable`() async throws {
        var set: Set<HTTP.Connection> = []

        set.insert(.close)
        set.insert(.close) // Duplicate
        set.insert(.keepAlive)

        #expect(set.count == 2)
    }

    @Test
    func `Codable`() async throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let conn = HTTP.Connection.close
        let encoded = try encoder.encode(conn)
        let decoded = try decoder.decode(HTTP.Connection.self, from: encoded)

        #expect(decoded == conn)
    }

    @Test
    func `Description`() async throws {
        let conn = HTTP.Connection.close

        #expect(conn.description == "close")
    }

    @Test
    func `LosslessStringConvertible`() async throws {
        let conn: HTTP.Connection? = HTTP.Connection("close")

        #expect(conn != nil)
        #expect(conn == .close)
    }

    @Test
    func `ExpressibleByStringLiteral`() async throws {
        let conn: HTTP.Connection = "close"

        #expect(conn == .close)
    }

    @Test
    func `Round trip - format and parse`() async throws {
        let original = HTTP.Connection.close
        let headerValue = original.headerValue
        let parsed = HTTP.Connection.parse(headerValue)

        #expect(parsed == original)
    }
}
