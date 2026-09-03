public import RFC_9110

public import Byte

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
    public var bytes: [Byte] {
        var result = "\(RFC_9112.Version.format(version)) \(status.code)".utf8.map(Byte.init(bitPattern:))
        if let reason {
            result.append(Byte(bitPattern: 0x20))
            result.append(contentsOf: reason.bytes)
        }
        return result
    }
}
