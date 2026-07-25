// HTTP.Framing.Connection.Server.Tests.swift
// swift-rfc-9112
//
// RFC 9112 Section 9: Connection Management.
//
// C3 and C4 are the two halves of finding (E)'s residual, and C4 is the one
// that matters: it fails by ACCEPTING, which no assertion on a return value can
// see. Every test feeds real octets and asserts on what was left behind.

import Testing

@testable import RFC_9112

@Suite
struct `HTTP.Framing.Connection.Server Tests` {
    @Suite struct Unit {}
    @Suite struct `Edge Case` {}
    @Suite struct Integration {}
}

extension `HTTP.Framing.Connection.Server Tests` {
    static func octets(_ text: String) -> [Byte] { Array(text.utf8) }

    /// Larger than the default head budget (8_000 + 65_536 = 73_536) and
    /// containing no empty line, so the deleted head-terminator heuristic could
    /// not have exempted it.
    static let largeBodyLength = 1_048_576

    static func headDeclaring(_ length: Int) -> String {
        "POST /upload HTTP/1.1\r\nHost: example.com\r\nContent-Length: \(length)\r\n\r\n"
    }
}

// MARK: - C3: the over-rejection half of (E)
//
// A large identity body delivered incrementally used to be measured against the
// HEAD budget, because `append` inferred the phase by scanning for an empty
// line and a body without one looked like an unterminated head.

extension `HTTP.Framing.Connection.Server Tests`.Integration {
    @Test
    func `C3 - a 1 MiB identity body delivered incrementally frames`() throws {
        let length = `HTTP.Framing.Connection.Server Tests`.largeBodyLength
        var server = HTTP.Framing.Connection.Server()
        try server.receive(
            `HTTP.Framing.Connection.Server Tests`.octets(
                `HTTP.Framing.Connection.Server Tests`.headDeclaring(length)
            )
        )

        guard case .head(let head) = try #require(try server.next()) else {
            Issue.record("expected a head")
            return
        }
        #expect(head.bodyLength == .length(length))

        // Deliver the body in 64 KiB reads. Every octet is 'A': there is no
        // empty line anywhere in it, which is precisely the shape the old guard
        // measured against `headSection` and refused.
        let payload = [Byte](repeating: Byte(0x41), count: length)
        var offset = 0
        while offset < length {
            let end = min(offset + 65_536, length)
            try server.receive(Array(payload[offset..<end]))
            offset = end
        }

        guard case .body(let content) = try #require(try server.next()) else {
            Issue.record("expected body octets")
            return
        }
        #expect(content.count == length)
        guard case .end(_, let octets) = try #require(try server.next()) else {
            Issue.record("expected the body to end")
            return
        }
        #expect(octets == length)
        #expect(server.unconsumed == 0)
    }

    @Test
    func `C3b - the SAME octets under the head phase are still refused`() throws {
        // The paired assertion: the fix is localised to knowing the phase, not a
        // widening of the head budget. Fed as a head, 1 MiB with no terminator
        // is still exactly what `headSection` exists to refuse.
        var framer = HTTP.Framing.Framer()
        let oversized = [Byte](
            repeating: Byte(0x41),
            count: `HTTP.Framing.Connection.Server Tests`.largeBodyLength
        )

        #expect(throws: HTTP.Framing.Error.headSectionTooLong(limit: 73_536)) {
            try framer.append(oversized, accumulating: .head)
        }
        // Refused BEFORE retention, as it always was.
        #expect(framer.unconsumed == 0)
    }
}

// MARK: - C5/C6: pipelining and the message boundary

extension `HTTP.Framing.Connection.Server Tests`.Integration {
    @Test
    func `C5 - three pipelined requests WITH BODIES frame in sequence`() throws {
        // The connection-level statement of F12: request 3 is reached only
        // because requests 1 and 2 each consumed exactly their own octets,
        // bodies included. An off-by-any error anywhere upstream reads request
        // 3's head from the middle of request 2.
        var server = HTTP.Framing.Connection.Server()
        try server.receive(
            `HTTP.Framing.Connection.Server Tests`.octets(
                "POST /1 HTTP/1.1\r\nContent-Length: 5\r\n\r\nHELLO"
                    + "POST /2 HTTP/1.1\r\nTransfer-Encoding: chunked\r\n\r\n3\r\nbye\r\n0\r\n\r\n"
                    + "GET /3 HTTP/1.1\r\nHost: x\r\n\r\n"
            )
        )

        var targets: [String] = []
        var payloads: [[Byte]] = []
        var bodyOctets: [Int] = []

        while let event = try server.next() {
            switch event {
            case .head(let head): targets.append(head.line.target)
            case .body(let content): payloads.append(content)
            case .end(_, let octets): bodyOctets.append(octets)
            }
        }

        #expect(targets == ["/1", "/2", "/3"])
        #expect(payloads.count == 2)  // /3 has no body, so it emits no `.body`
        #expect(payloads[0] == `HTTP.Framing.Connection.Server Tests`.octets("HELLO"))
        #expect(payloads[1] == `HTTP.Framing.Connection.Server Tests`.octets("bye"))
        // 5 identity; 13 chunked on the wire against 3 decoded; 0 for /3.
        #expect(bodyOctets == [5, 13, 0])
        #expect(server.unconsumed == 0)
    }

    @Test
    func `C6 - the next head is NOT framed while a body is outstanding`() throws {
        // Message-boundary discipline. The octets after an unconsumed body are
        // body, not a head, and a drive that framed them as a head would be
        // reading the next request out of the middle of this one.
        var server = HTTP.Framing.Connection.Server()
        try server.receive(
            `HTTP.Framing.Connection.Server Tests`.octets(
                "POST /1 HTTP/1.1\r\nContent-Length: 5\r\n\r\nHELLOGET /2 HTTP/1.1\r\nHost: x\r\n\r\n"
            )
        )

        guard case .head(let first) = try #require(try server.next()) else {
            Issue.record("expected a head")
            return
        }
        #expect(first.line.target == "/1")
        // Bound to a local first: `#expect` on a bare property of a ~Copyable
        // value routes through a check that requires Copyable.
        let readingBody = server.isReadingBody
        #expect(readingBody)

        // The very next event must be this request's body — never /2's head,
        // which is sitting in the buffer behind it.
        guard case .body(let content) = try #require(try server.next()) else {
            Issue.record("expected the outstanding body, not the next head")
            return
        }
        #expect(content == `HTTP.Framing.Connection.Server Tests`.octets("HELLO"))

        guard case .end = try #require(try server.next()) else {
            Issue.record("expected the body to end")
            return
        }
        #expect(server.isReadingBody == false)

        guard case .head(let second) = try #require(try server.next()) else {
            Issue.record("expected the second head only after the first body ended")
            return
        }
        #expect(second.line.target == "/2")
    }
}

// MARK: - C8: tear-down

extension `HTTP.Framing.Connection.Server Tests`.`Edge Case` {
    @Test
    func `C8 - Connection close ends reuse, and buffered octets are NOT framed`() throws {
        // RFC 9112 Section 9.6. The close takes effect after the current
        // message, and anything pipelined behind it must not be served — a
        // request framed after a declared close is a request the peer did not
        // agree was on this connection.
        var server = HTTP.Framing.Connection.Server()
        try server.receive(
            `HTTP.Framing.Connection.Server Tests`.octets(
                "GET /1 HTTP/1.1\r\nHost: x\r\nConnection: close\r\n\r\n"
                    + "GET /2 HTTP/1.1\r\nHost: x\r\n\r\n"
            )
        )

        guard case .head(let head) = try #require(try server.next()) else {
            Issue.record("expected a head")
            return
        }
        #expect(head.line.target == "/1")
        // Still reusable until the message it rode on completes.
        let reusableBeforeEnd = server.isReusable
        #expect(reusableBeforeEnd)

        guard case .end = try #require(try server.next()) else {
            Issue.record("expected the message to end")
            return
        }
        #expect(server.isReusable == false)

        // /2 is buffered and well-formed, and must still not be framed.
        #expect(try server.next() == nil)
        #expect(server.unconsumed > 0)
    }
}

// MARK: - ⭐ C4: the under-protection half of (E) — the load-bearing fixture
//
// The old guard was `projected > headSection && !containsHeadTerminator(buffer)`.
// Because `containsHeadTerminator` returned true for ANY empty line anywhere in
// the buffer, an attacker-chosen `CRLFCRLF` inside a body short-circuited the
// `&&` and the head budget stopped applying — with `Limits.body` enforced only
// inside `nextBody`, i.e. against octets ALREADY STORED.
//
// That failure is ACCEPTANCE. It cannot be seen by asserting on a return value,
// which is why every test that existed before 2c was blind to it.

extension `HTTP.Framing.Connection.Server Tests`.`Edge Case` {
    @Test
    func `C4 - a blank line already buffered does NOT disable the body budget`() throws {
        // Faithful reproduction of the short-circuit, which needs TWO reads.
        // The old guard read `projected > headSection && !containsHeadTerminator(buffer)`
        // and inspected the ALREADY-BUFFERED octets, so a single large read was
        // still refused. The hole opened only once a blank line was sitting in
        // the buffer from an earlier read — after which the head budget stopped
        // applying and nothing bounded retention at all.
        let limits = HTTP.Framing.Limits(startLine: 8_000, fieldSection: 65_536, body: 16_384)
        var server = HTTP.Framing.Connection.Server(limits: limits)

        // Chunked, so no declared length lets `nextBody` reject it up front —
        // the accumulation path is the one under test.
        try server.receive(
            `HTTP.Framing.Connection.Server Tests`.octets(
                "POST /x HTTP/1.1\r\nTransfer-Encoding: chunked\r\n\r\n"
            )
        )
        guard case .head = try #require(try server.next()) else {
            Issue.record("expected a head")
            return
        }
        #expect(server.unconsumed == 0)

        // Read 1 — a chunk header and data carrying an empty line. Small, and
        // accepted both before and after the fix. `containsHeadTerminator` now
        // returns true for this buffer, which is what used to arm the hole.
        let prefix = `HTTP.Framing.Connection.Server Tests`.octets("4000\r\nAAAA\r\n\r\n")
        try server.receive(prefix)
        #expect(server.unconsumed == prefix.count)

        // Read 2 — 100 KB, well past BOTH budgets. Under the old guard this was
        // ⭐ ACCEPTED: `projected > headSection` was true, but the buffered blank
        // line made `containsHeadTerminator` true, so the `&&` short-circuited
        // and the octets were stored with `limits.body` not yet consulted.
        let flood = [Byte](repeating: Byte(0x41), count: 100_000)
        #expect(throws: HTTP.Framing.Error.bodyTooLong(limit: 16_384)) {
            try server.receive(flood)
        }
        // The assertion the defect was invisible to — it fails by ACCEPTING, so
        // only what was left behind can see it.
        #expect(server.unconsumed == prefix.count)
    }

    @Test
    func `C10 - close mid-head is truncated, close on a boundary is clean`() throws {
        // RFC 9112 Section 8. The distinction a `nil` from `next()` cannot
        // express, carried through the drive rather than lost at it.
        var clean = HTTP.Framing.Connection.Server()
        try clean.receive(
            `HTTP.Framing.Connection.Server Tests`.octets("GET / HTTP/1.1\r\nHost: x\r\n\r\n")
        )
        _ = try clean.next()  // head
        _ = try clean.next()  // end (no body)
        #expect(try clean.finish() == .clean)

        var truncated = HTTP.Framing.Connection.Server()
        try truncated.receive(
            `HTTP.Framing.Connection.Server Tests`.octets("GET / HTTP/1.1\r\nHos")
        )
        #expect(try truncated.next() == nil)
        #expect(try truncated.finish() == .truncated(unconsumed: 19))
    }

    @Test
    func `C4b - the body budget is what fires, not the head budget`() throws {
        // Pins which limit governs. A body overrun reported as
        // `headSectionTooLong` would mean the phase was still being guessed.
        let limits = HTTP.Framing.Limits(startLine: 8_000, fieldSection: 65_536, body: 512)
        var server = HTTP.Framing.Connection.Server(limits: limits)

        try server.receive(
            `HTTP.Framing.Connection.Server Tests`.octets(
                "POST /x HTTP/1.1\r\nTransfer-Encoding: chunked\r\n\r\n"
            )
        )
        _ = try server.next()

        // 1 KiB of body: under the head budget (73_536), over the body budget.
        // Only a drive that knows it is reading a body refuses this.
        let body = [Byte](repeating: Byte(0x41), count: 1_024)
        #expect(throws: HTTP.Framing.Error.bodyTooLong(limit: 512)) {
            try server.receive(body)
        }
        #expect(server.unconsumed == 0)
    }
}
