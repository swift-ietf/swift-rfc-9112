#if Coder
    import Byte
    import Cursor
    import RFC_9110

    enum Framing {

        enum Error: Swift::Error, Equatable {

            case transferEncoding(String)

            case contentLength(String)

            case conflictingContentLength([String])
        }

        static func transferEncoding(
            in headers: RFC_9110.Message.Headers
        ) throws(Error) -> RFC_9112.Transfer.Encoding? {
            let values = headers.values(.transferEncoding)
            guard !values.isEmpty else { return nil }

            let combined = values.map(\.rawValue).joined(separator: ", ")
            var input = [Byte](utf8: combined)[...]

            do throws(RFC_9112.Transfer.Encoding.Error) {
                return try RFC_9112.Transfer.Encoding.coder.parse(&input)
            } catch {
                throw .transferEncoding(combined)
            }
        }

        static func contentLength(in headers: RFC_9110.Message.Headers) throws(Error) -> Int? {
            let values = headers.values(.contentLength)
            guard !values.isEmpty else { return nil }

            var tokens: [String] = []
            for value in values {
                for element in value.rawValue.split(separator: ",", omittingEmptySubsequences: false) {
                    let token = Scanning.trimmed(String(element))
                    guard !token.isEmpty, token.utf8.allSatisfy({ $0 >= 0x30 && $0 <= 0x39 }) else {
                        throw .contentLength(value.rawValue)
                    }
                    tokens.append(token)
                }
            }

            guard let first = tokens.first else { throw .contentLength("") }
            guard tokens.allSatisfy({ $0 == first }) else { throw .conflictingContentLength(tokens) }
            guard let length = Int(first) else { throw .contentLength(first) }
            return length
        }

        static func connection(
            in headers: RFC_9110.Message.Headers
        ) -> RFC_9112.Connection? {
            let values = headers.values(.connection)
            guard !values.isEmpty else { return nil }

            var input = [Byte](utf8: values.map(\.rawValue).joined(separator: ", "))[...]
            return try? RFC_9112.Connection.coder.parse(&input)
        }
    }
#endif
