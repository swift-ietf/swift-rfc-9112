// HTTP.Response.Validator.swift
// swift-rfc-9112

extension RFC_9110.Response {
    /// HTTP/1.1 response validation for security (RFC 9112 Section 11.1)
    ///
    /// Implements validation rules to prevent response splitting
    public enum Validator {

        /// Validate response for potential splitting attacks
        /// RFC 9112 Section 11.1: Response Splitting
        public static func validate(_ response: RFC_9110.Response) throws {
            let headers = response.headers

            // Check for multiple Content-Length headers with different values
            try validateContentLength(headers: Array(headers))

            // Validate Transfer-Encoding
            let hasTransferEncoding = headers.contains {
                $0.name.rawValue.lowercased() == "transfer-encoding"
            }
            if hasTransferEncoding {
                try validateTransferEncoding(headers: Array(headers))
            }

            // Check for invalid status codes
            // RFC 9112: Status code must be 3 digits (100-599)
            guard response.status.code >= 100 && response.status.code < 600 else {
                throw Error.invalidStatusCode(response.status.code)
            }

            // Check for Transfer-Encoding with incompatible status codes
            // RFC 9112 Section 6.1: "A server MUST NOT send a Transfer-Encoding header field
            // in any response with a status code of 1xx (Informational) or 204 (No Content)"
            // RFC 9112 Section 6.3: "A 304 response MUST NOT contain a message body"
            if hasTransferEncoding {
                let code = response.status.code
                if code / 100 == 1 || code == 204 || code == 304 {
                    throw Error.transferEncodingWithIncompatibleStatus(code)
                }
            }

            // Check for Transfer-Encoding with Content-Length
            // RFC 9112 Section 6.1: "A sender MUST NOT send a Content-Length header field
            // in any message that contains a Transfer-Encoding header field"
            if hasTransferEncoding {
                let hasContentLength = headers.contains {
                    $0.name.rawValue.lowercased() == "content-length"
                }
                if hasContentLength {
                    throw Error.transferEncodingWithContentLength
                }
            }
        }

        // MARK: - Header Validation

        /// Validate Transfer-Encoding header
        /// RFC 9112 Section 6.1
        private static func validateTransferEncoding(headers: [RFC_9110.Header.Field]) throws {
            let transferEncodingHeaders = headers.filter {
                $0.name.rawValue.lowercased() == "transfer-encoding"
            }

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
            let chunkedCount = transferEncodingHeaders.filter { header in
                RFC_9110.TransferEncoding.parse(header.value.rawValue)?.hasChunked ?? false
            }.count

            if chunkedCount > 1 {
                throw Error.chunkedAppliedMultipleTimes
            }
        }

        /// Validate Content-Length header
        /// RFC 9112 Section 6.2
        private static func validateContentLength(headers: [RFC_9110.Header.Field]) throws {
            let contentLengthHeaders = headers.filter {
                $0.name.rawValue.lowercased() == "content-length"
            }

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
            case invalidTransferEncoding(String)
            case invalidContentLength(reason: String)
            case multipleContentLengthValues([Int])
            case chunkedNotFinalEncoding
            case chunkedAppliedMultipleTimes
            case invalidStatusCode(Int)
            case transferEncodingWithIncompatibleStatus(Int)
            case transferEncodingWithContentLength
        }
    }
}
