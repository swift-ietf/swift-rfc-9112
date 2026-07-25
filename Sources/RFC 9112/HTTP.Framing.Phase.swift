// HTTP.Framing.Phase.swift
// swift-rfc-9112
//
// RFC 9112 Section 2.1: Message Format
// https://www.rfc-editor.org/rfc/rfc9112.html#section-2.1
//
// Which part of a message the framer is accumulating, supplied per call.

extension RFC_9110.Framing {
    /// What the octets being appended belong to.
    ///
    /// A message is a head section followed by a body (RFC 9112 Section 2.1),
    /// and the two are bounded by **different budgets** — `Limits.headSection`
    /// and `Limits.body`. Something has to say which budget applies to the
    /// octets now arriving.
    ///
    /// ## Why the caller says it rather than the framer knowing it
    ///
    /// The framer is stateless about phase by design: body delimitation rides on
    /// `Framer.nextBody(_:)`, and the answered method rides on
    /// `Framer.nextResponseHead(answering:)`. The phase rides on
    /// `Framer.append(_:accumulating:)` for the same reason — the connection
    /// drive is what knows a body is in progress, because knowing that is what
    /// makes it a *connection* rather than a sequence of messages (Section 3.1).
    ///
    /// ## The defect this replaced
    ///
    /// `append` previously inferred the phase by scanning the buffer for an
    /// empty line, and the inference was wrong in **both** directions:
    ///
    /// - it **over-rejected** a body larger than `Limits.headSection` that
    ///   happened to contain no empty line, measuring a body against the head's
    ///   budget; and
    /// - it **under-protected** whenever a body *did* contain an empty line —
    ///   the head budget silently stopped applying, and nothing bounded
    ///   retention until `nextBody` was finally called, by which point the
    ///   octets were already stored. `Limits` exists to make that impossible:
    ///   a limit checkable only after acceptance is not a limit.
    ///
    /// Both directions were properties of the *guess*, not of the budgets. Being
    /// told removes the guess, so it removes the defect class rather than the
    /// instance.
    public enum Phase: Sendable, Equatable, Hashable {
        /// Start line and field section, bounded by `Limits.headSection`.
        case head

        /// Message body, bounded by `Limits.body`.
        ///
        /// The delimitation is deliberately **not** carried here. It would
        /// suggest `append` uses it, and `append` does not: the bound is
        /// `Limits.body` whichever way the body is delimited. A `Content-Length`
        /// body cannot be bounded by its own declared length either, because on
        /// a pipelined connection the buffer legitimately holds this body *and*
        /// the octets of messages behind it.
        case body
    }
}

extension RFC_9110.Framing.Phase {
    /// The retention budget that applies to octets arriving in this phase.
    internal func budget(under limits: RFC_9110.Framing.Limits) -> Int {
        switch self {
        case .head: limits.headSection
        case .body: limits.body
        }
    }

    /// The failure raised when this phase's budget would be exceeded.
    ///
    /// Each phase reports against the budget it actually overran, so a caller is
    /// never told a body was too long for the head section.
    internal func overrun(of budget: Int) -> RFC_9110.Framing.Error {
        switch self {
        case .head: .headSectionTooLong(limit: budget)
        case .body: .bodyTooLong(limit: budget)
        }
    }
}
