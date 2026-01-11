// HTTP.ChunkedEncoding.swift
// swift-rfc-9112
//
// RFC 9112 Section 7.1: Chunked Transfer Coding
// https://www.rfc-editor.org/rfc/rfc9112.html#section-7.1
//
// Chunked transfer encoding encode/decode utilities

import Standard_Library_Extensions

extension RFC_9110 {
    /// Chunked transfer encoding utilities (RFC 9112 Section 7.1)
    ///
    /// Chunked transfer coding wraps the payload body to allow for dynamic
    /// content generation by framing the data as a series of chunks.
    ///
    /// ## Example Usage
    ///
    /// ```swift
    /// // Encoding
    /// let data = Array("Hello, World!".utf8)
    /// let chunked = try HTTP.ChunkedEncoding.encode(data)
    ///
    /// // With chunk extensions
    /// let extensions = [HTTP.ChunkedEncoding.Extension(name: "signature", value: "abc123")]
    /// let chunked2 = try HTTP.ChunkedEncoding.encode(data, chunkExtensions: extensions)
    ///
    /// // Decoding
    /// let result = try HTTP.ChunkedEncoding.decode(chunked)
    /// // result.data == data
    /// // result.chunkExtensions contains any chunk extensions
    /// ```
    ///
    /// ## RFC 9112 Reference
    ///
    /// From RFC 9112 Section 7.1:
    /// ```
    /// chunked-body   = *chunk
    ///                  last-chunk
    ///                  trailer-section
    ///                  CRLF
    ///
    /// chunk          = chunk-size [ chunk-ext ] CRLF
    ///                  chunk-data CRLF
    /// chunk-size     = 1*HEXDIG
    /// last-chunk     = 1*("0") [ chunk-ext ] CRLF
    /// chunk-ext      = *( BWS ";" BWS chunk-ext-name [ BWS "=" BWS chunk-ext-val ] )
    ///
    /// chunk-data     = 1*OCTET ; a sequence of chunk-size octets
    /// ```
    ///
    /// ## Reference
    ///
    /// - [RFC 9112 Section 7.1: Chunked](https://www.rfc-editor.org/rfc/rfc9112.html#section-7.1)
    /// - [RFC 9112 Section 7.1.1: Chunk Extensions](https://www.rfc-editor.org/rfc/rfc9112.html#section-7.1.1)
    public enum ChunkedEncoding {

        // MARK: - Chunk Extension

        /// Chunk extension (RFC 9112 Section 7.1.1)
        ///
        /// Chunk extensions provide a mechanism for additional chunk-specific metadata.
        /// RFC 9112: "Recipients MUST ignore unrecognized chunk extensions"
        public struct Extension: Sendable, Equatable, Hashable {
            public let name: String
            public let value: String?

            public init(name: String, value: String? = nil) {
                self.name = name
                self.value = value
            }

            /// Format as string for transmission
            /// Format: ";name" or ";name=value"
            public var formatted: String {
                if let value = value {
                    // Check if value needs quoting
                    if value.contains(where: { $0 == ";" || $0.isWhitespace }) {
                        return ";\(name)=\"\(value)\""
                    } else {
                        return ";\(name)=\(value)"
                    }
                } else {
                    return ";\(name)"
                }
            }

            /// Parse chunk extensions from string
            /// RFC 9112 Section 7.1.1: chunk-ext = *( BWS ";" BWS chunk-ext-name [ BWS "=" BWS chunk-ext-val ] )
            static func parseExtensions(_ string: String) -> [Extension] {
                var extensions: [Extension] = []
                let parts = string.split(separator: ";", omittingEmptySubsequences: true)

                for part in parts {
                    let trimmed = part.trimming(.ascii.whitespaces)
                    if trimmed.contains("=") {
                        let components = trimmed.split(separator: "=", maxSplits: 1)
                        if components.count == 2 {
                            let name = String(components[0]).trimming(.ascii.whitespaces)
                            var value = String(components[1]).trimming(.ascii.whitespaces)

                            // Remove quotes if present
                            if value.hasPrefix("\"") && value.hasSuffix("\"") {
                                value = String(value.dropFirst().dropLast())
                            }

                            extensions.append(Extension(name: name, value: value))
                        }
                    } else {
                        extensions.append(Extension(name: trimmed, value: nil))
                    }
                }

                return extensions
            }
        }

        /// Result of decoding chunked data
        public struct DecodeResult: Sendable, Equatable {
            public let data: [UInt8]
            public let chunkExtensions: [[Extension]]  // Extensions for each chunk
            public let trailers: [HTTP.Header.Field]

            public init(
                data: [UInt8],
                chunkExtensions: [[Extension]],
                trailers: [HTTP.Header.Field]
            ) {
                self.data = data
                self.chunkExtensions = chunkExtensions
                self.trailers = trailers
            }
        }
        /// Encodes data using chunked transfer encoding
        ///
        /// - Parameters:
        ///   - data: The data to encode
        ///   - chunkSize: Maximum size of each chunk (default: 8192)
        ///   - chunkExtensions: Optional chunk extensions to add to each chunk
        ///   - trailers: Optional trailer headers to append after the last chunk
        /// - Returns: The chunked-encoded data
        ///
        /// ## Example
        ///
        /// ```swift
        /// let data = Array("Hello, World!".utf8)
        /// let chunked = try HTTP.ChunkedEncoding.encode(data)
        /// // "d\r\nHello, World!\r\n0\r\n\r\n"
        /// ```
        public static func encode(
            _ data: [UInt8],
            chunkSize: Int = 8192,
            chunkExtensions: [Extension] = [],
            trailers: [HTTP.Header.Field] = []
        ) throws -> [UInt8] {
            var result = [UInt8]()

            // Format chunk extensions once
            let extensionsString = chunkExtensions.map { $0.formatted }.joined()

            // Encode data in chunks
            var offset = 0
            while offset < data.count {
                let end = min(offset + chunkSize, data.count)
                let chunkData = data[offset..<end]
                let size = chunkData.count

                // chunk-size (hex) + chunk-ext + CRLF
                result.append(contentsOf: String(size, radix: 16).utf8)
                if !chunkExtensions.isEmpty {
                    result.append(contentsOf: extensionsString.utf8)
                }
                result.append(contentsOf: [0x0D, 0x0A])  // CRLF

                // chunk-data + CRLF
                result.append(contentsOf: chunkData)
                result.append(contentsOf: [0x0D, 0x0A])  // CRLF

                offset = end
            }

            // last-chunk: "0" + chunk-ext + CRLF
            result.append(contentsOf: "0".utf8)
            if !chunkExtensions.isEmpty {
                result.append(contentsOf: extensionsString.utf8)
            }
            result.append(contentsOf: [0x0D, 0x0A])  // CRLF

            // trailer-section
            for trailer in trailers {
                let line = "\(trailer.name.rawValue): \(trailer.value.rawValue)\r\n"
                result.append(contentsOf: line.utf8)
            }

            // final CRLF
            result.append(contentsOf: [0x0D, 0x0A])

            return result
        }

        /// Decodes chunked transfer encoded data
        ///
        /// - Parameter data: The chunked-encoded data
        /// - Returns: DecodeResult containing decoded data, chunk extensions, and trailers
        /// - Throws: ChunkedDecodingError if data is invalid
        ///
        /// ## Example
        ///
        /// ```swift
        /// let chunked = Array("d\r\nHello, World!\r\n0\r\n\r\n".utf8)
        /// let result = try HTTP.ChunkedEncoding.decode(chunked)
        /// // result.data == Array("Hello, World!".utf8)
        /// // result.trailers == []
        /// ```
        public static func decode(_ data: [UInt8]) throws -> DecodeResult {
            var result = [UInt8]()
            var allChunkExtensions: [[Extension]] = []
            var trailers: [HTTP.Header.Field] = []
            var offset = 0

            while offset < data.count {
                // Find CRLF for chunk-size line
                guard let crlfIndex = data[offset...].firstIndex(of: 0x0D),
                    crlfIndex + 1 < data.count,
                    data[crlfIndex + 1] == 0x0A
                else {
                    throw ChunkedDecodingError.invalidFormat
                }

                // Parse chunk size (hex) and extensions
                let sizeLine = data[offset..<crlfIndex]
                let sizeString = String(decoding: sizeLine, as: UTF8.self)

                // Split into size and extensions
                let components = sizeString.split(separator: ";", maxSplits: 1)
                let sizeComponent = String(components[0]).trimming(.ascii.whitespaces)

                guard let size = Int(sizeComponent, radix: 16) else {
                    throw ChunkedDecodingError.invalidChunkSize
                }

                // Parse chunk extensions if present
                var chunkExtensions: [Extension] = []
                if components.count > 1 {
                    let extensionsString = String(components[1])
                    chunkExtensions = Extension.parseExtensions(extensionsString)
                }

                // Move past size line + CRLF
                offset = crlfIndex + 2

                // If size is 0, we've reached the last chunk
                if size == 0 {
                    // Store last-chunk extensions
                    if !chunkExtensions.isEmpty {
                        allChunkExtensions.append(chunkExtensions)
                    }

                    // Parse trailer section
                    while offset < data.count {
                        // Check for final CRLF
                        if offset + 1 < data.count && data[offset] == 0x0D
                            && data[offset + 1] == 0x0A {
                            // End of message
                            break
                        }

                        // Find next CRLF for trailer line
                        guard let nextCrlf = data[offset...].firstIndex(of: 0x0D),
                            nextCrlf + 1 < data.count,
                            data[nextCrlf + 1] == 0x0A
                        else {
                            throw ChunkedDecodingError.invalidFormat
                        }

                        let trailerLine = data[offset..<nextCrlf]
                        let trailerString = String(decoding: trailerLine, as: UTF8.self)
                        if !trailerString.isEmpty {
                            // Parse trailer field
                            let parts = trailerString.split(separator: ":", maxSplits: 1)
                            if parts.count == 2 {
                                let name = String(parts[0]).trimming(.ascii.whitespaces)
                                let value = String(parts[1]).trimming(.ascii.whitespaces)
                                do {
                                    let trailer = try HTTP.Header.Field(name: name, value: value)
                                    trailers.append(trailer)
                                } catch {
                                    // RFC 9112: "Recipients MUST ignore unrecognized chunk extensions"
                                    // Similarly, skip invalid trailers
                                }
                            }
                        }

                        offset = nextCrlf + 2
                    }

                    break
                }

                // Store chunk extensions for this chunk
                allChunkExtensions.append(chunkExtensions)

                // Read chunk data
                guard offset + size + 2 <= data.count else {
                    throw ChunkedDecodingError.incompleteChunk
                }

                let chunkData = data[offset..<(offset + size)]
                result.append(contentsOf: chunkData)

                // Verify CRLF after chunk data
                guard data[offset + size] == 0x0D,
                    data[offset + size + 1] == 0x0A
                else {
                    throw ChunkedDecodingError.missingCRLF
                }

                // Move past chunk data + CRLF
                offset += size + 2
            }

            return DecodeResult(
                data: result,
                chunkExtensions: allChunkExtensions,
                trailers: trailers
            )
        }

        /// Errors that can occur during chunked decoding
        public enum ChunkedDecodingError: Error, Sendable, Equatable {
            /// Invalid chunked encoding format
            case invalidFormat

            /// Invalid chunk size value
            case invalidChunkSize

            /// Incomplete chunk data
            case incompleteChunk

            /// Missing CRLF after chunk data
            case missingCRLF
        }
    }
}
