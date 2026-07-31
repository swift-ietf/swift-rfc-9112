// HTTP.Request.Line.Error.swift
// swift-rfc-9112

extension RFC_9110.Request.Line {
    public enum Error: Swift.Error, Sendable, Equatable {
        case lineTooLong(length: Int, max: Int)
    }
}
