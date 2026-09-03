public import RFC_9112
import RFC_9110
public import Byte
import Byte_Standard_Library_Integration
import INCITS_4_1986
import Standard_Library_Extensions

extension RFC_9112.Transfer.Coding.Chunked {
    public static func decode(_ data: [Byte]) throws(Error) -> Result {
        var result = [Byte]()
        var allExtensions: [[Extension]] = []
        var trailers: [RFC_9110.Field] = []
        var offset = 0

        while offset < data.count {

            guard let crlfIndex = data[offset...].firstIndex(of: Byte(bitPattern: 0x0D)),
                data.index(after: crlfIndex) < data.endIndex,
                data[crlfIndex + 1] == Byte(bitPattern: 0x0A)
            else {
                throw Error.invalidFormat
            }

            let sizeLine = data[offset..<crlfIndex]
            let sizeString = String(decoding: sizeLine, as: UTF8.self)

            let components = sizeString.split(separator: ";", maxSplits: 1)
            let sizeComponent = String(components[0]).trimming(.ascii.whitespaces)

            guard let size = Int(sizeComponent, radix: 16) else {
                throw Error.invalidChunkSize
            }

            var extensions: [Extension] = []
            if components.count > 1 {
                let extensionsString = String(components[1])
                extensions = Extension.parseExtensions(extensionsString)
            }

            offset = crlfIndex + 2

            if size == 0 {

                if !extensions.isEmpty {
                    allExtensions.append(extensions)
                }

                while offset < data.count {

                    if data.index(after: offset) < data.endIndex
                        && data[offset] == Byte(bitPattern: 0x0D)
                        && data[offset + 1] == Byte(bitPattern: 0x0A)
                    {

                        break
                    }

                    guard let nextCrlf = data[offset...].firstIndex(of: Byte(bitPattern: 0x0D)),
                        data.index(after: nextCrlf) < data.endIndex,
                        data[nextCrlf + 1] == Byte(bitPattern: 0x0A)
                    else {
                        throw Error.invalidFormat
                    }

                    let trailerLine = data[offset..<nextCrlf]
                    let trailerString = String(decoding: trailerLine, as: UTF8.self)
                    if !trailerString.isEmpty {

                        let parts = trailerString.split(separator: ":", maxSplits: 1)
                        if parts.count == 2 {
                            let name = String(parts[0]).trimming(.ascii.whitespaces)
                            let value = String(parts[1]).trimming(.ascii.whitespaces)
                            do throws(RFC_9110.Field.Error) {
                                let trailer = try RFC_9110.Field(
                                    name: name,
                                    value: value
                                )
                                trailers.append(trailer)
                            } catch {

                            }
                        }
                    }

                    offset = nextCrlf + 2
                }

                break
            }

            allExtensions.append(extensions)

            guard offset + size + 2 <= data.count else {
                throw Error.incompleteChunk
            }

            let chunkData = data[offset..<(offset + size)]
            result.append(contentsOf: chunkData)

            guard data[offset + size] == Byte(bitPattern: 0x0D),
                data[offset + size + 1] == Byte(bitPattern: 0x0A)
            else {
                throw Error.missingCRLF
            }

            offset += size + 2
        }

        return Result(
            data: result,
            extensions: allExtensions,
            trailers: trailers
        )
    }
}
