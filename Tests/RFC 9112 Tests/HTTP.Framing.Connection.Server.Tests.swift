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

    static let largeBodyLength = 1_048_576

    static func headDeclaring(_ length: Int) -> String {
        "POST /upload HTTP/1.1\r\nHost: example.com\r\nContent-Length: \(length)\r\n\r\n"
    }
}

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

        var framer = HTTP.Framing.Framer()
        let oversized = [Byte](
            repeating: Byte(0x41),
            count: `HTTP.Framing.Connection.Server Tests`.largeBodyLength
        )

        #expect(throws: HTTP.Framing.Error.headSectionTooLong(limit: 73_536)) {
            try framer.append(oversized, accumulating: .head)
        }

        #expect(framer.unconsumed == 0)
    }
}

extension `HTTP.Framing.Connection.Server Tests`.Integration {
    @Test
    func `C5 - three pipelined requests WITH BODIES frame in sequence`() throws {

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
        #expect(payloads.count == 2)
        #expect(payloads[0] == `HTTP.Framing.Connection.Server Tests`.octets("HELLO"))
        #expect(payloads[1] == `HTTP.Framing.Connection.Server Tests`.octets("bye"))

        #expect(bodyOctets == [5, 13, 0])
        #expect(server.unconsumed == 0)
    }

    @Test
    func `C6 - the next head is NOT framed while a body is outstanding`() throws {

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

        let readingBody = server.isReadingBody
        #expect(readingBody)

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

extension `HTTP.Framing.Connection.Server Tests`.`Edge Case` {
    @Test
    func `C8 - Connection close ends reuse, and buffered octets are NOT framed`() throws {

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

        let reusableBeforeEnd = server.isReusable
        #expect(reusableBeforeEnd)

        guard case .end = try #require(try server.next()) else {
            Issue.record("expected the message to end")
            return
        }
        #expect(server.isReusable == false)

        #expect(try server.next() == nil)
        #expect(server.unconsumed > 0)
    }
}

extension `HTTP.Framing.Connection.Server Tests`.`Edge Case` {
    @Test
    func `C4 - a blank line already buffered does NOT disable the body budget`() throws {

        let limits = HTTP.Framing.Limits(startLine: 8_000, fieldSection: 65_536, body: 16_384)
        var server = HTTP.Framing.Connection.Server(limits: limits)

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

        let prefix = `HTTP.Framing.Connection.Server Tests`.octets("4000\r\nAAAA\r\n\r\n")
        try server.receive(prefix)
        #expect(server.unconsumed == prefix.count)

        let flood = [Byte](repeating: Byte(0x41), count: 100_000)
        #expect(throws: HTTP.Framing.Error.bodyTooLong(limit: 16_384)) {
            try server.receive(flood)
        }

        #expect(server.unconsumed == prefix.count)
    }

    @Test
    func `C10 - close mid-head is truncated, close on a boundary is clean`() throws {

        var clean = HTTP.Framing.Connection.Server()
        try clean.receive(
            `HTTP.Framing.Connection.Server Tests`.octets("GET / HTTP/1.1\r\nHost: x\r\n\r\n")
        )
        _ = try clean.next()
        _ = try clean.next()
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

        let limits = HTTP.Framing.Limits(startLine: 8_000, fieldSection: 65_536, body: 512)
        var server = HTTP.Framing.Connection.Server(limits: limits)

        try server.receive(
            `HTTP.Framing.Connection.Server Tests`.octets(
                "POST /x HTTP/1.1\r\nTransfer-Encoding: chunked\r\n\r\n"
            )
        )
        _ = try server.next()

        let body = [Byte](repeating: Byte(0x41), count: 1_024)
        #expect(throws: HTTP.Framing.Error.bodyTooLong(limit: 512)) {
            try server.receive(body)
        }
        #expect(server.unconsumed == 0)
    }
}
