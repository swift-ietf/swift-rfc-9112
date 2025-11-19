// HTTP.Connection.Tests.swift
// swift-rfc-9112

import Testing
@testable import RFC_9112

@Suite("HTTP.Connection Tests")
struct HTTPConnectionTests {

    @Test("Connection - close")
    func connectionClose() async throws {
        let conn = HTTP.Connection.close

        #expect(conn.headerValue == "close")
        #expect(conn.hasClose == true)
        #expect(conn.hasKeepAlive == false)
        #expect(conn.shouldPersist() == false)
    }

    @Test("Connection - keep-alive")
    func connectionKeepAlive() async throws {
        let conn = HTTP.Connection.keepAlive

        #expect(conn.headerValue == "keep-alive")
        #expect(conn.hasClose == false)
        #expect(conn.hasKeepAlive == true)
        #expect(conn.shouldPersist() == true)
    }

    @Test("Connection - multiple options")
    func connectionMultipleOptions() async throws {
        let conn = HTTP.Connection(options: ["close", "custom"])

        let value = conn.headerValue
        #expect(value.contains("close"))
        #expect(value.contains("custom"))
    }

    @Test("Parse - close")
    func parseClose() async throws {
        let parsed = HTTP.Connection.parse("close")

        #expect(parsed == .close)
    }

    @Test("Parse - keep-alive")
    func parseKeepAlive() async throws {
        let parsed = HTTP.Connection.parse("keep-alive")

        #expect(parsed == .keepAlive)
    }

    @Test("Parse - multiple options")
    func parseMultiple() async throws {
        let parsed = HTTP.Connection.parse("close, custom")

        #expect(parsed?.options == Set(["close", "custom"]))
    }

    @Test("Parse - case insensitive")
    func parseCaseInsensitive() async throws {
        let parsed = HTTP.Connection.parse("CLOSE")

        #expect(parsed == .close)
    }

    @Test("Parse - with whitespace")
    func parseWithWhitespace() async throws {
        let parsed = HTTP.Connection.parse("  close  ,  custom  ")

        #expect(parsed?.options == Set(["close", "custom"]))
    }

    @Test("Parse - empty")
    func parseEmpty() async throws {
        #expect(HTTP.Connection.parse("") == nil)
        #expect(HTTP.Connection.parse("  ") == nil)
    }

    @Test("shouldPersist - HTTP/1.1 defaults to true")
    func shouldPersistHTTP11() async throws {
        let conn = HTTP.Connection(options: [])

        #expect(conn.shouldPersist(version: "HTTP/1.1") == true)
    }

    @Test("shouldPersist - HTTP/1.1 with close")
    func shouldPersistHTTP11WithClose() async throws {
        let conn = HTTP.Connection.close

        #expect(conn.shouldPersist(version: "HTTP/1.1") == false)
    }

    @Test("shouldPersist - HTTP/1.0 defaults to false")
    func shouldPersistHTTP10() async throws {
        let conn = HTTP.Connection(options: [])

        #expect(conn.shouldPersist(version: "HTTP/1.0") == false)
    }

    @Test("shouldPersist - HTTP/1.0 with keep-alive")
    func shouldPersistHTTP10WithKeepAlive() async throws {
        let conn = HTTP.Connection.keepAlive

        #expect(conn.shouldPersist(version: "HTTP/1.0") == true)
    }

    @Test("Equality")
    func equality() async throws {
        #expect(HTTP.Connection.close == .close)
        #expect(HTTP.Connection.keepAlive != .close)
        #expect(HTTP.Connection(options: ["close"]) == .close)
    }

    @Test("Hashable")
    func hashable() async throws {
        var set: Set<HTTP.Connection> = []

        set.insert(.close)
        set.insert(.close) // Duplicate
        set.insert(.keepAlive)

        #expect(set.count == 2)
    }

    @Test("Codable")
    func codable() async throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let conn = HTTP.Connection.close
        let encoded = try encoder.encode(conn)
        let decoded = try decoder.decode(HTTP.Connection.self, from: encoded)

        #expect(decoded == conn)
    }

    @Test("Description")
    func description() async throws {
        let conn = HTTP.Connection.close

        #expect(conn.description == "close")
    }

    @Test("LosslessStringConvertible")
    func losslessStringConvertible() async throws {
        let conn: HTTP.Connection? = HTTP.Connection("close")

        #expect(conn != nil)
        #expect(conn == .close)
    }

    @Test("ExpressibleByStringLiteral")
    func expressibleByStringLiteral() async throws {
        let conn: HTTP.Connection = "close"

        #expect(conn == .close)
    }

    @Test("Round trip - format and parse")
    func roundTrip() async throws {
        let original = HTTP.Connection.close
        let headerValue = original.headerValue
        let parsed = HTTP.Connection.parse(headerValue)

        #expect(parsed == original)
    }
}
