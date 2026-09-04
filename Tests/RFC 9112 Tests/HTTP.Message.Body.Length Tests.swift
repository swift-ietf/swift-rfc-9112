import RFC_9110
import RFC_9112
import Testing

@Suite
struct `HTTP.Message.Body.Length Tests` {

    @Test
    func `a request without framing fields carries no body`() throws {
        #expect(try RFC_9112.Message.Body.Length(.request) == .none)
    }

    @Test
    func `a content length names a fixed body`() throws {
        #expect(try RFC_9112.Message.Body.Length(.request, contentLength: 42) == .length(42))
    }

    @Test
    func `a final chunked coding frames the body`() throws {
        #expect(
            try RFC_9112.Message.Body.Length(.request, transferEncoding: .chunked) == .chunked
        )
    }

    @Test
    func `a request whose chunked coding is not final is rejected`() {
        #expect(throws: RFC_9112.Message.Body.Length.Error.chunkedNotFinal) {
            try RFC_9112.Message.Body.Length(
                .request,
                transferEncoding: .list([.chunked, .gzip])
            )
        }
    }

    @Test
    func `a response whose chunked coding is not final reads until close`() throws {
        #expect(
            try RFC_9112.Message.Body.Length(
                .response(status: .ok, to: .get),
                transferEncoding: .list([.chunked, .gzip])
            ) == .untilClose
        )
    }

    @Test
    func `transfer encoding and content length together are rejected`() {
        #expect(throws: RFC_9112.Message.Body.Length.Error.transferEncodingWithContentLength) {
            try RFC_9112.Message.Body.Length(
                .request,
                transferEncoding: .chunked,
                contentLength: 3
            )
        }
    }

    @Test
    func `a request transfer coding without chunked is rejected`() {
        #expect(throws: RFC_9112.Message.Body.Length.Error.transferEncodingWithoutChunked) {
            try RFC_9112.Message.Body.Length(.request, transferEncoding: .gzip)
        }
    }

    @Test
    func `a response to head carries no body`() throws {
        #expect(
            try RFC_9112.Message.Body.Length(
                .response(status: .ok, to: .head),
                contentLength: 10
            ) == .none
        )
    }

    @Test
    func `a not modified response carries no body`() throws {
        #expect(
            try RFC_9112.Message.Body.Length(
                .response(status: RFC_9110.Status(304), to: .get)
            ) == .none
        )
    }

    @Test
    func `a transfer coding on a not modified response is rejected`() {
        let status = RFC_9110.Status(304)
        #expect(
            throws: RFC_9112.Message.Body.Length.Error
                .transferEncodingWithIncompatibleStatus(status)
        ) {
            try RFC_9112.Message.Body.Length(
                .response(status: status, to: .get),
                transferEncoding: .chunked
            )
        }
    }

    @Test
    func `a successful response to connect is a tunnel`() throws {
        #expect(
            try RFC_9112.Message.Body.Length(
                .response(status: .ok, to: .connect)
            ) == .tunnel
        )
    }

    @Test
    func `a response without framing fields reads until close`() throws {
        #expect(
            try RFC_9112.Message.Body.Length(.response(status: .ok, to: .get)) == .untilClose
        )
    }

    @Test
    func `a chunked coding applied twice is rejected`() {
        #expect(throws: RFC_9112.Message.Body.Length.Error.chunkedAppliedMultipleTimes) {
            try RFC_9112.Message.Body.Length(
                .request,
                transferEncoding: .list([.chunked, .chunked])
            )
        }
    }

    @Test
    func `a fixed length reports its octets`() throws {
        let length = try RFC_9112.Message.Body.Length(.request, contentLength: 7)
        #expect(length.fixed == 7)
        #expect(length.hasBody)
        #expect(!length.isChunked)
    }
}
