import Testing

@testable import RFC_9112

@Suite
struct `HTTP.Framing.Framer Tests` {
    @Suite struct Unit {}
    @Suite struct `Edge Case` {}
    @Suite struct Integration {}
}

extension `HTTP.Framing.Framer Tests` {
    static func octets(_ text: String) -> [Byte] { Array(text.utf8) }

    static let simpleRequest = "GET /path HTTP/1.1\r\nHost: example.com\r\n\r\n"
    static let simpleResponse = "HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\n"
}

extension `HTTP.Framing.Framer Tests`.Unit {
    @Test
    func `a complete request head frames, and its octets are consumed exactly`() throws {
        var framer = HTTP.Framing.Framer()
        let bytes = `HTTP.Framing.Framer Tests`.octets(
            `HTTP.Framing.Framer Tests`.simpleRequest
        )
        try framer.append(bytes, accumulating: .head)

        let head = try framer.nextRequestHead()
        let unwrapped = try #require(head)

        #expect(unwrapped.line.method == .get)
        #expect(unwrapped.headers.contains("Host"))
        #expect(unwrapped.bodyLength == .none)

        #expect(unwrapped.octets == bytes.count)
        #expect(framer.unconsumed == 0)
    }

    @Test
    func `a response head frames using the method it answers`() throws {
        var framer = HTTP.Framing.Framer()
        try framer.append(
            `HTTP.Framing.Framer Tests`.octets(`HTTP.Framing.Framer Tests`.simpleResponse),
            accumulating: .head
        )

        let head = try #require(try framer.nextResponseHead(answering: .get))
        #expect(head.line.statusCode == 200)
        #expect(head.bodyLength == .length(5))
    }

    @Test
    func `the SAME response frames differently when it answers HEAD`() throws {

        var framer = HTTP.Framing.Framer()
        try framer.append(
            `HTTP.Framing.Framer Tests`.octets(`HTTP.Framing.Framer Tests`.simpleResponse),
            accumulating: .head
        )

        let head = try #require(try framer.nextResponseHead(answering: .head))
        #expect(head.line.statusCode == 200)

        #expect(head.bodyLength == .none)
    }

    @Test
    func `an incomplete head returns nil rather than throwing`() throws {
        var framer = HTTP.Framing.Framer()
        try framer.append(
            `HTTP.Framing.Framer Tests`.octets("GET /path HTTP/1.1\r\nHost: ex"),
            accumulating: .head
        )

        #expect(try framer.nextRequestHead() == nil)

        #expect(framer.unconsumed == 28)
    }

    @Test
    func `body octets are left in the buffer, not consumed with the head`() throws {
        var framer = HTTP.Framing.Framer()
        let head = "POST /x HTTP/1.1\r\nContent-Length: 5\r\n\r\n"
        try framer.append(`HTTP.Framing.Framer Tests`.octets(head + "HELLO"), accumulating: .head)

        let framed = try #require(try framer.nextRequestHead())
        #expect(framed.bodyLength == .length(5))
        #expect(framed.octets == head.utf8.count)

        #expect(framer.unconsumed == 5)
    }
}

extension `HTTP.Framing.Framer Tests`.`Edge Case` {
    @Test
    func `a bare CR is rejected`() throws {

        var framer = HTTP.Framing.Framer()
        try framer.append(
            `HTTP.Framing.Framer Tests`.octets("GET / HTTP/1.1\rHost: x\r\n\r\n"),
            accumulating: .head
        )

        #expect(throws: HTTP.Framing.Error.bareCarriageReturn) {
            try framer.nextRequestHead()
        }
    }

    @Test
    func `a trailing CR is NOT treated as a bare CR - the LF may still arrive`() throws {

        var framer = HTTP.Framing.Framer()
        try framer.append(
            `HTTP.Framing.Framer Tests`.octets("GET / HTTP/1.1\r"),
            accumulating: .head
        )

        #expect(try framer.nextRequestHead() == nil)

        try framer.append(
            `HTTP.Framing.Framer Tests`.octets("\nHost: x\r\n\r\n"),
            accumulating: .head
        )
        #expect(try framer.nextRequestHead() != nil)
    }

    @Test
    func `obsolete line folding is rejected`() throws {

        var framer = HTTP.Framing.Framer()
        try framer.append(
            `HTTP.Framing.Framer Tests`.octets("GET / HTTP/1.1\r\nHost: a\r\n b\r\n\r\n"),
            accumulating: .head
        )

        #expect(throws: HTTP.Framing.Error.obsoleteLineFolding) {
            try framer.nextRequestHead()
        }
    }

    @Test
    func `whitespace between a field name and the colon is rejected`() throws {

        var framer = HTTP.Framing.Framer()
        let bytes = `HTTP.Framing.Framer Tests`.octets(
            "GET / HTTP/1.1\r\nHost : example.com\r\n\r\n"
        )
        try framer.append(bytes, accumulating: .head)

        #expect(throws: HTTP.Framing.Error.malformedFieldLine("Host : example.com")) {
            try framer.nextRequestHead()
        }

        #expect(framer.unconsumed == bytes.count)
    }

    @Test
    func `a field line without a colon is rejected`() throws {
        var framer = HTTP.Framing.Framer()
        try framer.append(
            `HTTP.Framing.Framer Tests`.octets("GET / HTTP/1.1\r\nnot-a-field\r\n\r\n"),
            accumulating: .head
        )

        #expect(throws: HTTP.Framing.Error.malformedFieldLine("not-a-field")) {
            try framer.nextRequestHead()
        }
    }

    @Test
    func `an over-long head is refused BEFORE the octets are retained`() throws {

        let limits = HTTP.Framing.Limits(startLine: 32, fieldSection: 32, body: 16)
        var framer = HTTP.Framing.Framer(limits: limits)

        let oversized = `HTTP.Framing.Framer Tests`.octets(String(repeating: "A", count: 128))
        #expect(throws: HTTP.Framing.Error.headSectionTooLong(limit: 64)) {
            try framer.append(oversized, accumulating: .head)
        }

        #expect(framer.unconsumed == 0)
    }
}

extension `HTTP.Framing.Framer Tests`.Integration {
    @Test
    func `a head split at EVERY byte boundary frames identically to one delivered whole`() throws {

        let text = `HTTP.Framing.Framer Tests`.simpleRequest
        let bytes = `HTTP.Framing.Framer Tests`.octets(text)

        var framer = HTTP.Framing.Framer()
        var framedAt: Int?

        for (offset, byte) in bytes.enumerated() {
            try framer.append([byte], accumulating: .head)
            if let head = try framer.nextRequestHead() {
                framedAt = offset
                #expect(head.line.method == .get)
                #expect(head.octets == bytes.count)
                #expect(framer.unconsumed == 0)
                break
            }
        }

        #expect(framedAt == bytes.indices.last)
    }

    @Test
    func `two pipelined requests frame in sequence from one buffer`() throws {

        var framer = HTTP.Framing.Framer()
        try framer.append(
            `HTTP.Framing.Framer Tests`.octets(
                "GET /first HTTP/1.1\r\nHost: a\r\n\r\nGET /second HTTP/1.1\r\nHost: b\r\n\r\n"
            ),
            accumulating: .head
        )

        let first = try #require(try framer.nextRequestHead())
        #expect(first.line.target == "/first")

        let second = try #require(try framer.nextRequestHead())
        #expect(second.line.target == "/second")

        #expect(framer.unconsumed == 0)
        #expect(try framer.nextRequestHead() == nil)
    }

    @Test
    func `finish distinguishes a clean close from a truncated message`() throws {
        var clean = HTTP.Framing.Framer()
        try clean.append(
            `HTTP.Framing.Framer Tests`.octets(`HTTP.Framing.Framer Tests`.simpleRequest),
            accumulating: .head
        )
        _ = try clean.nextRequestHead()
        #expect(try clean.finish() == .clean)

        var truncated = HTTP.Framing.Framer()
        try truncated.append(
            `HTTP.Framing.Framer Tests`.octets("GET / HTTP/1.1\r\nHos"),
            accumulating: .head
        )

        #expect(try truncated.nextRequestHead() == nil)
        #expect(try truncated.finish() == .truncated(unconsumed: 19))
    }
}

extension `HTTP.Framing.Framer Tests`.Integration {
    @Test
    func `an identity body is delivered whole and consumes exactly its length`() throws {
        var framer = HTTP.Framing.Framer()
        try framer.append(
            `HTTP.Framing.Framer Tests`.octets(
                "POST /x HTTP/1.1\r\nContent-Length: 5\r\n\r\nHELLO"
            ),
            accumulating: .head
        )

        let head = try #require(try framer.nextRequestHead())
        #expect(head.bodyLength == .length(5))

        let body = try #require(try framer.nextBody(head.bodyLength))
        #expect(body.content == `HTTP.Framing.Framer Tests`.octets("HELLO"))
        #expect(body.octets == 5)
        #expect(body.trailers.isEmpty)
        #expect(framer.unconsumed == 0)
    }

    @Test
    func `a chunked body reports its true wire length, not the decoded length`() throws {

        var framer = HTTP.Framing.Framer()
        try framer.append(
            `HTTP.Framing.Framer Tests`.octets(
                "POST /x HTTP/1.1\r\nTransfer-Encoding: chunked\r\n\r\n5\r\nhello\r\n0\r\n\r\n"
            ),
            accumulating: .head
        )

        let head = try #require(try framer.nextRequestHead())
        #expect(head.bodyLength == .chunked)

        let body = try #require(try framer.nextBody(head.bodyLength))
        #expect(body.content == `HTTP.Framing.Framer Tests`.octets("hello"))
        #expect(body.content.count == 5)
        #expect(body.octets == 15)
        #expect(body.trailers.isEmpty)
        #expect(framer.unconsumed == 0)
    }
}

extension `HTTP.Framing.Framer Tests`.Integration {
    @Test
    func `F9 - a chunk consumes size line, data, CRLFs, zero chunk and final CRLF`() throws {

        var framer = HTTP.Framing.Framer()
        try framer.append(
            `HTTP.Framing.Framer Tests`.octets("5\r\nhello\r\n0\r\n\r\n"),
            accumulating: .body
        )

        let body = try #require(try framer.nextBody(.chunked))
        #expect(body.content == `HTTP.Framing.Framer Tests`.octets("hello"))
        #expect(body.octets == 15)
        #expect(body.trailers.isEmpty)
        #expect(framer.unconsumed == 0)
    }

    @Test
    func `F10 - a chunk extension counts toward consumed but not decoded`() throws {

        var framer = HTTP.Framing.Framer()
        try framer.append(
            `HTTP.Framing.Framer Tests`.octets("5;ext=1\r\nhello\r\n0\r\n\r\n"),
            accumulating: .body
        )

        let body = try #require(try framer.nextBody(.chunked))
        #expect(body.content == `HTTP.Framing.Framer Tests`.octets("hello"))
        #expect(body.content.count == 5)
        #expect(body.octets == 21)
        #expect(framer.unconsumed == 0)
    }

    @Test
    func `F11 - a trailer section counts toward consumed and is reported`() throws {

        var framer = HTTP.Framing.Framer()
        try framer.append(
            `HTTP.Framing.Framer Tests`.octets("5\r\nhello\r\n0\r\nX-Trailer: v\r\n\r\n"),
            accumulating: .body
        )

        let body = try #require(try framer.nextBody(.chunked))
        #expect(body.content == `HTTP.Framing.Framer Tests`.octets("hello"))
        #expect(body.octets == 29)
        #expect(body.trailers.count == 1)
        #expect(body.trailers.contains("X-Trailer"))
        #expect(framer.unconsumed == 0)
    }

    @Test
    func `F12 - two chunked messages back to back, the second must parse`() throws {

        var framer = HTTP.Framing.Framer()
        try framer.append(
            `HTTP.Framing.Framer Tests`.octets(
                "POST /1 HTTP/1.1\r\nTransfer-Encoding: chunked\r\n\r\n5\r\nhello\r\n0\r\n\r\n"
                    + "POST /2 HTTP/1.1\r\nTransfer-Encoding: chunked\r\n\r\n3\r\nbye\r\n0\r\n\r\n"
            ),
            accumulating: .head
        )

        let head1 = try #require(try framer.nextRequestHead())
        #expect(head1.line.target == "/1")
        #expect(head1.bodyLength == .chunked)
        let body1 = try #require(try framer.nextBody(head1.bodyLength))
        #expect(body1.content == `HTTP.Framing.Framer Tests`.octets("hello"))
        #expect(body1.octets == 15)

        let head2 = try #require(try framer.nextRequestHead())
        #expect(head2.line.target == "/2")
        #expect(head2.bodyLength == .chunked)
        let body2 = try #require(try framer.nextBody(head2.bodyLength))
        #expect(body2.content == `HTTP.Framing.Framer Tests`.octets("bye"))
        #expect(body2.octets == 13)

        #expect(framer.unconsumed == 0)
    }
}

extension `HTTP.Framing.Framer Tests`.`Edge Case` {
    @Test
    func `F7r - chunked-not-final on a request is rejected, buffer unadvanced`() throws {
        var framer = HTTP.Framing.Framer()
        let bytes = `HTTP.Framing.Framer Tests`.octets(
            "POST / HTTP/1.1\r\nTransfer-Encoding: chunked, gzip\r\n\r\n"
        )
        try framer.append(bytes, accumulating: .head)

        #expect(throws: HTTP.Framing.Error.chunkedNotFinal) {
            try framer.nextRequestHead()
        }
        #expect(framer.unconsumed == bytes.count)
    }

    @Test
    func `F1 - differing duplicate Content-Length on a request is rejected, buffer unadvanced`()
        throws
    {
        var framer = HTTP.Framing.Framer()
        let bytes = `HTTP.Framing.Framer Tests`.octets(
            "POST / HTTP/1.1\r\nContent-Length: 5\r\nContent-Length: 6\r\n\r\n"
        )
        try framer.append(bytes, accumulating: .head)

        #expect(throws: HTTP.Framing.Error.conflictingContentLength(["5", "6"])) {
            try framer.nextRequestHead()
        }
        #expect(framer.unconsumed == bytes.count)
    }
}

extension `HTTP.Framing.Framer Tests`.Unit {
    @Test
    func `F7s - chunked-not-final on a response reads until close, not an error`() throws {
        var framer = HTTP.Framing.Framer()
        try framer.append(
            `HTTP.Framing.Framer Tests`.octets(
                "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked, gzip\r\n\r\n"
            ),
            accumulating: .head
        )

        let head = try #require(try framer.nextResponseHead(answering: .get))
        #expect(head.line.statusCode == 200)
        #expect(head.bodyLength == .untilClose)
    }

    @Test
    func `F14 - no whitespace after the colon is accepted`() throws {

        var framer = HTTP.Framing.Framer()
        try framer.append(
            `HTTP.Framing.Framer Tests`.octets("POST /x HTTP/1.1\r\nContent-Length:5\r\n\r\nHELLO"),
            accumulating: .head
        )

        let head = try #require(try framer.nextRequestHead())
        #expect(head.headers.contains("Content-Length"))
        #expect(head.bodyLength == .length(5))
    }
}
