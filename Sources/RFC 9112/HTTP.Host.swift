// HTTP.Host.swift
// swift-rfc-9112

@_exported import RFC_3986

extension RFC_9110 {
    /// Host header utilities and validation (RFC 9112 Section 3.2.2)
    public enum Host {
        /// Host header validator implementing RFC 9112 Section 3.2.2
        public enum Validator {

        // MARK: - Validation

        /// Validate Host header in request
        /// RFC 9112 Section 3.2.2:
        /// "A client MUST send a Host header field in all HTTP/1.1 request messages"
        /// "A server MUST respond with a 400 (Bad Request) status code to any HTTP/1.1
        /// request message that lacks a Host header field"
        public static func validate(
            request: RFC_9110.Request,
            version: RFC_9110.Version
        ) throws {
            // Only required for HTTP/1.1
            guard version.isHTTP11OrHigher else {
                return
            }

            // Get Host header values
            let hostHeaders = request.headers.filter { $0.name.rawValue.lowercased() == "host" }

            // RFC 9112: Host header field MUST be present
            guard !hostHeaders.isEmpty else {
                throw ValidationError.missingHost
            }

            // RFC 9112 Section 3.2.2: "A server MUST respond with a 400 (Bad Request)
            // if more than one Host header field is present"
            guard hostHeaders.count == 1 else {
                throw ValidationError.multipleHostHeaders(count: hostHeaders.count)
            }

            let hostValue = hostHeaders[0].value.rawValue

            // Validate format (basic check)
            try validateHostFormat(hostValue)

            // If request has absolute-form target, validate Host matches
            // RFC 9112 Section 3.2.2: "the Host header field value MUST represent the same authority
            // component as the request-target, excluding any userinfo subcomponent"
            if case .absolute(let uri) = request.target {
                try validateHostMatchesAuthority(hostValue: hostValue, uri: uri)
            }
        }

        /// Validate Host header format
        /// RFC 9112 Section 3.2.2: Host = uri-host [ ":" port ]
        private static func validateHostFormat(_ host: String) throws {
            // Empty host value is invalid per RFC 9112
            // The Host header is required and must have a non-empty value
            if host.isEmpty {
                throw ValidationError.invalidHostFormat(host, reason: "Host value cannot be empty")
            }

            // Check for invalid characters
            // Host can be: IPv4, IPv6 (in brackets), or domain name
            if host.hasPrefix("[") {
                // IPv6 address - should end with ]
                guard host.hasSuffix("]") || host.contains("]:") else {
                    throw ValidationError.invalidHostFormat(host, reason: "IPv6 address must be bracketed")
                }
            }

            // Validate no whitespace
            guard !host.contains(where: \.isWhitespace) else {
                throw ValidationError.invalidHostFormat(host, reason: "Host contains whitespace")
            }

            // If port present, validate it
            if let portSeparatorIndex = host.lastIndex(of: ":") {
                let portString = host[host.index(after: portSeparatorIndex)...]

                // If it's not an IPv6 address, validate port
                if !host.hasPrefix("[") {
                    guard let port = Int(portString), port >= 0 && port <= 65535 else {
                        throw ValidationError.invalidPort(String(portString))
                    }
                }
            }
        }

        /// Validate Host header matches authority in absolute-form target
        /// RFC 9112 Section 3.2.2: "excluding any userinfo subcomponent"
        private static func validateHostMatchesAuthority(
            hostValue: String,
            uri: RFC_3986.URI
        ) throws {
            guard let host = uri.host else {
                // No host in URI, Host should be empty or match
                if !hostValue.isEmpty {
                    throw ValidationError.hostMismatchesAuthority(
                        host: hostValue,
                        authority: "(none)"
                    )
                }
                return
            }

            // Reconstruct authority without userinfo
            let expectedHost: String
            if let port = uri.port {
                expectedHost = "\(host.description):\(port.value)"
            } else {
                expectedHost = host.description
            }

            // Case-insensitive comparison for domain names
            // RFC 9112: Host is case-insensitive
            guard hostValue.lowercased() == expectedHost.lowercased() else {
                throw ValidationError.hostMismatchesAuthority(
                    host: hostValue,
                    authority: expectedHost
                )
            }
        }

        /// Extract host and port from Host header value
        public static func parseHost(_ value: String) -> (host: String, port: Int?) {
            // Handle IPv6
            if value.hasPrefix("[") {
                if let closeBracket = value.firstIndex(of: "]") {
                    let host = String(value[..<value.index(after: closeBracket)])
                    let remainder = value[value.index(after: closeBracket)...]

                    if remainder.hasPrefix(":"), let port = Int(remainder.dropFirst()) {
                        return (host: host, port: port)
                    }
                    return (host: host, port: nil)
                }
            }

            // Handle IPv4 or domain name
            if let lastColon = value.lastIndex(of: ":") {
                let host = String(value[..<lastColon])
                let portString = value[value.index(after: lastColon)...]
                if let port = Int(portString) {
                    return (host: host, port: port)
                }
            }

            return (host: value, port: nil)
        }

        // MARK: - Errors

        public enum ValidationError: Error, Sendable, Equatable {
            case missingHost
            case multipleHostHeaders(count: Int)
            case invalidHostFormat(String, reason: String)
            case invalidPort(String)
            case hostMismatchesAuthority(host: String, authority: String)
        }
        }
    }
}
