// HTTP.Framing.Connection.Client.State.swift
// swift-rfc-9112
//
// RFC 9112 Section 3.1: Message Parsing
// https://www.rfc-editor.org/rfc/rfc9112.html#section-3.1
//
// Where a client drive is in the message it is reading.

extension RFC_9110.Framing.Connection.Client {
    /// Which part of a response the drive is reading.
    ///
    /// This is the body-phase state the framer deliberately does not hold. It
    /// lives here because it is what makes a connection more than a sequence of
    /// messages: only something tracking a body in progress can tell
    /// `Framer.append(_:accumulating:)` which budget applies, and only something
    /// that knows a body is outstanding can refuse to frame the next head
    /// before it completes.
    internal enum State: Sendable, Equatable {
        /// Awaiting a response head.
        case head

        /// Reading a body delimited this way. Carries the delimitation because
        /// `Framer.nextBody(_:)` is stateless and must be handed it back.
        case body(RFC_9110.Framing.BodyLength)

        /// A tunnel was established; these octets are no longer HTTP messages.
        case tunnelled

        /// The connection will carry no further message — either the peer closed
        /// after a close-delimited body, or a message declared
        /// `Connection: close` (RFC 9112 Section 9.6).
        case finished
    }
}

extension RFC_9110.Framing.Connection.Client.State {
    /// The accumulation phase implied by this state.
    ///
    /// The single place the drive's state is translated into a budget, so a
    /// state that reads a body cannot be fed octets under the head's budget.
    internal var phase: RFC_9110.Framing.Phase {
        switch self {
        case .head, .tunnelled, .finished: .head
        case .body: .body
        }
    }
}
