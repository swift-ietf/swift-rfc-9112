// HTTP.Framing.Terminal.swift
// swift-rfc-9112
//
// RFC 9112 Section 8: Handling Incomplete Messages
// https://www.rfc-editor.org/rfc/rfc9112.html#section-8
//
// End-of-stream disposition.

extension RFC_9110.Framing {
    /// How a byte stream ended.
    ///
    /// This distinction is the reason `Framer.finish()` exists at all: a `nil`
    /// from a head-framing call means *"no complete head yet"*, which is
    /// indistinguishable from *"the peer closed mid-message"* until someone
    /// says the stream is over. RFC 9112 Section 8 is the normative treatment
    /// of incomplete messages, and it is the one section a whole-buffer parser
    /// cannot implement — a parser that requires the whole message has no
    /// representation for a partial one.
    public enum Terminal: Sendable, Equatable, Hashable {
        /// The stream ended on a message boundary with nothing buffered.
        case clean

        /// The stream ended with bytes still buffered, part-way through a
        /// message. The count is the number of unconsumed octets, which is
        /// diagnostic rather than recoverable.
        case truncated(unconsumed: Int)
    }
}
