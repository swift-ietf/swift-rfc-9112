// HTTP.Framing.ResponseHead.swift
// swift-rfc-9112
//
// RFC 9112 Section 2.1: Message Format
// https://www.rfc-editor.org/rfc/rfc9112.html#section-2.1
//
// A framed response head: everything before the body.

extension RFC_9110.Framing {
    /// A complete response head — status line and field section — together with
    /// how the body that follows it is delimited.
    ///
    /// See `RequestHead` for why this is a separate type rather than one type
    /// with an optional start line.
    public struct ResponseHead: Sendable, Equatable {
        /// The parsed status line (version, status code, reason phrase).
        public let line: RFC_9110.Response.Line

        /// The parsed field section.
        public let headers: RFC_9110.Headers

        /// How the body that follows is delimited, per RFC 9112 Section 6.3.
        ///
        /// For a response this depends on the method of the request being
        /// answered — `HEAD` has no body whatever the headers say, and a 2xx to
        /// `CONNECT` is a tunnel — which is why it is supplied per exchange to
        /// `Framer.nextResponseHead(answering:)` rather than fixed when the
        /// framer is constructed.
        public let bodyLength: BodyLength

        /// Octets consumed from the stream by this head, terminator included.
        public let octets: Int

        public init(
            line: RFC_9110.Response.Line,
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
