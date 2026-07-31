// HTTP.Header.Parser.ObsFoldPolicy.swift
// swift-rfc-9112

extension RFC_9110.Header.Parser {
    /// Handling policy for obsolete line folding
    public enum ObsFoldPolicy {
        case reject  // Return error (recommended for servers)
        case replaceWithSpace  // Replace with single space
        case discard  // Remove the obs-fold entirely
    }
}
