import RFC_9112
import Testing

@Suite
struct `HTTP.Version Tests` {
    @Test
    func `HTTP 1.1 has its exact shared semantic value`() {
        #expect(HTTP.Version.value.major == 1)
        #expect(HTTP.Version.value.minor == 1)
    }

    @Test
    func `HTTP 1.x syntax is bidirectional`() throws {
        let version = try HTTP.Version.parse("HTTP/1.0")
        #expect(HTTP.Version.format(version) == "HTTP/1.0")
    }

    @Test
    func `Version components are one decimal digit`() {
        #expect(throws: HTTP.Version.Error.self) {
            try HTTP.Version.parse("HTTP/11.0")
        }
    }
}
