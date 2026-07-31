// HTTP.Request.Line.ParsingError.swift
// swift-rfc-9112

extension RFC_9110.Request.Line {
    public enum ParsingError: Swift.Error, Sendable, Equatable {
        case invalidFormat(reason: String)
        case emptyMethod
        case emptyTarget
        case targetContainsWhitespace
        case invalidEncoding
        case invalidVersion(String)
    }
}
