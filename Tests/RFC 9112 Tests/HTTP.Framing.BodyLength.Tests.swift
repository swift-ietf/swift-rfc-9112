import Testing

@testable import RFC_9112

@Suite
struct `HTTP.Framing.BodyLength Tests` {
    @Suite struct Unit {}
    @Suite struct `Edge Case` {}
    @Suite struct Integration {}
}

extension `HTTP.Framing.BodyLength Tests`.`Edge Case` {
    @Test
    func `non-digit Content-Length throws rather than reporting no body`() throws {
        let headers: HTTP.Headers = [try .init(name: "Content-Length", value: "abc")]
        #expect(throws: HTTP.Framing.Error.invalidContentLength("abc")) {
            try HTTP.Framing.BodyLength.determine(context: .request, headers: headers)
        }
    }

    @Test
    func `negative Content-Length throws`() throws {

        let headers: HTTP.Headers = [try .init(name: "Content-Length", value: "-1")]
        #expect(throws: HTTP.Framing.Error.invalidContentLength("-1")) {
            try HTTP.Framing.BodyLength.determine(context: .request, headers: headers)
        }
    }

    @Test
    func `a leading-plus Content-Length throws`() throws {

        let headers: HTTP.Headers = [try .init(name: "Content-Length", value: "+5")]
        #expect(throws: HTTP.Framing.Error.invalidContentLength("+5")) {
            try HTTP.Framing.BodyLength.determine(context: .request, headers: headers)
        }
    }

    @Test
    func `a hex-prefixed Content-Length throws`() throws {

        let headers: HTTP.Headers = [try .init(name: "Content-Length", value: "0x5")]
        #expect(throws: HTTP.Framing.Error.invalidContentLength("0x5")) {
            try HTTP.Framing.BodyLength.determine(context: .request, headers: headers)
        }
    }

    @Test
    func `empty Content-Length throws`() throws {
        let headers: HTTP.Headers = [try .init(name: "Content-Length", value: "")]
        #expect(throws: (any Swift.Error).self) {
            try HTTP.Framing.BodyLength.determine(context: .request, headers: headers)
        }
    }

    @Test
    func `differing Content-Length field lines throw`() throws {
        let headers: HTTP.Headers = [
            try .init(name: "Content-Length", value: "42"),
            try .init(name: "Content-Length", value: "43"),
        ]
        #expect(throws: HTTP.Framing.Error.conflictingContentLength(["42", "43"])) {
            try HTTP.Framing.BodyLength.determine(context: .request, headers: headers)
        }
    }

    @Test
    func `differing values inside one Content-Length field throw`() throws {
        let headers: HTTP.Headers = [try .init(name: "Content-Length", value: "42, 43")]
        #expect(throws: HTTP.Framing.Error.conflictingContentLength(["42", "43"])) {
            try HTTP.Framing.BodyLength.determine(context: .request, headers: headers)
        }
    }

    @Test
    func `Transfer-Encoding with Content-Length is reported, not silently preferred`() throws {

        let headers: HTTP.Headers = [
            try .init(name: "Transfer-Encoding", value: "chunked"),
            try .init(name: "Content-Length", value: "42"),
        ]
        #expect(throws: HTTP.Framing.Error.transferEncodingWithContentLength) {
            try HTTP.Framing.BodyLength.determine(context: .request, headers: headers)
        }
    }

    @Test
    func `chunked not final is rejected on a request`() throws {

        let headers: HTTP.Headers = [try .init(name: "Transfer-Encoding", value: "chunked, gzip")]
        #expect(throws: HTTP.Framing.Error.chunkedNotFinal) {
            try HTTP.Framing.BodyLength.determine(context: .request, headers: headers)
        }
    }

    @Test
    func `Transfer-Encoding without chunked is rejected on a request`() throws {
        let headers: HTTP.Headers = [try .init(name: "Transfer-Encoding", value: "gzip")]
        #expect(throws: HTTP.Framing.Error.transferEncodingWithoutChunked) {
            try HTTP.Framing.BodyLength.determine(context: .request, headers: headers)
        }
    }

    @Test
    func `chunked split across field lines so it is not final overall is rejected`() throws {

        let headers: HTTP.Headers = [
            try .init(name: "Transfer-Encoding", value: "chunked"),
            try .init(name: "Transfer-Encoding", value: "gzip"),
        ]
        #expect(throws: HTTP.Framing.Error.chunkedNotFinal) {
            try HTTP.Framing.BodyLength.determine(context: .request, headers: headers)
        }
    }
}

extension `HTTP.Framing.BodyLength Tests`.Unit {
    @Test
    func `identical repeated Content-Length field lines are legal`() throws {

        let headers: HTTP.Headers = [
            try .init(name: "Content-Length", value: "42"),
            try .init(name: "Content-Length", value: "42"),
        ]
        let length = try HTTP.Framing.BodyLength.determine(context: .request, headers: headers)
        #expect(length == .length(42))
    }

    @Test
    func `identical values inside one Content-Length field are legal`() throws {
        let headers: HTTP.Headers = [try .init(name: "Content-Length", value: "42, 42")]
        let length = try HTTP.Framing.BodyLength.determine(context: .request, headers: headers)
        #expect(length == .length(42))
    }

    @Test
    func `chunked as the final coding is legal`() throws {
        let headers: HTTP.Headers = [try .init(name: "Transfer-Encoding", value: "gzip, chunked")]
        let length = try HTTP.Framing.BodyLength.determine(context: .request, headers: headers)
        #expect(length == .chunked)
    }

    @Test
    func `optional whitespace around a list separator does not invalidate a Content-Length`()
        throws
    {

        let headers: HTTP.Headers = [try .init(name: "Content-Length", value: "42 ,\t42")]
        let length = try HTTP.Framing.BodyLength.determine(context: .request, headers: headers)
        #expect(length == .length(42))
    }

    @Test
    func `a plain Content-Length is a length`() throws {
        let headers: HTTP.Headers = [try .init(name: "Content-Length", value: "13")]
        let length = try HTTP.Framing.BodyLength.determine(context: .request, headers: headers)
        #expect(length == .length(13))
    }

    @Test
    func `zero is a valid length and is not no-body`() throws {
        let headers: HTTP.Headers = [try .init(name: "Content-Length", value: "0")]
        let length = try HTTP.Framing.BodyLength.determine(context: .request, headers: headers)
        #expect(length == .length(0))
    }
}

extension `HTTP.Framing.BodyLength Tests`.Integration {
    @Test
    func `chunked-not-final rejects on request but reads until close on response`() throws {

        let headers: HTTP.Headers = [try .init(name: "Transfer-Encoding", value: "chunked, gzip")]

        #expect(throws: HTTP.Framing.Error.chunkedNotFinal) {
            try HTTP.Framing.BodyLength.determine(context: .request, headers: headers)
        }

        let response = try HTTP.Framing.BodyLength.determine(
            context: .response(statusCode: 200, requestMethod: .get),
            headers: headers
        )
        #expect(response == .untilClose)
    }

    @Test
    func `Transfer-Encoding without chunked rejects on request, reads until close on response`()
        throws
    {
        let headers: HTTP.Headers = [try .init(name: "Transfer-Encoding", value: "gzip")]

        #expect(throws: HTTP.Framing.Error.transferEncodingWithoutChunked) {
            try HTTP.Framing.BodyLength.determine(context: .request, headers: headers)
        }

        let response = try HTTP.Framing.BodyLength.determine(
            context: .response(statusCode: 200, requestMethod: .get),
            headers: headers
        )
        #expect(response == .untilClose)
    }

    @Test
    func `absent framing headers mean no body on a request and until-close on a response`() throws {
        let headers: HTTP.Headers = []

        let request = try HTTP.Framing.BodyLength.determine(context: .request, headers: headers)
        #expect(request == .none)

        let response = try HTTP.Framing.BodyLength.determine(
            context: .response(statusCode: 200, requestMethod: .get),
            headers: headers
        )
        #expect(response == .untilClose)
    }
}

extension `HTTP.Framing.BodyLength Tests`.Unit {
    @Test
    func `a response to HEAD has no body even with a Content-Length`() throws {
        let headers: HTTP.Headers = [try .init(name: "Content-Length", value: "100")]
        let length = try HTTP.Framing.BodyLength.determine(
            context: .response(statusCode: 200, requestMethod: .head),
            headers: headers
        )
        #expect(length == .none)
    }

    @Test
    func `a 204 response has no body`() throws {
        let headers: HTTP.Headers = []
        let length = try HTTP.Framing.BodyLength.determine(
            context: .response(statusCode: 204, requestMethod: .get),
            headers: headers
        )
        #expect(length == .none)
    }

    @Test
    func `a 304 response has no body`() throws {
        let headers: HTTP.Headers = []
        let length = try HTTP.Framing.BodyLength.determine(
            context: .response(statusCode: 304, requestMethod: .get),
            headers: headers
        )
        #expect(length == .none)
    }

    @Test
    func `a successful CONNECT response is a tunnel, distinct from no body`() throws {

        let headers: HTTP.Headers = []
        let length = try HTTP.Framing.BodyLength.determine(
            context: .response(statusCode: 200, requestMethod: .connect),
            headers: headers
        )
        #expect(length == .tunnel)
    }
}
