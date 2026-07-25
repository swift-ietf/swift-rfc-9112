// HTTP.Framing.Framer.Tests.swift
// swift-rfc-9112
//
// RFC 9112 Section 2.2 incremental framing.
//
// The failure mode of a framer is a DESYNC, not a failing test: it returns a
// plausible message and leaves the buffer positioned wrongly, so the next
// message is read from the wrong offset. Nothing here can be verified by
// "it compiled" or by a green suite that never fed it bytes. Every test below
// feeds real octets and asserts on what came back AND on what was left behind.

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

// MARK: - Unit

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
        // The head is the whole input here, so the framer must be empty after.
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
        // The per-exchange dependency that a construction-time role could not
        // express: identical octets, different framing, because the method
        // being answered differs.
        var framer = HTTP.Framing.Framer()
        try framer.append(
            `HTTP.Framing.Framer Tests`.octets(`HTTP.Framing.Framer Tests`.simpleResponse),
            accumulating: .head
        )

        let head = try #require(try framer.nextResponseHead(answering: .head))
        #expect(head.line.statusCode == 200)
        // Content-Length: 5 is present and MUST be ignored for a HEAD response.
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
        // Nothing was consumed by a failed attempt.
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
        // Exactly the body remains — the head accounting is not approximate.
        #expect(framer.unconsumed == 5)
    }
}

// MARK: - Edge Case

extension `HTTP.Framing.Framer Tests`.`Edge Case` {
    @Test
    func `a bare CR is rejected`() throws {
        // RFC 9112 Section 11.1: accepting bare CR desynchronises recipients
        // that disagree about whether it terminates a line.
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
        // The distinction that makes incremental parsing correct: at the end of
        // a partial read, CR is unterminated, not invalid. Treating it as a bare
        // CR would reject every message that happens to split on a CRLF.
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
        // RFC 9112 Section 5.2. Rejected rather than unfolded: forwarding a
        // folded field is a smuggling vector when a downstream recipient
        // unfolds it differently.
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
        // RFC 9112 Section 5.1: a server MUST reject a message with whitespace
        // between a field name and its colon. F13 in the law-inventory set — a
        // classic request-splitting vector, because a downstream recipient may
        // split `Host : example.com` differently. The reject path must also
        // leave the buffer byte-for-byte unadvanced: a desync presents as a
        // plausible message read from the wrong offset, which a throw-only
        // assertion cannot see.
        var framer = HTTP.Framing.Framer()
        let bytes = `HTTP.Framing.Framer Tests`.octets(
            "GET / HTTP/1.1\r\nHost : example.com\r\n\r\n"
        )
        try framer.append(bytes, accumulating: .head)

        #expect(throws: HTTP.Framing.Error.malformedFieldLine("Host : example.com")) {
            try framer.nextRequestHead()
        }
        // Nothing was consumed by the failed frame.
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
        // The property that distinguishes this from validate(maxLength:), which
        // is a post-parse call on an already-reconstructed line: by the time a
        // post-hoc limit fires, the memory is already committed.
        let limits = HTTP.Framing.Limits(startLine: 32, fieldSection: 32, body: 16)
        var framer = HTTP.Framing.Framer(limits: limits)

        let oversized = `HTTP.Framing.Framer Tests`.octets(String(repeating: "A", count: 128))
        #expect(throws: HTTP.Framing.Error.headSectionTooLong(limit: 64)) {
            try framer.append(oversized, accumulating: .head)
        }
        // Nothing was retained: the limit protected the buffer, not just the parse.
        #expect(framer.unconsumed == 0)
    }
}

// MARK: - Integration

extension `HTTP.Framing.Framer Tests`.Integration {
    @Test
    func `a head split at EVERY byte boundary frames identically to one delivered whole`() throws {
        // The GO condition for incremental framing. A framer that only works on
        // whole buffers passes every other test in this file.
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

        // It must frame exactly once the final octet arrives — never earlier
        // (which would mean framing an incomplete head) and never not at all.
        #expect(framedAt == bytes.indices.last)
    }

    @Test
    func `two pipelined requests frame in sequence from one buffer`() throws {
        // Proves the framer's buffer ownership actually works across messages:
        // the second message is found because the first consumed exactly its own
        // octets and left the rest untouched. This is the precondition for the
        // back-to-back chunked case that turns an accounting error into an
        // observable smuggle.
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
        // nil here means "incomplete", which finish() resolves into "truncated".
        #expect(try truncated.nextRequestHead() == nil)
        #expect(try truncated.finish() == .truncated(unconsumed: 19))
    }
}

// MARK: - Body framing (core)
//
// These two prove the body mechanism end to end before the law-inventory
// consumed-count set (F9–F12) is written. The chunked one is the one that
// matters: it asserts the CONSUMED octet count, not the decoded length, which
// are deliberately different — a decoded-size proxy would report 5 here and be
// off by exactly the framing overhead.

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
        // `5\r\nhello\r\n0\r\n\r\n` is 15 octets on the wire and decodes to 5.
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

// MARK: - Law-inventory consumed-count set (F9–F12)
//
// From `Research/rfc-9110-9112-law-inventory-2026-07-24.md` §4.3. Each asserts
// the CONSUMED octet count, never the decoded body — the decoded length is
// precisely the quantity that looks right while being wrong, so a decoded-size
// proxy (as `Message.Deserializer` uses) passes the body and fails the framing.
// The wire counts below are computed from the bytes, not copied from §4.3, whose
// F9 figure ("17") is off by two — the true length of `5\r\nhello\r\n0\r\n\r\n`
// is 15. F12 is the one that turns an accounting error into an observable
// smuggle: if message 1's consumed count is wrong, message 2 is read from the
// wrong offset and its head is garbage.

extension `HTTP.Framing.Framer Tests`.Integration {
    @Test
    func `F9 - a chunk consumes size line, data, CRLFs, zero chunk and final CRLF`() throws {
        // `5\r\nhello\r\n0\r\n\r\n` = 1+2 + 5+2 + 1+2 + 2 = 15 octets; decoded = 5.
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
        // `5;ext=1\r\nhello\r\n0\r\n\r\n` = 7+2 + 5+2 + 1+2 + 2 = 21 octets;
        // decoded is still 5. The extension is the difference between the two.
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
        // `5\r\nhello\r\n0\r\nX-Trailer: v\r\n\r\n` = 1+2 + 5+2 + 1+2 + 12+2 + 2
        // = 29 octets; decoded = 5. The trailer is consumed, not decoded.
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
        // The end-to-end statement of Finding D: message 2 is found only because
        // message 1 consumed EXACTLY its own octets. An off-by-any error in the
        // chunked count reads message 2's head from the wrong offset.
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

        // If body1's count were wrong, this head would not frame as `/2`.
        let head2 = try #require(try framer.nextRequestHead())
        #expect(head2.line.target == "/2")
        #expect(head2.bodyLength == .chunked)
        let body2 = try #require(try framer.nextBody(head2.bodyLength))
        #expect(body2.content == `HTTP.Framing.Framer Tests`.octets("bye"))
        #expect(body2.octets == 13)

        #expect(framer.unconsumed == 0)
    }
}

// MARK: - Law-inventory reject set, asserted end-to-end at the wire (F7r, F1)
//
// §4.5. These were already proven at the header-decision level in
// `HTTP.Framing.BodyLength.Tests`; here they run through the byte-level framer,
// which additionally proves the reject path leaves the buffer byte-for-byte
// UNADVANCED. A framer that threw the right error but advanced the buffer would
// desynchronise the next read — the failure a throw-only assertion cannot see.

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

// MARK: - Law-inventory accept set, asserted at the wire (F7s, F14)
//
// §4.5. The accept set is what proves the rejections discriminate rather than
// blanket-reject. F7s is the response half of the F7r pair — the SAME input that
// is rejected on a request reads until close on a response. F14 proves the
// no-whitespace-after-colon form is accepted, pinning (with F13) exactly WHICH
// whitespace RFC 9112 §5.1 forbids.

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
        // `Content-Length:5` — OWS after the colon is optional, so this frames.
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

// MARK: - F17 — a compile-guarantee and a trap-census, not a runtime assertion
//
// §4.5 F17: "byte-level `Request.Line.parse([Byte])` on any input must not
// terminate the process." There is deliberately NO runtime test, because there
// is nothing to call: the trapping `[Byte]` parse entry points were removed in
// `9ccfb80`, leaving only `Request.Line.parse(_ line: String) throws`. F17 is
// satisfied by construction and recorded, not asserted:
//
//   • compile-guarantee — no `[Byte]` parse overload exists on `Request.Line`
//     or `Response.Line`; a caller cannot reach a trapping byte parser because
//     the symbol is gone. Re-introducing one is a source change a reviewer sees.
//   • trap-census — `fatalError` / `try!` / `as!` / `preconditionFailure` over
//     `Sources/RFC 9112` is 0 (verified 2026-07-25). The byte-level entry point
//     is now the `Framer`, whose malformed-input paths throw (see the reject
//     fixtures above) rather than trap.
//
// A `#expect` here would test the surviving String parser, which is not what
// F17 constrains. The guarantee lives in the absence of the overload and the
// census, which is why it is written down rather than asserted.
