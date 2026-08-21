public import Byte_Primitives
import Standard_Library_Extensions

extension RFC_9110 {

    public enum MessageParser {}
}

extension RFC_9110.MessageParser {

    public static func parseLines(from data: [Byte]) throws(ParsingError) -> [Line] {
        var lines: [Line] = []
        var currentIndex = data.startIndex
        var lineNumber = 1

        while currentIndex < data.endIndex {
            guard
                let line = try parseLine(
                    from: data,
                    startingAt: &currentIndex,
                    lineNumber: lineNumber
                )
            else {
                break
            }
            lines.append(line)
            lineNumber += 1
        }

        return lines
    }

    private static func parseLine(
        from data: [Byte],
        startingAt index: inout Array<Byte>.Index,
        lineNumber: Int
    ) throws(ParsingError) -> Line? {
        guard index < data.endIndex else { return nil }

        var content = [Byte]()

        while index < data.endIndex {
            let byte = data[index]

            switch byte {
            case 0x0D:
                index = data.index(after: index)

                if index < data.endIndex && data[index] == 0x0A {

                    index = data.index(after: index)
                    return Line(content: content, terminator: .crlf, lineNumber: lineNumber)
                } else {

                    throw ParsingError.bareCR(lineNumber: lineNumber)
                }

            case 0x0A:

                index = data.index(after: index)
                return Line(content: content, terminator: .lf, lineNumber: lineNumber)

            default:
                content.append(byte)
                index = data.index(after: index)
            }
        }

        if !content.isEmpty {
            return Line(content: content, terminator: .none, lineNumber: lineNumber)
        }

        return nil
    }

    public static func findHeaderBodySeparator(in lines: [Line]) -> Int? {
        for (index, line) in lines.enumerated() {
            if line.content.isEmpty {
                return index
            }
        }
        return nil
    }

}
