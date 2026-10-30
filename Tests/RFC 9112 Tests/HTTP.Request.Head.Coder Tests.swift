#if Coder
    import Byte
    import Coder
    import Cursor
    import RFC_9110
    import RFC_9112
    import Testing

    @Suite
    struct `HTTP.Request.Head.Coder Tests` {

        @Test
        func `a request head reads its line fields and body length`() throws {
            var input = bytes(
                "POST /orders HTTP/1.1\r\nHost: example.com\r\nContent-Length: 5\r\n\r\n"
            )[...]

            let head = try RFC_9112.Request.Head.coder.parse(&input)

            #expect(head.line.method == .post)
            #expect(head.headers.count == 2)
            #expect(head.length == .length(5))
        }

        @Test
        func `a request head round trips`() throws {
            let source = "GET / HTTP/1.1\r\nHost: example.com\r\n\r\n"
            var input = bytes(source)[...]
            let head = try RFC_9112.Request.Head.coder.parse(&input)

            var buffer: [Byte] = []
            try RFC_9112.Request.Head.coder.serialize(head, into: &buffer)

            #expect(text(buffer) == source)
        }

        @Test
        func `a chunked request head frames a chunked body`() throws {
            var input = bytes(
                "POST / HTTP/1.1\r\nHost: example.com\r\nTransfer-Encoding: chunked\r\n\r\n"
            )[...]

            #expect(try RFC_9112.Request.Head.coder.parse(&input).length == .chunked)
        }

        @Test
        func `conflicting content lengths are rejected`() {
            var input = bytes("POST / HTTP/1.1\r\nContent-Length: 1, 2\r\n\r\n")[...]

            #expect(throws: RFC_9112.Request.Head.Error.conflictingContentLength(["1", "2"])) {
                try RFC_9112.Request.Head.coder.parse(&input)
            }
        }
    }

    @Suite
    struct `HTTP.Response.Head.Coder Tests` {

        @Test
        func `a response head reads its line fields and body length`() throws {
            var input = bytes("HTTP/1.1 200 OK\r\nContent-Length: 3\r\n\r\n")[...]

            let head = try RFC_9112.Response.Head.coder.parse(&input)

            #expect(head.line.status == RFC_9110.Status(200))
            #expect(head.length == .length(3))
        }

        @Test
        func `a response to head carries no body`() throws {
            var input = bytes("HTTP/1.1 200 OK\r\nContent-Length: 3\r\n\r\n")[...]

            let coder = RFC_9112.Response.Head.Coder<ArraySlice<Byte>, [Byte]>(answering: .head)

            #expect(try coder.parse(&input).length == .none)
        }

        @Test
        func `a response head round trips`() throws {
            let source = "HTTP/1.1 204 No Content\r\n\r\n"
            var input = bytes(source)[...]
            let head = try RFC_9112.Response.Head.coder.parse(&input)

            var buffer: [Byte] = []
            try RFC_9112.Response.Head.coder.serialize(head, into: &buffer)

            #expect(text(buffer) == source)
        }
    }
#endif
