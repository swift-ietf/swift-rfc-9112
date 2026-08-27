public import Byte_Primitives

extension RFC_9112.Request {
    public enum Deserializer {}
}

extension RFC_9112.Request.Deserializer {
    public static func deserialize(
        _ data: [Byte]
    ) throws(Error) -> (request: RFC_9112.Message.Request<[Byte]>, bytesConsumed: Int) {
        let lines: [RFC_9112.Message.Parser.Line]
        do throws(RFC_9112.Message.Parser.Error) {
            lines = try RFC_9112.Message.Parser.parseLines(from: data)
        } catch {
            throw .messageParsing(error)
        }

        guard !lines.isEmpty else {
            throw .emptyMessage
        }
        guard let separator = RFC_9112.Message.Parser.findHeaderBodySeparator(in: lines) else {
            throw .missingHeaderBodySeparator
        }

        let line: RFC_9112.Request.Line
        do throws(RFC_9112.Request.Line.Error) {
            line = try RFC_9112.Request.Line.parse(lines[0].string)
        } catch {
            throw .requestLine(error)
        }

        let pairs: [(name: String, value: String)]
        do throws(RFC_9112.Field.Parser.Error) {
            pairs = try RFC_9112.Field.Parser.parseFieldLines(
                lines[1..<separator].map(\.string)
            )
        } catch {
            throw .headerParsing(error)
        }

        var fields = [RFC_9110.Field]()
        for pair in pairs {
            do throws(RFC_9110.Field.Error) {
                fields.append(try RFC_9110.Field(name: pair.name, value: pair.value))
            } catch {
                throw .headerValidation(error)
            }
        }

        var consumed = lines[0...separator].reduce(into: 0) { count, line in
            count += line.content.count
            switch line.terminator {
            case .crlf: count += 2
            case .lf: count += 1
            case .none: break
            }
        }

        var request = RFC_9112.Message.Request<[Byte]>(
            version: line.version,
            method: line.method,
            target: line.target,
            headers: .init(fields)
        )

        let length = RFC_9112.Message.Body.Length.calculate(for: request)
        if let count = length.fixedLength {
            guard data.count >= consumed + count else {
                throw .incompleteBody(expected: count, available: data.count - consumed)
            }
            if count > 0 {
                request.content = Array(data[consumed..<(consumed + count)])
            }
            consumed += count
        } else if length.isChunked {
            let result: RFC_9112.Transfer.Coding.Chunked.Result
            do throws(RFC_9112.Transfer.Coding.Chunked.Error) {
                result = try RFC_9112.Transfer.Coding.Chunked.decode(Array(data[consumed...]))
            } catch {
                throw .chunkedDecoding(error)
            }
            request.content = result.data
            request.trailers = .init(result.trailers)
            consumed = data.count
        }

        return (request, consumed)
    }
}
