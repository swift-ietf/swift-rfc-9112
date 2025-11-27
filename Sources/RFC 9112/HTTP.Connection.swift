// HTTP.Connection.swift
// swift-rfc-9112
//
// RFC 9112 Section 9.6: Connection
// https://www.rfc-editor.org/rfc/rfc9112.html#section-9.6
//
// Connection header for HTTP/1.1 connection management


extension RFC_9110 {
    /// HTTP Connection header (RFC 9112 Section 9.6)
    ///
    /// The Connection header field allows the sender to indicate desired
    /// control options for the current connection.
    ///
    /// ## Example Usage
    ///
    /// ```swift
    /// // Close connection
    /// let conn = HTTP.Connection.close
    /// print(conn.headerValue)  // "close"
    ///
    /// // Keep alive
    /// let conn2 = HTTP.Connection.keepAlive
    /// print(conn2.headerValue)  // "keep-alive"
    ///
    /// // Multiple options
    /// let conn3 = HTTP.Connection.options(["close", "custom"])
    /// ```
    ///
    /// ## RFC 9112 Reference
    ///
    /// From RFC 9112 Section 9.6:
    /// ```
    /// Connection = #connection-option
    /// connection-option = token
    /// ```
    ///
    /// ## Important Notes
    ///
    /// - "close" signals that the connection will not persist after current response
    /// - HTTP/1.1 defaults to persistent connections
    /// - HTTP/1.0 requires explicit "keep-alive" for persistence
    ///
    /// ## Reference
    ///
    /// - [RFC 9112 Section 9.6: Connection](https://www.rfc-editor.org/rfc/rfc9112.html#section-9.6)
    public struct Connection: Sendable, Equatable, Hashable {
        /// Connection options
        public let options: Set<String>

        /// Creates a Connection header with specified options
        ///
        /// - Parameter options: Set of connection option tokens
        public init(options: Set<String>) {
            self.options = Set(options.map { $0.lowercased() })
        }

        /// Connection: close
        ///
        /// Signals that the connection will be closed after the current response.
        ///
        /// ## Example
        ///
        /// ```swift
        /// let conn = HTTP.Connection.close
        /// print(conn.headerValue)  // "close"
        /// ```
        public static let close = Connection(options: ["close"])

        /// Connection: keep-alive
        ///
        /// Signals that the connection should persist (primarily for HTTP/1.0).
        ///
        /// ## Example
        ///
        /// ```swift
        /// let conn = HTTP.Connection.keepAlive
        /// print(conn.headerValue)  // "keep-alive"
        /// ```
        public static let keepAlive = Connection(options: ["keep-alive"])

        /// The header value representation
        ///
        /// - Returns: The Connection value formatted for HTTP headers
        ///
        /// ## Example
        ///
        /// ```swift
        /// Connection.close.headerValue  // "close"
        /// Connection(options: ["close", "custom"]).headerValue  // "close, custom"
        /// ```
        public var headerValue: String {
            options.sorted().joined(separator: ", ")
        }

        /// Parses a Connection header value
        ///
        /// - Parameter headerValue: The Connection header value to parse
        /// - Returns: A Connection if parsing succeeds, nil otherwise
        ///
        /// ## Example
        ///
        /// ```swift
        /// Connection.parse("close")  // Connection.close
        /// Connection.parse("keep-alive")  // Connection.keepAlive
        /// Connection.parse("close, custom")  // Connection(options: ["close", "custom"])
        /// ```
        public static func parse(_ headerValue: String) -> Connection? {
            let opts = headerValue
                .components(separatedBy: ",")
                .map { $0.trimming(.ascii.whitespaces).lowercased() }
                .filter { !$0.isEmpty }

            guard !opts.isEmpty else {
                return nil
            }

            return Connection(options: Set(opts))
        }

        /// Returns true if "close" option is present
        ///
        /// ## Example
        ///
        /// ```swift
        /// Connection.close.hasClose  // true
        /// Connection.keepAlive.hasClose  // false
        /// ```
        public var hasClose: Bool {
            options.contains("close")
        }

        /// Returns true if "keep-alive" option is present
        ///
        /// ## Example
        ///
        /// ```swift
        /// Connection.keepAlive.hasKeepAlive  // true
        /// Connection.close.hasKeepAlive  // false
        /// ```
        public var hasKeepAlive: Bool {
            options.contains("keep-alive")
        }

        /// Returns true if connection should persist
        ///
        /// For HTTP/1.1: defaults to true unless "close" is present
        /// For HTTP/1.0: defaults to false unless "keep-alive" is present
        ///
        /// - Parameter version: HTTP version (defaults to HTTP/1.1)
        /// - Returns: True if connection should persist
        ///
        /// ## Example
        ///
        /// ```swift
        /// Connection.close.shouldPersist()  // false
        /// Connection.keepAlive.shouldPersist()  // true
        /// Connection(options: []).shouldPersist()  // true (HTTP/1.1 default)
        /// ```
        public func shouldPersist(version: String = "HTTP/1.1") -> Bool {
            if hasClose {
                return false
            }

            if version.hasPrefix("HTTP/1.1") {
                return true
            }

            if version.hasPrefix("HTTP/1.0") {
                return hasKeepAlive
            }

            return false
        }
    }
}

// MARK: - CustomStringConvertible

extension RFC_9110.Connection: CustomStringConvertible {
    public var description: String {
        headerValue
    }
}

// MARK: - Codable

extension RFC_9110.Connection: Codable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)

        guard let parsed = Self.parse(string) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid Connection: \(string)"
            )
        }

        self = parsed
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(headerValue)
    }
}

// MARK: - LosslessStringConvertible

extension RFC_9110.Connection: LosslessStringConvertible {
    /// Creates a Connection from a string description
    ///
    /// - Parameter description: The Connection string
    /// - Returns: A Connection instance, or nil if parsing fails
    ///
    /// # Example
    ///
    /// ```swift
    /// let conn = HTTP.Connection("close")
    /// let str = String(conn!)  // Round-trip
    /// ```
    public init?(_ description: String) {
        guard let parsed = Self.parse(description) else { return nil }
        self = parsed
    }
}

// MARK: - ExpressibleByStringLiteral

extension RFC_9110.Connection: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = Self.parse(value) ?? RFC_9110.Connection(options: [value])
    }
}
