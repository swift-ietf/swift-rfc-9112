import Byte_Primitives
import Testing

@testable import RFC_9112

@Suite
struct `HTTP.Request.Validator Tests` {
    @Suite struct Unit {}
    @Suite struct `Edge Case` {}
    @Suite struct Integration {}

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
            body: Array("1234567890".utf8).map { Byte($0) }
        )

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
            body: [Byte]()
        )

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
                try RFC_9110.Header.Field(name: "Content-Length", value: "10"),
            ],
            body: [Byte]()
        )

        #expect(throws: RFC_9110.Request.Validator.Error.self) {
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
            body: [Byte]()
        )

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
            body: [Byte]()
        )

        #expect(throws: RFC_9110.Request.Validator.Error.self) {
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
            body: [Byte]()
        )

        #expect(throws: RFC_9110.Request.Validator.Error.self) {
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
            body: Array("test".utf8).map { Byte($0) }
        )

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
            body: Array("patch".utf8).map { Byte($0) }
        )

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
                try RFC_9110.Header.Field(name: "Transfer-Encoding", value: "chunked"),
            ],
            body: [Byte]()
        )

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
            body: Array("test".utf8).map { Byte($0) }
        )

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
            body: [Byte]()
        )

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
            body: [Byte]()
        )

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
            body: [Byte]()
        )

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
            body: [Byte]()
        )

        try RFC_9110.Request.Validator.validate(request)
    }
}
