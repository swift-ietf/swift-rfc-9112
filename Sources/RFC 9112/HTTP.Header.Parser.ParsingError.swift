// HTTP.Header.Parser.ParsingError.swift
// swift-rfc-9112

extension RFC_9110.Header.Parser {
    public enum ParsingError: Swift.Error, Sendable, Equatable {
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
