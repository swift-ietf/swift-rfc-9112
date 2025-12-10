// HTTP.Message.Parser.swift
// swift-rfc-9112

import Standards

extension RFC_9110 {
    /// HTTP/1.1 message parser implementing RFC 9112 Section 2
    public enum MessageParser {

        // MARK: - Line Parsing

        /// Parse lines from HTTP message data
        /// RFC 9112 Section 2.2: "Each line ending with CRLF"
        /// Robustness: "A recipient that receives whitespace between the start-line and the first header field
        /// MUST either reject the message as invalid or consume each whitespace-preceded line without further processing"
        public static func parseLines(from data: [UInt8]) throws -> [Line] {
            var lines: [Line] = []
            var currentIndex = data.startIndex
            var lineNumber = 1

            while currentIndex < data.endIndex {
                guard
                    let line = try parseLine(
                        from: data,
                        startingAt: &currentIndex,
                        lineNumber: lineNumber
                    )
                else {
                    break
                }
                lines.append(line)
                lineNumber += 1
            }

            return lines
        }

        /// Parse a single line from data
        /// RFC 9112 Section 2.2: "HTTP/1.1 defines the sequence CR LF as the end-of-line marker"
        /// "A recipient MAY recognize a single LF as a line terminator and ignore any preceding CR"
        /// "A sender MUST NOT generate a bare CR"
        private static func parseLine(
            from data: [UInt8],
            startingAt index: inout Array<UInt8>.Index,
            lineNumber: Int
        ) throws -> Line? {
            guard index < data.endIndex else { return nil }

            let startIndex = index
            var content = [UInt8]()
            var foundCR = false

            while index < data.endIndex {
                let byte = data[index]

                switch byte {
                case 0x0D:  // CR
                    foundCR = true
                    index = data.index(after: index)

                    // Check if followed by LF
                    if index < data.endIndex && data[index] == 0x0A {
                        // CRLF - proper line ending
                        index = data.index(after: index)
                        return Line(content: content, terminator: .crlf, lineNumber: lineNumber)
                    } else {
                        // Bare CR - RFC 9112 Section 11.1: "reject or strip bare CR"
                        throw ParsingError.bareCR(lineNumber: lineNumber)
                    }

                case 0x0A:  // LF
                    // LF without CR - RFC 9112: "MAY recognize a single LF"
                    index = data.index(after: index)
                    return Line(content: content, terminator: .lf, lineNumber: lineNumber)

                default:
                    content.append(byte)
                    index = data.index(after: index)
                }
            }

            // Reached end without line terminator
            if !content.isEmpty {
                return Line(content: content, terminator: .none, lineNumber: lineNumber)
            }

            return nil
        }

        /// Find the blank line that separates headers from body
        /// RFC 9112 Section 2: "an empty line indicating the end of the header section"
        public static func findHeaderBodySeparator(in lines: [Line]) -> Int? {
            for (index, line) in lines.enumerated() {
                if line.content.isEmpty {
                    return index
                }
            }
            return nil
        }

        // MARK: - Types

        /// A parsed line from an HTTP message
        public struct Line: Sendable, Equatable {
            public let content: [UInt8]
            public let terminator: LineTerminator
            public let lineNumber: Int

            public init(content: [UInt8], terminator: LineTerminator, lineNumber: Int) {
                self.content = content
                self.terminator = terminator
                self.lineNumber = lineNumber
            }

            /// Get the line content as a string
            public var string: String {
                String(decoding: content, as: UTF8.self)
            }

            /// Check if line is empty (blank line)
            public var isEmpty: Bool {
                content.isEmpty
            }
        }

        /// Line terminator types
        public enum LineTerminator: Sendable, Equatable {
            case crlf  // Standard: CR LF (0x0D 0x0A)
            case lf  // Lenient: Single LF (0x0A)
            case none  // No terminator (end of data)
        }

        // MARK: - Errors

        public enum ParsingError: Error, Sendable, Equatable {
            case bareCR(lineNumber: Int)
            case invalidCharacter(lineNumber: Int, byte: UInt8)
            case lineTooLong(lineNumber: Int, length: Int)
            case unexpectedWhitespace(lineNumber: Int)
        }
    }
}
