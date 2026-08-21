import Byte_Primitives
import Testing

@testable import RFC_9112

@Suite
struct `HTTP.Response.Validator Tests` {
    @Suite struct Unit {}
    @Suite struct `Edge Case` {}
    @Suite struct Integration {}

    @Test
    func `Validate 200 OK response`() async throws {
        let response = RFC_9110.Response(
            status: RFC_9110.Status(200),
            headers: [
                try RFC_9110.Header.Field(name: "Content-Type", value: "text/plain"),
                try RFC_9110.Header.Field(name: "Content-Length", value: "5"),
            ],
            body: Array("Hello".utf8).map { Byte($0) }
        )

        try RFC_9110.Response.Validator.validate(response)
    }

    @Test
    func `Validate 404 Not Found response`() async throws {
        let response = RFC_9110.Response(
            status: RFC_9110.Status(404),
            headers: [],
            body: nil
        )

        try RFC_9110.Response.Validator.validate(response)
    }

    @Test
    func `Validate 101 Switching Protocols`() async throws {
        let response = RFC_9110.Response(
            status: RFC_9110.Status(101),
            headers: [
                try RFC_9110.Header.Field(name: "Upgrade", value: "websocket"),
                try RFC_9110.Header.Field(name: "Connection", value: "Upgrade"),
            ],
            body: nil
        )

        try RFC_9110.Response.Validator.validate(response)
    }

    @Test
    func `Validate 204 No Content`() async throws {
        let response = RFC_9110.Response(
            status: RFC_9110.Status(204),
            headers: [],
            body: nil
        )

        try RFC_9110.Response.Validator.validate(response)
    }

    @Test
    func `Validate 304 Not Modified`() async throws {
        let response = RFC_9110.Response(
            status: RFC_9110.Status(304),
            headers: [
                try RFC_9110.Header.Field(name: "ETag", value: "\"abc123\"")
            ],
            body: nil
        )

        try RFC_9110.Response.Validator.validate(response)
    }

    @Test
    func `Validate 101 with Transfer-Encoding`() async throws {
        let response = RFC_9110.Response(
            status: RFC_9110.Status(101),
            headers: [
                try RFC_9110.Header.Field(name: "Transfer-Encoding", value: "chunked")
            ],
            body: nil
        )

        #expect(throws: RFC_9110.Response.Validator.Error.self) {
            try RFC_9110.Response.Validator.validate(response)
        }
    }

    @Test
    func `Validate 204 with Transfer-Encoding`() async throws {
        let response = RFC_9110.Response(
            status: RFC_9110.Status(204),
            headers: [
                try RFC_9110.Header.Field(name: "Transfer-Encoding", value: "chunked")
            ],
            body: nil
        )

        #expect(throws: RFC_9110.Response.Validator.Error.self) {
            try RFC_9110.Response.Validator.validate(response)
        }
    }

    @Test
    func `Validate 304 with Transfer-Encoding`() async throws {
        let response = RFC_9110.Response(
            status: RFC_9110.Status(304),
            headers: [
                try RFC_9110.Header.Field(name: "Transfer-Encoding", value: "chunked")
            ],
            body: nil
        )

        #expect(throws: RFC_9110.Response.Validator.Error.self) {
            try RFC_9110.Response.Validator.validate(response)
        }
    }

    @Test
    func `Validate response with single Content-Length`() async throws {
        let response = RFC_9110.Response(
            status: RFC_9110.Status(200),
            headers: [
                try RFC_9110.Header.Field(name: "Content-Length", value: "10")
            ],
            body: [Byte](repeating: 0, count: 10)
        )

        try RFC_9110.Response.Validator.validate(response)
    }

    @Test
    func `Validate response with multiple identical Content-Length`() async throws {
        let response = RFC_9110.Response(
            status: RFC_9110.Status(200),
            headers: [
                try RFC_9110.Header.Field(name: "Content-Length", value: "10"),
                try RFC_9110.Header.Field(name: "Content-Length", value: "10"),
            ],
            body: [Byte](repeating: 0, count: 10)
        )

        try RFC_9110.Response.Validator.validate(response)
    }

    @Test
    func `Validate response with multiple different Content-Length`() async throws {
        let response = RFC_9110.Response(
            status: RFC_9110.Status(200),
            headers: [
                try RFC_9110.Header.Field(name: "Content-Length", value: "10"),
                try RFC_9110.Header.Field(name: "Content-Length", value: "20"),
            ],
            body: [Byte](repeating: 0, count: 10)
        )

        #expect(throws: RFC_9110.Response.Validator.Error.self) {
            try RFC_9110.Response.Validator.validate(response)
        }
    }

    @Test
    func `Validate response with Transfer-Encoding and Content-Length`() async throws {
        let response = RFC_9110.Response(
            status: RFC_9110.Status(200),
            headers: [
                try RFC_9110.Header.Field(name: "Transfer-Encoding", value: "chunked"),
                try RFC_9110.Header.Field(name: "Content-Length", value: "10"),
            ],
            body: [Byte]()
        )

        #expect(throws: RFC_9110.Response.Validator.Error.self) {
            try RFC_9110.Response.Validator.validate(response)
        }
    }

    @Test
    func `Validate response with invalid status code (too low)`() async throws {
        let response = RFC_9110.Response(
            status: RFC_9110.Status(99),
            headers: [],
            body: nil
        )

        #expect(throws: RFC_9110.Response.Validator.Error.self) {
            try RFC_9110.Response.Validator.validate(response)
        }
    }

    @Test
    func `Validate response with invalid status code (too high)`() async throws {
        let response = RFC_9110.Response(
            status: RFC_9110.Status(600),
            headers: [],
            body: nil
        )

        #expect(throws: RFC_9110.Response.Validator.Error.self) {
            try RFC_9110.Response.Validator.validate(response)
        }
    }

    @Test
    func `Validate 1xx response`() async throws {
        let response = RFC_9110.Response(
            status: RFC_9110.Status(100),
            headers: [],
            body: nil
        )

        try RFC_9110.Response.Validator.validate(response)
    }

    @Test
    func `Validate 2xx response`() async throws {
        let response = RFC_9110.Response(
            status: RFC_9110.Status(201),
            headers: [
                try RFC_9110.Header.Field(name: "Location", value: "/resource/123")
            ],
            body: nil
        )

        try RFC_9110.Response.Validator.validate(response)
    }

    @Test
    func `Validate 3xx response`() async throws {
        let response = RFC_9110.Response(
            status: RFC_9110.Status(301),
            headers: [
                try RFC_9110.Header.Field(name: "Location", value: "https://example.com/new")
            ],
            body: nil
        )

        try RFC_9110.Response.Validator.validate(response)
    }

    @Test
    func `Validate 4xx response`() async throws {
        let response = RFC_9110.Response(
            status: RFC_9110.Status(400),
            headers: [],
            body: Array("Bad Request".utf8).map { Byte($0) }
        )

        try RFC_9110.Response.Validator.validate(response)
    }

    @Test
    func `Validate 5xx response`() async throws {
        let response = RFC_9110.Response(
            status: RFC_9110.Status(500),
            headers: [],
            body: Array("Internal Server Error".utf8).map { Byte($0) }
        )

        try RFC_9110.Response.Validator.validate(response)
    }

    @Test
    func `Validate response with chunked encoding`() async throws {
        let response = RFC_9110.Response(
            status: RFC_9110.Status(200),
            headers: [
                try RFC_9110.Header.Field(name: "Transfer-Encoding", value: "chunked")
            ],
            body: [Byte]()
        )

        try RFC_9110.Response.Validator.validate(response)
    }

    @Test
    func `Validate response with gzip and chunked encoding`() async throws {
        let response = RFC_9110.Response(
            status: RFC_9110.Status(200),
            headers: [
                try RFC_9110.Header.Field(name: "Transfer-Encoding", value: "gzip, chunked")
            ],
            body: [Byte]()
        )

        try RFC_9110.Response.Validator.validate(response)
    }

    @Test
    func `Validate response with custom status code`() async throws {
        let response = RFC_9110.Response(
            status: RFC_9110.Status(599),
            headers: [],
            body: nil
        )

        try RFC_9110.Response.Validator.validate(response)
    }

    @Test
    func `Validate response without headers`() async throws {
        let response = RFC_9110.Response(
            status: RFC_9110.Status(200),
            headers: [],
            body: Array("Hello".utf8).map { Byte($0) }
        )

        try RFC_9110.Response.Validator.validate(response)
    }

    @Test
    func `Validate response without body`() async throws {
        let response = RFC_9110.Response(
            status: RFC_9110.Status(200),
            headers: [
                try RFC_9110.Header.Field(name: "Content-Length", value: "0")
            ],
            body: nil
        )

        try RFC_9110.Response.Validator.validate(response)
    }

    @Test
    func `Validate 206 Partial Content`() async throws {
        let response = RFC_9110.Response(
            status: RFC_9110.Status(206),
            headers: [
                try RFC_9110.Header.Field(name: "Content-Range", value: "bytes 0-99/1000"),
                try RFC_9110.Header.Field(name: "Content-Length", value: "100"),
            ],
            body: [Byte](repeating: 0, count: 100)
        )

        try RFC_9110.Response.Validator.validate(response)
    }

    @Test
    func `Validate case-insensitive header names`() async throws {
        let response = RFC_9110.Response(
            status: RFC_9110.Status(200),
            headers: [
                try RFC_9110.Header.Field(name: "content-length", value: "10"),
                try RFC_9110.Header.Field(name: "CONTENT-LENGTH", value: "10"),
            ],
            body: [Byte](repeating: 0, count: 10)
        )

        try RFC_9110.Response.Validator.validate(response)
    }
}
