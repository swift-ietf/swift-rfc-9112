// HTTP.Request.Line.swift
// swift-rfc-9112

public 
extension RFC_9110.Request {
    /// HTTP/1.1 request-line parser implementing RFC 9112 Section 3
    /// Format: method SP request-target SP HTTP-version CRLF
    public struct Line: Sendable, Equatable {
        public let method: RFC_9110.Method
        public let target: String  // Raw target before parsing into Target type
        public let version: RFC_9110.Version

        public init(method: RFC_9110.Method, target: String, version: RFC_9110.Version) {
            self.method = method
            self.target = target
            self.version = version
        }

        // MARK: - Parsing

        /// Parse request-line from string
        /// RFC 9112 Section 3: "request-line = method SP request-target SP HTTP-version"
        public static func parse(_ line: String) throws -> Line {
            // Find first space (after method)
            guard let firstSpace = line.firstIndex(of: " ") else {
                throw ParsingError.invalidFormat(reason: "Missing space after method")
            }

            // Parse method
            let methodString = String(line[..<firstSpace])
            guard !methodString.isEmpty else {
                throw ParsingError.emptyMethod
            }
            // RFC 9112 Section 3.1: "The method token is case-sensitive"
            let method = RFC_9110.Method(rawValue: methodString)

            // Find where version starts (should be " HTTP/")
            let afterMethod = line.index(after: firstSpace)
            guard let httpRange = line.range(of: " HTTP/", options: .backwards) else {
                throw ParsingError.invalidFormat(reason: "Missing HTTP version")
            }

            // Parse target (everything between method and version)
            let targetString = String(line[afterMethod..<httpRange.lowerBound])
            guard !targetString.isEmpty else {
                throw ParsingError.emptyTarget
            }
            // Validate target doesn't contain whitespace
            guard !targetString.contains(where: \.isWhitespace) else {
                throw ParsingError.targetContainsWhitespace
            }

            // Parse version (everything after the space before HTTP/)
            let versionString = String(line[line.index(after: httpRange.lowerBound)...])
            let version = try RFC_9110.Version.parse(versionString)

            return Line(method: method, target: targetString, version: version)
        }

        /// Parse request-line from data
        public static func parse(_ data: Data) throws -> Line {
            guard let string = String(data: data, encoding: .utf8) else {
                throw ParsingError.invalidEncoding
            }
            return try parse(string)
        }

        // MARK: - Formatting

        /// Format request-line as string
        public var formatted: String {
            "\(method.rawValue) \(target) \(version.formatted)"
        }

        // MARK: - Validation

        /// Validate the request-line components
        /// RFC 9112 Section 3: Servers SHOULD be able to handle at least 8000 octets
        public func validate(maxLength: Int = 8000) throws {
            let formattedLength = formatted.utf8.count
            guard formattedLength <= maxLength else {
                throw ValidationError.lineTooLong(length: formattedLength, max: maxLength)
            }

            // Validate method is known or server can handle it
            // RFC 9112 Section 3.1: "A server that receives a method longer than any that it implements
            // SHOULD respond with a 501 (Not Implemented) status code"
            // Note: This is advisory - library consumers decide

            // Validate target form matches method constraints
            // RFC 9112 Section 3.2: CONNECT must use authority-form
            // This validation happens when parsing target into Target type
        }

        // MARK: - Errors

        public enum ParsingError: Error, Sendable, Equatable {
            case invalidFormat(reason: String)
            case emptyMethod
            case emptyTarget
            case targetContainsWhitespace
            case invalidEncoding
            case invalidVersion(String)
        }

        public enum ValidationError: Error, Sendable, Equatable {
            case lineTooLong(length: Int, max: Int)
        }
    }
}
