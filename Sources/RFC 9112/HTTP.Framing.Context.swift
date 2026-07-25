// HTTP.Framing.Context.swift
// swift-rfc-9112
//
// RFC 9112 Section 6.3: Message Body Length
// https://www.rfc-editor.org/rfc/rfc9112.html#section-6.3
//
// The message's role, carrying exactly the data that role needs.

extension RFC_9110.Framing {
    /// Which side of the exchange is being framed, and the context that side
    /// requires to determine body length.
    ///
    /// RFC 9112 Section 6.3 gives requests and responses *different* dispositions
    /// for the same malformed input. A `Transfer-Encoding` whose final coding is
    /// not `chunked` must be rejected on the request side and read until close on
    /// the response side; a request with neither framing header has no body,
    /// while a response with neither reads until close.
    ///
    /// Making the role a construction parameter rather than a flag consulted
    /// midway means a single shared code path that is correct for one side and
    /// wrong for the other cannot be written. The response case additionally
    /// carries the request's method, because Section 6.3 rules 1 and 2 make the
    /// response's framing depend on it (`HEAD`, and a successful `CONNECT`).
    public enum Context: Sendable, Equatable, Hashable {
        /// A request being framed by a server.
        case request

        /// A response being framed by a client, together with the method of the
        /// request it answers.
        ///
        /// The status is carried as its numeric code rather than as a
        /// `RFC_9110.Status`, because Section 6.3 reasons about **ranges** —
        /// 1xx, 204, 304, and 2xx-to-`CONNECT`. A registered-status type would
        /// be over-specified for that and would leave an unregistered code
        /// unframeable, when in fact an unknown 2xx must still frame correctly.
        case response(statusCode: Int, requestMethod: RFC_9110.Method)
    }
}

extension RFC_9110.Framing.Context {
    /// Whether this context frames a request.
    ///
    /// Used where Section 6.3 prescribes reject-on-request but tolerate-on-response.
    public var isRequest: Bool {
        switch self {
        case .request: true
        case .response: false
        }
    }
}
