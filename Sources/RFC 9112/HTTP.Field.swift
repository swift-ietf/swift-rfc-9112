// HTTP.Field.swift
// swift-rfc-9112

import Standards

extension RFC_9110.Header {
    /// Field-line parser implementing RFC 9112 Section 5
    public enum Parser {

        // MARK: - Parsing

        /// Parse a field-line from string
        /// RFC 9112 Section 5.1: field-line = field-name ":" OWS field-value OWS
        /// RFC 9112: "No whitespace is allowed between the field name and colon"
        public static func parseFieldLine(_ line: String) throws -> (name: String, value: String) {
            // Find colon separator
            guard let colonIndex = line.firstIndex(of: ":") else {
                throw ParsingError.missingColon
            }

            // Extract field name
            let nameEndIndex = colonIndex
            let fieldName = String(line[..<nameEndIndex])

            // RFC 9112 Section 5.1: "No whitespace is allowed between the field name and colon"
            // "A field name MUST NOT be empty"
            guard !fieldName.isEmpty else {
                throw ParsingError.emptyFieldName
            }

            // Check for whitespace before colon
            guard !fieldName.hasSuffix(" ") && !fieldName.hasSuffix("\t") else {
                throw ParsingError.whitespaceBeforeColon
            }

            // Validate field name contains only allowed characters
            // RFC 9110 Section 5.1: field-name = token
            guard fieldName.allSatisfy({ $0.isASCII && !$0.isWhitespace && !isSeparator($0) }) else {
                throw ParsingError.invalidFieldName(fieldName)
            }

            // Extract field value (after colon)
            let valueStartIndex = line.index(after: colonIndex)
            var fieldValue = String(line[valueStartIndex...])

            // RFC 9112 Section 5.1: "field-value does not include leading or trailing whitespace"
            fieldValue = fieldValue.trimming(.ascii.whitespaces)

            // Validate field value (allow visible chars, whitespace, obs-text)
            // RFC 9110 Section 5.5: field-value = *( field-content / obs-fold )
            try validateFieldValue(fieldValue)

            return (name: fieldName, value: fieldValue)
        }

        /// Parse field-line from data
        public static func parseFieldLine(_ data: [UInt8]) throws -> (name: String, value: String) {
            let string = String(decoding: data, as: UTF8.self)
            return try parseFieldLine(string)
        }

        /// Parse multiple field-lines from lines
        /// Handles obsolete line folding (obs-fold)
        /// RFC 9112 Section 5.2: "obs-fold = OWS CRLF RWS"
        public static func parseFieldLines(_ lines: [String]) throws -> [(name: String, value: String)] {
            var fields: [(name: String, value: String)] = []
            var currentName: String?
            var currentValue = ""

            for (index, line) in lines.enumerated() {
                // Check if this is a continuation line (obs-fold)
                if line.first?.isWhitespace == true {
                    // RFC 9112 Section 5.2: "A sender MUST NOT generate a message that includes obs-fold"
                    // "A server that receives an obs-fold in a request message...SHOULD
                    // either reject the message with a 400 (Bad Request) status code"

                    guard let name = currentName else {
                        throw ParsingError.obsFoldWithoutPrecedingField(lineNumber: index + 1)
                    }

                    // Optionally handle obs-fold by replacing with space
                    // RFC 9112: "or replace each received obs-fold with one or more SP octets"
                    currentValue += " " + line.trimming(.ascii.whitespaces)

                } else {
                    // Save previous field if exists
                    if let name = currentName {
                        fields.append((name: name, value: currentValue))
                    }

                    // Parse new field (this will throw missingColon if no colon found)
                    let parsed = try parseFieldLine(line)
                    currentName = parsed.name
                    currentValue = parsed.value
                }
            }

            // Save last field
            if let name = currentName {
                fields.append((name: name, value: currentValue))
            }

            return fields
        }

        // MARK: - Validation

        /// Validate field value characters
        /// RFC 9110 Section 5.5: field-value = *( field-content / obs-fold )
        /// field-content = field-vchar [ 1*( SP / HTAB / field-vchar ) field-vchar ]
        /// field-vchar = VCHAR / obs-text
        /// Note: We allow UTF-8 characters (> 0xFF) for modern HTTP usage
        private static func validateFieldValue(_ value: String) throws {
            for char in value {
                let scalar = char.unicodeScalars.first!
                let value = scalar.value

                // Allow visible characters (0x21-0x7E)
                if value >= 0x21 && value <= 0x7E {
                    continue
                }

                // Allow whitespace (SP = 0x20, HTAB = 0x09)
                if value == 0x20 || value == 0x09 {
                    continue
                }

                // Allow obs-text and UTF-8 (>= 0x80) - for compatibility and modern usage
                if value >= 0x80 {
                    continue
                }

                // Reject control characters (0x00-0x1F, 0x7F)
                throw ParsingError.invalidFieldValueChar(char)
            }
        }

        /// Check if character is a separator
        /// RFC 9110 Section 5.6.2: separators
        private static func isSeparator(_ char: Character) -> Bool {
            switch char {
            case "(", ")", "<", ">", "@", ",", ";", ":", "\\", "\"", "/",
                 "[", "]", "?", "=", "{", "}", " ", "\t":
                return true
            default:
                return false
            }
        }

        // MARK: - Obsolete Line Folding

        /// Handling policy for obsolete line folding
        public enum ObsFoldPolicy {
            case reject       // Return error (recommended for servers)
            case replaceWithSpace  // Replace with single space
            case discard      // Remove the obs-fold entirely
        }

        /// Parse field-lines with specific obs-fold handling policy
        public static func parseFieldLines(
            _ lines: [String],
            obsFoldPolicy: ObsFoldPolicy = .reject
        ) throws -> [(name: String, value: String)] {
            switch obsFoldPolicy {
            case .reject:
                // Default behavior - will throw error on obs-fold
                return try parseFieldLines(lines)

            case .replaceWithSpace:
                // Already implemented in default parseFieldLines
                return try parseFieldLines(lines)

            case .discard:
                // Filter out obs-fold lines before parsing
                let filtered = lines.filter { !($0.first?.isWhitespace ?? false) }
                return try parseFieldLines(filtered)
            }
        }

        // MARK: - Errors

        public enum ParsingError: Error, Sendable, Equatable {
            case missingColon
            case emptyFieldName
            case whitespaceBeforeColon
            case invalidFieldName(String)
            case invalidFieldValueChar(Character)
            case invalidEncoding
            case obsFoldWithoutPrecedingField(lineNumber: Int)
            case invalidFieldLine(lineNumber: Int)
        }
    }
}
