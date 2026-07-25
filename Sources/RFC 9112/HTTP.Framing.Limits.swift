// HTTP.Framing.Limits.swift
// swift-rfc-9112
//
// RFC 9112 Section 3: Request Line (recipient size expectations)
// https://www.rfc-editor.org/rfc/rfc9112.html#section-3
//
// Bounds enforced during accumulation, not after it.

extension RFC_9110.Framing {
    /// Bounds a `Framer` enforces on what it will retain.
    ///
    /// These are checked **inside `append`, before the bytes are stored**. The
    /// distinction is the whole point: `Request.Line.validate(maxLength:)` in
    /// this package is a *post-parse* call on an already-reconstructed line, so
    /// it cannot prevent an over-long line from being accepted first. **A limit
    /// checkable only after acceptance is not a limit** — by the time it fires,
    /// the memory is already committed, which is the denial-of-service half of
    /// the whole-buffer problem rather than a conformance detail.
    public struct Limits: Sendable, Equatable, Hashable {
        /// Maximum octets in the start line.
        ///
        /// RFC 9112 Section 3: a recipient SHOULD support a request line of at
        /// least 8000 octets, so this is a floor for interoperability rather
        /// than a target.
        public var startLine: Int

        /// Maximum octets in the field section, terminator included.
        public var fieldSection: Int

        /// Maximum octets in a message body.
        ///
        /// Unused until body framing lands; carried here so the budget is
        /// declared in one place rather than appearing later as a second
        /// concept.
        public var body: Int

        public init(startLine: Int, fieldSection: Int, body: Int) {
            self.startLine = startLine
            self.fieldSection = fieldSection
            self.body = body
        }
    }
}

extension RFC_9110.Framing.Limits {
    /// The budget the framer may retain while no complete head has been
    /// yielded: everything before the body.
    public var headSection: Int { startLine + fieldSection }
}

extension RFC_9110.Framing.Limits {
    /// Interoperable defaults: an 8000-octet start line per RFC 9112 Section 3,
    /// a 64 KiB field section, and a 16 MiB body.
    ///
    /// Deliberately not "generous". A framer that accepts more than it can
    /// account for is the shape being replaced.
    public static let `default` = Self(
        startLine: 8_000,
        fieldSection: 64 * 1_024,
        body: 16 * 1_024 * 1_024
    )
}
