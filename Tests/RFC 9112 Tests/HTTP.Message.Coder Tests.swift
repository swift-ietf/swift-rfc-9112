#if Coder
    import Byte
    import Coder
    import RFC_9110
    import RFC_9112
    import Testing

    @Suite
    struct `HTTP.Message.Coder Tests` {

        @Test
        func `a request arriving in two parts is framed once complete`() throws {
            var coder = RFC_9112.Message.Coder()

            try coder.append(bytes("POST /orders HTTP/1.1\r\nContent-"), accumulating: .head)
            let partial = try coder.request()
            #expect(partial == nil)

            try coder.append(bytes("Length: 5\r\n\r\n"), accumulating: .head)
            let framed = try coder.request()
            let head = try #require(framed)
            #expect(head.length == .length(5))

            let awaited = try coder.body(head.length)
            #expect(awaited == nil)

            try coder.append(bytes("hello"), accumulating: .body)
            let read = try coder.body(head.length)
            let body = try #require(read)

            #expect(text(body.content) == "hello")
            #expect(coder.unconsumed == 0)
        }

        @Test
        func `a chunked body is framed with its trailers`() throws {
            var coder = RFC_9112.Message.Coder()

            try coder.append(
                bytes("POST / HTTP/1.1\r\nTransfer-Encoding: chunked\r\n\r\n"),
                accumulating: .head
            )
            let framed = try coder.request()
            let head = try #require(framed)
            #expect(head.length == .chunked)

            try coder.append(bytes("5\r\nhello\r\n0\r\nExpires: soon\r\n\r\n"), accumulating: .body)
            let read = try coder.body(head.length)
            let body = try #require(read)

            #expect(text(body.content) == "hello")
            #expect(body.trailers.count == 1)
        }

        @Test
        func `a bare carriage return is rejected`() throws {
            var coder = RFC_9112.Message.Coder()
            try coder.append(bytes("GET / HTTP/1.1\rHost: example.com\r\n\r\n"), accumulating: .head)

            do throws(RFC_9112.Message.Coder.Error) {
                _ = try coder.request()
                Issue.record("a bare carriage return was accepted")
            } catch {
                #expect(error == .bareCarriageReturn)
            }
        }

        @Test
        func `a response is framed against the method it answers`() throws {
            var coder = RFC_9112.Message.Coder()
            try coder.append(
                bytes("HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\nhello"),
                accumulating: .head
            )

            let framed = try coder.response(answering: .get)
            let head = try #require(framed)
            #expect(head.length == .length(5))

            let read = try coder.body(head.length)
            let body = try #require(read)
            #expect(text(body.content) == "hello")
        }
    }
#endif
