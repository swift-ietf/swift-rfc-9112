import Byte
import Byte_Standard_Library_Integration
import RFC_9110
import RFC_9112
import Testing

@Suite
struct `HTTP.Response.Line Tests` {
    @Test
    func `A status line is bidirectional`() throws {
        let parsed = try HTTP.Response.Line.parse("HTTP/1.1 200 OK")
        #expect(parsed.version == HTTP.Version.value)
        #expect(parsed.status == .ok)
        #expect(String(decoding: parsed.reason?.bytes ?? [], as: UTF8.self) == "OK")
        #expect(String(decoding: parsed.bytes.map(\.bitPattern), as: UTF8.self) == "HTTP/1.1 200 OK")
    }

    @Test
    func `A status code is limited to the semantic registry range`() {
        #expect(throws: HTTP.Response.Line.Error.self) {
            try HTTP.Response.Line.parse("HTTP/1.1 999 Invalid")
        }
    }
}
