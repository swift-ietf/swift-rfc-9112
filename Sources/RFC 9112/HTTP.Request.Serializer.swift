// HTTP.Request.Serializer.swift
// swift-rfc-9112

public import Byte_Primitives
import Standard_Library_Extensions

extension RFC_9110.Request {
    /// Serialize HTTP/1.1 request to wire format
    /// RFC 9112 Section 3: HTTP/1.1 request message format
    public struct Serializer {}
}

extension RFC_9110.Request.Serializer {

    /// Serialize request to bytes
    /// Format: request-line CRLF *(field-line CRLF) CRLF [ message-body ]
    public static func serialize(
        _ request: RFC_9110.Request,
        version: RFC_9110.Version = .http11
    ) -> [Byte] {
        var data = [Byte]()

        // Request line
        let requestLine = formatRequestLine(request, version: version)
        data.append(contentsOf: requestLine.utf8.map { Byte($0) })
        data.append(contentsOf: [0x0D, 0x0A])  // CRLF

        // Header fields
        for header in request.headers {
            let fieldLine = "\(header.name): \(header.value)"
            data.append(contentsOf: fieldLine.utf8.map { Byte($0) })
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
    ) -> String {
        let method = request.method.description
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
