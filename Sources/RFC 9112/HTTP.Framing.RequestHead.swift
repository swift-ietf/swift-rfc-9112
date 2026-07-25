// HTTP.Framing.RequestHead.swift
// swift-rfc-9112
//
// RFC 9112 Section 2.1: Message Format
// https://www.rfc-editor.org/rfc/rfc9112.html#section-2.1
//
// A framed request head: everything before the body.

extension RFC_9110.Framing {
    /// A complete request head — start line and field section — together with
    /// how the body that follows it is delimited.
    ///
    /// Separate from `ResponseHead` rather than one type with optional members,
    /// because a single type would need a `requestLine`/`statusLine` pair of
    /// which exactly one is populated. That is a value that can be constructed
    /// wrongly; two total types cannot be.
    public struct RequestHead: Sendable, Equatable {
        /// The parsed request line (method, target, version).
        public let line: RFC_9110.Request.Line

        /// The parsed field section.
        public let headers: RFC_9110.Headers

        /// How the body that follows is delimited, determined per RFC 9112
        /// Section 6.3 at the moment the head was framed — while the headers
        /// that decide it are in hand, rather than left for a caller to
        /// re-derive and possibly re-derive differently.
        public let bodyLength: BodyLength

        /// Octets consumed from the stream by this head, terminator included.
        ///
        /// Reported for accounting and tests. It is **not** required to locate
        /// the body: the framer has already removed exactly these octets from
        /// its own buffer, so a caller never computes an offset. That is the
        /// property that makes an inexact consumed count unreachable rather
        /// than merely corrected.
        public let octets: Int

        public init(
            line: RFC_9110.Request.Line,
            headers: RFC_9110.Headers,
            bodyLength: BodyLength,
            octets: Int
        ) {
            self.line = line
            self.headers = headers
            self.bodyLength = bodyLength
            self.octets = octets
        }
    }
}
