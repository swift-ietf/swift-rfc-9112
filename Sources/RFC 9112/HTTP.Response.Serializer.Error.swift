// HTTP.Response.Serializer.Error.swift
// swift-rfc-9112

extension RFC_9110.Response.Serializer {
    /// A failure to serialize a structurally valid HTTP/1.1 response stream.
    public enum Error: Swift.Error, Sendable, Equatable {
        /// An event arrived outside head/body/end order.
        case transition

        /// The head's declared delimitation disagreed with RFC 9112 Section
        /// 6.3 because its framing fields were malformed.
        case framing(RFC_9110.Framing.Error)

        /// The head's declared body delimitation disagreed with the value
        /// determined from its status, request method, and fields.
        case delimitation(
            expected: RFC_9110.Framing.BodyLength,
            actual: RFC_9110.Framing.BodyLength
        )

        /// The status code was not the three-digit response syntax.
        case status(Int)

        /// The reason phrase contained an octet forbidden in a status line.
        case reason

        /// A field could not be lawfully emitted in this response position.
        case field(String)

        /// A body segment was supplied for a response that cannot carry one.
        case body

        /// A fixed-length body ended at a different length than declared.
        case mismatch(expected: Int, actual: Int)

        /// A body segment would exceed its declared fixed length.
        case exceeded(expected: Int, actual: Int)

        /// The cumulative body length overflowed `Int`.
        case overflow

        /// Trailers were supplied for a body not using chunked transfer coding,
        /// or a trailer field would alter message framing.
        case trailers

        /// `finish()` was called before the end event completed the response.
        case incomplete

        /// A prior serialization failure poisoned the state machine.
        case failed
    }
}
