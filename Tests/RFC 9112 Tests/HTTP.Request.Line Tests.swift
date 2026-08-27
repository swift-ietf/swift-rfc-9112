import RFC_9112
import Testing

@Suite
struct `HTTP.Request.Line Tests` {
    @Test
    func `Origin form is bidirectional`() throws {
        let line = try HTTP.Request.Line.parse("GET /greeting?name=Blob HTTP/1.1")
        #expect(line.method == .get)
        #expect(line.target.text == "/greeting?name=Blob")
        #expect(line.version == HTTP.Version.value)
        #expect(line.formatted == "GET /greeting?name=Blob HTTP/1.1")
    }

    @Test
    func `The four request target forms remain version owned`() throws {
        #expect(try HTTP.Request.Line.parse("OPTIONS * HTTP/1.1").target == .asterisk)
        #expect(try HTTP.Request.Line.parse("CONNECT example.com:443 HTTP/1.1").target.text == "example.com:443")
        #expect(try HTTP.Request.Line.parse("GET https://example.com/ HTTP/1.1").target.text == "https://example.com/")
    }
}
