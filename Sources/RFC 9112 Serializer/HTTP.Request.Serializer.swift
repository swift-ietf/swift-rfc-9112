public import RFC_9112
public import Byte
import RFC_9110

extension RFC_9112.Request {
    public enum Serializer {}
}

extension RFC_9112.Request.Serializer {
    public static func serialize(
        _ request: RFC_9112.Message.Request<[Byte]>
    ) -> [Byte] {
        var bytes = [Byte]()
        let line = RFC_9112.Request.Line(
            method: request.method,
            target: request.target,
            version: request.version
        )

        bytes.append(contentsOf: line.formatted.utf8.map(Byte.init(bitPattern:)))
        bytes.append(contentsOf: [Byte(bitPattern: 0x0D), Byte(bitPattern: 0x0A)])

        for field in request.headers {
            bytes.append(contentsOf: "\(field.name): \(field.value)".utf8.map(Byte.init(bitPattern:)))
            bytes.append(contentsOf: [Byte(bitPattern: 0x0D), Byte(bitPattern: 0x0A)])
        }

        bytes.append(contentsOf: [Byte(bitPattern: 0x0D), Byte(bitPattern: 0x0A)])
        if let content = request.content {
            bytes.append(contentsOf: content)
        }
        return bytes
    }
}
