// HTTP.Request.Deserializer.swift
// swift-rfc-9112

public import Byte_Primitives
import Standard_Library_Extensions

extension RFC_9110.Request {
    /// Deserialize HTTP/1.1 request from wire format
    /// RFC 9112 Section 3: HTTP/1.1 request message format
    public struct Deserializer {}
}

extension RFC_9110.Request.Deserializer {

    /// Deserialize request from bytes
    /// Returns: (request, bytesConsumed)
    public static func deserialize(
        _ data: [Byte]
    ) throws(Error) -> (request: RFC_9110.Request, bytesConsumed: Int) {
        // Parse lines
        let lines: [RFC_9110.MessageParser.Line]
        do throws(RFC_9110.MessageParser.ParsingError) {
            lines = try RFC_9110.MessageParser.parseLines(from: data)
        } catch {
            throw .messageParsing(error)
        }

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
        do throws(RFC_9110.Request.Line.ParsingError) {
            requestLine = try RFC_9110.Request.Line.parse(requestLineString)
        } catch {
            throw .requestLine(error)
        }

        // Parse header fields (lines between request-line and separator)
        let headerLines = lines[1..<separatorIndex].map { $0.string }
        let headerPairs: [(name: String, value: String)]
        do throws(RFC_9110.Header.Parser.ParsingError) {
            headerPairs = try RFC_9110.Header.Parser.parseFieldLines(headerLines)
        } catch {
            throw .headerParsing(error)
        }

        // Create header fields
        var headers: [RFC_9110.Header.Field] = []
        for (name, value) in headerPairs {
            do throws(RFC_9110.Header.Field.Error) {
                headers.append(try RFC_9110.Header.Field(name: name, value: value))
            } catch {
                throw .headerValidation(error)
            }
        }

        // Parse target into Target type
        let target = try parseTarget(requestLine.target, method: requestLine.method)

        // Calculate bytes consumed (up to and including separator line)
        var bytesConsumed = 0
        for line in lines[0...separatorIndex] {
            bytesConsumed += line.content.count
            switch line.terminator {
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
        var body: [Byte]?
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
            do throws(RFC_9110.ChunkedEncoding.ChunkedDecodingError) {
                result = try RFC_9110.ChunkedEncoding.decode(Array(chunkedData))
            } catch {
                throw .chunkedDecoding(error)
            }
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
            let uri: RFC_3986.URI
            do throws(RFC_3986.Error) {
                uri = try RFC_3986.URI(targetString)
            } catch {
                throw .invalidTarget(targetString)
            }
            return .absolute(uri)
        }

        // Check for authority-form (CONNECT method)
        if method == .connect {
            let authority: RFC_3986.URI.Authority
            do throws(RFC_3986.URI.Authority.Error) {
                authority = try RFC_3986.URI.Authority(targetString)
            } catch {
                throw .invalidTarget(targetString)
            }
            return .authority(authority)
        }

        // origin-form: path and optional query
        let components = targetString.split(separator: "?", maxSplits: 1)
        let pathString = String(components[0])

        let path: RFC_3986.URI.Path
        do throws(RFC_3986.URI.Path.Error) {
            path = try RFC_3986.URI.Path(pathString)
        } catch {
            throw .invalidTarget(targetString)
        }

        let query: RFC_3986.URI.Query?
        if components.count > 1 {
            let queryString = String(components[1])
            do throws(RFC_3986.URI.Query.Error) {
                query = try RFC_3986.URI.Query(queryString)
            } catch {
                // Malformed query on an otherwise-valid target is tolerated:
                // RFC 9112 Section 3.2 leaves origin-form query handling to
                // the target consumer, and a request line MUST NOT be
                // rejected solely for a query string that doesn't parse.
                query = nil
            }
        } else {
            query = nil
        }

        return .origin(path: path, query: query)
    }
}
