// HTTP.Response.Serializer.swift
// swift-rfc-9112

public import Byte_Primitives
import Standard_Library_Extensions

extension RFC_9110.Response {
    /// Serializes an HTTP/1.1 response to wire format.
    ///
    /// Use the stateful initializer and `serialize(_:)` when the body arrives
    /// incrementally. The static `serialize(_:version:includeReasonPhrase:)`
    /// operation remains the whole-response compatibility surface.
    public struct Serializer {
        /// Where the incremental serializer is in its response.
        private var state: State

        /// Creates an incremental response serializer awaiting a head.
        public init() {
            self.state = .head
        }
    }
}

extension RFC_9110.Response.Serializer {

    /// Serialize response to bytes
    /// Format: status-line CRLF *(field-line CRLF) CRLF [ message-body ]
    public static func serialize(
        _ response: RFC_9110.Response,
        version: RFC_9110.Version = .http11,
        includeReasonPhrase: Bool = true
    ) -> [Byte] {
        var data = [Byte]()

        // Status line
        let statusLine = formatStatusLine(
            response,
            version: version,
            includeReasonPhrase: includeReasonPhrase
        )
        data.append(contentsOf: statusLine.utf8.map { Byte($0) })
        data.append(contentsOf: [0x0D, 0x0A])  // CRLF

        // Header fields
        for header in response.headers {
            let fieldLine = "\(header.name): \(header.value)"
            data.append(contentsOf: fieldLine.utf8.map { Byte($0) })
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
