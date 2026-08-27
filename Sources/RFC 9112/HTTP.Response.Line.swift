public import Byte_Primitive

extension RFC_9112.Response {
    public struct Line: Equatable {
        public let version: RFC_9110.Version
        public let status: RFC_9110.Status
        public let reason: RFC_9110.Status.Reason?

        public init(
            version: RFC_9110.Version,
            status: RFC_9110.Status,
            reason: RFC_9110.Status.Reason? = nil
        ) {
            self.version = version
            self.status = status
            self.reason = reason
        }
    }
}

extension RFC_9112.Response.Line {
    public static func parse(_ line: String) throws(Error) -> Self {
        let components = line.split(
            separator: " ",
            maxSplits: 2,
            omittingEmptySubsequences: false
        )
        guard components.count >= 2 else {
            throw .invalidFormat(reason: "Expected a version and status code")
        }

        let version: RFC_9110.Version
        do throws(RFC_9112.Version.Error) {
            version = try RFC_9112.Version.parse(String(components[0]))
        } catch {
            throw .invalidFormat(reason: "Invalid HTTP version")
        }

        let statusText = String(components[1])
        guard statusText.count == 3, let code = Int(statusText) else {
            throw .invalidStatusCode(statusText)
        }
        guard (100...599).contains(code) else {
            throw .statusCodeOutOfRange(code)
        }

        let reason: RFC_9110.Status.Reason?
        if components.count == 3, !components[2].isEmpty {
            reason = .init(components[2].utf8.map(Byte.init))
        } else {
            reason = nil
        }

        return Self(version: version, status: .init(code), reason: reason)
    }

    public var bytes: [Byte] {
        var result = "\(RFC_9112.Version.format(version)) \(status.code)".utf8.map(Byte.init)
        if let reason {
            result.append(0x20)
            result.append(contentsOf: reason.bytes)
        }
        return result
    }
}
