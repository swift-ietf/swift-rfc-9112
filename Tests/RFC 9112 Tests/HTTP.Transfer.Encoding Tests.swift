import RFC_9112
import Testing

@Suite
struct `HTTP.Transfer.Encoding Tests` {

    @Test
    func `a nested list is flattened so the chunked checks see every coding`() {
        let inner = RFC_9112.Transfer.Encoding.list([.gzip, .chunked])
        let encoding = RFC_9112.Transfer.Encoding.list([.chunked, inner])

        #expect(encoding == .list([.chunked, .gzip, .chunked]))
        #expect(encoding.codings == ["chunked", "gzip", "chunked"])
        #expect(encoding.chunkedCount == 2)
        #expect(encoding.isChunkedFinal)
    }

    @Test
    func `chunked inside a nested list is found`() {
        let encoding = RFC_9112.Transfer.Encoding.list([.gzip, .list([.deflate, .chunked])])

        #expect(encoding.hasChunked)
        #expect(encoding.chunkedCount == 1)
        #expect(encoding.isChunkedFinal)
    }
}
