#if Coder
    import Byte
    import Coder
    import Cursor
    import RFC_9110
    import RFC_9112
    import Testing

    @Suite
    struct `HTTP.Response.Line.Coder Tests` {

        @Test
        func `a status line reads as its version status and reason`() throws {
            var input = bytes("HTTP/1.1 200 OK")[...]

            let line = try RFC_9112.Response.Line.coder.parse(&input)

            #expect(line.status == RFC_9110.Status(200))
            #expect(line.reason == RFC_9110.Status.Reason(bytes("OK")))
        }

        @Test
        func `a status line round trips`() throws {
            var input = bytes("HTTP/1.1 404 Not Found")[...]
            let line = try RFC_9112.Response.Line.coder.parse(&input)

            var buffer: [Byte] = []
            try RFC_9112.Response.Line.coder.serialize(line, into: &buffer)

            #expect(text(buffer) == "HTTP/1.1 404 Not Found")
        }

        @Test
        func `a status line without a reason round trips`() throws {
            var input = bytes("HTTP/1.1 204")[...]
            let line = try RFC_9112.Response.Line.coder.parse(&input)

            #expect(line.reason == nil)

            var buffer: [Byte] = []
            try RFC_9112.Response.Line.coder.serialize(line, into: &buffer)
            #expect(text(buffer) == "HTTP/1.1 204")
        }

        @Test
        func `a status outside the range is rejected`() {
            var input = bytes("HTTP/1.1 999 Nope")[...]

            #expect(throws: RFC_9112.Response.Line.Error.statusOutOfRange(999)) {
                try RFC_9112.Response.Line.coder.parse(&input)
            }
        }
    }
#endif
