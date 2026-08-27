extension RFC_9112.Field.Parser {
    public enum Error: Swift.Error, Equatable {
        case missingColon
        case emptyFieldName
        case whitespaceBeforeColon
        case invalidFieldName(String)
        case invalidFieldValueChar(Character)
        case invalidEncoding
        case obsFoldWithoutPrecedingField(lineNumber: Int)
        case invalidFieldLine(lineNumber: Int)
    }
}
