// HTTP.MessageParser.ParsingError.swift
// swift-rfc-9112

public import Byte_Primitives

extension RFC_9110.MessageParser {
    public enum ParsingError: Swift.Error, Sendable, Equatable {
        case bareCR(lineNumber: Int)
        case invalidCharacter(lineNumber: Int, byte: Byte)
        case lineTooLong(lineNumber: Int, length: Int)
        case unexpectedWhitespace(lineNumber: Int)
    }
}
