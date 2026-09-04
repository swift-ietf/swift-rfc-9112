import RFC_9110
import RFC_9112
import Testing

@Suite
struct `HTTP.Connection Tests` {

    @Test
    func `close ends persistence on any version`() {
        #expect(!RFC_9112.Connection.close.persists(over: RFC_9112.Version.value))
        #expect(!RFC_9112.Connection.close.persists(over: http10))
    }

    @Test
    func `keep alive revives persistence on HTTP 1 0`() {
        #expect(RFC_9112.Connection.keepAlive.persists(over: http10))
    }

    @Test
    func `options are compared case insensitively`() {
        #expect(RFC_9112.Connection(options: ["Close"]) == .close)
    }
}

@Suite
struct `HTTP.Connection.State Tests` {

    @Test
    func `an HTTP 1 1 connection is persistent until close is requested`() {
        var state = RFC_9112.Connection.State()
        #expect(state.isPersistent)

        state.apply(.close)
        #expect(!state.isPersistent)
    }

    @Test
    func `an HTTP 1 0 connection becomes persistent on keep alive`() {
        var state = RFC_9112.Connection.State(version: http10)
        #expect(!state.isPersistent)

        state.apply(.keepAlive)
        #expect(state.isPersistent)
    }

    @Test
    func `resetting restores the version default`() {
        var state = RFC_9112.Connection.State()
        state.close()
        state.reset()
        #expect(state.isPersistent)
    }
}

@Suite
struct `HTTP.Connection.Client Tests` {

    @Test
    func `a response without an outstanding request is rejected`() {
        var client = RFC_9112.Connection.Client()
        #expect(throws: RFC_9112.Connection.Client.Error.responseWithoutRequest) {
            try client.apply(.head(Self.head(.length(2)), connection: nil))
        }
    }

    @Test
    func `a message returns the client to the head state`() throws {
        var client = RFC_9112.Connection.Client()
        client.expect(.get)
        #expect(client.answering == .get)

        try client.apply(.head(Self.head(.length(2)), connection: nil))
        #expect(client.state == .body(.length(2)))
        #expect(client.outstanding == 0)

        try client.apply(.end)
        #expect(client.state == .head)
        #expect(client.isReusable)
    }

    @Test
    func `a close option finishes the connection after the message`() throws {
        var client = RFC_9112.Connection.Client()
        client.expect(.get)

        try client.apply(.head(Self.head(.length(0)), connection: .close))
        try client.apply(.end)

        #expect(client.state == .finished)
        #expect(!client.isReusable)
    }

    @Test
    func `a tunnel leaves the connection unusable for messages`() throws {
        var client = RFC_9112.Connection.Client()
        client.expect(.connect)

        try client.apply(.head(Self.head(.tunnel), connection: nil))
        #expect(client.state == .tunnelled)
        #expect(!client.isReusable)
    }

    @Test
    func `a peer close finishes a body read until close`() throws {
        var client = RFC_9112.Connection.Client()
        client.expect(.get)

        try client.apply(.head(Self.head(.untilClose), connection: nil))
        try client.apply(.close)

        #expect(client.closed)
        #expect(client.state == .finished)
    }

    static func head(_ length: RFC_9112.Message.Body.Length) -> RFC_9112.Response.Head {
        .init(
            line: .init(status: .ok),
            headers: [],
            length: length
        )
    }
}

@Suite
struct `HTTP.Connection.Server Tests` {

    @Test
    func `a request is read and the connection is reused`() throws {
        var server = RFC_9112.Connection.Server()

        try server.apply(.head(Self.head(.length(4)), connection: nil))
        #expect(server.isReadingBody)

        try server.apply(.end)
        #expect(server.state == .head)
        #expect(server.isReusable)
    }

    @Test
    func `a close delimited request is rejected`() {
        var server = RFC_9112.Connection.Server()
        #expect(throws: RFC_9112.Connection.Server.Error.closeDelimitedRequest) {
            try server.apply(.head(Self.head(.untilClose), connection: nil))
        }
    }

    @Test
    func `a close option finishes the connection after the message`() throws {
        var server = RFC_9112.Connection.Server()

        try server.apply(.head(Self.head(.none), connection: .close))
        try server.apply(.end)

        #expect(server.state == .finished)
        #expect(!server.isReusable)
    }

    static func head(_ length: RFC_9112.Message.Body.Length) -> RFC_9112.Request.Head {
        .init(
            line: .init(method: .get, target: .asterisk),
            headers: [],
            length: length
        )
    }
}
