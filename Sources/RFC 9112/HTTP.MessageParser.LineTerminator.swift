extension RFC_9110.MessageParser {

    public enum LineTerminator: Sendable, Equatable {
        case crlf
        case lf
        case none
    }
}
