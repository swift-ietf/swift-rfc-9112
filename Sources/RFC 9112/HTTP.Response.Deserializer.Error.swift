extension RFC_9110.Response.Deserializer {
    public enum Error: Swift.Error, Sendable {
        case emptyMessage
        case missingHeaderBodySeparator
        case invalidEncoding
        case incompleteBody(expected: Int, available: Int)
        case messageParsing(RFC_9110.MessageParser.ParsingError)
        case responseLine(RFC_9110.Response.Line.ParsingError)
        case headerParsing(RFC_9110.Header.Parser.ParsingError)
        case headerValidation(RFC_9110.Header.Field.Error)
        case chunkedDecoding(RFC_9110.ChunkedEncoding.ChunkedDecodingError)
    }
}
