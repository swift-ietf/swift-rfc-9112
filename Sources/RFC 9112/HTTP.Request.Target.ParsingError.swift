// HTTP.Request.Target.ParsingError.swift
// swift-rfc-9112

extension RFC_9110.Request.Target {
    /// A failure to interpret an HTTP/1.1 request-target according to RFC 9112
    /// Section 3.2.
    public enum ParsingError: Swift.Error, Sendable, Equatable {
        /// The target does not match any grammatical request-target form.
        case syntax(String)

        /// The target form is not permitted for the request method.
        case form(String, method: RFC_9110.Method)
    }
}
