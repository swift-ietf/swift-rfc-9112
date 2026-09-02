import RFC_9110
import Byte
import Testing

@testable import RFC_9112

@Suite
struct `HTTP.Response.Validator Tests` {
    @Suite struct Unit {}
    @Suite struct `Edge Case` {}
    @Suite struct Integration {}

    @Test
    func `Validate 200 OK response`() async throws {
        let response = RFC_9112.Message.Response<[Byte]>(
            status: RFC_9110.Status(200),
            headers: [
                try RFC_9110.Field(name: "Content-Type", value: "text/plain"),
                try RFC_9110.Field(name: "Content-Length", value: "5"),
            ],
            content: Array("Hello".utf8).map { Byte(bitPattern: $0) }
        )

        try RFC_9112.Response.Validator.validate(response)
    }

    @Test
    func `Validate 404 Not Found response`() async throws {
        let response = RFC_9112.Message.Response<[Byte]>(
            status: RFC_9110.Status(404),
            headers: [],
            content: nil
        )

        try RFC_9112.Response.Validator.validate(response)
    }

    @Test
    func `Validate 101 Switching Protocols`() async throws {
        let response = RFC_9112.Message.Response<[Byte]>(
            status: RFC_9110.Status(101),
            headers: [
                try RFC_9110.Field(name: "Upgrade", value: "websocket"),
                try RFC_9110.Field(name: "Connection", value: "Upgrade"),
            ],
            content: nil
        )

        try RFC_9112.Response.Validator.validate(response)
    }

    @Test
    func `Validate 204 No Content`() async throws {
        let response = RFC_9112.Message.Response<[Byte]>(
            status: RFC_9110.Status(204),
            headers: [],
            content: nil
        )

        try RFC_9112.Response.Validator.validate(response)
    }

    @Test
    func `Validate 304 Not Modified`() async throws {
        let response = RFC_9112.Message.Response<[Byte]>(
            status: RFC_9110.Status(304),
            headers: [
                try RFC_9110.Field(name: "ETag", value: "\"abc123\"")
            ],
            content: nil
        )

        try RFC_9112.Response.Validator.validate(response)
    }

    @Test
    func `Validate 101 with Transfer-Encoding`() async throws {
        let response = RFC_9112.Message.Response<[Byte]>(
            status: RFC_9110.Status(101),
            headers: [
                try RFC_9110.Field(name: "Transfer-Encoding", value: "chunked")
            ],
            content: nil
        )

        #expect(throws: RFC_9112.Response.Validator.Error.self) {
            try RFC_9112.Response.Validator.validate(response)
        }
    }

    @Test
    func `Validate 204 with Transfer-Encoding`() async throws {
        let response = RFC_9112.Message.Response<[Byte]>(
            status: RFC_9110.Status(204),
            headers: [
                try RFC_9110.Field(name: "Transfer-Encoding", value: "chunked")
            ],
            content: nil
        )

        #expect(throws: RFC_9112.Response.Validator.Error.self) {
            try RFC_9112.Response.Validator.validate(response)
        }
    }

    @Test
    func `Validate 304 with Transfer-Encoding`() async throws {
        let response = RFC_9112.Message.Response<[Byte]>(
            status: RFC_9110.Status(304),
            headers: [
                try RFC_9110.Field(name: "Transfer-Encoding", value: "chunked")
            ],
            content: nil
        )

        #expect(throws: RFC_9112.Response.Validator.Error.self) {
            try RFC_9112.Response.Validator.validate(response)
        }
    }

    @Test
    func `Validate response with single Content-Length`() async throws {
        let response = RFC_9112.Message.Response<[Byte]>(
            status: RFC_9110.Status(200),
            headers: [
                try RFC_9110.Field(name: "Content-Length", value: "10")
            ],
            content: [Byte](repeating: Byte(bitPattern: 0), count: 10)
        )

        try RFC_9112.Response.Validator.validate(response)
    }

    @Test
    func `Validate response with multiple identical Content-Length`() async throws {
        let response = RFC_9112.Message.Response<[Byte]>(
            status: RFC_9110.Status(200),
            headers: [
                try RFC_9110.Field(name: "Content-Length", value: "10"),
                try RFC_9110.Field(name: "Content-Length", value: "10"),
            ],
            content: [Byte](repeating: Byte(bitPattern: 0), count: 10)
        )

        try RFC_9112.Response.Validator.validate(response)
    }

    @Test
    func `Validate response with multiple different Content-Length`() async throws {
        let response = RFC_9112.Message.Response<[Byte]>(
            status: RFC_9110.Status(200),
            headers: [
                try RFC_9110.Field(name: "Content-Length", value: "10"),
                try RFC_9110.Field(name: "Content-Length", value: "20"),
            ],
            content: [Byte](repeating: Byte(bitPattern: 0), count: 10)
        )

        #expect(throws: RFC_9112.Response.Validator.Error.self) {
            try RFC_9112.Response.Validator.validate(response)
        }
    }

    @Test
    func `Validate response with Transfer-Encoding and Content-Length`() async throws {
        let response = RFC_9112.Message.Response<[Byte]>(
            status: RFC_9110.Status(200),
            headers: [
                try RFC_9110.Field(name: "Transfer-Encoding", value: "chunked"),
                try RFC_9110.Field(name: "Content-Length", value: "10"),
            ],
            content: [Byte]()
        )

        #expect(throws: RFC_9112.Response.Validator.Error.self) {
            try RFC_9112.Response.Validator.validate(response)
        }
    }

    @Test
    func `Validate response with invalid status code (too low)`() async throws {
        let response = RFC_9112.Message.Response<[Byte]>(
            status: RFC_9110.Status(99),
            headers: [],
            content: nil
        )

        #expect(throws: RFC_9112.Response.Validator.Error.self) {
            try RFC_9112.Response.Validator.validate(response)
        }
    }

    @Test
    func `Validate response with invalid status code (too high)`() async throws {
        let response = RFC_9112.Message.Response<[Byte]>(
            status: RFC_9110.Status(600),
            headers: [],
            content: nil
        )

        #expect(throws: RFC_9112.Response.Validator.Error.self) {
            try RFC_9112.Response.Validator.validate(response)
        }
    }

    @Test
    func `Validate 1xx response`() async throws {
        let response = RFC_9112.Message.Response<[Byte]>(
            status: RFC_9110.Status(100),
            headers: [],
            content: nil
        )

        try RFC_9112.Response.Validator.validate(response)
    }

    @Test
    func `Validate 2xx response`() async throws {
        let response = RFC_9112.Message.Response<[Byte]>(
            status: RFC_9110.Status(201),
            headers: [
                try RFC_9110.Field(name: "Location", value: "/resource/123")
            ],
            content: nil
        )

        try RFC_9112.Response.Validator.validate(response)
    }

    @Test
    func `Validate 3xx response`() async throws {
        let response = RFC_9112.Message.Response<[Byte]>(
            status: RFC_9110.Status(301),
            headers: [
                try RFC_9110.Field(name: "Location", value: "https://example.com/new")
            ],
            content: nil
        )

        try RFC_9112.Response.Validator.validate(response)
    }

    @Test
    func `Validate 4xx response`() async throws {
        let response = RFC_9112.Message.Response<[Byte]>(
            status: RFC_9110.Status(400),
            headers: [],
            content: Array("Bad Request".utf8).map { Byte(bitPattern: $0) }
        )

        try RFC_9112.Response.Validator.validate(response)
    }

    @Test
    func `Validate 5xx response`() async throws {
        let response = RFC_9112.Message.Response<[Byte]>(
            status: RFC_9110.Status(500),
            headers: [],
            content: Array("Internal Server Error".utf8).map { Byte(bitPattern: $0) }
        )

        try RFC_9112.Response.Validator.validate(response)
    }

    @Test
    func `Validate response with chunked encoding`() async throws {
        let response = RFC_9112.Message.Response<[Byte]>(
            status: RFC_9110.Status(200),
            headers: [
                try RFC_9110.Field(name: "Transfer-Encoding", value: "chunked")
            ],
            content: [Byte]()
        )

        try RFC_9112.Response.Validator.validate(response)
    }

    @Test
    func `Validate response with gzip and chunked encoding`() async throws {
        let response = RFC_9112.Message.Response<[Byte]>(
            status: RFC_9110.Status(200),
            headers: [
                try RFC_9110.Field(name: "Transfer-Encoding", value: "gzip, chunked")
            ],
            content: [Byte]()
        )

        try RFC_9112.Response.Validator.validate(response)
    }

    @Test
    func `Validate response with custom status code`() async throws {
        let response = RFC_9112.Message.Response<[Byte]>(
            status: RFC_9110.Status(599),
            headers: [],
            content: nil
        )

        try RFC_9112.Response.Validator.validate(response)
    }

    @Test
    func `Validate response without headers`() async throws {
        let response = RFC_9112.Message.Response<[Byte]>(
            status: RFC_9110.Status(200),
            headers: [],
            content: Array("Hello".utf8).map { Byte(bitPattern: $0) }
        )

        try RFC_9112.Response.Validator.validate(response)
    }

    @Test
    func `Validate response without body`() async throws {
        let response = RFC_9112.Message.Response<[Byte]>(
            status: RFC_9110.Status(200),
            headers: [
                try RFC_9110.Field(name: "Content-Length", value: "0")
            ],
            content: nil
        )

        try RFC_9112.Response.Validator.validate(response)
    }

    @Test
    func `Validate 206 Partial Content`() async throws {
        let response = RFC_9112.Message.Response<[Byte]>(
            status: RFC_9110.Status(206),
            headers: [
                try RFC_9110.Field(name: "Content-Range", value: "bytes 0-99/1000"),
                try RFC_9110.Field(name: "Content-Length", value: "100"),
            ],
            content: [Byte](repeating: Byte(bitPattern: 0), count: 100)
        )

        try RFC_9112.Response.Validator.validate(response)
    }

    @Test
    func `Validate case-insensitive header names`() async throws {
        let response = RFC_9112.Message.Response<[Byte]>(
            status: RFC_9110.Status(200),
            headers: [
                try RFC_9110.Field(name: "content-length", value: "10"),
                try RFC_9110.Field(name: "CONTENT-LENGTH", value: "10"),
            ],
            content: [Byte](repeating: Byte(bitPattern: 0), count: 10)
        )

        try RFC_9112.Response.Validator.validate(response)
    }
}
