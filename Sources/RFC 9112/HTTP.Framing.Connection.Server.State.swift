// HTTP.Framing.Connection.Server.State.swift
// swift-rfc-9112
//
// RFC 9112 Section 3.1: Message Parsing
// https://www.rfc-editor.org/rfc/rfc9112.html#section-3.1
//
// Where a server drive is in the message it is reading.

extension RFC_9110.Framing.Connection.Server {
    /// Which part of a request the drive is reading.
    ///
    /// This is the body-phase state the framer deliberately does not hold, and
    /// it does two jobs: it tells `Framer.append(_:accumulating:)` which budget
    /// applies to arriving octets, and it makes framing the next head **while a
    /// body is outstanding** unrepresentable rather than merely discouraged.
    internal enum State: Sendable, Equatable {
        /// Awaiting a request head.
        case head

        /// Reading a body delimited this way. Carries the delimitation because
        /// `Framer.nextBody(_:)` is stateless and must be handed it back.
        case body(RFC_9110.Framing.BodyLength)

        /// The connection will carry no further request: a message declared
        /// `Connection: close` (RFC 9112 Section 9.6).
        case finished
    }
}

extension RFC_9110.Framing.Connection.Server.State {
    /// The accumulation phase implied by this state.
    internal var phase: RFC_9110.Framing.Phase {
        switch self {
        case .head, .finished: .head
        case .body: .body
        }
    }
}
