import Byte_Primitives
import INCITS_4_1986

extension RFC_9110.Framing.Framer {

    internal struct ChunkedScan {

        let content: [Byte]

        let octets: Int

        let trailers: RFC_9110.Headers
    }

    internal static func scanChunkedBody(
        _ buffer: borrowing [Byte],
        limit: Int
    ) throws(RFC_9110.Framing.Error) -> ChunkedScan? {
        var content: [Byte] = []
        var index = 0

        while true {

            guard let sizeLineEnd = Self.indexOfCRLF(buffer, from: index) else { return nil }
            let sizeLine = Array(buffer[index..<sizeLineEnd])

            let sizeToken: [Byte]
            if let semicolon = sizeLine.firstIndex(of: 0x3B) {
                sizeToken = Array(sizeLine[sizeLine.startIndex..<semicolon])
            } else {
                sizeToken = sizeLine
            }
            guard let size = Self.hexValue(sizeToken) else {
                throw .invalidChunkSize(Self.text(sizeLine))
            }
            index = sizeLineEnd + 2

            if size == 0 {

                var fields: [RFC_9110.Header.Field] = []
                while true {
                    if buffer.indices.contains(index + 1), buffer[index] == 0x0D,
                        buffer[index + 1] == 0x0A
                    {
                        index += 2
                        return ChunkedScan(
                            content: content,
                            octets: index,
                            trailers: RFC_9110.Headers(fields)
                        )
                    }
                    guard let lineEnd = Self.indexOfCRLF(buffer, from: index) else { return nil }
                    let line = Array(buffer[index..<lineEnd])
                    guard let colon = line.firstIndex(of: 0x3A) else {
                        throw .malformedChunk(Self.text(line))
                    }
                    let nameBytes = Array(line[line.startIndex..<colon])
                    guard Self.isFieldName(nameBytes) else {
                        throw .malformedChunk(Self.text(line))
                    }
                    let name = Self.text(nameBytes)
                    let value = Self.text(Array(line[line.index(after: colon)...]))
                        .trimming(.ascii.whitespaces)
                    do throws(RFC_9110.Header.Field.Error) {
                        fields.append(try RFC_9110.Header.Field(name: name, value: value))
                    } catch {
                        throw .malformedChunk(Self.text(line))
                    }
                    index = lineEnd + 2
                }
            }

            guard index + size + 2 <= buffer.count else { return nil }
            content.append(contentsOf: buffer[index..<(index + size)])
            if content.count > limit { throw .bodyTooLong(limit: limit) }
            guard buffer[index + size] == 0x0D, buffer[index + size + 1] == 0x0A else {
                throw .malformedChunk("missing CRLF after chunk data")
            }
            index += size + 2
        }
    }

    internal static func indexOfCRLF(_ buffer: borrowing [Byte], from: Int) -> Int? {
        var index = from
        while buffer.indices.contains(index + 1) {
            if buffer[index] == 0x0D, buffer[index + 1] == 0x0A { return index }
            index += 1
        }
        return nil
    }

    internal static func hexValue(_ bytes: [Byte]) -> Int? {
        let string = Self.text(bytes)
        guard !string.isEmpty, string.utf8.allSatisfy(Self.isHexDigit) else { return nil }
        return Int(string, radix: 16)
    }

    private static func isHexDigit(_ byte: UInt8) -> Bool {
        switch byte {
        case 0x30...0x39, 0x41...0x46, 0x61...0x66: true
        default: false
        }
    }
}
