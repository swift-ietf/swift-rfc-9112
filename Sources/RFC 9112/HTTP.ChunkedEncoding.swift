public import Byte_Primitives
import INCITS_4_1986
import Standard_Library_Extensions

extension RFC_9110 {

    public enum ChunkedEncoding {}
}

extension RFC_9110.ChunkedEncoding {

    public static func encode(
        _ data: [Byte],
        chunkSize: Int = 8192,
        chunkExtensions: [Extension] = [],
        trailers: [RFC_9110.Header.Field] = []
    ) -> [Byte] {
        var result = [Byte]()

        let extensionsString = chunkExtensions.map { $0.formatted }.joined()

        var offset = 0
        while offset < data.count {
            let end = min(offset + chunkSize, data.count)
            let chunkData = data[offset..<end]
            let size = chunkData.count

            result.append(contentsOf: String(size, radix: 16).utf8)
            if !chunkExtensions.isEmpty {
                result.append(contentsOf: extensionsString.utf8)
            }
            result.append(contentsOf: [0x0D, 0x0A])

            result.append(contentsOf: chunkData)
            result.append(contentsOf: [0x0D, 0x0A])

            offset = end
        }

        result.append(contentsOf: "0".utf8)
        if !chunkExtensions.isEmpty {
            result.append(contentsOf: extensionsString.utf8)
        }
        result.append(contentsOf: [0x0D, 0x0A])

        for trailer in trailers {
            let line = "\(trailer.name): \(trailer.value)\r\n"
            result.append(contentsOf: line.utf8)
        }

        result.append(contentsOf: [0x0D, 0x0A])

        return result
    }

    public static func decode(_ data: [Byte]) throws(ChunkedDecodingError) -> DecodeResult {
        var result = [Byte]()
        var allChunkExtensions: [[Extension]] = []
        var trailers: [RFC_9110.Header.Field] = []
        var offset = 0

        while offset < data.count {

            guard let crlfIndex = data[offset...].firstIndex(of: 0x0D),
                data.index(after: crlfIndex) < data.endIndex,
                data[crlfIndex + 1] == 0x0A
            else {
                throw ChunkedDecodingError.invalidFormat
            }

            let sizeLine = data[offset..<crlfIndex]
            let sizeString = String(decoding: sizeLine, as: UTF8.self)

            let components = sizeString.split(separator: ";", maxSplits: 1)
            let sizeComponent = String(components[0]).trimming(.ascii.whitespaces)

            guard let size = Int(sizeComponent, radix: 16) else {
                throw ChunkedDecodingError.invalidChunkSize
            }

            var chunkExtensions: [Extension] = []
            if components.count > 1 {
                let extensionsString = String(components[1])
                chunkExtensions = Extension.parseExtensions(extensionsString)
            }

            offset = crlfIndex + 2

            if size == 0 {

                if !chunkExtensions.isEmpty {
                    allChunkExtensions.append(chunkExtensions)
                }

                while offset < data.count {

                    if data.index(after: offset) < data.endIndex && data[offset] == 0x0D
                        && data[offset + 1] == 0x0A
                    {

                        break
                    }

                    guard let nextCrlf = data[offset...].firstIndex(of: 0x0D),
                        data.index(after: nextCrlf) < data.endIndex,
                        data[nextCrlf + 1] == 0x0A
                    else {
                        throw ChunkedDecodingError.invalidFormat
                    }

                    let trailerLine = data[offset..<nextCrlf]
                    let trailerString = String(decoding: trailerLine, as: UTF8.self)
                    if !trailerString.isEmpty {

                        let parts = trailerString.split(separator: ":", maxSplits: 1)
                        if parts.count == 2 {
                            let name = String(parts[0]).trimming(.ascii.whitespaces)
                            let value = String(parts[1]).trimming(.ascii.whitespaces)
                            do throws(RFC_9110.Header.Field.Error) {
                                let trailer = try RFC_9110.Header.Field(
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

            allChunkExtensions.append(chunkExtensions)

            guard offset + size + 2 <= data.count else {
                throw ChunkedDecodingError.incompleteChunk
            }

            let chunkData = data[offset..<(offset + size)]
            result.append(contentsOf: chunkData)

            guard data[offset + size] == 0x0D,
                data[offset + size + 1] == 0x0A
            else {
                throw ChunkedDecodingError.missingCRLF
            }

            offset += size + 2
        }

        return DecodeResult(
            data: result,
            chunkExtensions: allChunkExtensions,
            trailers: trailers
        )
    }
}
