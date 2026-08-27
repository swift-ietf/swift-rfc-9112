public import Byte_Primitives

extension RFC_9112.Message.Parser {
    public enum Error: Swift.Error, Equatable {
        case bareCR(lineNumber: Int)
        case invalidCharacter(lineNumber: Int, byte: Byte)
        case lineTooLong(lineNumber: Int, length: Int)
        case unexpectedWhitespace(lineNumber: Int)
    }
}
