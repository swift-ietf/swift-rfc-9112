import INCITS_4_1986

extension RFC_9112.Framing.Body {
    public enum Length: Equatable, Hashable {

        case none

        case length(Int)

        case chunked

        case untilClose

        case tunnel
    }
}

extension RFC_9112.Framing.Body.Length {

    public static func determine(
        context: RFC_9112.Framing.Context,
        headers: RFC_9110.Message.Headers
    ) throws(RFC_9112.Framing.Error) -> Self {

        if case .response(let status, let request) = context {
            if request == .head { return .none }

            switch status {
            case 100..<200, 204, 304:
                return .none

            case 200..<300 where request == .connect:
                return .tunnel

            default:
                break
            }
        }

        let transferEncodings = headers.values(.transferEncoding)
        let contentLengths = headers.values(.contentLength)

        if !transferEncodings.isEmpty {

            if !contentLengths.isEmpty {
                throw .transferEncodingWithContentLength
            }

            let combined = transferEncodings.map(\.description).joined(separator: ", ")

            guard let coding = RFC_9112.Transfer.Encoding.parse(combined) else {
                throw .malformedTransferEncoding(combined)
            }

            if coding.hasChunked {

                if coding.isChunkedFinal { return .chunked }

                if context.isRequest { throw .chunkedNotFinal }
                return .untilClose
            }

            if context.isRequest { throw .transferEncodingWithoutChunked }
            return .untilClose
        }

        if !contentLengths.isEmpty {
            var seen: [String] = []

            for value in contentLengths {
                let raw = value.description

                for element in raw.split(separator: ",", omittingEmptySubsequences: false) {
                    let token = String(element).trimming(.ascii.whitespaces)
                    guard Self.isDigits(token) else {
                        throw .invalidContentLength(raw)
                    }
                    seen.append(token)
                }
            }

            guard let first = seen.first else {
                throw .invalidContentLength("")
            }
            guard seen.allSatisfy({ $0 == first }) else {
                throw .conflictingContentLength(seen)
            }
            guard let length = Int(first) else {
                throw .invalidContentLength(first)
            }
            return .length(length)
        }

        return context.isRequest ? .none : .untilClose
    }
}

extension RFC_9112.Framing.Body.Length {

    private static func isDigits(_ token: String) -> Bool {
        guard !token.isEmpty else { return false }
        return token.utf8.allSatisfy { $0 >= 0x30 && $0 <= 0x39 }
    }
}
