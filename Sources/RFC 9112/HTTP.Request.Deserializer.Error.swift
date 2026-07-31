// HTTP.Request.Deserializer.Error.swift
// swift-rfc-9112

extension RFC_9110.Request.Deserializer {
    public enum Error: Swift.Error, Sendable {
        case emptyMessage
        case missingHeaderBodySeparator
        case invalidEncoding
        case invalidTarget(String)
        case incompleteBody(expected: Int, available: Int)
        case messageParsing(RFC_9110.MessageParser.ParsingError)
        case requestLine(RFC_9110.Request.Line.ParsingError)
        case headerParsing(RFC_9110.Header.Parser.ParsingError)
        case headerValidation(RFC_9110.Header.Field.Error)
        case chunkedDecoding(RFC_9110.ChunkedEncoding.ChunkedDecodingError)
    }
}
