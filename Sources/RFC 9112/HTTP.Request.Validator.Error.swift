// HTTP.Request.Validator.Error.swift
// swift-rfc-9112

extension RFC_9110.Request.Validator {
    public enum Error: Swift.Error, Sendable, Equatable {
        case ambiguousMessageFraming(reason: String)
        case invalidTransferEncoding(String)
        case invalidContentLength(reason: String)
        case multipleContentLengthValues([Int])
        case chunkedNotFinalEncoding
        case chunkedAppliedMultipleTimes
    }
}
