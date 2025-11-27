// HTTP.Request.Validator.swift
// swift-rfc-9112

extension RFC_9110.Request {
    /// HTTP/1.1 request validation for security (RFC 9112 Section 11.2)
    ///
    /// Implements validation rules to prevent request smuggling
    public enum Validator {

        /// Validate request for potential smuggling attacks
        /// RFC 9112 Section 11.2: Request Smuggling
        ///
        /// Key rule: "A server MAY reject a request that contains both Content-Length and
        /// Transfer-Encoding or process such a request in accordance with the Transfer-Encoding
        /// alone. Regardless, the server MUST close the connection after responding to such a
        /// request to avoid the potential attacks."
        public static func validate(_ request: RFC_9110.Request) throws {
            let headers = request.headers

            // Check for both Transfer-Encoding and Content-Length
            let hasTransferEncoding = headers.contains { $0.name.rawValue.lowercased() == "transfer-encoding" }
            let hasContentLength = headers.contains { $0.name.rawValue.lowercased() == "content-length" }

            if hasTransferEncoding && hasContentLength {
                throw Error.ambiguousMessageFraming(
                    reason: "Request contains both Transfer-Encoding and Content-Length"
                )
            }

            // Validate Transfer-Encoding if present
            if hasTransferEncoding {
                try validateTransferEncoding(headers: Array(headers))
            }

            // Validate Content-Length if present
            if hasContentLength {
                try validateContentLength(headers: Array(headers))
            }
        }

        // MARK: - Header Validation

        /// Validate Transfer-Encoding header
        /// RFC 9112 Section 6.1
        private static func validateTransferEncoding(headers: [RFC_9110.Header.Field]) throws {
            let transferEncodingHeaders = headers.filter { $0.name.rawValue.lowercased() == "transfer-encoding" }

            guard !transferEncodingHeaders.isEmpty else {
                return
            }

            // Parse Transfer-Encoding value
            for header in transferEncodingHeaders {
                guard let te = RFC_9110.TransferEncoding.parse(header.value.rawValue) else {
                    throw Error.invalidTransferEncoding(header.value.rawValue)
                }

                // RFC 9112 Section 7: Chunked must be final encoding (if present in list)
                if te.hasChunked && !te.isChunkedFinal {
                    throw Error.chunkedNotFinalEncoding
                }
            }

            // RFC 9112: "A sender MUST NOT apply the chunked transfer coding more than once to a message body"
            var chunkedCount = 0
            for header in transferEncodingHeaders {
                if let te = RFC_9110.TransferEncoding.parse(header.value.rawValue) {
                    // Count how many times chunked appears in this header
                    chunkedCount += te.chunkedCount
                }
            }

            if chunkedCount > 1 {
                throw Error.chunkedAppliedMultipleTimes
            }
        }

        /// Validate Content-Length header
        /// RFC 9112 Section 6.2
        private static func validateContentLength(headers: [RFC_9110.Header.Field]) throws {
            let contentLengthHeaders = headers.filter { $0.name.rawValue.lowercased() == "content-length" }

            guard contentLengthHeaders.count > 1 else {
                return
            }

            // Multiple Content-Length headers - check if they all have the same value
            let values = contentLengthHeaders.compactMap { Int($0.value.rawValue) }

            guard values.count == contentLengthHeaders.count else {
                throw Error.invalidContentLength(reason: "Non-integer Content-Length value")
            }

            guard Set(values).count == 1 else {
                throw Error.multipleContentLengthValues(values)
            }
        }

        // MARK: - Errors

        public enum Error: Swift.Error, Sendable, Equatable {
            case ambiguousMessageFraming(reason: String)
            case invalidTransferEncoding(String)
            case invalidContentLength(reason: String)
            case multipleContentLengthValues([Int])
            case chunkedNotFinalEncoding
            case chunkedAppliedMultipleTimes
        }
    }
}
