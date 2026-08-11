// HTTP.Response.Serializer.Tests.swift
// swift-rfc-9112

import Testing

@testable import RFC_9112

extension HTTP.Response.Serializer {
    @Suite struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension HTTP.Response.Serializer.Test {
    static func octets(_ text: String) -> [Byte] {
        Array(text.utf8)
    }

    static func head(
        status: HTTP.Status = .ok,
        headers: HTTP.Headers,
        bodyLength: HTTP.Framing.BodyLength,
        method: HTTP.Method = .get
    ) -> HTTP.Response.Serializer.Event {
        .head(
            HTTP.Framing.ResponseHead(
                line: HTTP.Response.Line(version: .http11, status: status),
                headers: headers,
                bodyLength: bodyLength,
                octets: 0
            ),
            answering: method
        )
    }
}

extension HTTP.Response.Serializer.Test.Unit {
    @Test
    func `head emits status fields and the empty line`() throws {
        let headers: HTTP.Headers = [
            try HTTP.Header.Field(name: "Content-Length", value: "0"),
            try HTTP.Header.Field(name: "Content-Type", value: "text/plain"),
        ]
        var serializer = HTTP.Response.Serializer()

        let bytes = try serializer.serialize(
            HTTP.Response.Serializer.Test.head(headers: headers, bodyLength: .length(0))
        )

        #expect(
            bytes
                == HTTP.Response.Serializer.Test.octets(
                    "HTTP/1.1 200 OK\r\nContent-Length: 0\r\nContent-Type: text/plain\r\n\r\n"
                )
        )
    }

    @Test
    func `fixed length content is emitted without buffering or decoration`() throws {
        let headers: HTTP.Headers = [
            try HTTP.Header.Field(name: "Content-Length", value: "5")
        ]
        var serializer = HTTP.Response.Serializer()
        _ = try serializer.serialize(
            HTTP.Response.Serializer.Test.head(headers: headers, bodyLength: .length(5))
        )

        let first = try serializer.serialize(.body(HTTP.Response.Serializer.Test.octets("he")))
        let second = try serializer.serialize(.body(HTTP.Response.Serializer.Test.octets("llo")))
        let end = try serializer.serialize(.end(trailers: []))

        #expect(first == HTTP.Response.Serializer.Test.octets("he"))
        #expect(second == HTTP.Response.Serializer.Test.octets("llo"))
        #expect(end.isEmpty)
        let finished = serializer.isFinished
        #expect(finished)
    }

    @Test
    func `chunked content emits one complete chunk per nonempty body event`() throws {
        let headers: HTTP.Headers = [
            try HTTP.Header.Field(name: "Transfer-Encoding", value: "chunked")
        ]
        var serializer = HTTP.Response.Serializer()
        _ = try serializer.serialize(
            HTTP.Response.Serializer.Test.head(headers: headers, bodyLength: .chunked)
        )

        let first = try serializer.serialize(.body(HTTP.Response.Serializer.Test.octets("hello")))
        let empty = try serializer.serialize(.body([]))
        let second = try serializer.serialize(.body(HTTP.Response.Serializer.Test.octets("!")))

        #expect(first == HTTP.Response.Serializer.Test.octets("5\r\nhello\r\n"))
        #expect(empty.isEmpty)
        #expect(second == HTTP.Response.Serializer.Test.octets("1\r\n!\r\n"))
    }

    @Test
    func `chunked end emits the last chunk trailers and terminal empty line`() throws {
        let headers: HTTP.Headers = [
            try HTTP.Header.Field(name: "Transfer-Encoding", value: "chunked")
        ]
        let trailers: HTTP.Headers = [
            try HTTP.Header.Field(name: "Checksum", value: "abc123")
        ]
        var serializer = HTTP.Response.Serializer()
        _ = try serializer.serialize(
            HTTP.Response.Serializer.Test.head(headers: headers, bodyLength: .chunked)
        )

        let bytes = try serializer.serialize(.end(trailers: trailers))

        #expect(bytes == HTTP.Response.Serializer.Test.octets("0\r\nChecksum: abc123\r\n\r\n"))
    }
}

extension HTTP.Response.Serializer.Test.`Edge Case` {
    @Test
    func `response to HEAD remains bodyless despite its representation length`() throws {
        let headers: HTTP.Headers = [
            try HTTP.Header.Field(name: "Content-Length", value: "5")
        ]
        var serializer = HTTP.Response.Serializer()
        _ = try serializer.serialize(
            HTTP.Response.Serializer.Test.head(
                headers: headers,
                bodyLength: .none,
                method: .head
            )
        )

        do throws(HTTP.Response.Serializer.Error) {
            _ = try serializer.serialize(.body(HTTP.Response.Serializer.Test.octets("hello")))
            Issue.record("expected HEAD response body rejection")
        } catch {
            #expect(error == .body)
        }
    }

    @Test
    func `no body status accepts only an empty body and trailer section`() throws {
        var serializer = HTTP.Response.Serializer()
        let head = try serializer.serialize(
            HTTP.Response.Serializer.Test.head(
                status: .noContent,
                headers: [],
                bodyLength: .none
            )
        )
        let empty = try serializer.serialize(.body([]))
        let end = try serializer.serialize(.end(trailers: []))

        #expect(head == HTTP.Response.Serializer.Test.octets("HTTP/1.1 204 No Content\r\n\r\n"))
        #expect(empty.isEmpty)
        #expect(end.isEmpty)

        var rejected = HTTP.Response.Serializer()
        _ = try rejected.serialize(
            HTTP.Response.Serializer.Test.head(
                status: .noContent,
                headers: [],
                bodyLength: .none
            )
        )
        do throws(HTTP.Response.Serializer.Error) {
            _ = try rejected.serialize(.body([0x41]))
            Issue.record("expected body rejection")
        } catch {
            #expect(error == .body)
        }
    }

    @Test
    func `fixed length mismatch poisons the serializer`() throws {
        let headers: HTTP.Headers = [
            try HTTP.Header.Field(name: "Content-Length", value: "3")
        ]
        var serializer = HTTP.Response.Serializer()
        _ = try serializer.serialize(
            HTTP.Response.Serializer.Test.head(headers: headers, bodyLength: .length(3))
        )
        _ = try serializer.serialize(.body([0x41, 0x42]))

        do throws(HTTP.Response.Serializer.Error) {
            _ = try serializer.serialize(.end(trailers: []))
            Issue.record("expected fixed-length mismatch")
        } catch {
            #expect(error == .mismatch(expected: 3, actual: 2))
        }

        do throws(HTTP.Response.Serializer.Error) {
            _ = try serializer.serialize(.body([0x43]))
            Issue.record("expected poisoned state")
        } catch {
            #expect(error == .failed)
        }
    }

    @Test
    func `body before head is an invalid transition and poisons the serializer`() {
        var serializer = HTTP.Response.Serializer()

        do throws(HTTP.Response.Serializer.Error) {
            _ = try serializer.serialize(.body([0x41]))
            Issue.record("expected invalid transition")
        } catch {
            #expect(error == .transition)
        }

        do throws(HTTP.Response.Serializer.Error) {
            _ = try serializer.serialize(.end(trailers: []))
            Issue.record("expected poisoned state")
        } catch {
            #expect(error == .failed)
        }
    }

    @Test
    func `finish rejects an incomplete response`() throws {
        let headers: HTTP.Headers = [
            try HTTP.Header.Field(name: "Content-Length", value: "1")
        ]
        var serializer = HTTP.Response.Serializer()
        _ = try serializer.serialize(
            HTTP.Response.Serializer.Test.head(headers: headers, bodyLength: .length(1))
        )

        do throws(HTTP.Response.Serializer.Error) {
            try serializer.finish()
            Issue.record("expected incomplete response")
        } catch {
            #expect(error == .incomplete)
        }

        do throws(HTTP.Response.Serializer.Error) {
            _ = try serializer.serialize(.body([0x41]))
            Issue.record("expected poisoned state")
        } catch {
            #expect(error == .failed)
        }
    }
}

extension HTTP.Response.Serializer.Test.Integration {
    @Test
    func `whole response serializer remains source compatible`() throws {
        let response = HTTP.Response(
            status: .ok,
            headers: [try HTTP.Header.Field(name: "Content-Length", value: "2")],
            body: [0x4F, 0x4B]
        )

        let bytes = HTTP.Response.Serializer.serialize(response)

        #expect(
            bytes
                == HTTP.Response.Serializer.Test.octets(
                    "HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nOK"
                )
        )
    }

    @Test
    func `finish accepts a response only after its end event`() throws {
        let headers: HTTP.Headers = [
            try HTTP.Header.Field(name: "Content-Length", value: "2")
        ]
        var serializer = HTTP.Response.Serializer()
        _ = try serializer.serialize(
            HTTP.Response.Serializer.Test.head(headers: headers, bodyLength: .length(2))
        )
        _ = try serializer.serialize(.body([0x4F, 0x4B]))
        _ = try serializer.serialize(.end(trailers: []))

        try serializer.finish()
    }
}
