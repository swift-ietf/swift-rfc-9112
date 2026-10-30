#if Coder
    import Byte
    import Coder
    import Cursor
    import RFC_9110
    import RFC_9112
    import Testing

    @Suite
    struct `HTTP.Transfer.Coding.Chunked.Coder Tests` {

        @Test
        func `a chunked body reads as its content`() throws {
            var input = bytes("5\r\nhello\r\n0\r\n\r\n")[...]

            let result = try RFC_9112.Transfer.Coding.Chunked.coder.parse(&input)

            #expect(text(result.data) == "hello")
            #expect(result.trailers.isEmpty)
        }

        @Test
        func `chunk extensions are read`() throws {
            var input = bytes("5;name=value\r\nhello\r\n0\r\n\r\n")[...]

            let result = try RFC_9112.Transfer.Coding.Chunked.coder.parse(&input)

            #expect(result.extensions == [[.init(name: "name", value: "value")]])
        }

        @Test
        func `trailers are read after the last chunk`() throws {
            var input = bytes("5\r\nhello\r\n0\r\nExpires: soon\r\n\r\n")[...]

            let result = try RFC_9112.Transfer.Coding.Chunked.coder.parse(&input)

            #expect(result.trailers.count == 1)
            #expect(result.trailers.first?.value.rawValue == "soon")
        }

        @Test
        func `a chunked body round trips`() throws {
            let result = RFC_9112.Transfer.Coding.Chunked.Result(
                data: bytes("hello"),
                extensions: [[]],
                trailers: []
            )

            var buffer: [Byte] = []
            try RFC_9112.Transfer.Coding.Chunked.Result.coder.serialize(result, into: &buffer)
            #expect(text(buffer) == "5\r\nhello\r\n0\r\n\r\n")

            var input = buffer[...]
            #expect(try RFC_9112.Transfer.Coding.Chunked.coder.parse(&input) == result)
        }

        @Test
        func `an unfinished chunk is rejected`() {
            var input = bytes("5\r\nhel\r\n")[...]

            #expect(throws: RFC_9112.Transfer.Coding.Chunked.Error.missingCRLF) {
                try RFC_9112.Transfer.Coding.Chunked.coder.parse(&input)
            }
        }
    }
#endif
