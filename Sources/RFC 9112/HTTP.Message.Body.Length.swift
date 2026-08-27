import INCITS_4_1986

extension RFC_9112.Message.Body {
    public enum Length: Equatable {

        case none

        case length(Int)

        case chunked

        case untilClose
    }
}

extension RFC_9112.Message.Body.Length {

    public static func calculate<Content>(
        for response: RFC_9112.Message.Response<Content>,
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

        if let teHeader = response.headers[.transferEncoding].first?.description,
            let te = RFC_9112.Transfer.Encoding.parse(teHeader)
        {

            if te.hasChunked {
                return .chunked
            }
        }

        let clHeaders = response.headers[.contentLength]
        if !clHeaders.isEmpty {

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

    public static func calculate<Content>(
        for request: RFC_9112.Message.Request<Content>
    ) -> Self {

        if let teHeader = request.headers[.transferEncoding].first?.description,
            let te = RFC_9112.Transfer.Encoding.parse(teHeader)
        {
            if te.hasChunked {
                return .chunked
            }
        }

        let clHeaders = request.headers[.contentLength]
        if !clHeaders.isEmpty {

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
