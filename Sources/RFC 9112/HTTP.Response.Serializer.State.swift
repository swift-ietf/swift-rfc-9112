// HTTP.Response.Serializer.State.swift
// swift-rfc-9112

extension RFC_9110.Response.Serializer {
    /// The structural position of an incremental response.
    internal enum State: Sendable, Equatable {
        /// Awaiting the response head.
        case head

        /// Emitting a body with this delimitation and this many content octets
        /// already accepted.
        case body(RFC_9110.Framing.BodyLength, octets: Int)

        /// The end event was emitted successfully.
        case end

        /// A serialization error made further output unsafe.
        case failed
    }
}
