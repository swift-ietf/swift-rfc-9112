import RFC_3986
import RFC_9110
import Byte
import Testing

@testable import RFC_9112
@testable import RFC_9112_Parser
@testable import RFC_9112_Serializer

@Suite
struct `HTTP.Request.Validator Tests` {
    @Suite struct Unit {}
    @Suite struct `Edge Case` {}
    @Suite struct Integration {}

    @Test
    func `Validate request with Content-Length only`() async throws {
        let request = try RFC_9112.Message.Request<[Byte]>(
            method: .post,
            target: .origin(path: RFC_3986.URI.Path("/"), query: nil),
            headers: [
                try RFC_9110.Field(name: "Content-Length", value: "10")
            ],
            content: Array("1234567890".utf8).map { Byte(bitPattern: $0) }
        )

        try RFC_9112.Request.Validator.validate(request)
    }

    @Test
    func `Validate request with Transfer-Encoding only`() async throws {
        let request = try RFC_9112.Message.Request<[Byte]>(
            method: .post,
            target: .origin(path: RFC_3986.URI.Path("/"), query: nil),
            headers: [
                try RFC_9110.Field(name: "Transfer-Encoding", value: "chunked")
            ],
            content: [Byte]()
        )

        try RFC_9112.Request.Validator.validate(request)
    }

    @Test
    func `Validate request with Transfer-Encoding and Content-Length`() async throws {
        let request = try RFC_9112.Message.Request<[Byte]>(
            method: .post,
            target: .origin(path: RFC_3986.URI.Path("/"), query: nil),
            headers: [
                try RFC_9110.Field(name: "Transfer-Encoding", value: "chunked"),
                try RFC_9110.Field(name: "Content-Length", value: "10"),
            ],
            content: [Byte]()
        )

        #expect(throws: RFC_9112.Request.Validator.Error.self) {
            try RFC_9112.Request.Validator.validate(request)
        }
    }

    @Test
    func `Validate request with chunked as final encoding`() async throws {
        let request = try RFC_9112.Message.Request<[Byte]>(
            method: .post,
            target: .origin(path: RFC_3986.URI.Path("/"), query: nil),
            headers: [
                try RFC_9110.Field(name: "Transfer-Encoding", value: "gzip, chunked")
            ],
            content: [Byte]()
        )

        try RFC_9112.Request.Validator.validate(request)
    }

    @Test
    func `Validate request with chunked not final`() async throws {
        let request = try RFC_9112.Message.Request<[Byte]>(
            method: .post,
            target: .origin(path: RFC_3986.URI.Path("/"), query: nil),
            headers: [
                try RFC_9110.Field(name: "Transfer-Encoding", value: "chunked, gzip")
            ],
            content: [Byte]()
        )

        #expect(throws: RFC_9112.Request.Validator.Error.self) {
            try RFC_9112.Request.Validator.validate(request)
        }
    }

    @Test
    func `Validate request with multiple chunked encodings`() async throws {
        let request = try RFC_9112.Message.Request<[Byte]>(
            method: .post,
            target: .origin(path: RFC_3986.URI.Path("/"), query: nil),
            headers: [
                try RFC_9110.Field(name: "Transfer-Encoding", value: "chunked, chunked")
            ],
            content: [Byte]()
        )

        #expect(throws: RFC_9112.Request.Validator.Error.self) {
            try RFC_9112.Request.Validator.validate(request)
        }
    }

    @Test
    func `Validate GET request without body`() async throws {
        let request = try RFC_9112.Message.Request<[Byte]>(
            method: .get,
            target: .origin(path: RFC_3986.URI.Path("/"), query: nil),
            headers: [],
            content: nil
        )

        try RFC_9112.Request.Validator.validate(request)
    }

    @Test
    func `Validate HEAD request`() async throws {
        let request = try RFC_9112.Message.Request<[Byte]>(
            method: .head,
            target: .origin(path: RFC_3986.URI.Path("/"), query: nil),
            headers: [],
            content: nil
        )

        try RFC_9112.Request.Validator.validate(request)
    }

    @Test
    func `Validate DELETE request`() async throws {
        let request = try RFC_9112.Message.Request<[Byte]>(
            method: .delete,
            target: .origin(path: RFC_3986.URI.Path("/resource"), query: nil),
            headers: [],
            content: nil
        )

        try RFC_9112.Request.Validator.validate(request)
    }

    @Test
    func `Validate PUT request with body`() async throws {
        let request = try RFC_9112.Message.Request<[Byte]>(
            method: .put,
            target: .origin(path: RFC_3986.URI.Path("/resource"), query: nil),
            headers: [
                try RFC_9110.Field(name: "Content-Length", value: "4")
            ],
            content: Array("test".utf8).map { Byte(bitPattern: $0) }
        )

        try RFC_9112.Request.Validator.validate(request)
    }

    @Test
    func `Validate PATCH request with body`() async throws {
        let request = try RFC_9112.Message.Request<[Byte]>(
            method: .patch,
            target: .origin(path: RFC_3986.URI.Path("/resource"), query: nil),
            headers: [
                try RFC_9110.Field(name: "Content-Length", value: "5")
            ],
            content: Array("patch".utf8).map { Byte(bitPattern: $0) }
        )

        try RFC_9112.Request.Validator.validate(request)
    }

    @Test
    func `Validate TRACE request`() async throws {
        let request = try RFC_9112.Message.Request<[Byte]>(
            method: .trace,
            target: .origin(path: RFC_3986.URI.Path("/"), query: nil),
            headers: [],
            content: nil
        )

        try RFC_9112.Request.Validator.validate(request)
    }

    @Test
    func `Validate OPTIONS request`() async throws {
        let request = RFC_9112.Message.Request<[Byte]>(
            method: .options,
            target: .asterisk,
            headers: [],
            content: nil
        )

        try RFC_9112.Request.Validator.validate(request)
    }

    @Test
    func `Validate CONNECT request`() async throws {
        let authority = try RFC_3986.URI.Authority("example.com:443")
        let request = RFC_9112.Message.Request<[Byte]>(
            method: .connect,
            target: .authority(authority),
            headers: [],
            content: nil
        )

        try RFC_9112.Request.Validator.validate(request)
    }

    @Test
    func `Validate request with multiple Transfer-Encoding headers`() async throws {
        let request = try RFC_9112.Message.Request<[Byte]>(
            method: .post,
            target: .origin(path: RFC_3986.URI.Path("/"), query: nil),
            headers: [
                try RFC_9110.Field(name: "Transfer-Encoding", value: "gzip"),
                try RFC_9110.Field(name: "Transfer-Encoding", value: "chunked"),
            ],
            content: [Byte]()
        )

        try RFC_9112.Request.Validator.validate(request)
    }

    @Test
    func `Validate request with identity encoding`() async throws {
        let request = try RFC_9112.Message.Request<[Byte]>(
            method: .post,
            target: .origin(path: RFC_3986.URI.Path("/"), query: nil),
            headers: [
                try RFC_9110.Field(name: "Transfer-Encoding", value: "identity")
            ],
            content: Array("test".utf8).map { Byte(bitPattern: $0) }
        )

        try RFC_9112.Request.Validator.validate(request)
    }

    @Test
    func `Validate request with compress encoding`() async throws {
        let request = try RFC_9112.Message.Request<[Byte]>(
            method: .post,
            target: .origin(path: RFC_3986.URI.Path("/"), query: nil),
            headers: [
                try RFC_9110.Field(name: "Transfer-Encoding", value: "compress, chunked")
            ],
            content: [Byte]()
        )

        try RFC_9112.Request.Validator.validate(request)
    }

    @Test
    func `Validate request with deflate encoding`() async throws {
        let request = try RFC_9112.Message.Request<[Byte]>(
            method: .post,
            target: .origin(path: RFC_3986.URI.Path("/"), query: nil),
            headers: [
                try RFC_9110.Field(name: "Transfer-Encoding", value: "deflate, chunked")
            ],
            content: [Byte]()
        )

        try RFC_9112.Request.Validator.validate(request)
    }

    @Test
    func `Validate request with case-insensitive Transfer-Encoding`() async throws {
        let request = try RFC_9112.Message.Request<[Byte]>(
            method: .post,
            target: .origin(path: RFC_3986.URI.Path("/"), query: nil),
            headers: [
                try RFC_9110.Field(name: "transfer-encoding", value: "CHUNKED")
            ],
            content: [Byte]()
        )

        try RFC_9112.Request.Validator.validate(request)
    }

    @Test
    func `Validate request with whitespace in Transfer-Encoding`() async throws {
        let request = try RFC_9112.Message.Request<[Byte]>(
            method: .post,
            target: .origin(path: RFC_3986.URI.Path("/"), query: nil),
            headers: [
                try RFC_9110.Field(name: "Transfer-Encoding", value: " gzip , chunked ")
            ],
            content: [Byte]()
        )

        try RFC_9112.Request.Validator.validate(request)
    }
}
