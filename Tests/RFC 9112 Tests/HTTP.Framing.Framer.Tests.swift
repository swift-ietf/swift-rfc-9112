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
        try framer.append(bytes)

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
            `HTTP.Framing.Framer Tests`.octets(`HTTP.Framing.Framer Tests`.simpleResponse)
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
            `HTTP.Framing.Framer Tests`.octets(`HTTP.Framing.Framer Tests`.simpleResponse)
        )

        let head = try #require(try framer.nextResponseHead(answering: .head))
        #expect(head.line.statusCode == 200)
        // Content-Length: 5 is present and MUST be ignored for a HEAD response.
        #expect(head.bodyLength == .none)
    }

    @Test
    func `an incomplete head returns nil rather than throwing`() throws {
        var framer = HTTP.Framing.Framer()
        try framer.append(`HTTP.Framing.Framer Tests`.octets("GET /path HTTP/1.1\r\nHost: ex"))

        #expect(try framer.nextRequestHead() == nil)
        // Nothing was consumed by a failed attempt.
        #expect(framer.unconsumed == 28)
    }

    @Test
    func `body octets are left in the buffer, not consumed with the head`() throws {
        var framer = HTTP.Framing.Framer()
        let head = "POST /x HTTP/1.1\r\nContent-Length: 5\r\n\r\n"
        try framer.append(`HTTP.Framing.Framer Tests`.octets(head + "HELLO"))

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
        try framer.append(`HTTP.Framing.Framer Tests`.octets("GET / HTTP/1.1\rHost: x\r\n\r\n"))

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
        try framer.append(`HTTP.Framing.Framer Tests`.octets("GET / HTTP/1.1\r"))

        #expect(try framer.nextRequestHead() == nil)

        try framer.append(`HTTP.Framing.Framer Tests`.octets("\nHost: x\r\n\r\n"))
        #expect(try framer.nextRequestHead() != nil)
    }

    @Test
    func `obsolete line folding is rejected`() throws {
        // RFC 9112 Section 5.2. Rejected rather than unfolded: forwarding a
        // folded field is a smuggling vector when a downstream recipient
        // unfolds it differently.
        var framer = HTTP.Framing.Framer()
        try framer.append(
            `HTTP.Framing.Framer Tests`.octets("GET / HTTP/1.1\r\nHost: a\r\n b\r\n\r\n")
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
        try framer.append(bytes)

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
            `HTTP.Framing.Framer Tests`.octets("GET / HTTP/1.1\r\nnot-a-field\r\n\r\n")
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
            try framer.append(oversized)
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
            try framer.append([byte])
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
            )
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
            `HTTP.Framing.Framer Tests`.octets(`HTTP.Framing.Framer Tests`.simpleRequest)
        )
        _ = try clean.nextRequestHead()
        #expect(try clean.finish() == .clean)

        var truncated = HTTP.Framing.Framer()
        try truncated.append(`HTTP.Framing.Framer Tests`.octets("GET / HTTP/1.1\r\nHos"))
        // nil here means "incomplete", which finish() resolves into "truncated".
        #expect(try truncated.nextRequestHead() == nil)
        #expect(try truncated.finish() == .truncated(unconsumed: 19))
    }
}
