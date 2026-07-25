// HTTP.Framing.Connection.Server.Event.swift
// swift-rfc-9112
//
// RFC 9112 Section 6: Message Body
// https://www.rfc-editor.org/rfc/rfc9112.html#section-6
//
// What a server drive yields as a request arrives.

public import Byte_Primitives

extension RFC_9110.Framing.Connection.Server {
    /// One step of a request arriving.
    ///
    /// Every request yields `.head`, then **zero or more** `.body`, then exactly
    /// one `.end`.
    ///
    /// There is no `tunnel` case, and no close-delimited body to stream. RFC
    /// 9112 Section 6.3 gives `.untilClose` and `.tunnel` to responses only, so
    /// a request body is always self-delimiting — `Content-Length`, `chunked`,
    /// or absent. The server drive is smaller than the client drive for that
    /// reason rather than by omission, which is why they are separate types: one
    /// type spanning both roles would carry a case this side can never reach.
    public enum Event: Sendable, Equatable {
        /// A framed request head.
        case head(RFC_9110.Framing.RequestHead)

        /// Payload octets, already decoded.
        ///
        /// For a chunked body this is the decoded content, with chunk framing
        /// removed; the framing octets are counted in `end`'s `octets` and
        /// appear here nowhere.
        case body([Byte])

        /// The body is complete.
        ///
        /// - Parameters:
        ///   - trailers: the trailer section (chunked bodies only).
        ///   - octets: the body's **true wire length**, all framing overhead
        ///     included.
        case end(trailers: RFC_9110.Headers, octets: Int)
    }
}
