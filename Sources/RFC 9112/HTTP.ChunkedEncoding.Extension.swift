// HTTP.ChunkedEncoding.Extension.swift
// swift-rfc-9112
//
// RFC 9112 Section 7.1.1: Chunk Extensions
// https://www.rfc-editor.org/rfc/rfc9112.html#section-7.1.1

import INCITS_4_1986
import Standard_Library_Extensions

extension RFC_9110.ChunkedEncoding {

    // MARK: - Chunk Extension

    /// Chunk extension (RFC 9112 Section 7.1.1)
    ///
    /// Chunk extensions provide a mechanism for additional chunk-specific metadata.
    /// RFC 9112: "Recipients MUST ignore unrecognized chunk extensions"
    public struct Extension: Sendable, Equatable, Hashable {
        public let name: String
        public let value: String?

        public init(name: String, value: String? = nil) {
            self.name = name
            self.value = value
        }
    }
}

extension RFC_9110.ChunkedEncoding.Extension {
    /// Format as string for transmission
    /// Format: ";name" or ";name=value"
    public var formatted: String {
        if let value {
            // Check if value needs quoting
            if value.contains(where: { $0 == ";" || $0.isWhitespace }) {
                return ";\(name)=\"\(value)\""
            } else {
                return ";\(name)=\(value)"
            }
        } else {
            return ";\(name)"
        }
    }

    /// Parse chunk extensions from string
    /// RFC 9112 Section 7.1.1: chunk-ext = *( BWS ";" BWS chunk-ext-name [ BWS "=" BWS chunk-ext-val ] )
    static func parseExtensions(_ string: String) -> [Self] {
        var extensions: [Self] = []
        let parts = string.split(separator: ";", omittingEmptySubsequences: true)

        for part in parts {
            let trimmed = part.trimming(.ascii.whitespaces)
            if trimmed.contains("=") {
                let components = trimmed.split(separator: "=", maxSplits: 1)
                if components.count == 2 {
                    let name = String(components[0]).trimming(.ascii.whitespaces)
                    var value = String(components[1]).trimming(.ascii.whitespaces)

                    // Remove quotes if present
                    if value.hasPrefix("\"") && value.hasSuffix("\"") {
                        value = String(value.dropFirst().dropLast())
                    }

                    extensions.append(Self(name: name, value: value))
                }
            } else {
                extensions.append(Self(name: trimmed, value: nil))
            }
        }

        return extensions
    }
}
