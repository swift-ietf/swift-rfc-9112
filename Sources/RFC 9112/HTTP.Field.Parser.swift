public import Byte
import Byte_Standard_Library_Integration
import INCITS_4_1986
import Standard_Library_Extensions

extension RFC_9112.Field {
    public enum Parser {}
}

extension RFC_9112.Field.Parser {

    public static func parseFieldLine(
        _ line: String
    ) throws(Error) -> (name: String, value: String) {

        guard let colonIndex = line.firstIndex(of: ":") else {
            throw Error.missingColon
        }

        let nameEndIndex = colonIndex
        let fieldName = String(line[..<nameEndIndex])

        guard !fieldName.isEmpty else {
            throw Error.emptyFieldName
        }

        guard !fieldName.hasSuffix(" ") && !fieldName.hasSuffix("\t") else {
            throw Error.whitespaceBeforeColon
        }

        guard fieldName.allSatisfy({ $0.isASCII && !$0.isWhitespace && !isSeparator($0) })
        else {
            throw Error.invalidFieldName(fieldName)
        }

        let valueStartIndex = line.index(after: colonIndex)
        var fieldValue = String(line[valueStartIndex...])

        fieldValue = fieldValue.trimming(.ascii.whitespaces)

        try validateFieldValue(fieldValue)

        return (name: fieldName, value: fieldValue)
    }

    public static func parseFieldLine(
        _ data: [Byte]
    ) throws(Error) -> (name: String, value: String) {
        let string = String(decoding: data, as: UTF8.self)
        return try parseFieldLine(string)
    }

    public static func parseFieldLines(
        _ lines: [String]
    ) throws(Error) -> [(name: String, value: String)] {
        var fields: [(name: String, value: String)] = []
        var currentName: String?
        var currentValue = ""

        for (index, line) in lines.enumerated() {

            if line.first?.isWhitespace == true {

                guard currentName != nil else {
                    throw Error.obsFoldWithoutPrecedingField(lineNumber: index + 1)
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

    private static func validateFieldValue(_ value: String) throws(Error) {
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

            throw Error.invalidFieldValueChar(Character(UnicodeScalar(byte)))
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
        policy: RFC_9112.Field.Parser.ObsFold.Policy = .reject
    ) throws(Error) -> [(name: String, value: String)] {
        switch policy {
        case .reject:

            return try parseFieldLines(lines)

        case .space:

            return try parseFieldLines(lines)

        case .discard:

            let filtered = lines.filter { !($0.first?.isWhitespace ?? false) }
            return try parseFieldLines(filtered)
        }
    }

}
