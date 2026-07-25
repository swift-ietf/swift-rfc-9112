// HTTP.Framing.Framer.Scan.swift
// swift-rfc-9112
//
// RFC 9112 Section 2.1: Message Format
// https://www.rfc-editor.org/rfc/rfc9112.html#section-2.1
//
// A head located in the buffer but not yet consumed from it.

extension RFC_9110.Framing.Framer {
    /// A complete head found in the buffer, described but **not yet removed**.
    ///
    /// The separation is deliberate. Scanning is fallible — a malformed field
    /// line, a bare CR, obsolete folding — and a scan that consumed as it went
    /// would leave the buffer half-advanced when it threw, which is precisely
    /// the desynchronised state the framer exists to prevent. So scanning
    /// reports where the head ends, and the caller removes exactly those octets
    /// only once the head is known to be well formed and its body length known.
    ///
    /// Failure therefore leaves the buffer byte-for-byte as it was.
    internal struct Scan {
        /// The start line, without its terminator.
        let startLine: String

        /// The parsed field section.
        let headers: RFC_9110.Headers

        /// Octets the head occupies, both the start-line terminator and the
        /// empty line that ends the field section included.
        let octets: Int
    }
}
