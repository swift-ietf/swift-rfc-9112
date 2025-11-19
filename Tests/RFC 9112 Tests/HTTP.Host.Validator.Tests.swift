// HTTP.Host.Validator.Tests.swift
// swift-rfc-9112

import Testing
@testable import RFC_9112

@Suite("HTTP.Host.Validator Tests")
struct HTTPHostValidatorTests {

    @Test("Validate request with single Host header")
    func validateSingleHost() async throws {
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

    @Test("Validate request with Host header including port")
    func validateHostWithPort() async throws {
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

    @Test("Validate request with IPv6 Host")
    func validateIPv6Host() async throws {
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

    @Test("Validate HTTP/1.1 request missing Host header")
    func validateHTTP11MissingHost() async throws {
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

        #expect(throws: RFC_9110.Host.Validator.ValidationError.missingHost) {
            try RFC_9110.Host.Validator.validate(request: request, version: .http11)
        }
    }

    @Test("Validate HTTP/1.0 request missing Host header")
    func validateHTTP10MissingHost() async throws {
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

    @Test("Validate request with multiple Host headers")
    func validateMultipleHosts() async throws {
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

        #expect(throws: RFC_9110.Host.Validator.ValidationError.self) {
            try RFC_9110.Host.Validator.validate(request: request, version: .http11)
        }
    }

    @Test("Validate request with case-insensitive Host header")
    func validateCaseInsensitiveHost() async throws {
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

    @Test("Validate CONNECT request")
    func validateConnectRequest() async throws {
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

    @Test("Validate request with empty Host value")
    func validateEmptyHost() async throws {
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

        #expect(throws: RFC_9110.Host.Validator.ValidationError.self) {
            try RFC_9110.Host.Validator.validate(request: request, version: .http11)
        }
    }

    @Test("Validate request with whitespace-only Host")
    func validateWhitespaceHost() async throws {
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

        #expect(throws: RFC_9110.Host.Validator.ValidationError.self) {
            try RFC_9110.Host.Validator.validate(request: request, version: .http11)
        }
    }

    @Test("Validate OPTIONS * request")
    func validateOptionsAsterisk() async throws {
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

    @Test("Validate request with absolute-form target")
    func validateAbsoluteForm() async throws {
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

    @Test("Validate request with mismatched Host and target")
    func validateMismatchedHost() async throws {
        let uri = try RFC_3986.URI("http://example.com/path")
        let request = RFC_9110.Request(
            method: .get,
            target: .absolute(uri),
            headers: [
                try RFC_9110.Header.Field(name: "Host", value: "different.com")
            ],
            body: nil
        )

        #expect(throws: RFC_9110.Host.Validator.ValidationError.self) {
            try RFC_9110.Host.Validator.validate(request: request, version: .http11)
        }
    }

    @Test("Validate request with valid subdomain")
    func validateSubdomain() async throws {
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

    @Test("Validate request with IPv4 address")
    func validateIPv4() async throws {
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

    @Test("Validate request with localhost")
    func validateLocalhost() async throws {
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

    @Test("Validate HTTP/2.0 request without Host")
    func validateHTTP2NoHost() async throws {
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
        #expect(throws: RFC_9110.Host.Validator.ValidationError.missingHost) {
            try RFC_9110.Host.Validator.validate(request: request, version: http2)
        }
    }
}
