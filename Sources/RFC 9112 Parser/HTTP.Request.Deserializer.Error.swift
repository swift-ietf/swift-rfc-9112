public import RFC_9112
public import RFC_9110

extension RFC_9112.Request.Deserializer {
    public enum Error: Swift.Error {
        case emptyMessage
        case missingHeaderBodySeparator
        case invalidEncoding
        case invalidTarget(String)
        case incompleteBody(expected: Int, available: Int)
        case messageParsing(RFC_9112.Message.Parser.Error)
        case requestLine(RFC_9112.Request.Line.Error)
        case headerParsing(RFC_9112.Field.Parser.Error)
        case headerValidation(RFC_9110.Field.Error)
        case chunkedDecoding(RFC_9112.Transfer.Coding.Chunked.Error)
    }
}
