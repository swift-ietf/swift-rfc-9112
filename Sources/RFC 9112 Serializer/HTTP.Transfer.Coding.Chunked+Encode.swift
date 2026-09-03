public import RFC_9112
public import RFC_9110
public import Byte
import Byte_Standard_Library_Integration
import INCITS_4_1986
import Standard_Library_Extensions

extension RFC_9112.Transfer.Coding.Chunked {
    public static func encode(
        _ data: [Byte],
        chunkSize: Int = 8192,
        extensions: [Extension] = [],
        trailers: [RFC_9110.Field] = []
    ) -> [Byte] {
        var result = [Byte]()

        let extensionsString = extensions.map { $0.formatted }.joined()

        var offset = 0
        while offset < data.count {
            let end = min(offset + chunkSize, data.count)
            let chunkData = data[offset..<end]
            let size = chunkData.count

            result.append(contentsOf: String(size, radix: 16).utf8.lazy.map(Byte.init(bitPattern:)))
            if !extensions.isEmpty {
                result.append(contentsOf: extensionsString.utf8.lazy.map(Byte.init(bitPattern:)))
            }
            result.append(contentsOf: [Byte(bitPattern: 0x0D), Byte(bitPattern: 0x0A)])

            result.append(contentsOf: chunkData)
            result.append(contentsOf: [Byte(bitPattern: 0x0D), Byte(bitPattern: 0x0A)])

            offset = end
        }

        result.append(contentsOf: "0".utf8.lazy.map(Byte.init(bitPattern:)))
        if !extensions.isEmpty {
            result.append(contentsOf: extensionsString.utf8.lazy.map(Byte.init(bitPattern:)))
        }
        result.append(contentsOf: [Byte(bitPattern: 0x0D), Byte(bitPattern: 0x0A)])

        for trailer in trailers {
            let line = "\(trailer.name): \(trailer.value)\r\n"
            result.append(contentsOf: line.utf8.lazy.map(Byte.init(bitPattern:)))
        }

        result.append(contentsOf: [Byte(bitPattern: 0x0D), Byte(bitPattern: 0x0A)])

        return result
    }
}
