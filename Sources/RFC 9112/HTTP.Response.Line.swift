extension RFC_9110.Response {

    public struct Line: Sendable, Equatable {
        public let version: RFC_9110.Version
        public let statusCode: Int
        public let reasonPhrase: String?

        public init(version: RFC_9110.Version, statusCode: Int, reasonPhrase: String? = nil) {
            self.version = version
            self.statusCode = statusCode
            self.reasonPhrase = reasonPhrase
        }

        public init(version: RFC_9110.Version, status: RFC_9110.Status, reasonPhrase: String? = nil)
        {
            self.version = version
            self.statusCode = status.code
            self.reasonPhrase = reasonPhrase ?? status.reasonPhrase
        }
    }
}

extension RFC_9110.Response.Line {

    public static func parse(_ line: String) throws(ParsingError) -> Self {

        let components = line.split(
            separator: " ",
            maxSplits: 2,
            omittingEmptySubsequences: false
        )

        guard components.count >= 2 else {
            throw ParsingError.invalidFormat(
                reason: "Expected at least version and status code"
            )
        }

        let versionString = String(components[0])
        let version: RFC_9110.Version
        do throws(RFC_9110.Version.ParsingError) {
            version = try RFC_9110.Version.parse(versionString)
        } catch {
            throw ParsingError.invalidFormat(reason: "Invalid HTTP version: \(versionString)")
        }

        let statusString = String(components[1])
        guard let statusCode = Int(statusString), statusString.count == 3 else {
            throw ParsingError.invalidStatusCode(statusString)
        }

        guard statusCode >= 100 && statusCode <= 999 else {
            throw ParsingError.statusCodeOutOfRange(statusCode)
        }

        var reasonPhrase: String?
        if components.count == 3 {
            let phrase = String(components[2])
            reasonPhrase = phrase.isEmpty ? nil : phrase
        }

        return Self(version: version, statusCode: statusCode, reasonPhrase: reasonPhrase)
    }

    public var formatted: String {
        if let reason = reasonPhrase {
            return "\(version.formatted) \(statusCode) \(reason)"
        } else {
            return "\(version.formatted) \(statusCode) "
        }
    }

    public var status: RFC_9110.Status? {
        RFC_9110.Status.from(code: statusCode)
    }

}

extension RFC_9110.Status {

    internal static func from(code: Int) -> RFC_9110.Status? {

        return RFC_9110.Status(code)
    }
}
