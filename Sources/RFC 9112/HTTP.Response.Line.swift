// HTTP.Response.Line.swift
// swift-rfc-9112

extension RFC_9110.Response {
    /// HTTP/1.1 status-line parser implementing RFC 9112 Section 4
    /// Format: HTTP-version SP status-code SP [ reason-phrase ]
    public struct Line: Sendable, Equatable {
        public let version: RFC_9110.Version
        public let statusCode: Int
        public let reasonPhrase: String?

        public init(version: RFC_9110.Version, statusCode: Int, reasonPhrase: String? = nil) {
            self.version = version
            self.statusCode = statusCode
            self.reasonPhrase = reasonPhrase
        }

        // MARK: - Parsing

        /// Parse status-line from string
        /// RFC 9112 Section 4: "status-line = HTTP-version SP status-code SP [ reason-phrase ]"
        /// RFC 9112: "the space that separates the status-code from the reason-phrase is required
        /// even if the reason-phrase is absent"
        public static func parse(_ line: String) throws -> Line {
            // Split into version and rest
            let components = line.split(
                separator: " ",
                maxSplits: 2,
                omittingEmptySubsequences: false
            )

            guard components.count >= 2 else {
                throw ParsingError.invalidFormat(
                    reason: "Expected at least version and status code"
                )
            }

            // Parse version
            let versionString = String(components[0])
            let version = try RFC_9110.Version.parse(versionString)

            // Parse status code
            let statusString = String(components[1])
            guard let statusCode = Int(statusString), statusString.count == 3 else {
                throw ParsingError.invalidStatusCode(statusString)
            }

            // RFC 9112 Section 4: status-code must be 3 digits
            guard statusCode >= 100 && statusCode <= 999 else {
                throw ParsingError.statusCodeOutOfRange(statusCode)
            }

            // Parse reason phrase (optional)
            // RFC 9112: "Clients SHOULD ignore the reason-phrase content because it is not a reliable channel"
            var reasonPhrase: String?
            if components.count == 3 {
                let phrase = String(components[2])
                reasonPhrase = phrase.isEmpty ? nil : phrase
            }

            return Line(version: version, statusCode: statusCode, reasonPhrase: reasonPhrase)
        }

        /// Parse status-line from data
        public static func parse(_ data: [UInt8]) throws -> Line {
            fatalError("Not implemented")
            //            guard let string = String(data: data, encoding: .utf8) else {
            //                throw ParsingError.invalidEncoding
            //            }
            //            return try parse(string)
        }

        // MARK: - Formatting

        /// Format status-line as string
        /// RFC 9112 Section 4: "the space that separates the status-code from the reason-phrase
        /// is required even if the reason-phrase is absent"
        public var formatted: String {
            if let reason = reasonPhrase {
                return "\(version.formatted) \(statusCode) \(reason)"
            } else {
                return "\(version.formatted) \(statusCode) "
            }
        }

        // MARK: - Convenience

        /// Get the status as RFC_9110.Status if it's a known status code
        public var status: RFC_9110.Status? {
            RFC_9110.Status.from(code: statusCode)
        }

        /// Create from RFC_9110.Status
        public init(version: RFC_9110.Version, status: RFC_9110.Status, reasonPhrase: String? = nil) {
            self.version = version
            self.statusCode = status.code
            self.reasonPhrase = reasonPhrase ?? status.reasonPhrase
        }

        // MARK: - Errors

        public enum ParsingError: Error, Sendable, Equatable {
            case invalidFormat(reason: String)
            case invalidStatusCode(String)
            case statusCodeOutOfRange(Int)
            case invalidEncoding
        }
    }
}

extension RFC_9110.Status {
    /// Get Status from status code if known
    internal static func from(code: Int) -> RFC_9110.Status? {
        // Check if it's a known status
        // This is a helper that can be used but isn't required
        // Since Status has init(_ code: Int), we can always create one
        return RFC_9110.Status(code)
    }
}
