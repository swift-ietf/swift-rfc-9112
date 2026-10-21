import Byte
import RFC_3986
import RFC_9110
import RFC_9112
import Testing

@Suite
struct `HTTP.Message Tests` {
    @Test
    func `semantic request gains an HTTP 1.1 representation`() throws {
        let resource = try RFC_3986.URI("/greeting?name=Ada")
        let semantic = RFC_9110.Message.Request<String>(
            method: .get,
            target: .resource(resource),
            content: "hello"
        )

        let representation = try RFC_9112.Message.Request(semantic)

        #expect(representation.version == RFC_9112.Version.value)
        #expect(representation.target == .origin(path: try RFC_3986.URI.Path("/greeting"), query: try RFC_3986.URI.Query("name=Ada")))
        #expect(representation.semantic == semantic)
    }

    @Test
    func `semantic response gains an HTTP 1.1 representation`() {
        let semantic = RFC_9110.Message.Response<String>(
            status: .ok,
            content: "hello"
        )

        let representation = RFC_9112.Message.Response(semantic)

        #expect(representation.version == RFC_9112.Version.value)
        #expect(representation.semantic == semantic)
    }
}
