// HTTP.Framing.RequestHead.Request.Tests.swift
// swift-rfc-9112

import Testing

@testable import RFC_9112

extension HTTP.Framing.RequestHead {
    @Suite struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension HTTP.Framing.RequestHead.Test {
    static func framed(
        method: HTTP.Method,
        target: String,
        version: HTTP.Version = .http11,
        headers: HTTP.Headers = []
    ) -> HTTP.Framing.RequestHead {
        .init(
            line: .init(method: method, target: target, version: version),
            headers: headers,
            bodyLength: .none,
            octets: 42
        )
    }
}

extension HTTP.Framing.RequestHead.Test.Unit {
    @Test
    func `origin form preserves method query version and headers`() throws {
        let headers: HTTP.Headers = [
            try HTTP.Header.Field(name: "Host", value: "example.com")
        ]
        let framed = HTTP.Framing.RequestHead.Test.framed(
            method: .post,
            target: "/users?page=1",
            version: .http10,
            headers: headers
        )

        let request = try framed.request()

        #expect(request.method == .post)
        #expect(
            request.target
                == .origin(
                    path: try RFC_3986.URI.Path("/users"),
                    query: try RFC_3986.URI.Query("page=1")
                )
        )
        #expect(request.headers == headers)
        #expect(framed.line.version == .http10)
        #expect(framed.bodyLength == .none)
        #expect(framed.octets == 42)
    }

    @Test
    func `absolute form preserves the complete URI`() throws {
        let framed = HTTP.Framing.RequestHead.Test.framed(
            method: .get,
            target: "http://example.com/items?q=1"
        )

        let request = try framed.request()

        #expect(
            request.target
                == .absolute(try RFC_3986.URI("http://example.com/items?q=1"))
        )
    }

    @Test
    func `authority form is produced for CONNECT`() throws {
        let framed = HTTP.Framing.RequestHead.Test.framed(
            method: .connect,
            target: "example.com:443"
        )

        let request = try framed.request()

        #expect(
            request.target
                == .authority(try RFC_3986.URI.Authority("example.com:443"))
        )
    }

    @Test
    func `asterisk form is produced for OPTIONS`() throws {
        let framed = HTTP.Framing.RequestHead.Test.framed(
            method: .options,
            target: "*"
        )

        let request = try framed.request()

        #expect(request.target == .asterisk)
    }
}

extension HTTP.Framing.RequestHead.Test.`Edge Case` {
    @Test
    func `relative reference is not a request-target form`() {
        let framed = HTTP.Framing.RequestHead.Test.framed(
            method: .get,
            target: "relative/path"
        )

        #expect(throws: HTTP.Request.Target.ParsingError.syntax("relative/path")) {
            try framed.request()
        }
    }

    @Test
    func `absolute form cannot contain a fragment`() {
        let target = "http://example.com/items#fragment"
        let framed = HTTP.Framing.RequestHead.Test.framed(
            method: .get,
            target: target
        )

        #expect(throws: HTTP.Request.Target.ParsingError.syntax(target)) {
            try framed.request()
        }
    }

    @Test
    func `authority form requires a port and forbids userinfo`() {
        let missingPort = HTTP.Framing.RequestHead.Test.framed(
            method: .connect,
            target: "example.com"
        )
        let userinfo = HTTP.Framing.RequestHead.Test.framed(
            method: .connect,
            target: "user@example.com:443"
        )

        #expect(throws: HTTP.Request.Target.ParsingError.syntax("example.com")) {
            try missingPort.request()
        }
        #expect(throws: HTTP.Request.Target.ParsingError.syntax("user@example.com:443")) {
            try userinfo.request()
        }
    }

    @Test
    func `asterisk form is reserved for OPTIONS`() {
        let framed = HTTP.Framing.RequestHead.Test.framed(
            method: .get,
            target: "*"
        )

        #expect(throws: HTTP.Request.Target.ParsingError.form("*", method: .get)) {
            try framed.request()
        }
    }

    @Test
    func `malformed origin query is rejected without data loss`() {
        let target = "/items?value=%ZZ"
        let framed = HTTP.Framing.RequestHead.Test.framed(
            method: .get,
            target: target
        )

        #expect(throws: HTTP.Request.Target.ParsingError.syntax(target)) {
            try framed.request()
        }
    }

    @Test
    func `origin form cannot contain whitespace or a fragment`() {
        let whitespace = HTTP.Framing.RequestHead.Test.framed(
            method: .get,
            target: "/two words"
        )
        let fragment = HTTP.Framing.RequestHead.Test.framed(
            method: .get,
            target: "/items#fragment"
        )

        #expect(throws: HTTP.Request.Target.ParsingError.syntax("/two words")) {
            try whitespace.request()
        }
        #expect(throws: HTTP.Request.Target.ParsingError.syntax("/items#fragment")) {
            try fragment.request()
        }
    }
}
