// HTTP.Framing.Connection.swift
// swift-rfc-9112
//
// RFC 9112 Section 3.1: Message Parsing (message vs connection)
// RFC 9112 Section 9: Connection Management
// https://www.rfc-editor.org/rfc/rfc9112.html#section-9
//
// The connection drive: the three facts the framer refuses to know.

extension RFC_9110.Framing {
    /// Drives a `Framer` across a whole connection.
    ///
    /// The framer knows **messages**. A connection is more than a sequence of
    /// them, and RFC 9112 Section 3.1 is that split. This namespace holds the
    /// two drives, and each adds exactly the facts a message-scoped framer
    /// cannot hold:
    ///
    /// 1. **Phase** — whether the octets arriving belong to a head or a body, so
    ///    `Framer.append(_:accumulating:)` applies the right budget *before*
    ///    retaining them.
    /// 2. **Whether the peer has closed** — the terminator for a close-delimited
    ///    body, which is why `Framer.nextBody(_:)` returns `nil` for
    ///    `.untilClose` and `.tunnel`.
    /// 3. **The per-exchange method sequence** — so a pipelined response frames
    ///    against the request it actually answers (`Client` only).
    ///
    /// What the drives do **not** do is account for octets. Every consumed count
    /// stays inside the framer, and a drive never computes an offset into
    /// anything — the property that makes the consumed-count defect class
    /// unreachable rather than merely fixed. Self-delimiting bodies are
    /// delegated to `Framer.nextBody(_:)` unchanged; a drive implements only
    /// what the framer structurally cannot, which is delivery of a body whose
    /// terminator is not in the byte stream.
    ///
    /// ## Two types, not one
    ///
    /// `Server` reads requests; `Client` reads responses and holds the method
    /// queue. A single type with a role field would permit a server drive
    /// carrying a queue it can never use, which is the wrong-combination
    /// signature that keeping a construction-time role on the framer would have
    /// been. The split is confirmed by measurement rather than taste:
    /// `BodyLength.determine` yields `.untilClose` and `.tunnel` **only** on the
    /// response arm, so a request body is never close-delimited and `Server`
    /// structurally cannot need close-delimited delivery.
    ///
    /// ## ⚠️ Name shadowing
    ///
    /// This type shares its name with `RFC_9110.Connection`, the **`Connection`
    /// header field** (RFC 9110 Section 7.6.1). They are unrelated: that one is
    /// a parsed field value, this one drives a byte stream. Inside
    /// `extension RFC_9110.Framing { … }` the bare name `Connection` resolves to
    /// **this** type, so the header field must be spelled `RFC_9110.Connection`
    /// in full there.
    public enum Connection {}
}
