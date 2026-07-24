// HTTP.Framing.BodyLength.Tests.swift
// swift-rfc-9112
//
// RFC 9112 Section 6.3 conformance, both directions.
//
// The reject set alone is not sufficient: a determination that rejected every
// message near the hazard would pass all of it. The accept set is what proves
// the rejections are discriminating, and the request/response pair on the same
// input is what proves the two dispositions were distinguished rather than
// unified into whichever was easier to implement.

import Testing

@testable import RFC_9112

@Suite
struct `HTTP.Framing.BodyLength Tests` {
    @Suite struct Unit {}
    @Suite struct `Edge Case` {}
    @Suite struct Integration {}
}

// MARK: - Edge Case: framing that MUST NOT be reported as a valid length

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
        // Content-Length = 1*DIGIT, so a sign is not merely out of range.
        let headers: HTTP.Headers = [try .init(name: "Content-Length", value: "-1")]
        #expect(throws: HTTP.Framing.Error.invalidContentLength("-1")) {
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
        // Section 6.3 rule 3. The condition must be reported so a forwarding
        // intermediary can obey the MUST to strip Content-Length; silently
        // returning .chunked leaves it unable to comply.
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
        // `hasChunked` membership would accept this; `isChunkedFinal` is the
        // conformant test and this is the case that separates them.
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
        // Two field lines are equivalent to one comma-joined list, so this is
        // `chunked, gzip` and chunked is not final. Judging finality per line
        // would wrongly accept it.
        let headers: HTTP.Headers = [
            try .init(name: "Transfer-Encoding", value: "chunked"),
            try .init(name: "Transfer-Encoding", value: "gzip"),
        ]
        #expect(throws: HTTP.Framing.Error.chunkedNotFinal) {
            try HTTP.Framing.BodyLength.determine(context: .request, headers: headers)
        }
    }
}

// MARK: - Unit: valid framing that MUST NOT be rejected

extension `HTTP.Framing.BodyLength Tests`.Unit {
    @Test
    func `identical repeated Content-Length field lines are legal`() throws {
        // Section 6.3 rule 4 makes only DIFFERING values invalid.
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
        // OWS is permitted around list separators (RFC 9110 Section 5.6.1), so
        // the digits check must run on the trimmed token, not the raw element.
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

// MARK: - Integration: the same input framed in both roles

extension `HTTP.Framing.BodyLength Tests`.Integration {
    @Test
    func `chunked-not-final rejects on request but reads until close on response`() throws {
        // The pair, not either half, is what proves the two dispositions were
        // distinguished rather than unified into whichever was easier.
        let headers: HTTP.Headers = [try .init(name: "Transfer-Encoding", value: "chunked, gzip")]

        #expect(throws: HTTP.Framing.Error.chunkedNotFinal) {
            try HTTP.Framing.BodyLength.determine(context: .request, headers: headers)
        }

        let response = try HTTP.Framing.BodyLength.determine(
            context: .response(status: .ok, requestMethod: .get),
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
            context: .response(status: .ok, requestMethod: .get),
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
            context: .response(status: .ok, requestMethod: .get),
            headers: headers
        )
        #expect(response == .untilClose)
    }
}

// MARK: - Unit: status and method override any framing header

extension `HTTP.Framing.BodyLength Tests`.Unit {
    @Test
    func `a response to HEAD has no body even with a Content-Length`() throws {
        let headers: HTTP.Headers = [try .init(name: "Content-Length", value: "100")]
        let length = try HTTP.Framing.BodyLength.determine(
            context: .response(status: .ok, requestMethod: .head),
            headers: headers
        )
        #expect(length == .none)
    }

    @Test
    func `a 204 response has no body`() throws {
        let headers: HTTP.Headers = []
        let length = try HTTP.Framing.BodyLength.determine(
            context: .response(status: .noContent, requestMethod: .get),
            headers: headers
        )
        #expect(length == .none)
    }

    @Test
    func `a 304 response has no body`() throws {
        let headers: HTTP.Headers = []
        let length = try HTTP.Framing.BodyLength.determine(
            context: .response(status: .notModified, requestMethod: .get),
            headers: headers
        )
        #expect(length == .none)
    }

    @Test
    func `a successful CONNECT response is a tunnel, distinct from no body`() throws {
        // .tunnel rather than .none: the connection stops being a sequence of
        // HTTP messages, which "no body, then the next message" would deny.
        let headers: HTTP.Headers = []
        let length = try HTTP.Framing.BodyLength.determine(
            context: .response(status: .ok, requestMethod: .connect),
            headers: headers
        )
        #expect(length == .tunnel)
    }
}
