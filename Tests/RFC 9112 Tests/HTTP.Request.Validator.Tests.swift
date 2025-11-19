// HTTP.Request.Validator.Tests.swift
// swift-rfc-9112

import Testing
@testable import RFC_9112

@Suite
struct `HTTP.Request.Validator Tests` {

    @Test
    func `Validate request with Content-Length only`() async throws {
        let request = try RFC_9110.Request(
            method: .post,
            scheme: nil,
            userinfo: nil,
            host: RFC_3986.URI.Host("example.com"),
            port: nil,
            path: RFC_3986.URI.Path("/"),
            query: nil,
            headers: [
                try RFC_9110.Header.Field(name: "Content-Length", value: "10")
            ],
            body: Data("1234567890".utf8)
        )

        // Should not throw
        try RFC_9110.Request.Validator.validate(request)
    }

    @Test
    func `Validate request with Transfer-Encoding only`() async throws {
        let request = try RFC_9110.Request(
            method: .post,
            scheme: nil,
            userinfo: nil,
            host: RFC_3986.URI.Host("example.com"),
            port: nil,
            path: RFC_3986.URI.Path("/"),
            query: nil,
            headers: [
                try RFC_9110.Header.Field(name: "Transfer-Encoding", value: "chunked")
            ],
            body: Data()
        )

        // Should not throw
        try RFC_9110.Request.Validator.validate(request)
    }

    @Test
    func `Validate request with Transfer-Encoding and Content-Length`() async throws {
        let request = try RFC_9110.Request(
            method: .post,
            scheme: nil,
            userinfo: nil,
            host: RFC_3986.URI.Host("example.com"),
            port: nil,
            path: RFC_3986.URI.Path("/"),
            query: nil,
            headers: [
                try RFC_9110.Header.Field(name: "Transfer-Encoding", value: "chunked"),
                try RFC_9110.Header.Field(name: "Content-Length", value: "10")
            ],
            body: Data()
        )

        // RFC 9112 Section 11.2: Request smuggling prevention
        #expect(throws: RFC_9110.Request.Validator.ValidationError.self) {
            try RFC_9110.Request.Validator.validate(request)
        }
    }

    @Test
    func `Validate request with chunked as final encoding`() async throws {
        let request = try RFC_9110.Request(
            method: .post,
            scheme: nil,
            userinfo: nil,
            host: RFC_3986.URI.Host("example.com"),
            port: nil,
            path: RFC_3986.URI.Path("/"),
            query: nil,
            headers: [
                try RFC_9110.Header.Field(name: "Transfer-Encoding", value: "gzip, chunked")
            ],
            body: Data()
        )

        // Chunked should be the final encoding - should not throw
        try RFC_9110.Request.Validator.validate(request)
    }

    @Test
    func `Validate request with chunked not final`() async throws {
        let request = try RFC_9110.Request(
            method: .post,
            scheme: nil,
            userinfo: nil,
            host: RFC_3986.URI.Host("example.com"),
            port: nil,
            path: RFC_3986.URI.Path("/"),
            query: nil,
            headers: [
                try RFC_9110.Header.Field(name: "Transfer-Encoding", value: "chunked, gzip")
            ],
            body: Data()
        )

        #expect(throws: RFC_9110.Request.Validator.ValidationError.self) {
            try RFC_9110.Request.Validator.validate(request)
        }
    }

    @Test
    func `Validate request with multiple chunked encodings`() async throws {
        let request = try RFC_9110.Request(
            method: .post,
            scheme: nil,
            userinfo: nil,
            host: RFC_3986.URI.Host("example.com"),
            port: nil,
            path: RFC_3986.URI.Path("/"),
            query: nil,
            headers: [
                try RFC_9110.Header.Field(name: "Transfer-Encoding", value: "chunked, chunked")
            ],
            body: Data()
        )

        #expect(throws: RFC_9110.Request.Validator.ValidationError.self) {
            try RFC_9110.Request.Validator.validate(request)
        }
    }

    @Test
    func `Validate GET request without body`() async throws {
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

        // GET without body should be valid
        try RFC_9110.Request.Validator.validate(request)
    }

    @Test
    func `Validate HEAD request`() async throws {
        let request = try RFC_9110.Request(
            method: .head,
            scheme: nil,
            userinfo: nil,
            host: RFC_3986.URI.Host("example.com"),
            port: nil,
            path: RFC_3986.URI.Path("/"),
            query: nil,
            headers: [],
            body: nil
        )

        // HEAD requests should not have body
        try RFC_9110.Request.Validator.validate(request)
    }

    @Test
    func `Validate DELETE request`() async throws {
        let request = try RFC_9110.Request(
            method: .delete,
            scheme: nil,
            userinfo: nil,
            host: RFC_3986.URI.Host("example.com"),
            port: nil,
            path: RFC_3986.URI.Path("/resource"),
            query: nil,
            headers: [],
            body: nil
        )

        // DELETE without body should be valid
        try RFC_9110.Request.Validator.validate(request)
    }

    @Test
    func `Validate PUT request with body`() async throws {
        let request = try RFC_9110.Request(
            method: .put,
            scheme: nil,
            userinfo: nil,
            host: RFC_3986.URI.Host("example.com"),
            port: nil,
            path: RFC_3986.URI.Path("/resource"),
            query: nil,
            headers: [
                try RFC_9110.Header.Field(name: "Content-Length", value: "4")
            ],
            body: Data("test".utf8)
        )

        // PUT with body should be valid
        try RFC_9110.Request.Validator.validate(request)
    }

    @Test
    func `Validate PATCH request with body`() async throws {
        let request = try RFC_9110.Request(
            method: .patch,
            scheme: nil,
            userinfo: nil,
            host: RFC_3986.URI.Host("example.com"),
            port: nil,
            path: RFC_3986.URI.Path("/resource"),
            query: nil,
            headers: [
                try RFC_9110.Header.Field(name: "Content-Length", value: "5")
            ],
            body: Data("patch".utf8)
        )

        // PATCH with body should be valid
        try RFC_9110.Request.Validator.validate(request)
    }

    @Test
    func `Validate TRACE request`() async throws {
        let request = try RFC_9110.Request(
            method: .trace,
            scheme: nil,
            userinfo: nil,
            host: RFC_3986.URI.Host("example.com"),
            port: nil,
            path: RFC_3986.URI.Path("/"),
            query: nil,
            headers: [],
            body: nil
        )

        // TRACE should not have body
        try RFC_9110.Request.Validator.validate(request)
    }

    @Test
    func `Validate OPTIONS request`() async throws {
        let request = RFC_9110.Request(
            method: .options,
            target: .asterisk,
            headers: [],
            body: nil
        )

        // OPTIONS * should be valid
        try RFC_9110.Request.Validator.validate(request)
    }

    @Test
    func `Validate CONNECT request`() async throws {
        let authority = try RFC_3986.URI.Authority("example.com:443")
        let request = RFC_9110.Request(
            method: .connect,
            target: .authority(authority),
            headers: [],
            body: nil
        )

        // CONNECT should be valid
        try RFC_9110.Request.Validator.validate(request)
    }

    @Test
    func `Validate request with multiple Transfer-Encoding headers`() async throws {
        let request = try RFC_9110.Request(
            method: .post,
            scheme: nil,
            userinfo: nil,
            host: RFC_3986.URI.Host("example.com"),
            port: nil,
            path: RFC_3986.URI.Path("/"),
            query: nil,
            headers: [
                try RFC_9110.Header.Field(name: "Transfer-Encoding", value: "gzip"),
                try RFC_9110.Header.Field(name: "Transfer-Encoding", value: "chunked")
            ],
            body: Data()
        )

        // Multiple Transfer-Encoding headers should be valid if chunked is last
        try RFC_9110.Request.Validator.validate(request)
    }

    @Test
    func `Validate request with identity encoding`() async throws {
        let request = try RFC_9110.Request(
            method: .post,
            scheme: nil,
            userinfo: nil,
            host: RFC_3986.URI.Host("example.com"),
            port: nil,
            path: RFC_3986.URI.Path("/"),
            query: nil,
            headers: [
                try RFC_9110.Header.Field(name: "Transfer-Encoding", value: "identity")
            ],
            body: Data("test".utf8)
        )

        // Identity encoding (deprecated) should be handled
        try RFC_9110.Request.Validator.validate(request)
    }

    @Test
    func `Validate request with compress encoding`() async throws {
        let request = try RFC_9110.Request(
            method: .post,
            scheme: nil,
            userinfo: nil,
            host: RFC_3986.URI.Host("example.com"),
            port: nil,
            path: RFC_3986.URI.Path("/"),
            query: nil,
            headers: [
                try RFC_9110.Header.Field(name: "Transfer-Encoding", value: "compress, chunked")
            ],
            body: Data()
        )

        // compress encoding with chunked should be valid
        try RFC_9110.Request.Validator.validate(request)
    }

    @Test
    func `Validate request with deflate encoding`() async throws {
        let request = try RFC_9110.Request(
            method: .post,
            scheme: nil,
            userinfo: nil,
            host: RFC_3986.URI.Host("example.com"),
            port: nil,
            path: RFC_3986.URI.Path("/"),
            query: nil,
            headers: [
                try RFC_9110.Header.Field(name: "Transfer-Encoding", value: "deflate, chunked")
            ],
            body: Data()
        )

        // deflate encoding with chunked should be valid
        try RFC_9110.Request.Validator.validate(request)
    }

    @Test
    func `Validate request with case-insensitive Transfer-Encoding`() async throws {
        let request = try RFC_9110.Request(
            method: .post,
            scheme: nil,
            userinfo: nil,
            host: RFC_3986.URI.Host("example.com"),
            port: nil,
            path: RFC_3986.URI.Path("/"),
            query: nil,
            headers: [
                try RFC_9110.Header.Field(name: "transfer-encoding", value: "CHUNKED")
            ],
            body: Data()
        )

        // Header names and values should be case-insensitive
        try RFC_9110.Request.Validator.validate(request)
    }

    @Test
    func `Validate request with whitespace in Transfer-Encoding`() async throws {
        let request = try RFC_9110.Request(
            method: .post,
            scheme: nil,
            userinfo: nil,
            host: RFC_3986.URI.Host("example.com"),
            port: nil,
            path: RFC_3986.URI.Path("/"),
            query: nil,
            headers: [
                try RFC_9110.Header.Field(name: "Transfer-Encoding", value: " gzip , chunked ")
            ],
            body: Data()
        )

        // Whitespace around encoding values should be handled
        try RFC_9110.Request.Validator.validate(request)
    }
}
