import RFC_9112
import Testing

@Suite
struct `HTTP token case` {
    @Test(arguments: ["Chunked", "CHUNKED", "cHuNkEd"])
    func `a transfer coding name is case-insensitive`(_ name: String) {
        let encoding = RFC_9112.Transfer.Encoding(codingName: name)
        #expect(encoding.isChunked)
        #expect(encoding == .chunked)
        #expect(RFC_9112.Transfer.Encoding.list([.gzip, encoding]).isChunkedFinal)
    }

    @Test
    func `a Kelvin sign does not become an ASCII k in a connection option`() {
        let connection = RFC_9112.Connection(options: ["\u{212A}eep-alive"])
        #expect(!connection.hasKeepAlive)
    }

    @Test
    func `ASCII connection options are case-insensitive`() {
        #expect(RFC_9112.Connection(options: ["Keep-Alive"]).hasKeepAlive)
        #expect(RFC_9112.Connection(options: ["CLOSE"]).hasClose)
    }
}
