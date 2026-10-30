#if Coder
    import Byte
    import RFC_3986
    import RFC_9110
    import RFC_9112
    import Testing

    @Suite
    struct `HTTP.Host.Coder Tests` {

        @Test
        func `a name and port are read from the field value`() throws {
            let host = try RFC_9112.Host(text: "example.com:8080")
            #expect(host.name == "example.com")
            #expect(host.port == RFC_3986.URI.Port(8080))
            #expect(host.description == "example.com:8080")
        }

        @Test
        func `a bracketed address keeps its brackets`() throws {
            let host = try RFC_9112.Host(text: "[::1]:443")
            #expect(host.name == "[::1]")
            #expect(host.port == RFC_3986.URI.Port(443))
        }

        @Test
        func `an unbracketed address is rejected`() {
            #expect(throws: RFC_9112.Host.Failure.unclosedBracket("[::1")) {
                try RFC_9112.Host(text: "[::1")
            }
        }

        @Test
        func `a port outside the range is rejected`() {
            #expect(throws: RFC_9112.Host.Failure.invalidPort("99999")) {
                try RFC_9112.Host(text: "example.com:99999")
            }
        }

        @Test
        func `an empty field value is rejected`() {
            #expect(throws: RFC_9112.Host.Failure.empty) {
                try RFC_9112.Host(text: "")
            }
        }

        @Test
        func `an HTTP 1 1 request without a host field is rejected`() throws {
            let request = RFC_9112.Message.Request<[Byte]>(
                method: .get,
                target: .asterisk
            )

            #expect(throws: RFC_9112.Host.Failure.missing) {
                try request.host
            }
        }

        @Test
        func `a request carries the host of its field`() throws {
            let request = RFC_9112.Message.Request<[Byte]>(
                method: .get,
                target: .asterisk,
                headers: [try RFC_9110.Field(name: "Host", value: "example.com")]
            )

            #expect(try request.host == RFC_9112.Host(name: "example.com"))
        }

        @Test
        func `duplicate host fields are rejected`() throws {
            let request = RFC_9112.Message.Request<[Byte]>(
                method: .get,
                target: .asterisk,
                headers: [
                    try RFC_9110.Field(name: "Host", value: "example.com"),
                    try RFC_9110.Field(name: "Host", value: "example.org"),
                ]
            )

            #expect(throws: RFC_9112.Host.Failure.duplicated(count: 2)) {
                try request.host
            }
        }

        @Test
        func `a host disagreeing with an absolute target is rejected`() throws {
            let uri = try RFC_3986.URI("http://example.com/greeting")
            let request = RFC_9112.Message.Request<[Byte]>(
                method: .get,
                target: .absolute(uri),
                headers: [try RFC_9110.Field(name: "Host", value: "example.org")]
            )

            #expect(throws: (any Swift::Error).self) {
                try request.host
            }
        }
    }
#endif
