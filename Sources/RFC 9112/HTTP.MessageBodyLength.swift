// HTTP.MessageBodyLength.swift
// swift-rfc-9112
//
// RFC 9112 Section 6.3: Message Body Length
// https://www.rfc-editor.org/rfc/rfc9112.html#section-6.3
//
// Message body length determination for HTTP/1.1

import INCITS_4_1986

extension RFC_9110 {
    /// Message body length calculation utilities (RFC 9112 Section 6.3)
    ///
    /// Determines the length of an HTTP message body based on headers and context.
    ///
    /// ## Example Usage
    ///
    /// ```swift
    /// let response = HTTP.Response(
    ///     status: .ok,
    ///     headers: [try .init(name: "Content-Length", value: "13")]
    /// )
    ///
    /// let length = HTTP.MessageBodyLength.calculate(
    ///     for: response,
    ///     requestMethod: .get
    /// )
    /// // length == .length(13)
    /// ```
    ///
    /// ## RFC 9112 Reference
    ///
    /// From RFC 9112 Section 6.3, the priority order for determining body length:
    ///
    /// 1. HEAD requests and certain status codes never have a body
    /// 2. Successful CONNECT creates a tunnel
    /// 3. Transfer-Encoding takes precedence over Content-Length
    /// 4. Chunked encoding signals completion
    /// 5. Multiple/invalid Content-Length triggers error
    /// 6. Valid Content-Length defines length
    /// 7. Requests without indicators have zero-length body
    /// 8. Responses use connection close for delimitation
    ///
    /// ## Reference
    ///
    /// - [RFC 9112 Section 6.3: Message Body Length](https://www.rfc-editor.org/rfc/rfc9112.html#section-6.3)
    public enum MessageBodyLength: Sendable, Equatable {
        /// No body present
        case none

        /// Fixed-length body
        case length(Int)

        /// Chunked transfer encoding
        case chunked

        /// Delimited by connection close
        case untilClose

        /// Calculates message body length for a response
        ///
        /// - Parameters:
        ///   - response: The HTTP response
        ///   - requestMethod: The request method that generated this response
        /// - Returns: The message body length indicator
        ///
        /// ## Example
        ///
        /// ```swift
        /// let response = HTTP.Response(
        ///     status: .ok,
        ///     headers: [try .init(name: "Transfer-Encoding", value: "chunked")]
        /// )
        ///
        /// let length = HTTP.MessageBodyLength.calculate(
        ///     for: response,
        ///     requestMethod: .get
        /// )
        /// // length == .chunked
        /// ```
        public static func calculate(
            for response: HTTP.Response,
            requestMethod: HTTP.Method
        ) -> MessageBodyLength {
            // Rule 1: HEAD requests never have a body
            if requestMethod == .head {
                return .none
            }

            // Rule 1: 1xx, 204, and 304 responses never have a body
            if response.status.code < 200 ||
               response.status.code == 204 ||
               response.status.code == 304 {
                return .none
            }

            // Rule 2: Successful CONNECT creates a tunnel (no body in initial response)
            if requestMethod == .connect && response.status.code >= 200 && response.status.code < 300 {
                return .none
            }

            // Rule 3-4: Check Transfer-Encoding
            if let teHeader = response.headers["Transfer-Encoding"]?.first?.rawValue,
               let te = TransferEncoding.parse(teHeader) {
                // Transfer-Encoding takes precedence
                if te.hasChunked {
                    return .chunked
                }
            }

            // Rule 5-6: Check Content-Length
            if let clHeaders = response.headers["Content-Length"], !clHeaders.isEmpty {
                // Multiple Content-Length headers
                if clHeaders.count > 1 {
                    // Check if all values are identical
                    let values = clHeaders.map { $0.rawValue }
                    let uniqueValues = Set(values)
                    if uniqueValues.count > 1 {
                        // Invalid: multiple different Content-Length values
                        // Per RFC 9112, this should trigger an error
                        return .none
                    }
                }

                // Parse single Content-Length value
                if let clValue = clHeaders.first?.rawValue.trimming(.ascii.whitespaces),
                   let length = Int(clValue), length >= 0 {
                    return .length(length)
                }

                // Invalid Content-Length
                return .none
            }

            // Rule 8: Response without length indicators uses connection close
            return .untilClose
        }

        /// Calculates message body length for a request
        ///
        /// - Parameter request: The HTTP request
        /// - Returns: The message body length indicator
        ///
        /// ## Example
        ///
        /// ```swift
        /// let request = HTTP.Request(
        ///     method: .post,
        ///     target: .origin(path: .init("/api/data"), query: nil),
        ///     headers: [try .init(name: "Content-Length", value: "42")]
        /// )
        ///
        /// let length = HTTP.MessageBodyLength.calculate(for: request)
        /// // length == .length(42)
        /// ```
        public static func calculate(for request: HTTP.Request) -> MessageBodyLength {
            // Check Transfer-Encoding
            if let teHeader = request.headers["Transfer-Encoding"]?.first?.rawValue,
               let te = TransferEncoding.parse(teHeader) {
                if te.hasChunked {
                    return .chunked
                }
            }

            // Check Content-Length
            if let clHeaders = request.headers["Content-Length"], !clHeaders.isEmpty {
                // Multiple Content-Length headers
                if clHeaders.count > 1 {
                    let values = clHeaders.map { $0.rawValue }
                    let uniqueValues = Set(values)
                    if uniqueValues.count > 1 {
                        // Invalid: multiple different Content-Length values
                        return .none
                    }
                }

                // Parse single Content-Length value
                if let clValue = clHeaders.first?.rawValue.trimming(.ascii.whitespaces),
                   let length = Int(clValue), length >= 0 {
                    return .length(length)
                }

                // Invalid Content-Length
                return .none
            }

            // Rule 7: Requests without indicators have zero-length body
            return .none
        }

        /// Returns true if the message has a body
        ///
        /// ## Example
        ///
        /// ```swift
        /// MessageBodyLength.none.hasBody  // false
        /// MessageBodyLength.length(100).hasBody  // true
        /// MessageBodyLength.chunked.hasBody  // true
        /// ```
        public var hasBody: Bool {
            switch self {
            case .none:
                return false
            case .length(let len):
                return len > 0
            case .chunked, .untilClose:
                return true
            }
        }

        /// Returns the fixed length if known
        ///
        /// ## Example
        ///
        /// ```swift
        /// MessageBodyLength.length(100).fixedLength  // 100
        /// MessageBodyLength.chunked.fixedLength  // nil
        /// MessageBodyLength.none.fixedLength  // 0
        /// ```
        public var fixedLength: Int? {
            switch self {
            case .none:
                return 0
            case .length(let len):
                return len
            case .chunked, .untilClose:
                return nil
            }
        }

        /// Returns true if chunked encoding is used
        ///
        /// ## Example
        ///
        /// ```swift
        /// MessageBodyLength.chunked.isChunked  // true
        /// MessageBodyLength.length(100).isChunked  // false
        /// ```
        public var isChunked: Bool {
            if case .chunked = self {
                return true
            }
            return false
        }

        /// Returns true if length is delimited by connection close
        ///
        /// ## Example
        ///
        /// ```swift
        /// MessageBodyLength.untilClose.isUntilClose  // true
        /// MessageBodyLength.length(100).isUntilClose  // false
        /// ```
        public var isUntilClose: Bool {
            if case .untilClose = self {
                return true
            }
            return false
        }
    }
}
