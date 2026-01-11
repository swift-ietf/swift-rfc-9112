// HTTP.Message.Serializer.swift
// swift-rfc-9112

import Standard_Library_Extensions

extension RFC_9110.Request {
    /// Serialize HTTP/1.1 request to wire format
    /// RFC 9112 Section 3: HTTP/1.1 request message format
    public struct Serializer {

        /// Serialize request to bytes
        /// Format: request-line CRLF *(field-line CRLF) CRLF [ message-body ]
        public static func serialize(
            _ request: RFC_9110.Request,
            version: RFC_9110.Version = .http11
        ) throws -> [UInt8] {
            var data = [UInt8]()

            // Request line
            let requestLine = try formatRequestLine(request, version: version)
            data.append(contentsOf: requestLine.utf8)
            data.append(contentsOf: [0x0D, 0x0A])  // CRLF

            // Header fields
            for header in request.headers {
                let fieldLine = "\(header.name.rawValue): \(header.value.rawValue)"
                data.append(contentsOf: fieldLine.utf8)
                data.append(contentsOf: [0x0D, 0x0A])  // CRLF
            }

            // Empty line separating headers from body
            data.append(contentsOf: [0x0D, 0x0A])  // CRLF

            // Message body (if present)
            if let body = request.body {
                data.append(contentsOf: body)
            }

            return data
        }

        /// Format request-line from request
        private static func formatRequestLine(
            _ request: RFC_9110.Request,
            version: RFC_9110.Version
        ) throws -> String {
            let method = request.method.rawValue
            let target = formatTarget(request.target)
            let versionString = version.formatted

            return "\(method) \(target) \(versionString)"
        }

        /// Format request target
        private static func formatTarget(_ target: RFC_9110.Request.Target) -> String {
            switch target {
            case .origin(let path, let query):
                if let query = query {
                    return "\(path.description)?\(query.description)"
                }
                return path.description

            case .absolute(let uri):
                return uri.description

            case .authority(let authority):
                // authority-form: host:port (for CONNECT)
                if let port = authority.port {
                    return "\(authority.host.description):\(port.value)"
                }
                return authority.host.description

            case .asterisk:
                return "*"
            }
        }
    }
}

extension RFC_9110.Response {
    /// Serialize HTTP/1.1 response to wire format
    /// RFC 9112 Section 4: HTTP/1.1 response message format
    public struct Serializer {

        /// Serialize response to bytes
        /// Format: status-line CRLF *(field-line CRLF) CRLF [ message-body ]
        public static func serialize(
            _ response: RFC_9110.Response,
            version: RFC_9110.Version = .http11,
            includeReasonPhrase: Bool = true
        ) throws -> [UInt8] {
            var data = [UInt8]()

            // Status line
            let statusLine = formatStatusLine(
                response,
                version: version,
                includeReasonPhrase: includeReasonPhrase
            )
            data.append(contentsOf: statusLine.utf8)
            data.append(contentsOf: [0x0D, 0x0A])  // CRLF

            // Header fields
            for header in response.headers {
                let fieldLine = "\(header.name.rawValue): \(header.value.rawValue)"
                data.append(contentsOf: fieldLine.utf8)
                data.append(contentsOf: [0x0D, 0x0A])  // CRLF
            }

            // Empty line separating headers from body
            data.append(contentsOf: [0x0D, 0x0A])  // CRLF

            // Message body (if present)
            if let body = response.body {
                data.append(contentsOf: body)
            }

            return data
        }

        /// Format status-line from response
        private static func formatStatusLine(
            _ response: RFC_9110.Response,
            version: RFC_9110.Version,
            includeReasonPhrase: Bool
        ) -> String {
            let versionString = version.formatted
            let code = response.status.code

            if includeReasonPhrase, let reasonPhrase = response.status.reasonPhrase {
                return "\(versionString) \(code) \(reasonPhrase)"
            } else {
                // RFC 9112: Space after status code is required even without reason phrase
                return "\(versionString) \(code) "
            }
        }
    }
}
