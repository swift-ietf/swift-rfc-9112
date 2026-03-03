// HTTP.Message.Deserializer.swift
// swift-rfc-9112

import Standard_Library_Extensions

extension RFC_9110.Request {
    /// Deserialize HTTP/1.1 request from wire format
    /// RFC 9112 Section 3: HTTP/1.1 request message format
    public struct Deserializer {

        /// Deserialize request from bytes
        /// Returns: (request, bytesConsumed)
        public static func deserialize(
            _ data: [UInt8]
        ) throws(Error) -> (request: RFC_9110.Request, bytesConsumed: Int) {
            // Parse lines
            let lines: [RFC_9110.MessageParser.Line]
            do { lines = try RFC_9110.MessageParser.parseLines(from: data) }
            catch { throw .messageParsing(error) }

            guard !lines.isEmpty else {
                throw .emptyMessage
            }

            // Find header-body separator (blank line)
            guard let separatorIndex = RFC_9110.MessageParser.findHeaderBodySeparator(in: lines)
            else {
                throw .missingHeaderBodySeparator
            }

            // Parse request line (first line)
            let requestLineString = lines[0].string
            let requestLine: RFC_9110.Request.Line
            do { requestLine = try RFC_9110.Request.Line.parse(requestLineString) }
            catch { throw .requestLine(error) }

            // Parse header fields (lines between request-line and separator)
            let headerLines = lines[1..<separatorIndex].map { $0.string }
            let headerPairs: [(name: String, value: String)]
            do { headerPairs = try RFC_9110.Header.Parser.parseFieldLines(headerLines) }
            catch { throw .headerParsing(error) }

            // Create header fields
            var headers: [RFC_9110.Header.Field] = []
            for (name, value) in headerPairs {
                do { headers.append(try RFC_9110.Header.Field(name: name, value: value)) }
                catch { throw .headerValidation(error) }
            }

            // Parse target into Target type
            let target = try parseTarget(requestLine.target, method: requestLine.method)

            // Calculate bytes consumed (up to and including separator line)
            var bytesConsumed = 0
            for i in 0...separatorIndex {
                bytesConsumed += lines[i].content.count
                switch lines[i].terminator {
                case .crlf:
                    bytesConsumed += 2
                case .lf:
                    bytesConsumed += 1
                case .none:
                    break
                }
            }

            // Determine body length
            let bodyLength = RFC_9110.MessageBodyLength.calculate(
                for: RFC_9110.Request(
                    method: requestLine.method,
                    target: target,
                    headers: RFC_9110.Headers(headers),
                    body: nil
                )
            )

            // Read body based on determined length
            var body: [UInt8]?
            if let fixedLength = bodyLength.fixedLength {
                guard data.count >= bytesConsumed + fixedLength else {
                    throw .incompleteBody(
                        expected: fixedLength,
                        available: data.count - bytesConsumed
                    )
                }
                body = Array(data[bytesConsumed..<(bytesConsumed + fixedLength)])
                bytesConsumed += fixedLength

            } else if bodyLength.isChunked {
                // Decode chunked body
                let chunkedData = data[bytesConsumed...]
                let result: RFC_9110.ChunkedEncoding.DecodeResult
                do { result = try RFC_9110.ChunkedEncoding.decode(Array(chunkedData)) }
                catch { throw .chunkedDecoding(error) }
                body = result.data
                // Add trailer headers if present
                for trailer in result.trailers {
                    headers.append(trailer)
                }
                // Calculate chunked bytes consumed (this is approximate - should track precisely)
                // For now, we'll use the decoded data size as estimate
                bytesConsumed += chunkedData.count
            }

            // Create request
            let request = RFC_9110.Request(
                method: requestLine.method,
                target: target,
                headers: RFC_9110.Headers(headers),
                body: body
            )

            return (request, bytesConsumed)
        }

        /// Parse target string into Target type
        private static func parseTarget(
            _ targetString: String,
            method: RFC_9110.Method
        ) throws(Error) -> RFC_9110.Request.Target {
            // RFC 9112 Section 3.2: Request target forms
            if targetString == "*" {
                return .asterisk
            }

            // Check for absolute-form (starts with scheme)
            if targetString.contains("://") {
                guard let uri = try? RFC_3986.URI(targetString) else {
                    throw .invalidTarget(targetString)
                }
                return .absolute(uri)
            }

            // Check for authority-form (CONNECT method)
            if method == .connect {
                guard let authority = try? RFC_3986.URI.Authority(targetString) else {
                    throw .invalidTarget(targetString)
                }
                return .authority(authority)
            }

            // origin-form: path and optional query
            let components = targetString.split(separator: "?", maxSplits: 1)
            let pathString = String(components[0])

            guard let path = try? RFC_3986.URI.Path(pathString) else {
                throw .invalidTarget(targetString)
            }

            let query: RFC_3986.URI.Query?
            if components.count > 1 {
                let queryString = String(components[1])
                query = try? RFC_3986.URI.Query(queryString)
            } else {
                query = nil
            }

            return .origin(path: path, query: query)
        }

        // MARK: - Errors

        public enum Error: Swift.Error, Sendable {
            case emptyMessage
            case missingHeaderBodySeparator
            case invalidEncoding
            case invalidTarget(String)
            case incompleteBody(expected: Int, available: Int)
            case messageParsing(RFC_9110.MessageParser.ParsingError)
            case requestLine(RFC_9110.Request.Line.ParsingError)
            case headerParsing(RFC_9110.Header.Parser.ParsingError)
            case headerValidation(RFC_9110.Header.Field.Error)
            case chunkedDecoding(RFC_9110.ChunkedEncoding.ChunkedDecodingError)
        }
    }
}

extension RFC_9110.Response {
    /// Deserialize HTTP/1.1 response from wire format
    /// RFC 9112 Section 4: HTTP/1.1 response message format
    public struct Deserializer {

        /// Deserialize response from bytes
        /// Returns: (response, bytesConsumed)
        /// Note: Requires request method to properly determine body length
        public static func deserialize(
            _ data: [UInt8],
            requestMethod: RFC_9110.Method
        ) throws(Error) -> (response: RFC_9110.Response, bytesConsumed: Int) {
            // Parse lines
            let lines: [RFC_9110.MessageParser.Line]
            do { lines = try RFC_9110.MessageParser.parseLines(from: data) }
            catch { throw .messageParsing(error) }

            guard !lines.isEmpty else {
                throw .emptyMessage
            }

            // Find header-body separator (blank line)
            guard let separatorIndex = RFC_9110.MessageParser.findHeaderBodySeparator(in: lines)
            else {
                throw .missingHeaderBodySeparator
            }

            // Parse status line (first line)
            let statusLineString = lines[0].string
            let statusLine: RFC_9110.Response.Line
            do { statusLine = try RFC_9110.Response.Line.parse(statusLineString) }
            catch { throw .responseLine(error) }

            // Parse header fields
            let headerLines = lines[1..<separatorIndex].map { $0.string }
            let headerPairs: [(name: String, value: String)]
            do { headerPairs = try RFC_9110.Header.Parser.parseFieldLines(headerLines) }
            catch { throw .headerParsing(error) }

            // Create header fields
            var headers: [RFC_9110.Header.Field] = []
            for (name, value) in headerPairs {
                do { headers.append(try RFC_9110.Header.Field(name: name, value: value)) }
                catch { throw .headerValidation(error) }
            }

            // Calculate bytes consumed (up to and including separator line)
            var bytesConsumed = 0
            for i in 0...separatorIndex {
                bytesConsumed += lines[i].content.count
                switch lines[i].terminator {
                case .crlf:
                    bytesConsumed += 2
                case .lf:
                    bytesConsumed += 1
                case .none:
                    break
                }
            }

            // Create preliminary response to determine body length
            let preliminaryResponse = RFC_9110.Response(
                status: RFC_9110.Status(statusLine.statusCode),
                headers: RFC_9110.Headers(headers),
                body: nil
            )

            // Determine body length
            let bodyLength = RFC_9110.MessageBodyLength.calculate(
                for: preliminaryResponse,
                requestMethod: requestMethod
            )

            // Read body based on determined length
            var body: [UInt8]?
            if let fixedLength = bodyLength.fixedLength {
                guard data.count >= bytesConsumed + fixedLength else {
                    throw .incompleteBody(
                        expected: fixedLength,
                        available: data.count - bytesConsumed
                    )
                }
                body = Array(data[bytesConsumed..<(bytesConsumed + fixedLength)])
                bytesConsumed += fixedLength

            } else if bodyLength.isChunked {
                // Decode chunked body
                let chunkedData = data[bytesConsumed...]
                let result: RFC_9110.ChunkedEncoding.DecodeResult
                do { result = try RFC_9110.ChunkedEncoding.decode(Array(chunkedData)) }
                catch { throw .chunkedDecoding(error) }
                body = result.data
                // Add trailer headers if present
                for trailer in result.trailers {
                    headers.append(trailer)
                }
                bytesConsumed += chunkedData.count

            } else if bodyLength.isUntilClose {
                // Read all remaining data
                body = Array(data[bytesConsumed...])
                bytesConsumed = data.count
            }

            // Create final response
            let response = RFC_9110.Response(
                status: RFC_9110.Status(statusLine.statusCode),
                headers: RFC_9110.Headers(headers),
                body: body
            )

            return (response, bytesConsumed)
        }

        // MARK: - Errors

        public enum Error: Swift.Error, Sendable {
            case emptyMessage
            case missingHeaderBodySeparator
            case invalidEncoding
            case incompleteBody(expected: Int, available: Int)
            case messageParsing(RFC_9110.MessageParser.ParsingError)
            case responseLine(RFC_9110.Response.Line.ParsingError)
            case headerParsing(RFC_9110.Header.Parser.ParsingError)
            case headerValidation(RFC_9110.Header.Field.Error)
            case chunkedDecoding(RFC_9110.ChunkedEncoding.ChunkedDecodingError)
        }
    }
}
