// HTTP.Framing.Error.swift
// swift-rfc-9112
//
// RFC 9112 Section 6.3: Message Body Length
// RFC 9112 Section 11.2: Request Smuggling
// https://www.rfc-editor.org/rfc/rfc9112.html#section-11.2
//
// The failure channel that lets invalid framing be invalid.

extension RFC_9110.Framing {
    /// A framing failure.
    ///
    /// Every case here is a condition RFC 9112 Section 6.3 requires a recipient
    /// to detect. The existing non-throwing `MessageBodyLength.calculate`
    /// detects several of them and then returns `.none`, which is
    /// indistinguishable from a legitimately body-less message — so the trailing
    /// bytes become the next message on a reused connection. Section 11.2 names
    /// that outcome request smuggling.
    ///
    /// Each case names the specific condition rather than collapsing to a single
    /// "invalid framing", because Section 6.3 permits different responses to
    /// different conditions: an intermediary that chooses to forward a message
    /// carrying both `Transfer-Encoding` and `Content-Length` **must** strip the
    /// `Content-Length` first, and it can only do that if it is told which
    /// condition occurred.
    public enum Error: Swift.Error, Sendable, Equatable, Hashable {
        /// A `Content-Length` value was not a non-empty sequence of digits.
        ///
        /// Section 6.3 rule 4: a single `Content-Length` field with an invalid
        /// value makes the message framing invalid.
        case invalidContentLength(String)

        /// Multiple `Content-Length` values disagreed.
        ///
        /// Section 6.3 rule 4. Identical repeated values are *not* an error and
        /// do not reach this case.
        case conflictingContentLength([String])

        /// Both `Transfer-Encoding` and `Content-Length` were present.
        ///
        /// Section 6.3 rule 3: `Transfer-Encoding` overrides `Content-Length`,
        /// and such a message "ought to be handled as an error" because it may be
        /// an attempt at request smuggling (Section 11.2) or response splitting
        /// (Section 11.1). An intermediary that forwards it MUST first remove the
        /// `Content-Length`; this case is what tells it to.
        case transferEncodingWithContentLength

        /// `Transfer-Encoding` was present and `chunked` was not its final coding.
        ///
        /// Section 6.3 rule 3: chunked MUST be the final encoding when present.
        /// Only raised for requests; a response in this state reads until close.
        case chunkedNotFinal

        /// `Transfer-Encoding` was present on a request without `chunked` at all,
        /// leaving the message with no way to determine its own length.
        ///
        /// Only raised for requests; a response in this state reads until close.
        case transferEncodingWithoutChunked

        /// A `Transfer-Encoding` value could not be parsed as a transfer coding.
        case malformedTransferEncoding(String)

        // MARK: - Framing (incremental)

        /// The head section exceeded its budget before a complete head arrived.
        ///
        /// Raised by `Framer.append` **before** the offending bytes are retained.
        /// A limit that can only be checked after acceptance is not a limit: the
        /// memory has already been committed by the time it fires.
        case headSectionTooLong(limit: Int)

        /// The start line was not well formed.
        case malformedStartLine(String)

        /// A field line was not `name: value`.
        case malformedFieldLine(String)

        /// A bare CR appeared outside a CRLF pair.
        ///
        /// RFC 9112 Section 2.2 forbids generating one, and Section 11.1 makes
        /// accepting one a response-splitting vector, because a recipient that
        /// treats bare CR as a line terminator can be desynchronised from one
        /// that does not.
        case bareCarriageReturn

        /// A field line began with whitespace (obsolete line folding).
        ///
        /// RFC 9112 Section 5.2: a recipient MUST either reject the message or
        /// replace the folding with SP before interpreting it. This
        /// implementation rejects, because forwarding a folded field is a
        /// request-smuggling vector (Section 11.2) when a downstream recipient
        /// unfolds differently.
        case obsoleteLineFolding

        /// The stream ended part-way through a message.
        case truncatedMessage
    }
}
