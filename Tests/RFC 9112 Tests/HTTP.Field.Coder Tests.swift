#if Coder
    import Byte
    import Coder
    import Cursor
    import RFC_9110
    import RFC_9112
    import Testing

    @Suite
    struct `HTTP.Field.Coder Tests` {

        @Test
        func `a field line reads as a name and value`() throws {
            var input = bytes("Content-Length: 42")[...]

            let field = try RFC_9112.Field.coder.parse(&input)

            #expect(field.name == .contentLength)
            #expect(field.value.rawValue == "42")
        }

        @Test
        func `a field line round trips`() throws {
            var input = bytes("Host: example.com")[...]
            let field = try RFC_9112.Field.coder.parse(&input)

            var buffer: [Byte] = []
            try RFC_9112.Field.coder.serialize(field, into: &buffer)

            #expect(text(buffer) == "Host: example.com")
        }

        @Test
        func `whitespace before the colon is rejected`() {
            var input = bytes("Host : example.com")[...]

            #expect(throws: RFC_9112.Field.Error.whitespaceBeforeColon) {
                try RFC_9112.Field.coder.parse(&input)
            }
        }

        @Test
        func `a line without a colon is rejected`() {
            var input = bytes("Host example.com")[...]

            #expect(throws: RFC_9112.Field.Error.missingColon) {
                try RFC_9112.Field.coder.parse(&input)
            }
        }

        @Test
        func `obsolete line folding is rejected by default`() {
            var input = bytes("Host: example.com\r\n more")[...]

            #expect(throws: RFC_9112.Field.Error.obsoleteLineFolding) {
                try RFC_9112.Field.coder.parse(&input)
            }
        }

        @Test
        func `a folding policy of space joins the continuation`() throws {
            var input = bytes("Subject: first\r\n  second")[...]

            let coder = RFC_9112.Field.Coder<ArraySlice<Byte>, [Byte]>(policy: .space)
            let field = try coder.parse(&input)

            #expect(field.value.rawValue == "first second")
        }
    }
#endif
