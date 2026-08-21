extension RFC_9110.Request {

    public enum Validator {}
}

extension RFC_9110.Request.Validator {

    public static func validate(_ request: RFC_9110.Request) throws(Error) {
        let headers = request.headers

        let hasTransferEncoding = headers.contains {
            $0.name.description.lowercased() == "transfer-encoding"
        }
        let hasContentLength = headers.contains {
            $0.name.description.lowercased() == "content-length"
        }

        if hasTransferEncoding && hasContentLength {
            throw Error.ambiguousMessageFraming(
                reason: "Request contains both Transfer-Encoding and Content-Length"
            )
        }

        if hasTransferEncoding {
            try validateTransferEncoding(headers: Array(headers))
        }

        if hasContentLength {
            try validateContentLength(headers: Array(headers))
        }
    }

    private static func validateTransferEncoding(headers: [RFC_9110.Header.Field]) throws(Error) {
        let transferEncodingHeaders = headers.filter {
            $0.name.description.lowercased() == "transfer-encoding"
        }

        guard !transferEncodingHeaders.isEmpty else {
            return
        }

        for header in transferEncodingHeaders {
            guard let te = RFC_9110.TransferEncoding.parse(header.value.description) else {
                throw Error.invalidTransferEncoding(header.value.description)
            }

            if te.hasChunked && !te.isChunkedFinal {
                throw Error.chunkedNotFinalEncoding
            }
        }

        var chunkedCount = 0
        for header in transferEncodingHeaders {
            if let te = RFC_9110.TransferEncoding.parse(header.value.description) {

                chunkedCount += te.chunkedCount
            }
        }

        if chunkedCount > 1 {
            throw Error.chunkedAppliedMultipleTimes
        }
    }

    private static func validateContentLength(headers: [RFC_9110.Header.Field]) throws(Error) {
        let contentLengthHeaders = headers.filter {
            $0.name.description.lowercased() == "content-length"
        }

        guard contentLengthHeaders.count > 1 else {
            return
        }

        let values = contentLengthHeaders.compactMap { Int($0.value.description) }

        guard values.count == contentLengthHeaders.count else {
            throw Error.invalidContentLength(reason: "Non-integer Content-Length value")
        }

        guard Set(values).count == 1 else {
            throw Error.multipleContentLengthValues(values)
        }
    }

}
