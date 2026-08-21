import INCITS_4_1986

extension RFC_9110 {

    public enum MessageBodyLength: Sendable, Equatable {

        case none

        case length(Int)

        case chunked

        case untilClose
    }
}

extension RFC_9110.MessageBodyLength {

    public static func calculate(
        for response: RFC_9110.Response,
        requestMethod: RFC_9110.Method
    ) -> Self {

        if requestMethod == .head {
            return .none
        }

        if response.status.code < 200 || response.status.code == 204
            || response.status.code == 304
        {
            return .none
        }

        if requestMethod == .connect && response.status.code >= 200
            && response.status.code < 300
        {
            return .none
        }

        if let teHeader = response.headers["Transfer-Encoding"]?.first?.description,
            let te = RFC_9110.TransferEncoding.parse(teHeader)
        {

            if te.hasChunked {
                return .chunked
            }
        }

        if let clHeaders = response.headers["Content-Length"], !clHeaders.isEmpty {

            if clHeaders.count > 1 {

                let values = clHeaders.map { $0.description }
                let uniqueValues = Set(values)
                if uniqueValues.count > 1 {

                    return .none
                }
            }

            if let clValue = clHeaders.first?.description.trimming(.ascii.whitespaces),
                let length = Int(clValue), length >= 0
            {
                return .length(length)
            }

            return .none
        }

        return .untilClose
    }

    public static func calculate(for request: RFC_9110.Request) -> Self {

        if let teHeader = request.headers["Transfer-Encoding"]?.first?.description,
            let te = RFC_9110.TransferEncoding.parse(teHeader)
        {
            if te.hasChunked {
                return .chunked
            }
        }

        if let clHeaders = request.headers["Content-Length"], !clHeaders.isEmpty {

            if clHeaders.count > 1 {
                let values = clHeaders.map { $0.description }
                let uniqueValues = Set(values)
                if uniqueValues.count > 1 {

                    return .none
                }
            }

            if let clValue = clHeaders.first?.description.trimming(.ascii.whitespaces),
                let length = Int(clValue), length >= 0
            {
                return .length(length)
            }

            return .none
        }

        return .none
    }

    public var hasBody: Bool {
        switch self {
        case .none:
            return false

        case .length(let len):
            return len > 0

        case .chunked, .untilClose:
            return true
        }
    }

    public var fixedLength: Int? {
        switch self {
        case .none:
            return 0

        case .length(let len):
            return len

        case .chunked, .untilClose:
            return nil
        }
    }

    public var isChunked: Bool {
        if case .chunked = self {
            return true
        }
        return false
    }

    public var isUntilClose: Bool {
        if case .untilClose = self {
            return true
        }
        return false
    }
}
