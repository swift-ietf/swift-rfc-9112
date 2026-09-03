public import RFC_9112
extension RFC_9112.Message.Parser.Line {
    public enum Terminator: Equatable {
        case crlf
        case lf
        case none
    }
}
