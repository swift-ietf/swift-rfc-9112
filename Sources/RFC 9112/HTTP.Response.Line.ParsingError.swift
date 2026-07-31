// HTTP.Response.Line.ParsingError.swift
// swift-rfc-9112

extension RFC_9110.Response.Line {
    public enum ParsingError: Swift.Error, Sendable, Equatable {
        case invalidFormat(reason: String)
        case invalidStatusCode(String)
        case statusCodeOutOfRange(Int)
        case invalidEncoding
    }
}
