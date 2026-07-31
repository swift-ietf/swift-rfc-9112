// HTTP.Pipeline.PendingRequest.swift
// swift-rfc-9112

extension RFC_9110.Pipeline {
    /// Pending request information
    struct PendingRequest: Sendable {
        let method: RFC_9110.Method
        let timestamp: RFC_9110.Date
    }
}
