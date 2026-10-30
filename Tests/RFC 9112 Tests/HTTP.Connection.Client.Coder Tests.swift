#if Coder
    import Byte
    import RFC_9110
    import RFC_9112
    import Testing

    @Suite
    struct `HTTP.Connection.Client.Coder Tests` {

        @Test
        func `a response is delivered as head body and end`() throws {
            var client = RFC_9112.Connection.Client.Coder()
            client.expect(.get)

            try client.receive(bytes("HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\nhello"))

            let head = try client.next()
            guard case .head(let response)? = head else {
                Issue.record("expected a head event")
                return
            }
            #expect(response.length == .length(5))

            let body = try client.next()
            guard case .body(let content)? = body else {
                Issue.record("expected a body event")
                return
            }
            #expect(text(content) == "hello")

            let end = try client.next()
            guard case .end? = end else {
                Issue.record("expected an end event")
                return
            }

            let isReusable = client.isReusable
            #expect(isReusable)
        }

        @Test
        func `a response arriving without a request is rejected`() throws {
            var client = RFC_9112.Connection.Client.Coder()
            try client.receive(bytes("HTTP/1.1 200 OK\r\n\r\n"))

            do throws(RFC_9112.Connection.Client.Coder.Error) {
                _ = try client.next()
                Issue.record("a response without a request was accepted")
            } catch {
                #expect(error == .connection(.responseWithoutRequest))
            }
        }
    }

    @Suite
    struct `HTTP.Connection.Server.Coder Tests` {

        @Test
        func `a request is delivered as head and end`() throws {
            var server = RFC_9112.Connection.Server.Coder()
            try server.receive(bytes("GET / HTTP/1.1\r\nHost: example.com\r\n\r\n"))

            let head = try server.next()
            guard case .head(let request)? = head else {
                Issue.record("expected a head event")
                return
            }
            #expect(request.line.method == .get)

            let end = try server.next()
            guard case .end? = end else {
                Issue.record("expected an end event")
                return
            }

            let isReusable = server.isReusable
            #expect(isReusable)
        }
    }
#endif
