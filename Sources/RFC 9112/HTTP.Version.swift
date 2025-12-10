// HTTP.Version.swift
// swift-rfc-9112

extension RFC_9110 {
    /// HTTP version in request/response line
    /// RFC 9112 Section 2.3: HTTP-version = HTTP-name "/" DIGIT "." DIGIT
    public struct Version: Sendable, Equatable, Hashable {
        public let major: Int
        public let minor: Int

        public init(major: Int, minor: Int) {
            self.major = major
            self.minor = minor
        }

        /// HTTP/1.0
        public static let http10 = Version(major: 1, minor: 0)

        /// HTTP/1.1
        public static let http11 = Version(major: 1, minor: 1)

        // MARK: - Parsing

        /// Parse HTTP version from string
        /// RFC 9112 Section 2.3: "HTTP-name is case-sensitive"
        public static func parse(_ string: String) throws -> Version {
            // Expected format: HTTP/1.1
            let parts = string.split(separator: "/")
            guard parts.count == 2 else {
                throw ParsingError.invalidFormat(reason: "Expected format HTTP/M.m")
            }

            // Validate HTTP-name (case-sensitive)
            guard parts[0] == "HTTP" else {
                throw ParsingError.invalidHTTPName(String(parts[0]))
            }

            // Parse version numbers
            let versionParts = parts[1].split(separator: ".")
            guard versionParts.count == 2 else {
                throw ParsingError.invalidFormat(reason: "Expected format M.m")
            }

            guard let major = Int(versionParts[0]),
                let minor = Int(versionParts[1])
            else {
                throw ParsingError.invalidVersionNumber
            }

            return Version(major: major, minor: minor)
        }

        // MARK: - Formatting

        /// Format version as string (e.g., "HTTP/1.1")
        public var formatted: String {
            "HTTP/\(major).\(minor)"
        }

        // MARK: - Comparisons

        /// Check if this version is HTTP/1.1
        public var isHTTP11: Bool {
            self == .http11
        }

        /// Check if this version is HTTP/1.0
        public var isHTTP10: Bool {
            self == .http10
        }

        /// Check if version is at least HTTP/1.1
        public var isHTTP11OrHigher: Bool {
            major > 1 || (major == 1 && minor >= 1)
        }

        // MARK: - Errors

        public enum ParsingError: Error, Sendable, Equatable {
            case invalidFormat(reason: String)
            case invalidHTTPName(String)
            case invalidVersionNumber
        }
    }
}
