// HTTP.Response.Validator.Error.swift
// swift-rfc-9112

extension RFC_9110.Response.Validator {
    public enum Error: Swift.Error, Sendable, Equatable {
        case invalidTransferEncoding(String)
        case invalidContentLength(reason: String)
        case multipleContentLengthValues([Int])
        case chunkedNotFinalEncoding
        case chunkedAppliedMultipleTimes
        case invalidStatusCode(Int)
        case transferEncodingWithIncompatibleStatus(Int)
        case transferEncodingWithContentLength
    }
}
