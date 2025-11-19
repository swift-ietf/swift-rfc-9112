// HTTP.Response.Validator.Tests.swift
// swift-rfc-9112

import Testing
@testable import RFC_9112

@Suite("HTTP.Response.Validator Tests")
struct HTTPResponseValidatorTests {

    @Test("Validate 200 OK response")
    func validate200OK() async throws {
        let response = RFC_9110.Response(
            status: RFC_9110.Status(200),
            headers: [
                try RFC_9110.Header.Field(name: "Content-Type", value: "text/plain"),
                try RFC_9110.Header.Field(name: "Content-Length", value: "5")
            ],
            body: Data("Hello".utf8)
        )

        // Should not throw
        try RFC_9110.Response.Validator.validate(response)
    }

    @Test("Validate 404 Not Found response")
    func validate404() async throws {
        let response = RFC_9110.Response(
            status: RFC_9110.Status(404),
            headers: [],
            body: nil
        )

        // Should not throw
        try RFC_9110.Response.Validator.validate(response)
    }

    @Test("Validate 101 Switching Protocols")
    func validate101() async throws {
        let response = RFC_9110.Response(
            status: RFC_9110.Status(101),
            headers: [
                try RFC_9110.Header.Field(name: "Upgrade", value: "websocket"),
                try RFC_9110.Header.Field(name: "Connection", value: "Upgrade")
            ],
            body: nil
        )

        // 101 should not have body
        try RFC_9110.Response.Validator.validate(response)
    }

    @Test("Validate 204 No Content")
    func validate204() async throws {
        let response = RFC_9110.Response(
            status: RFC_9110.Status(204),
            headers: [],
            body: nil
        )

        // 204 should not have body
        try RFC_9110.Response.Validator.validate(response)
    }

    @Test("Validate 304 Not Modified")
    func validate304() async throws {
        let response = RFC_9110.Response(
            status: RFC_9110.Status(304),
            headers: [
                try RFC_9110.Header.Field(name: "ETag", value: "\"abc123\"")
            ],
            body: nil
        )

        // 304 should not have body
        try RFC_9110.Response.Validator.validate(response)
    }

    @Test("Validate 101 with Transfer-Encoding")
    func validate101WithTransferEncoding() async throws {
        let response = RFC_9110.Response(
            status: RFC_9110.Status(101),
            headers: [
                try RFC_9110.Header.Field(name: "Transfer-Encoding", value: "chunked")
            ],
            body: nil
        )

        // 101 cannot have Transfer-Encoding
        #expect(throws: RFC_9110.Response.Validator.ValidationError.self) {
            try RFC_9110.Response.Validator.validate(response)
        }
    }

    @Test("Validate 204 with Transfer-Encoding")
    func validate204WithTransferEncoding() async throws {
        let response = RFC_9110.Response(
            status: RFC_9110.Status(204),
            headers: [
                try RFC_9110.Header.Field(name: "Transfer-Encoding", value: "chunked")
            ],
            body: nil
        )

        // 204 cannot have Transfer-Encoding
        #expect(throws: RFC_9110.Response.Validator.ValidationError.self) {
            try RFC_9110.Response.Validator.validate(response)
        }
    }

    @Test("Validate 304 with Transfer-Encoding")
    func validate304WithTransferEncoding() async throws {
        let response = RFC_9110.Response(
            status: RFC_9110.Status(304),
            headers: [
                try RFC_9110.Header.Field(name: "Transfer-Encoding", value: "chunked")
            ],
            body: nil
        )

        // 304 cannot have Transfer-Encoding
        #expect(throws: RFC_9110.Response.Validator.ValidationError.self) {
            try RFC_9110.Response.Validator.validate(response)
        }
    }

    @Test("Validate response with single Content-Length")
    func validateSingleContentLength() async throws {
        let response = RFC_9110.Response(
            status: RFC_9110.Status(200),
            headers: [
                try RFC_9110.Header.Field(name: "Content-Length", value: "10")
            ],
            body: Data(repeating: 0, count: 10)
        )

        // Single Content-Length is valid
        try RFC_9110.Response.Validator.validate(response)
    }

    @Test("Validate response with multiple identical Content-Length")
    func validateMultipleIdenticalContentLength() async throws {
        let response = RFC_9110.Response(
            status: RFC_9110.Status(200),
            headers: [
                try RFC_9110.Header.Field(name: "Content-Length", value: "10"),
                try RFC_9110.Header.Field(name: "Content-Length", value: "10")
            ],
            body: Data(repeating: 0, count: 10)
        )

        // Multiple identical Content-Length values are allowed
        try RFC_9110.Response.Validator.validate(response)
    }

    @Test("Validate response with multiple different Content-Length")
    func validateMultipleDifferentContentLength() async throws {
        let response = RFC_9110.Response(
            status: RFC_9110.Status(200),
            headers: [
                try RFC_9110.Header.Field(name: "Content-Length", value: "10"),
                try RFC_9110.Header.Field(name: "Content-Length", value: "20")
            ],
            body: Data(repeating: 0, count: 10)
        )

        // Multiple different Content-Length values should be rejected
        #expect(throws: RFC_9110.Response.Validator.ValidationError.self) {
            try RFC_9110.Response.Validator.validate(response)
        }
    }

    @Test("Validate response with Transfer-Encoding and Content-Length")
    func validateTransferEncodingWithContentLength() async throws {
        let response = RFC_9110.Response(
            status: RFC_9110.Status(200),
            headers: [
                try RFC_9110.Header.Field(name: "Transfer-Encoding", value: "chunked"),
                try RFC_9110.Header.Field(name: "Content-Length", value: "10")
            ],
            body: Data()
        )

        // Transfer-Encoding with Content-Length should be rejected
        #expect(throws: RFC_9110.Response.Validator.ValidationError.self) {
            try RFC_9110.Response.Validator.validate(response)
        }
    }

    @Test("Validate response with invalid status code (too low)")
    func validateInvalidStatusCodeLow() async throws {
        let response = RFC_9110.Response(
            status: RFC_9110.Status(99),
            headers: [],
            body: nil
        )

        // Status code < 100 is invalid
        #expect(throws: RFC_9110.Response.Validator.ValidationError.self) {
            try RFC_9110.Response.Validator.validate(response)
        }
    }

    @Test("Validate response with invalid status code (too high)")
    func validateInvalidStatusCodeHigh() async throws {
        let response = RFC_9110.Response(
            status: RFC_9110.Status(600),
            headers: [],
            body: nil
        )

        // Status code >= 600 is invalid
        #expect(throws: RFC_9110.Response.Validator.ValidationError.self) {
            try RFC_9110.Response.Validator.validate(response)
        }
    }

    @Test("Validate 1xx response")
    func validate1xxResponse() async throws {
        let response = RFC_9110.Response(
            status: RFC_9110.Status(100),
            headers: [],
            body: nil
        )

        // 100 Continue should be valid
        try RFC_9110.Response.Validator.validate(response)
    }

    @Test("Validate 2xx response")
    func validate2xxResponse() async throws {
        let response = RFC_9110.Response(
            status: RFC_9110.Status(201),
            headers: [
                try RFC_9110.Header.Field(name: "Location", value: "/resource/123")
            ],
            body: nil
        )

        // 201 Created should be valid
        try RFC_9110.Response.Validator.validate(response)
    }

    @Test("Validate 3xx response")
    func validate3xxResponse() async throws {
        let response = RFC_9110.Response(
            status: RFC_9110.Status(301),
            headers: [
                try RFC_9110.Header.Field(name: "Location", value: "https://example.com/new")
            ],
            body: nil
        )

        // 301 Moved Permanently should be valid
        try RFC_9110.Response.Validator.validate(response)
    }

    @Test("Validate 4xx response")
    func validate4xxResponse() async throws {
        let response = RFC_9110.Response(
            status: RFC_9110.Status(400),
            headers: [],
            body: Data("Bad Request".utf8)
        )

        // 400 Bad Request should be valid
        try RFC_9110.Response.Validator.validate(response)
    }

    @Test("Validate 5xx response")
    func validate5xxResponse() async throws {
        let response = RFC_9110.Response(
            status: RFC_9110.Status(500),
            headers: [],
            body: Data("Internal Server Error".utf8)
        )

        // 500 Internal Server Error should be valid
        try RFC_9110.Response.Validator.validate(response)
    }

    @Test("Validate response with chunked encoding")
    func validateChunkedEncoding() async throws {
        let response = RFC_9110.Response(
            status: RFC_9110.Status(200),
            headers: [
                try RFC_9110.Header.Field(name: "Transfer-Encoding", value: "chunked")
            ],
            body: Data()
        )

        // Chunked encoding should be valid
        try RFC_9110.Response.Validator.validate(response)
    }

    @Test("Validate response with gzip and chunked encoding")
    func validateGzipChunkedEncoding() async throws {
        let response = RFC_9110.Response(
            status: RFC_9110.Status(200),
            headers: [
                try RFC_9110.Header.Field(name: "Transfer-Encoding", value: "gzip, chunked")
            ],
            body: Data()
        )

        // Multiple encodings with chunked last should be valid
        try RFC_9110.Response.Validator.validate(response)
    }

    @Test("Validate response with custom status code")
    func validateCustomStatusCode() async throws {
        let response = RFC_9110.Response(
            status: RFC_9110.Status(599),
            headers: [],
            body: nil
        )

        // Custom status code in valid range should be accepted
        try RFC_9110.Response.Validator.validate(response)
    }

    @Test("Validate response without headers")
    func validateNoHeaders() async throws {
        let response = RFC_9110.Response(
            status: RFC_9110.Status(200),
            headers: [],
            body: Data("Hello".utf8)
        )

        // Response without headers should be valid
        try RFC_9110.Response.Validator.validate(response)
    }

    @Test("Validate response without body")
    func validateNoBody() async throws {
        let response = RFC_9110.Response(
            status: RFC_9110.Status(200),
            headers: [
                try RFC_9110.Header.Field(name: "Content-Length", value: "0")
            ],
            body: nil
        )

        // Response with no body should be valid
        try RFC_9110.Response.Validator.validate(response)
    }

    @Test("Validate 206 Partial Content")
    func validate206() async throws {
        let response = RFC_9110.Response(
            status: RFC_9110.Status(206),
            headers: [
                try RFC_9110.Header.Field(name: "Content-Range", value: "bytes 0-99/1000"),
                try RFC_9110.Header.Field(name: "Content-Length", value: "100")
            ],
            body: Data(repeating: 0, count: 100)
        )

        // 206 Partial Content should be valid
        try RFC_9110.Response.Validator.validate(response)
    }

    @Test("Validate case-insensitive header names")
    func validateCaseInsensitiveHeaders() async throws {
        let response = RFC_9110.Response(
            status: RFC_9110.Status(200),
            headers: [
                try RFC_9110.Header.Field(name: "content-length", value: "10"),
                try RFC_9110.Header.Field(name: "CONTENT-LENGTH", value: "10")
            ],
            body: Data(repeating: 0, count: 10)
        )

        // Multiple identical Content-Length (case-insensitive) should be allowed
        try RFC_9110.Response.Validator.validate(response)
    }
}
