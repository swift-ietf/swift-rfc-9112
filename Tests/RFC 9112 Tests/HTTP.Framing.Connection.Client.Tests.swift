// HTTP.Framing.Connection.Client.Tests.swift
// swift-rfc-9112
//
// RFC 9112 Section 9: Connection Management.
//
// The drive's failure mode is the framer's: a DESYNC, not a failing test. It
// returns plausible events and leaves the stream positioned wrongly, so the
// next message is read from the wrong offset. Every test feeds real octets and
// asserts on what came back AND on what was left behind.

import Testing

@testable import RFC_9112

@Suite
struct `HTTP.Framing.Connection.Client Tests` {
    @Suite struct Unit {}
    @Suite struct `Edge Case` {}
    @Suite struct Integration {}
}

extension `HTTP.Framing.Connection.Client Tests` {
    static func octets(_ text: String) -> [Byte] { Array(text.utf8) }

    /// A response with no framing headers at all. RFC 9112 Section 6.3 rule 8:
    /// a response with neither `Content-Length` nor `Transfer-Encoding` is
    /// delimited by the connection closing.
    static let closeDelimited = "HTTP/1.1 200 OK\r\n\r\n"
}

// MARK: - C1: close-delimited bodies
//
// `nextBody` returns nil for `.untilClose` because the end is not in the byte
// stream. Delivery is the drive's job, and the close is the terminator.

extension `HTTP.Framing.Connection.Client Tests`.Unit {
    @Test
    func `C1 - a close-delimited body is delivered, and the close ends it`() throws {
        var client = HTTP.Framing.Connection.Client()
        client.expect(.get)
        try client.receive(
            `HTTP.Framing.Connection.Client Tests`.octets(
                `HTTP.Framing.Connection.Client Tests`.closeDelimited + "hello"
            )
        )

        guard case .head(let head) = try #require(try client.next()) else {
            Issue.record("expected a head")
            return
        }
        #expect(head.line.statusCode == 200)
        // The framing that the framer cannot deliver on its own.
        #expect(head.bodyLength == .untilClose)

        guard case .body(let payload) = try #require(try client.next()) else {
            Issue.record("expected body octets")
            return
        }
        #expect(payload == `HTTP.Framing.Connection.Client Tests`.octets("hello"))

        // ⭐ The body is NOT complete before the close: the delimiter has not
        // arrived, so inventing an end here would be inventing a boundary the
        // stream does not contain.
        #expect(try client.next() == nil)

        client.peerClosed()
        guard case .end(let trailers, let octets) = try #require(try client.next()) else {
            Issue.record("expected the body to end at the close")
            return
        }
        #expect(trailers.isEmpty)
        #expect(octets == 5)
        // The close both ended the body and ended the connection.
        #expect(client.isReusable == false)
    }

    @Test
    func `C1b - a close-delimited body of zero octets still ends at the close`() throws {
        // The degenerate case, and the one an implementation streaming "whatever
        // has arrived" gets wrong by never emitting an end at all.
        var client = HTTP.Framing.Connection.Client()
        client.expect(.get)
        try client.receive(
            `HTTP.Framing.Connection.Client Tests`.octets(
                `HTTP.Framing.Connection.Client Tests`.closeDelimited
            )
        )

        guard case .head = try #require(try client.next()) else {
            Issue.record("expected a head")
            return
        }
        #expect(try client.next() == nil)

        client.peerClosed()
        guard case .end(_, let octets) = try #require(try client.next()) else {
            Issue.record("expected an empty body to end at the close")
            return
        }
        #expect(octets == 0)
    }
}

// MARK: - ⭐ C7: the method queue — a smuggle proof, not a bookkeeping test
//
// RFC 9112 Section 6.3 rule 1: a response to HEAD has NO body however large its
// Content-Length. Section 9.3.2: responses arrive in the order their requests
// were sent. Put together, the queue is framing-critical — if it pops out of
// order or not at all, response 1 consumes five octets that are not its body,
// and those five octets are the front of response 2's status line.

extension `HTTP.Framing.Connection.Client Tests`.Integration {
    @Test
    func `C7 - HEAD then GET - response 1 has no body and response 2 still frames`() throws {
        var client = HTTP.Framing.Connection.Client()
        client.expect(.head)
        client.expect(.get)
        #expect(client.outstanding == 2)

        try client.receive(
            `HTTP.Framing.Connection.Client Tests`.octets(
                "HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\n"
                    + "HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nhi"
            )
        )

        guard case .head(let first) = try #require(try client.next()) else {
            Issue.record("expected the first head")
            return
        }
        // Content-Length: 5 is present and MUST be ignored — this answers HEAD.
        #expect(first.line.statusCode == 200)
        #expect(first.bodyLength == .none)
        #expect(client.outstanding == 1)

        guard case .end(_, let firstOctets) = try #require(try client.next()) else {
            Issue.record("expected the first message to end with no body")
            return
        }
        // ⭐ Zero. Consuming 5 here is the smuggle: those octets are response 2.
        #expect(firstOctets == 0)

        guard case .head(let second) = try #require(try client.next()) else {
            Issue.record("response 2 did not frame — response 1 consumed its octets")
            return
        }
        #expect(second.line.statusCode == 200)
        #expect(second.bodyLength == .length(2))

        guard case .body(let payload) = try #require(try client.next()) else {
            Issue.record("expected response 2's body")
            return
        }
        #expect(payload == `HTTP.Framing.Connection.Client Tests`.octets("hi"))
        #expect(client.outstanding == 0)
        #expect(client.unconsumed == 0)
    }

    @Test
    func `C7b - a response with nothing queued is reported, not guessed`() throws {
        // Guessing a method would frame the response against a request that was
        // never sent, and rule 1 makes that guess change the framing.
        var client = HTTP.Framing.Connection.Client()
        let bytes = `HTTP.Framing.Connection.Client Tests`.octets(
            "HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\nHELLO"
        )
        try client.receive(bytes)

        #expect(throws: HTTP.Framing.Error.responseWithoutRequest) {
            try client.next()
        }
        // The reject path leaves the stream byte-for-byte unadvanced.
        #expect(client.unconsumed == bytes.count)
    }

    @Test
    func `C7c - a failed frame does NOT pop the queue`() throws {
        // The drive's analogue of the framer's unadvanced buffer: a throw must
        // leave the drive exactly as it was, or the retry frames the next
        // response against the wrong request.
        var client = HTTP.Framing.Connection.Client()
        client.expect(.get)
        try client.receive(
            `HTTP.Framing.Connection.Client Tests`.octets(
                "HTTP/1.1 200 OK\r\nContent-Length: 5\r\nContent-Length: 6\r\n\r\n"
            )
        )

        #expect(throws: HTTP.Framing.Error.conflictingContentLength(["5", "6"])) {
            try client.next()
        }
        // Still outstanding: the exchange was never answered.
        #expect(client.outstanding == 1)
    }
}

// MARK: - C9: tunnel

extension `HTTP.Framing.Connection.Client Tests`.`Edge Case` {
    @Test
    func `C9 - a 2xx to CONNECT tunnels, and the residual octets are handed back`() throws {
        // RFC 9112 Section 9.3.3: the connection stops being a sequence of HTTP
        // messages. Framing must stop rather than continue reading the tunnel's
        // payload as though it were a response.
        var client = HTTP.Framing.Connection.Client()
        client.expect(.connect)
        try client.receive(
            `HTTP.Framing.Connection.Client Tests`.octets(
                "HTTP/1.1 200 Connection Established\r\n\r\n\u{01}\u{02}not-http"
            )
        )

        guard case .head(let head) = try #require(try client.next()) else {
            Issue.record("expected a head")
            return
        }
        #expect(head.bodyLength == .tunnel)

        guard case .tunnel = try #require(try client.next()) else {
            Issue.record("expected the tunnel event")
            return
        }
        #expect(client.isReusable == false)
        // Nothing further is framed; the octets belong to the tunnel now.
        #expect(try client.next() == nil)

        let residual = client.surrenderTunnel()
        #expect(residual == `HTTP.Framing.Connection.Client Tests`.octets("\u{01}\u{02}not-http"))
    }
}

// MARK: - C2: the incremental GO condition, lifted to the drive
//
// The 2a rule was that a head split at every byte boundary frames identically
// to one delivered whole. A drive that only works on whole buffers passes every
// other test in this file.

extension `HTTP.Framing.Connection.Client Tests`.Integration {
    @Test
    func `C2 - a close-delimited response split at EVERY byte boundary is identical`() throws {
        let text = `HTTP.Framing.Connection.Client Tests`.closeDelimited + "hello world"
        let bytes = `HTTP.Framing.Connection.Client Tests`.octets(text)

        var client = HTTP.Framing.Connection.Client()
        client.expect(.get)

        var head: HTTP.Framing.ResponseHead?
        var payload: [Byte] = []
        var ended = false
        var endOctets = 0

        for byte in bytes {
            try client.receive([byte])
            while let event = try client.next() {
                switch event {
                case .head(let framed): head = framed
                case .body(let chunk): payload.append(contentsOf: chunk)

                case .end(_, let octets):
                    ended = true
                    endOctets = octets

                case .tunnel: Issue.record("no tunnel in this fixture")
                }
            }
        }

        // Every octet has arrived, but the delimiter has not.
        #expect(head != nil)
        #expect(ended == false)

        client.peerClosed()
        while let event = try client.next() {
            if case .end(_, let octets) = event {
                ended = true
                endOctets = octets
            }
        }

        #expect(try #require(head).line.statusCode == 200)
        #expect(payload == `HTTP.Framing.Connection.Client Tests`.octets("hello world"))
        #expect(ended)
        // Byte-at-a-time delivery reports the same wire count as one whole read.
        #expect(endOctets == 11)
    }

    @Test
    func `C2b - byte-at-a-time and whole-buffer delivery agree exactly`() throws {
        // The comparison the previous test implies but does not state: two
        // drives, same octets, different read sizes, identical output.
        let text = `HTTP.Framing.Connection.Client Tests`.closeDelimited + "hello world"
        let bytes = `HTTP.Framing.Connection.Client Tests`.octets(text)

        func drain(readSize: Int) throws -> ([Byte], Int) {
            var client = HTTP.Framing.Connection.Client()
            client.expect(.get)
            var payload: [Byte] = []
            var octets = 0

            var offset = 0
            while offset < bytes.count {
                let end = min(offset + readSize, bytes.count)
                try client.receive(Array(bytes[offset..<end]))
                offset = end
                while let event = try client.next() {
                    if case .body(let chunk) = event { payload.append(contentsOf: chunk) }
                }
            }
            client.peerClosed()
            while let event = try client.next() {
                switch event {
                case .body(let chunk): payload.append(contentsOf: chunk)
                case .end(_, let count): octets = count
                default: break
                }
            }
            return (payload, octets)
        }

        let byteAtATime = try drain(readSize: 1)
        let wholeBuffer = try drain(readSize: bytes.count)

        #expect(byteAtATime.0 == wholeBuffer.0)
        #expect(byteAtATime.1 == wholeBuffer.1)
        #expect(wholeBuffer.0 == `HTTP.Framing.Connection.Client Tests`.octets("hello world"))
    }
}
