// HTTP.Framing.BodyLength.swift
// swift-rfc-9112
//
// RFC 9112 Section 6.3: Message Body Length
// https://www.rfc-editor.org/rfc/rfc9112.html#section-6.3
//
// The message body length determination, with a failure channel.

import INCITS_4_1986

extension RFC_9110.Framing {
    /// How the body of a message is delimited (RFC 9112 Section 6.3).
    ///
    /// Distinct from `RFC_9110.MessageBodyLength` in two ways that matter:
    ///
    /// - `determine` throws, so invalid framing cannot be returned as `.none`.
    /// - `.tunnel` is separate from `.none`, because a successful `CONNECT` does
    ///   not mean "no body, then the next message" — it means the connection
    ///   stops being a sequence of HTTP messages.
    public enum BodyLength: Sendable, Equatable, Hashable {
        /// No body is present and the connection remains a message sequence.
        case none

        /// A body of exactly this many octets.
        case length(Int)

        /// A chunked body, self-delimiting per Section 7.1.
        case chunked

        /// A body delimited by connection close (responses only).
        case untilClose

        /// A successful `CONNECT` response: the connection becomes a tunnel.
        case tunnel
    }
}

extension RFC_9110.Framing.BodyLength {
    /// Determines how a message body is delimited, per RFC 9112 Section 6.3.
    ///
    /// The rules are applied in the specification's order; the order is
    /// load-bearing, because `Transfer-Encoding` overrides `Content-Length` and
    /// the framing-header rules only apply to messages that can carry a body at
    /// all.
    ///
    /// - Throws: `RFC_9110.Framing.Error` when the framing is invalid. Section
    ///   6.3 requires these conditions to be detected; returning a value for
    ///   them is what produces request smuggling.
    public static func determine(
        context: RFC_9110.Framing.Context,
        headers: RFC_9110.Headers
    ) throws(RFC_9110.Framing.Error) -> Self {
        // Rules 1 and 2 — responses whose framing is fixed by their status or by
        // the method they answer, regardless of any framing header present.
        if case .response(let status, let requestMethod) = context {
            if requestMethod == .head { return .none }

            switch status.code {
            case 100..<200, 204, 304:
                return .none
            case 200..<300 where requestMethod == .connect:
                return .tunnel
            default:
                break
            }
        }

        let transferEncodings = headers.values("Transfer-Encoding")
        let contentLengths = headers.values("Content-Length")

        // Rule 3 — Transfer-Encoding, which overrides Content-Length.
        if !transferEncodings.isEmpty {
            // Section 6.3 rule 3: a message carrying both is to be handled as an
            // error. Reported specifically so a forwarding intermediary can obey
            // the MUST to strip Content-Length rather than guess.
            if !contentLengths.isEmpty {
                throw .transferEncodingWithContentLength
            }

            // RFC 9110 Section 5.3: multiple field lines with the same name are
            // equivalent to one field line whose value is the comma-joined list.
            // Finality must therefore be judged on the COMBINED list — chunked
            // last in the first of two field lines is not final overall — so the
            // combination happens before the parse, not after.
            let combined = transferEncodings.map(\.rawValue).joined(separator: ", ")

            guard let coding = RFC_9110.TransferEncoding.parse(combined) else {
                throw .malformedTransferEncoding(combined)
            }

            if coding.hasChunked {
                // `isChunkedFinal`, not `hasChunked`, is the conformant test.
                // Membership alone accepts `chunked, gzip`, which Section 6.3
                // requires a server to reject.
                if coding.isChunkedFinal { return .chunked }
                // Chunked present but not final: reject on the request side,
                // read until close on the response side.
                if context.isRequest { throw .chunkedNotFinal }
                return .untilClose
            }

            // Transfer-Encoding without chunked leaves a request undelimited.
            if context.isRequest { throw .transferEncodingWithoutChunked }
            return .untilClose
        }

        // Rules 4 and 5 — Content-Length.
        if !contentLengths.isEmpty {
            var seen: [String] = []

            for value in contentLengths {
                let raw = value.rawValue
                // A single field line may itself carry a comma-separated list.
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

        // Rules 6 and 7 — neither framing header present.
        return context.isRequest ? .none : .untilClose
    }
}

extension RFC_9110.Framing.BodyLength {
    /// True when the string is a non-empty sequence of ASCII digits.
    ///
    /// RFC 9112 Section 6.2 defines `Content-Length = 1*DIGIT`, so a leading
    /// sign, whitespace inside the token, or an empty value is invalid. Written
    /// against the ASCII range rather than a character-set helper to keep the
    /// check independent of locale and of Foundation.
    private static func isDigits(_ token: String) -> Bool {
        guard !token.isEmpty else { return false }
        return token.utf8.allSatisfy { $0 >= 0x30 && $0 <= 0x39 }  // '0'...'9'
    }
}
