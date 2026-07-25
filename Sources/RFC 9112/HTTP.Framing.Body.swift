// HTTP.Framing.Body.swift
// swift-rfc-9112
//
// RFC 9112 Section 6: Message Body
// RFC 9112 Section 7.1: Chunked Transfer Coding
// https://www.rfc-editor.org/rfc/rfc9112.html#section-6
//
// A framed message body, delivered whole, with its exact consumed count.

public import Byte_Primitives

extension RFC_9110.Framing {
    /// A fully-received message body, together with the exact number of octets
    /// it consumed from the wire.
    ///
    /// `content` is the decoded payload; `octets` is what the framer removed
    /// from its buffer to produce it. For an identity (`Content-Length`) body
    /// the two are equal. **For a chunked body they are not** — `octets`
    /// includes every chunk-size line, chunk extension, inter-chunk CRLF, the
    /// terminating zero chunk, the trailer section and the final CRLF, none of
    /// which appear in `content`.
    ///
    /// That gap is the whole subject of the defect this type closes. A consumed
    /// count estimated from the decoded size (`Message.Deserializer` does
    /// exactly this) under-counts by precisely the framing overhead, and the
    /// octets it under-counts by become the start of the next message on a
    /// reused connection — request smuggling (RFC 9112 Section 11.2). Because
    /// the framer reports the true consumed count and removes exactly that many
    /// octets itself, a caller never derives the boundary and so cannot derive
    /// it wrongly.
    public struct Body: Sendable, Equatable {
        /// The decoded payload octets.
        public let content: [Byte]

        /// Octets consumed from the wire, all framing overhead included.
        public let octets: Int

        /// The trailer section (chunked bodies only; empty otherwise).
        public let trailers: RFC_9110.Headers

        public init(content: [Byte], octets: Int, trailers: RFC_9110.Headers) {
            self.content = content
            self.octets = octets
            self.trailers = trailers
        }
    }
}
