extension RFC_9110.Response {

    public enum Validator {}
}

extension RFC_9110.Response.Validator {

    public static func validate(_ response: RFC_9110.Response) throws(Error) {
        let headers = response.headers

        try validateContentLength(headers: Array(headers))

        let hasTransferEncoding = headers.contains {
            $0.name.description.lowercased() == "transfer-encoding"
        }
        if hasTransferEncoding {
            try validateTransferEncoding(headers: Array(headers))
        }

        guard response.status.code >= 100 && response.status.code < 600 else {
            throw Error.invalidStatusCode(response.status.code)
        }

        if hasTransferEncoding {
            let code = response.status.code
            if code / 100 == 1 || code == 204 || code == 304 {
                throw Error.transferEncodingWithIncompatibleStatus(code)
            }
        }

        if hasTransferEncoding {
            let hasContentLength = headers.contains {
                $0.name.description.lowercased() == "content-length"
            }
            if hasContentLength {
                throw Error.transferEncodingWithContentLength
            }
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

        let chunkedCount = transferEncodingHeaders.filter { header in
            RFC_9110.TransferEncoding.parse(header.value.description)?.hasChunked ?? false
        }.count

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
