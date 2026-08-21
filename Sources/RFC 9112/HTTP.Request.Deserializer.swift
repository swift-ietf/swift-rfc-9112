public import Byte_Primitives
import Standard_Library_Extensions

extension RFC_9110.Request {

    public struct Deserializer {}
}

extension RFC_9110.Request.Deserializer {

    public static func deserialize(
        _ data: [Byte]
    ) throws(Error) -> (request: RFC_9110.Request, bytesConsumed: Int) {

        let lines: [RFC_9110.MessageParser.Line]
        do throws(RFC_9110.MessageParser.ParsingError) {
            lines = try RFC_9110.MessageParser.parseLines(from: data)
        } catch {
            throw .messageParsing(error)
        }

        guard !lines.isEmpty else {
            throw .emptyMessage
        }

        guard let separatorIndex = RFC_9110.MessageParser.findHeaderBodySeparator(in: lines)
        else {
            throw .missingHeaderBodySeparator
        }

        let requestLineString = lines[0].string
        let requestLine: RFC_9110.Request.Line
        do throws(RFC_9110.Request.Line.ParsingError) {
            requestLine = try RFC_9110.Request.Line.parse(requestLineString)
        } catch {
            throw .requestLine(error)
        }

        let headerLines = lines[1..<separatorIndex].map { $0.string }
        let headerPairs: [(name: String, value: String)]
        do throws(RFC_9110.Header.Parser.ParsingError) {
            headerPairs = try RFC_9110.Header.Parser.parseFieldLines(headerLines)
        } catch {
            throw .headerParsing(error)
        }

        var headers: [RFC_9110.Header.Field] = []
        for (name, value) in headerPairs {
            do throws(RFC_9110.Header.Field.Error) {
                headers.append(try RFC_9110.Header.Field(name: name, value: value))
            } catch {
                throw .headerValidation(error)
            }
        }

        let target = try parseTarget(requestLine.target, method: requestLine.method)

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

        let bodyLength = RFC_9110.MessageBodyLength.calculate(
            for: RFC_9110.Request(
                method: requestLine.method,
                target: target,
                headers: RFC_9110.Headers(headers),
                body: nil
            )
        )

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

            let chunkedData = data[bytesConsumed...]
            let result: RFC_9110.ChunkedEncoding.DecodeResult
            do throws(RFC_9110.ChunkedEncoding.ChunkedDecodingError) {
                result = try RFC_9110.ChunkedEncoding.decode(Array(chunkedData))
            } catch {
                throw .chunkedDecoding(error)
            }
            body = result.data

            for trailer in result.trailers {
                headers.append(trailer)
            }

            bytesConsumed += chunkedData.count
        }

        let request = RFC_9110.Request(
            method: requestLine.method,
            target: target,
            headers: RFC_9110.Headers(headers),
            body: body
        )

        return (request, bytesConsumed)
    }

    private static func parseTarget(
        _ targetString: String,
        method: RFC_9110.Method
    ) throws(Error) -> RFC_9110.Request.Target {

        if targetString == "*" {
            return .asterisk
        }

        if targetString.contains("://") {
            let uri: RFC_3986.URI
            do throws(RFC_3986.Error) {
                uri = try RFC_3986.URI(targetString)
            } catch {
                throw .invalidTarget(targetString)
            }
            return .absolute(uri)
        }

        if method == .connect {
            let authority: RFC_3986.URI.Authority
            do throws(RFC_3986.URI.Authority.Error) {
                authority = try RFC_3986.URI.Authority(targetString)
            } catch {
                throw .invalidTarget(targetString)
            }
            return .authority(authority)
        }

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

                query = nil
            }
        } else {
            query = nil
        }

        return .origin(path: path, query: query)
    }
}
