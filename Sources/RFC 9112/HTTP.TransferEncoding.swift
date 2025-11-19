// HTTP.TransferEncoding.swift
// swift-rfc-9112
//
// RFC 9112 Section 6: Transfer Codings
// https://www.rfc-editor.org/rfc/rfc9112.html#section-6
//
// Transfer codings for HTTP/1.1 message framing


extension RFC_9110 {
    /// HTTP Transfer-Encoding header (RFC 9112 Section 6)
    ///
    /// The Transfer-Encoding header field lists the transfer coding names
    /// corresponding to the sequence of transfer codings that have been
    /// applied to the payload body in order to form the message body.
    ///
    /// ## Example Usage
    ///
    /// ```swift
    /// // Chunked encoding
    /// let te = HTTP.TransferEncoding.chunked
    /// print(te.headerValue)  // "chunked"
    ///
    /// // Multiple encodings
    /// let te2 = HTTP.TransferEncoding.list([.gzip, .chunked])
    /// print(te2.headerValue)  // "gzip, chunked"
    ///
    /// // Parsing
    /// let parsed = HTTP.TransferEncoding.parse("chunked")
    /// // parsed == .chunked
    /// ```
    ///
    /// ## RFC 9112 Reference
    ///
    /// From RFC 9112 Section 6.1:
    /// ```
    /// Transfer-Encoding = #transfer-coding
    /// transfer-coding   = "chunked" / "compress" / "deflate" / "gzip"
    ///                   / transfer-extension
    /// ```
    ///
    /// ## Important Notes
    ///
    /// - chunked MUST NOT be applied more than once to a message body
    /// - chunked, when present, MUST be the final encoding
    /// - Transfer-Encoding takes precedence over Content-Length
    ///
    /// ## Reference
    ///
    /// - [RFC 9112 Section 6: Transfer Codings](https://www.rfc-editor.org/rfc/rfc9112.html#section-6)
    /// - [RFC 9112 Section 6.1: Chunked](https://www.rfc-editor.org/rfc/rfc9112.html#section-6.1)
    public enum TransferEncoding: Sendable, Equatable, Hashable {
        /// Chunked transfer coding
        case chunked

        /// Gzip compression
        case gzip

        /// Compress (LZW) compression
        case compress

        /// Deflate compression
        case deflate

        /// Custom/extension transfer coding
        case custom(String)

        /// Multiple transfer codings applied in sequence
        case list([TransferEncoding])

        /// The header value representation
        ///
        /// - Returns: The Transfer-Encoding value formatted for HTTP headers
        ///
        /// ## Example
        ///
        /// ```swift
        /// TransferEncoding.chunked.headerValue  // "chunked"
        /// TransferEncoding.list([.gzip, .chunked]).headerValue  // "gzip, chunked"
        /// ```
        public var headerValue: String {
            switch self {
            case .chunked:
                return "chunked"
            case .gzip:
                return "gzip"
            case .compress:
                return "compress"
            case .deflate:
                return "deflate"
            case .custom(let name):
                return name
            case .list(let encodings):
                return encodings.map { $0.headerValue }.joined(separator: ", ")
            }
        }

        /// Parses a Transfer-Encoding header value
        ///
        /// - Parameter headerValue: The Transfer-Encoding header value to parse
        /// - Returns: A TransferEncoding if parsing succeeds, nil otherwise
        ///
        /// ## Example
        ///
        /// ```swift
        /// TransferEncoding.parse("chunked")  // .chunked
        /// TransferEncoding.parse("gzip, chunked")  // .list([.gzip, .chunked])
        /// ```
        public static func parse(_ headerValue: String) -> TransferEncoding? {
            let encodings = headerValue
                .components(separatedBy: ",")
                .map { $0.trimming(.whitespaces).lowercased() }
                .filter { !$0.isEmpty }
                .compactMap { name -> TransferEncoding? in
                    switch name {
                    case "chunked":
                        return .chunked
                    case "gzip":
                        return .gzip
                    case "compress", "x-compress":
                        return .compress
                    case "deflate":
                        return .deflate
                    default:
                        return .custom(name)
                    }
                }

            guard !encodings.isEmpty else {
                return nil
            }

            if encodings.count == 1 {
                return encodings[0]
            }

            return .list(encodings)
        }

        /// Returns true if this is chunked encoding
        ///
        /// ## Example
        ///
        /// ```swift
        /// TransferEncoding.chunked.isChunked  // true
        /// TransferEncoding.gzip.isChunked  // false
        /// TransferEncoding.list([.gzip, .chunked]).isChunked  // false
        /// ```
        public var isChunked: Bool {
            if case .chunked = self {
                return true
            }
            return false
        }

        /// Returns true if chunked encoding is present (including in a list)
        ///
        /// ## Example
        ///
        /// ```swift
        /// TransferEncoding.chunked.hasChunked  // true
        /// TransferEncoding.list([.gzip, .chunked]).hasChunked  // true
        /// TransferEncoding.gzip.hasChunked  // false
        /// ```
        public var hasChunked: Bool {
            switch self {
            case .chunked:
                return true
            case .list(let encodings):
                return encodings.contains { $0.isChunked }
            default:
                return false
            }
        }

        /// Returns true if chunked is the final encoding (when in a list)
        ///
        /// Per RFC 9112, chunked MUST be the final encoding when present.
        ///
        /// ## Example
        ///
        /// ```swift
        /// TransferEncoding.chunked.isChunkedFinal  // true
        /// TransferEncoding.list([.gzip, .chunked]).isChunkedFinal  // true
        /// TransferEncoding.list([.chunked, .gzip]).isChunkedFinal  // false (invalid!)
        /// ```
        public var isChunkedFinal: Bool {
            switch self {
            case .chunked:
                return true
            case .list(let encodings):
                return encodings.last?.isChunked ?? false
            default:
                return false
            }
        }

        /// Count how many times chunked encoding appears
        ///
        /// Per RFC 9112, chunked MUST NOT be applied more than once.
        ///
        /// ## Example
        ///
        /// ```swift
        /// TransferEncoding.chunked.chunkedCount  // 1
        /// TransferEncoding.list([.gzip, .chunked]).chunkedCount  // 1
        /// TransferEncoding.list([.chunked, .chunked]).chunkedCount  // 2 (invalid!)
        /// ```
        public var chunkedCount: Int {
            switch self {
            case .chunked:
                return 1
            case .list(let encodings):
                return encodings.filter { $0.isChunked }.count
            default:
                return 0
            }
        }
    }
}

// MARK: - CustomStringConvertible

extension RFC_9110.TransferEncoding: CustomStringConvertible {
    public var description: String {
        headerValue
    }
}

// MARK: - Codable

extension RFC_9110.TransferEncoding: Codable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)

        guard let parsed = Self.parse(string) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid Transfer-Encoding: \(string)"
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

extension RFC_9110.TransferEncoding: LosslessStringConvertible {
    /// Creates a TransferEncoding from a string description
    ///
    /// - Parameter description: The Transfer-Encoding string
    /// - Returns: A TransferEncoding instance, or nil if parsing fails
    ///
    /// # Example
    ///
    /// ```swift
    /// let te = HTTP.TransferEncoding("chunked")
    /// let str = String(te!)  // Round-trip
    /// ```
    public init?(_ description: String) {
        guard let parsed = Self.parse(description) else { return nil }
        self = parsed
    }
}

// MARK: - ExpressibleByStringLiteral

extension RFC_9110.TransferEncoding: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = Self.parse(value) ?? .custom(value)
    }
}
