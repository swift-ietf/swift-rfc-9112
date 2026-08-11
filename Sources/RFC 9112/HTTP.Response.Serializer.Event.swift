// HTTP.Response.Serializer.Event.swift
// swift-rfc-9112
//
// RFC 9112 Sections 2.1, 6.3, and 7.1

public import Byte_Primitives

extension RFC_9110.Response.Serializer {
    /// One structural event in an outbound response.
    ///
    /// A response is exactly one `head`, followed by zero or more `body`
    /// events, followed by exactly one `end`. The request method accompanies
    /// the head because RFC 9112 Section 6.3 makes the response framing depend
    /// on whether it answers `HEAD` or `CONNECT`.
    public enum Event: Sendable, Equatable {
        /// The response head and the method of the request it answers.
        case head(RFC_9110.Framing.ResponseHead, answering: RFC_9110.Method)

        /// One owned segment of response content octets.
        case body([Byte])

        /// The response body is complete, with any dynamically produced
        /// trailer fields.
        case end(trailers: RFC_9110.Headers)
    }
}
