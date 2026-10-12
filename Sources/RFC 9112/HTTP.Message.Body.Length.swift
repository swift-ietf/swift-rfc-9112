public import RFC_9110

extension RFC_9112.Message.Body {

    public enum Length: Equatable, Hashable {

        case none

        case length(Int)

        case chunked

        case untilClose

        case tunnel
    }
}

extension RFC_9112.Message.Body.Length {

    public enum Context: Equatable, Hashable {

        case request

        case response(status: RFC_9110.Status, to: RFC_9110.Method)
    }
}

extension RFC_9112.Message.Body.Length.Context {

    public var isRequest: Bool {
        switch self {
        case .request: true
        case .response: false
        }
    }
}

extension RFC_9112.Message.Body.Length {

    public enum Error: Swift::Error, Equatable {

        case transferEncodingWithContentLength

        case transferEncodingWithIncompatibleStatus(RFC_9110.Status)

        case chunkedNotFinal

        case chunkedAppliedMultipleTimes

        case transferEncodingWithoutChunked
    }
}

extension RFC_9112.Message.Body.Length {

    public init(
        _ context: Context,
        transferEncoding: RFC_9112.Transfer.Encoding? = nil,
        contentLength: Int? = nil
    ) throws(Error) {
        if case .response(let status, let method) = context {
            if method == .head {
                self = .none
                return
            }

            if status.isInformational || status.code == 204 || status.code == 304 {
                guard transferEncoding == nil else {
                    throw .transferEncodingWithIncompatibleStatus(status)
                }
                self = .none
                return
            }

            if method == .connect, status.isSuccessful {
                self = .tunnel
                return
            }
        }

        if let transferEncoding {
            guard contentLength == nil else {
                throw .transferEncodingWithContentLength
            }
            guard transferEncoding.chunkedCount <= 1 else {
                throw .chunkedAppliedMultipleTimes
            }

            guard transferEncoding.hasChunked else {
                guard !context.isRequest else { throw .transferEncodingWithoutChunked }
                self = .untilClose
                return
            }

            if transferEncoding.isChunkedFinal {
                self = .chunked
                return
            }

            guard !context.isRequest else { throw .chunkedNotFinal }
            self = .untilClose
            return
        }

        if let contentLength {
            self = .length(contentLength)
            return
        }

        self = context.isRequest ? .none : .untilClose
    }
}

extension RFC_9112.Message.Body.Length {

    public var hasBody: Bool {
        switch self {
        case .none: false
        case .length(let count): count > 0
        case .chunked, .untilClose, .tunnel: true
        }
    }

    public var fixed: Int? {
        switch self {
        case .none: 0
        case .length(let count): count
        case .chunked, .untilClose, .tunnel: nil
        }
    }

    public var isChunked: Bool {
        self == .chunked
    }

    public var isUntilClose: Bool {
        self == .untilClose
    }
}
