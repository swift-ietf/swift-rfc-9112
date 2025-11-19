// HTTP.Request.Validator.Tests.swift
// swift-rfc-9112

import Testing
@testable import RFC_9112

@Suite("HTTP.Request.Validator Tests")
struct HTTPRequestValidatorTests {

    @Test("Validate request with Content-Length only")
    func validateContentLengthOnly() async throws {
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

    @Test("Validate request with Transfer-Encoding only")
    func validateTransferEncodingOnly() async throws {
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

    @Test("Validate request with Transfer-Encoding and Content-Length")
    func validateBothEncodings() async throws {
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

    @Test("Validate request with chunked as final encoding")
    func validateChunkedFinal() async throws {
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

    @Test("Validate request with chunked not final")
    func validateChunkedNotFinal() async throws {
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

    @Test("Validate request with multiple chunked encodings")
    func validateDoubleChunked() async throws {
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

    @Test("Validate GET request without body")
    func validateGETNoBody() async throws {
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

    @Test("Validate HEAD request")
    func validateHEAD() async throws {
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

    @Test("Validate DELETE request")
    func validateDELETE() async throws {
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

    @Test("Validate PUT request with body")
    func validatePUTWithBody() async throws {
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

    @Test("Validate PATCH request with body")
    func validatePATCHWithBody() async throws {
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

    @Test("Validate TRACE request")
    func validateTRACE() async throws {
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

    @Test("Validate OPTIONS request")
    func validateOPTIONS() async throws {
        let request = RFC_9110.Request(
            method: .options,
            target: .asterisk,
            headers: [],
            body: nil
        )

        // OPTIONS * should be valid
        try RFC_9110.Request.Validator.validate(request)
    }

    @Test("Validate CONNECT request")
    func validateCONNECT() async throws {
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

    @Test("Validate request with multiple Transfer-Encoding headers")
    func validateMultipleTransferEncodingHeaders() async throws {
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

    @Test("Validate request with identity encoding")
    func validateIdentityEncoding() async throws {
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

    @Test("Validate request with compress encoding")
    func validateCompressEncoding() async throws {
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

    @Test("Validate request with deflate encoding")
    func validateDeflateEncoding() async throws {
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

    @Test("Validate request with case-insensitive Transfer-Encoding")
    func validateCaseInsensitiveTransferEncoding() async throws {
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

    @Test("Validate request with whitespace in Transfer-Encoding")
    func validateTransferEncodingWhitespace() async throws {
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
