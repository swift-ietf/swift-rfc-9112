public import Byte_Primitives

extension RFC_9110.MessageParser {

    public struct Line: Sendable, Equatable {
        public let content: [Byte]
        public let terminator: LineTerminator
        public let lineNumber: Int

        public init(content: [Byte], terminator: LineTerminator, lineNumber: Int) {
            self.content = content
            self.terminator = terminator
            self.lineNumber = lineNumber
        }
    }
}

extension RFC_9110.MessageParser.Line {

    public var string: String {
        String(decoding: content, as: UTF8.self)
    }

    public var isEmpty: Bool {
        content.isEmpty
    }
}
