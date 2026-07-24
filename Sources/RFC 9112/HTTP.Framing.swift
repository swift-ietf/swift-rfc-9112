// HTTP.Framing.swift
// swift-rfc-9112
//
// RFC 9112 Section 6: Message Body
// https://www.rfc-editor.org/rfc/rfc9112.html#section-6
//
// Namespace for incremental HTTP/1.1 message framing.

extension RFC_9110 {
    /// Incremental HTTP/1.1 message framing (RFC 9112 Sections 6 and 7).
    ///
    /// ## Why this exists beside `MessageBodyLength`
    ///
    /// `MessageBodyLength.calculate` is non-throwing and returns `.none` for
    /// framing it has detected to be *invalid* — the same value it returns for a
    /// legitimately body-less message. A recipient therefore cannot distinguish
    /// "this message has no body" from "this message's framing is malformed",
    /// and the bytes that follow become the next message. That is the
    /// Content-Length desync primitive, reached through the clause whose purpose
    /// is to prevent it.
    ///
    /// The root cause is a *total signature over a partial operation*: the
    /// operation can fail, the signature cannot express failure, so failure
    /// relocates to the nearest legal-looking value.
    ///
    /// `Framing.BodyLength.determine` is the corrected form. It throws, so an
    /// invalid framing cannot be mistaken for a valid one, and it reports the
    /// conditions RFC 9112 requires a recipient to be able to act on.
    ///
    /// It is introduced alongside the existing type rather than replacing it
    /// because changing `calculate`'s signature is a source-breaking change to a
    /// live L2 package, which is sequenced separately with a consumer gate.
    public enum Framing {}
}
