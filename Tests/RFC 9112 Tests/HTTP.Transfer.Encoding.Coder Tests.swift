#if Coder
    import Byte
    import Coder
    import Cursor
    import RFC_9112
    import Testing

    @Suite
    struct `HTTP.Transfer.Encoding.Coder Tests` {

        @Test
        func `a single coding reads as itself`() throws {
            var input = bytes("chunked")[...]

            #expect(try RFC_9112.Transfer.Encoding.coder.parse(&input) == .chunked)
        }

        @Test
        func `a coding list round trips`() throws {
            var input = bytes("gzip, chunked")[...]
            let encoding = try RFC_9112.Transfer.Encoding.coder.parse(&input)

            #expect(encoding.codings == ["gzip", "chunked"])
            #expect(encoding.isChunkedFinal)

            var buffer: [Byte] = []
            try RFC_9112.Transfer.Encoding.coder.serialize(encoding, into: &buffer)
            #expect(text(buffer) == "gzip, chunked")
        }

        @Test
        func `a coding name is read case insensitively`() throws {
            var input = bytes("Chunked")[...]

            #expect(try RFC_9112.Transfer.Encoding.coder.parse(&input) == .chunked)
        }
    }
#endif
