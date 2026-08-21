public import Byte_Primitives
import Standard_Library_Extensions

extension RFC_9110.Response {

    public struct Deserializer {}
}

extension RFC_9110.Response.Deserializer {

    public static func deserialize(
        _ data: [Byte],
        requestMethod: RFC_9110.Method
    ) throws(Error) -> (response: RFC_9110.Response, bytesConsumed: Int) {

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

        let statusLineString = lines[0].string
        let statusLine: RFC_9110.Response.Line
        do throws(RFC_9110.Response.Line.ParsingError) {
            statusLine = try RFC_9110.Response.Line.parse(statusLineString)
        } catch {
            throw .responseLine(error)
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

        let preliminaryResponse = RFC_9110.Response(
            status: RFC_9110.Status(statusLine.statusCode),
            headers: RFC_9110.Headers(headers),
            body: nil
        )

        let bodyLength = RFC_9110.MessageBodyLength.calculate(
            for: preliminaryResponse,
            requestMethod: requestMethod
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

        } else if bodyLength.isUntilClose {

            body = Array(data[bytesConsumed...])
            bytesConsumed = data.count
        }

        let response = RFC_9110.Response(
            status: RFC_9110.Status(statusLine.statusCode),
            headers: RFC_9110.Headers(headers),
            body: body
        )

        return (response, bytesConsumed)
    }
}
