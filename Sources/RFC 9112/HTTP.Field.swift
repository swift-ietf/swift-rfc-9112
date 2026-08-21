public import Byte_Primitives
import INCITS_4_1986
import Standard_Library_Extensions

extension RFC_9110.Header {

    public enum Parser {}
}

extension RFC_9110.Header.Parser {

    public static func parseFieldLine(
        _ line: String
    ) throws(ParsingError) -> (name: String, value: String) {

        guard let colonIndex = line.firstIndex(of: ":") else {
            throw ParsingError.missingColon
        }

        let nameEndIndex = colonIndex
        let fieldName = String(line[..<nameEndIndex])

        guard !fieldName.isEmpty else {
            throw ParsingError.emptyFieldName
        }

        guard !fieldName.hasSuffix(" ") && !fieldName.hasSuffix("\t") else {
            throw ParsingError.whitespaceBeforeColon
        }

        guard fieldName.allSatisfy({ $0.isASCII && !$0.isWhitespace && !isSeparator($0) })
        else {
            throw ParsingError.invalidFieldName(fieldName)
        }

        let valueStartIndex = line.index(after: colonIndex)
        var fieldValue = String(line[valueStartIndex...])

        fieldValue = fieldValue.trimming(.ascii.whitespaces)

        try validateFieldValue(fieldValue)

        return (name: fieldName, value: fieldValue)
    }

    public static func parseFieldLine(
        _ data: [Byte]
    ) throws(ParsingError) -> (name: String, value: String) {
        let string = String(decoding: data, as: UTF8.self)
        return try parseFieldLine(string)
    }

    public static func parseFieldLines(
        _ lines: [String]
    ) throws(ParsingError) -> [(name: String, value: String)] {
        var fields: [(name: String, value: String)] = []
        var currentName: String?
        var currentValue = ""

        for (index, line) in lines.enumerated() {

            if line.first?.isWhitespace == true {

                guard currentName != nil else {
                    throw ParsingError.obsFoldWithoutPrecedingField(lineNumber: index + 1)
                }

                currentValue += " " + line.trimming(.ascii.whitespaces)

            } else {

                if let name = currentName {
                    fields.append((name: name, value: currentValue))
                }

                let parsed = try parseFieldLine(line)
                currentName = parsed.name
                currentValue = parsed.value
            }
        }

        if let name = currentName {
            fields.append((name: name, value: currentValue))
        }

        return fields
    }

    private static func validateFieldValue(_ value: String) throws(ParsingError) {
        for byte in value.utf8 {

            if byte >= 0x21 && byte <= 0x7E {
                continue
            }

            if byte == 0x20 || byte == 0x09 {
                continue
            }

            if byte >= 0x80 {
                continue
            }

            throw ParsingError.invalidFieldValueChar(Character(UnicodeScalar(byte)))
        }
    }

    private static func isSeparator(_ char: Character) -> Bool {
        switch char {
        case "(", ")", "<", ">", "@", ",", ";", ":", "\\", "\"", "/",
            "[", "]", "?", "=", "{", "}", " ", "\t":
            return true

        default:
            return false
        }
    }

    public static func parseFieldLines(
        _ lines: [String],
        obsFoldPolicy: ObsFoldPolicy = .reject
    ) throws(ParsingError) -> [(name: String, value: String)] {
        switch obsFoldPolicy {
        case .reject:

            return try parseFieldLines(lines)

        case .replaceWithSpace:

            return try parseFieldLines(lines)

        case .discard:

            let filtered = lines.filter { !($0.first?.isWhitespace ?? false) }
            return try parseFieldLines(filtered)
        }
    }

}
