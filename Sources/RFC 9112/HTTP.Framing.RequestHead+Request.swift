// HTTP.Framing.RequestHead+Request.swift
// swift-rfc-9112

extension RFC_9110.Framing.RequestHead {
    /// Produces the protocol-independent semantic request head represented by
    /// this framed HTTP/1.1 head.
    ///
    /// Method and fields are preserved verbatim, while the raw request-target
    /// is parsed into its typed RFC 9110 form. `RFC_9110.Request.Head` does not
    /// carry a protocol version; the validated wire version remains available
    /// from this value's `line.version`.
    public func request() throws(RFC_9110.Request.Target.ParsingError) -> RFC_9110.Request.Head {
        .init(
            method: line.method,
            target: try RFC_9110.Request.Target.parse(line.target, method: line.method),
            headers: headers
        )
    }
}
