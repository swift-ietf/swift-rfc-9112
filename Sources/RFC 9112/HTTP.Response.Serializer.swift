public import Byte
import RFC_9110

extension RFC_9112.Response {
    public enum Serializer {}
}

extension RFC_9112.Response.Serializer {
    public static func serialize(
        _ response: RFC_9112.Message.Response<[Byte]>
    ) -> [Byte] {
        var bytes = RFC_9112.Response.Line(
            version: response.version,
            status: response.status,
            reason: response.reason
        ).bytes
        bytes.append(contentsOf: [Byte(bitPattern: 0x0D), Byte(bitPattern: 0x0A)])

        for field in response.headers {
            bytes.append(contentsOf: "\(field.name): \(field.value)".utf8.map(Byte.init(bitPattern:)))
            bytes.append(contentsOf: [Byte(bitPattern: 0x0D), Byte(bitPattern: 0x0A)])
        }

        bytes.append(contentsOf: [Byte(bitPattern: 0x0D), Byte(bitPattern: 0x0A)])
        if let content = response.content {
            bytes.append(contentsOf: content)
        }
        return bytes
    }
}
