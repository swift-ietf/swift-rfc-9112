// HTTP.MessageParser.Line.swift
// swift-rfc-9112

public import Byte_Primitives

extension RFC_9110.MessageParser {
    /// A parsed line from an HTTP message
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
    /// Get the line content as a string
    public var string: String {
        String(decoding: content, as: UTF8.self)
    }

    /// Check if line is empty (blank line)
    public var isEmpty: Bool {
        content.isEmpty
    }
}
