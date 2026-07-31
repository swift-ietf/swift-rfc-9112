// HTTP.MessageParser.LineTerminator.swift
// swift-rfc-9112

extension RFC_9110.MessageParser {
    /// Line terminator types
    public enum LineTerminator: Sendable, Equatable {
        case crlf  // Standard: CR LF (0x0D 0x0A)
        case lf  // Lenient: Single LF (0x0A)
        case none  // No terminator (end of data)
    }
}
