// HTTP.Response.Serializer+Incremental.swift
// swift-rfc-9112
//
// RFC 9112 Sections 2.1, 4, 6.1-6.3, and 7.1

public import Byte_Primitives

extension RFC_9110.Response.Serializer {
    /// Serializes one response event to an owned, bounded wire segment.
    ///
    /// The returned allocation is bounded by the event: a head emits only its
    /// status line and fields, a body emits only that segment and its chunk
    /// framing, and an end emits only the last chunk and trailers. No operation
    /// buffers the complete response.
    ///
    /// After any error the serializer is poisoned and rejects every later
    /// event. This prevents a caller from continuing a wire response after an
    /// ambiguous partial transition.
    public mutating func serialize(_ event: Event) throws(Error) -> [Byte] {
        do throws(Error) {
            return try serializeEvent(event)
        } catch {
            state = .failed
            throw error
        }
    }

    /// Declares that no further response event will be supplied.
    ///
    /// An end event must already have completed the response; otherwise the
    /// message is incomplete and cannot be put on a persistent connection.
    /// An incomplete finish poisons the serializer like every other failure.
    public mutating func finish() throws(Error) {
        switch state {
        case .end:
            return

        case .failed:
            throw .failed

        case .head, .body:
            state = .failed
            throw .incomplete
        }
    }

    /// Whether the response end has been emitted successfully.
    public var isFinished: Bool {
        if case .end = state { return true }
        return false
    }
}

extension RFC_9110.Response.Serializer {
    private mutating func serializeEvent(_ event: Event) throws(Error) -> [Byte] {
        switch (state, event) {
        case (.head, .head(let head, let requestMethod)):
            let bytes = try Self.serializeHead(head, answering: requestMethod)
            state = .body(head.bodyLength, octets: 0)
            return bytes

        case (.body(let delimitation, let octets), .body(let content)):
            return try serializeBody(content, delimitation: delimitation, octets: octets)

        case (.body(let delimitation, let octets), .end(let trailers)):
            let bytes = try Self.serializeEnd(
                trailers,
                delimitation: delimitation,
                octets: octets
            )
            state = .end
            return bytes

        case (.failed, _):
            throw .failed

        case (.head, .body), (.head, .end), (.body, .head), (.end, _):
            throw .transition
        }
    }
}

extension RFC_9110.Response.Serializer {
    private static func serializeHead(
        _ head: RFC_9110.Framing.ResponseHead,
        answering requestMethod: RFC_9110.Method
    ) throws(Error) -> [Byte] {
        guard (100...999).contains(head.line.statusCode) else {
            throw .status(head.line.statusCode)
        }
        guard isReason(head.line.reasonPhrase) else {
            throw .reason
        }

        let transferEncodings = head.headers.values("Transfer-Encoding")
        let contentLengths = head.headers.values("Content-Length")
        let transferEncoding = !transferEncodings.isEmpty
        let contentLength = !contentLengths.isEmpty
        if transferEncoding && contentLength {
            throw .framing(.transferEncodingWithContentLength)
        }

        let statusCode = head.line.statusCode
        let tunnel = (200..<300).contains(statusCode) && requestMethod == .connect
        if (100..<200).contains(statusCode) || statusCode == 204 || tunnel {
            if transferEncoding { throw .field("Transfer-Encoding") }
            if contentLength { throw .field("Content-Length") }
        }

        if transferEncoding {
            let combined = transferEncodings.map(\.description).joined(separator: ", ")
            guard let coding = RFC_9110.TransferEncoding.parse(combined) else {
                throw .framing(.malformedTransferEncoding(combined))
            }
            if coding.hasChunked && !coding.isChunkedFinal {
                throw .framing(.chunkedNotFinal)
            }
        }

        let determined: RFC_9110.Framing.BodyLength
        do throws(RFC_9110.Framing.Error) {
            // Section 6.3 determines no-body responses before consulting their
            // framing fields. A sender must still generate valid field values,
            // so validate those fields once in a body-bearing context before
            // determining the actual response.
            _ = try RFC_9110.Framing.BodyLength.determine(
                context: .response(statusCode: 200, requestMethod: .get),
                headers: head.headers
            )
            determined = try RFC_9110.Framing.BodyLength.determine(
                context: .response(statusCode: statusCode, requestMethod: requestMethod),
                headers: head.headers
            )
        } catch {
            throw .framing(error)
        }
        guard determined == head.bodyLength else {
            throw .delimitation(expected: determined, actual: head.bodyLength)
        }

        var bytes = [Byte]()
        bytes.append(contentsOf: head.line.formatted.utf8.map(Byte.init))
        bytes.append(contentsOf: [0x0D, 0x0A])
        try append(head.headers, to: &bytes)
        bytes.append(contentsOf: [0x0D, 0x0A])
        return bytes
    }

    private mutating func serializeBody(
        _ content: [Byte],
        delimitation: RFC_9110.Framing.BodyLength,
        octets: Int
    ) throws(Error) -> [Byte] {
        switch delimitation {
        case .none, .tunnel:
            guard content.isEmpty else { throw .body }
            return []

        case .untilClose:
            let (total, overflow) = octets.addingReportingOverflow(content.count)
            guard !overflow else { throw .overflow }
            state = .body(delimitation, octets: total)
            return content

        case .length(let expected):
            guard expected >= 0 else {
                throw .framing(.invalidContentLength(String(expected)))
            }
            let (total, overflow) = octets.addingReportingOverflow(content.count)
            guard !overflow else { throw .overflow }
            guard total <= expected else {
                throw .exceeded(expected: expected, actual: total)
            }
            state = .body(delimitation, octets: total)
            return content

        case .chunked:
            guard !content.isEmpty else { return [] }
            let (total, overflow) = octets.addingReportingOverflow(content.count)
            guard !overflow else { throw .overflow }
            state = .body(delimitation, octets: total)

            var bytes = String(content.count, radix: 16).utf8.map(Byte.init)
            bytes.append(contentsOf: [0x0D, 0x0A])
            bytes.append(contentsOf: content)
            bytes.append(contentsOf: [0x0D, 0x0A])
            return bytes
        }
    }

    private static func serializeEnd(
        _ trailers: RFC_9110.Headers,
        delimitation: RFC_9110.Framing.BodyLength,
        octets: Int
    ) throws(Error) -> [Byte] {
        switch delimitation {
        case .length(let expected):
            guard trailers.isEmpty else { throw .trailers }
            guard octets == expected else {
                throw .mismatch(expected: expected, actual: octets)
            }
            return []

        case .none, .tunnel, .untilClose:
            guard trailers.isEmpty else { throw .trailers }
            return []

        case .chunked:
            guard trailers.values("Content-Length").isEmpty,
                trailers.values("Transfer-Encoding").isEmpty,
                trailers.values("Trailer").isEmpty
            else {
                throw .trailers
            }

            var bytes: [Byte] = [0x30, 0x0D, 0x0A]
            try append(trailers, to: &bytes)
            bytes.append(contentsOf: [0x0D, 0x0A])
            return bytes
        }
    }
}

extension RFC_9110.Response.Serializer {
    private static func append(
        _ headers: RFC_9110.Headers,
        to bytes: inout [Byte]
    ) throws(Error) {
        for field in headers {
            let name = field.name.description
            let value = field.value.description
            guard isFieldName(name), !value.utf8.contains(0x0D), !value.utf8.contains(0x0A) else {
                throw .field(name)
            }
            bytes.append(contentsOf: name.utf8.map(Byte.init))
            bytes.append(contentsOf: [0x3A, 0x20])
            bytes.append(contentsOf: value.utf8.map(Byte.init))
            bytes.append(contentsOf: [0x0D, 0x0A])
        }
    }

    private static func isReason(_ reason: String?) -> Bool {
        guard let reason else { return true }
        return reason.utf8.allSatisfy { octet in
            octet == 0x09 || (octet >= 0x20 && octet != 0x7F)
        }
    }

    private static func isFieldName(_ name: String) -> Bool {
        guard !name.isEmpty else { return false }
        return name.utf8.allSatisfy { octet in
            switch octet {
            case 0x30...0x39, 0x41...0x5A, 0x61...0x7A,
                0x21, 0x23, 0x24, 0x25, 0x26, 0x27, 0x2A, 0x2B, 0x2D,
                0x2E, 0x5E, 0x5F, 0x60, 0x7C, 0x7E:
                true

            default:
                false
            }
        }
    }
}
