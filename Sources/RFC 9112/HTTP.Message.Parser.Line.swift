public import Byte_Primitives
import Byte_Primitives_Standard_Library_Integration

extension RFC_9112.Message.Parser {

    public struct Line: Equatable {
        public let content: [Byte]
        public let terminator: Terminator
        public let lineNumber: Int

        public init(content: [Byte], terminator: Terminator, lineNumber: Int) {
            self.content = content
            self.terminator = terminator
            self.lineNumber = lineNumber
        }
    }
}

extension RFC_9112.Message.Parser.Line {

    public var string: String {
        String(decoding: content, as: UTF8.self)
    }

    public var isEmpty: Bool {
        content.isEmpty
    }
}
