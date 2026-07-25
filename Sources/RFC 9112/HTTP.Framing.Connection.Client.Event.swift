// HTTP.Framing.Connection.Client.Event.swift
// swift-rfc-9112
//
// RFC 9112 Section 6: Message Body
// https://www.rfc-editor.org/rfc/rfc9112.html#section-6
//
// What a client drive yields as a response arrives.

public import Byte_Primitives

extension RFC_9110.Framing.Connection.Client {
    /// One step of a response arriving.
    ///
    /// A drive yields **events rather than whole messages**, and the reason is
    /// not ergonomic. A close-delimited body (Section 6.3 rule 8) is *unbounded
    /// by construction*: its length is not declared anywhere, and its end is the
    /// connection closing. Returning a whole body would therefore mean
    /// accumulating until close with nothing able to bound it — reopening the
    /// bounded-retention hole that `Limits` exists to close. A whole-message
    /// return also has no way to express a tunnel, after which the octets are
    /// not HTTP messages at all.
    ///
    /// Every response yields `.head`, then **zero or more** `.body`, then
    /// exactly one `.end` — except a tunnel, which yields `.head` then
    /// `.tunnel` and nothing further.
    public enum Event: Sendable, Equatable {
        /// A framed response head.
        case head(RFC_9110.Framing.ResponseHead)

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
        ///     included. Reported for accounting; nothing needs it to locate the
        ///     next message, because the framer has already consumed exactly
        ///     this many octets itself.
        case end(trailers: RFC_9110.Headers, octets: Int)

        /// A successful `CONNECT`: the connection stops being a sequence of HTTP
        /// messages (RFC 9112 Section 9.3.3).
        ///
        /// No further event follows. Take the remaining octets with
        /// `Client.surrenderTunnel()`.
        case tunnel
    }
}
