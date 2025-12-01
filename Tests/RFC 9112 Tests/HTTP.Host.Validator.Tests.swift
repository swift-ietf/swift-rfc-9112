// HTTP.Host.Validator.Tests.swift
// swift-rfc-9112

import Testing
@testable import RFC_9112

@Suite
struct `HTTP.Host.Validator Tests` {

    @Test
    func `Validate request with single Host header`() async throws {
        let request = try RFC_9110.Request(
            method: .get,
            scheme: nil,
            userinfo: nil,
            host: RFC_3986.URI.Host("example.com"),
            port: nil,
            path: RFC_3986.URI.Path("/"),
            query: nil,
            headers: [
                try RFC_9110.Header.Field(name: "Host", value: "example.com")
            ],
            body: nil
        )

        // Should not throw
        try RFC_9110.Host.Validator.validate(request: request, version: .http11)
    }

    @Test
    func `Validate request with Host header including port`() async throws {
        let request = try RFC_9110.Request(
            method: .get,
            scheme: nil,
            userinfo: nil,
            host: RFC_3986.URI.Host("example.com"),
            port: RFC_3986.URI.Port(8080),
            path: RFC_3986.URI.Path("/"),
            query: nil,
            headers: [
                try RFC_9110.Header.Field(name: "Host", value: "example.com:8080")
            ],
            body: nil
        )

        // Should not throw
        try RFC_9110.Host.Validator.validate(request: request, version: .http11)
    }

    @Test
    func `Validate request with IPv6 Host`() async throws {
        let request = try RFC_9110.Request(
            method: .get,
            scheme: nil,
            userinfo: nil,
            host: RFC_3986.URI.Host("[::1]"),
            port: nil,
            path: RFC_3986.URI.Path("/"),
            query: nil,
            headers: [
                try RFC_9110.Header.Field(name: "Host", value: "[::1]")
            ],
            body: nil
        )

        // Should not throw
        try RFC_9110.Host.Validator.validate(request: request, version: .http11)
    }

    @Test
    func `Validate HTTP/1.1 request missing Host header`() async throws {
        let request = try RFC_9110.Request(
            method: .get,
            scheme: nil,
            userinfo: nil,
            host: RFC_3986.URI.Host("example.com"),
            port: nil,
            path: RFC_3986.URI.Path("/"),
            query: nil,
            headers: [],
            body: nil
        )

        #expect(throws: RFC_9110.Host.Validator.Error.missingHost) {
            try RFC_9110.Host.Validator.validate(request: request, version: .http11)
        }
    }

    @Test
    func `Validate HTTP/1.0 request missing Host header`() async throws {
        let request = try RFC_9110.Request(
            method: .get,
            scheme: nil,
            userinfo: nil,
            host: RFC_3986.URI.Host("example.com"),
            port: nil,
            path: RFC_3986.URI.Path("/"),
            query: nil,
            headers: [],
            body: nil
        )

        // HTTP/1.0 doesn't require Host header - should not throw
        try RFC_9110.Host.Validator.validate(request: request, version: .http10)
    }

    @Test
    func `Validate request with multiple Host headers`() async throws {
        let request = try RFC_9110.Request(
            method: .get,
            scheme: nil,
            userinfo: nil,
            host: RFC_3986.URI.Host("example.com"),
            port: nil,
            path: RFC_3986.URI.Path("/"),
            query: nil,
            headers: [
                try RFC_9110.Header.Field(name: "Host", value: "example.com"),
                try RFC_9110.Header.Field(name: "Host", value: "another.com")
            ],
            body: nil
        )

        #expect(throws: RFC_9110.Host.Validator.Error.self) {
            try RFC_9110.Host.Validator.validate(request: request, version: .http11)
        }
    }

    @Test
    func `Validate request with case-insensitive Host header`() async throws {
        let request = try RFC_9110.Request(
            method: .get,
            scheme: nil,
            userinfo: nil,
            host: RFC_3986.URI.Host("example.com"),
            port: nil,
            path: RFC_3986.URI.Path("/"),
            query: nil,
            headers: [
                try RFC_9110.Header.Field(name: "host", value: "example.com")
            ],
            body: nil
        )

        // Should recognize "host" (lowercase) as Host header
        try RFC_9110.Host.Validator.validate(request: request, version: .http11)
    }

    @Test
    func `Validate CONNECT request`() async throws {
        let request = try RFC_9110.Request(
            method: .connect,
            scheme: nil,
            userinfo: nil,
            host: RFC_3986.URI.Host("example.com"),
            port: RFC_3986.URI.Port(443),
            path: nil,
            query: nil,
            headers: [
                try RFC_9110.Header.Field(name: "Host", value: "example.com:443")
            ],
            body: nil
        )

        // CONNECT requests have special handling
        try RFC_9110.Host.Validator.validate(request: request, version: .http11)
    }

    @Test
    func `Validate request with empty Host value`() async throws {
        let request = try RFC_9110.Request(
            method: .get,
            scheme: nil,
            userinfo: nil,
            host: RFC_3986.URI.Host("example.com"),
            port: nil,
            path: RFC_3986.URI.Path("/"),
            query: nil,
            headers: [
                try RFC_9110.Header.Field(name: "Host", value: "")
            ],
            body: nil
        )

        #expect(throws: RFC_9110.Host.Validator.Error.self) {
            try RFC_9110.Host.Validator.validate(request: request, version: .http11)
        }
    }

    @Test
    func `Validate request with whitespace-only Host`() async throws {
        let request = try RFC_9110.Request(
            method: .get,
            scheme: nil,
            userinfo: nil,
            host: RFC_3986.URI.Host("example.com"),
            port: nil,
            path: RFC_3986.URI.Path("/"),
            query: nil,
            headers: [
                try RFC_9110.Header.Field(name: "Host", value: "   ")
            ],
            body: nil
        )

        #expect(throws: RFC_9110.Host.Validator.Error.self) {
            try RFC_9110.Host.Validator.validate(request: request, version: .http11)
        }
    }

    @Test
    func `Validate OPTIONS * request`() async throws {
        let request = RFC_9110.Request(
            method: .options,
            target: .asterisk,
            headers: [
                try RFC_9110.Header.Field(name: "Host", value: "example.com")
            ],
            body: nil
        )

        // OPTIONS * with Host header should be valid
        try RFC_9110.Host.Validator.validate(request: request, version: .http11)
    }

    @Test
    func `Validate request with absolute-form target`() async throws {
        let uri = try RFC_3986.URI("http://example.com/path")
        let request = RFC_9110.Request(
            method: .get,
            target: .absolute(uri),
            headers: [
                try RFC_9110.Header.Field(name: "Host", value: "example.com")
            ],
            body: nil
        )

        // Absolute-form includes host in request-target
        try RFC_9110.Host.Validator.validate(request: request, version: .http11)
    }

    @Test
    func `Validate request with mismatched Host and target`() async throws {
        let uri = try RFC_3986.URI("http://example.com/path")
        let request = RFC_9110.Request(
            method: .get,
            target: .absolute(uri),
            headers: [
                try RFC_9110.Header.Field(name: "Host", value: "different.com")
            ],
            body: nil
        )

        #expect(throws: RFC_9110.Host.Validator.Error.self) {
            try RFC_9110.Host.Validator.validate(request: request, version: .http11)
        }
    }

    @Test
    func `Validate request with valid subdomain`() async throws {
        let request = try RFC_9110.Request(
            method: .get,
            scheme: nil,
            userinfo: nil,
            host: RFC_3986.URI.Host("api.example.com"),
            port: nil,
            path: RFC_3986.URI.Path("/"),
            query: nil,
            headers: [
                try RFC_9110.Header.Field(name: "Host", value: "api.example.com")
            ],
            body: nil
        )

        // Subdomain should be valid
        try RFC_9110.Host.Validator.validate(request: request, version: .http11)
    }

    @Test
    func `Validate request with IPv4 address`() async throws {
        let request = try RFC_9110.Request(
            method: .get,
            scheme: nil,
            userinfo: nil,
            host: RFC_3986.URI.Host("192.168.1.1"),
            port: nil,
            path: RFC_3986.URI.Path("/"),
            query: nil,
            headers: [
                try RFC_9110.Header.Field(name: "Host", value: "192.168.1.1")
            ],
            body: nil
        )

        // IPv4 address should be valid
        try RFC_9110.Host.Validator.validate(request: request, version: .http11)
    }

    @Test
    func `Validate request with localhost`() async throws {
        let request = try RFC_9110.Request(
            method: .get,
            scheme: nil,
            userinfo: nil,
            host: RFC_3986.URI.Host("localhost"),
            port: RFC_3986.URI.Port(8080),
            path: RFC_3986.URI.Path("/"),
            query: nil,
            headers: [
                try RFC_9110.Header.Field(name: "Host", value: "localhost:8080")
            ],
            body: nil
        )

        // localhost with port should be valid
        try RFC_9110.Host.Validator.validate(request: request, version: .http11)
    }

    @Test
    func `Validate HTTP/2.0 request without Host`() async throws {
        let request = try RFC_9110.Request(
            method: .get,
            scheme: nil,
            userinfo: nil,
            host: RFC_3986.URI.Host("example.com"),
            port: nil,
            path: RFC_3986.URI.Path("/"),
            query: nil,
            headers: [],
            body: nil
        )

        // HTTP/2.0 uses :authority pseudo-header instead of Host
        // For this validator, we may allow it
        let http2 = RFC_9110.Version(major: 2, minor: 0)

        // Implementation-dependent: may not require Host for HTTP/2
        // This test documents expected behavior
        #expect(throws: RFC_9110.Host.Validator.Error.missingHost) {
            try RFC_9110.Host.Validator.validate(request: request, version: http2)
        }
    }
}
