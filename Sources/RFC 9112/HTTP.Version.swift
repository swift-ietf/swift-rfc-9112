extension RFC_9110 {

    public struct Version: Sendable, Equatable, Hashable {
        public let major: Int
        public let minor: Int

        public init(major: Int, minor: Int) {
            self.major = major
            self.minor = minor
        }
    }
}

extension RFC_9110.Version {

    public static let http10 = Self(major: 1, minor: 0)

    public static let http11 = Self(major: 1, minor: 1)

    public static func parse(_ string: String) throws(ParsingError) -> Self {

        let parts = string.split(separator: "/")
        guard parts.count == 2 else {
            throw ParsingError.invalidFormat(reason: "Expected format HTTP/M.m")
        }

        guard parts[0] == "HTTP" else {
            throw ParsingError.invalidHTTPName(String(parts[0]))
        }

        let versionParts = parts[1].split(separator: ".")
        guard versionParts.count == 2 else {
            throw ParsingError.invalidFormat(reason: "Expected format M.m")
        }

        guard let major = Int(versionParts[0]),
            let minor = Int(versionParts[1])
        else {
            throw ParsingError.invalidVersionNumber
        }

        return Self(major: major, minor: minor)
    }

    public var formatted: String {
        "HTTP/\(major).\(minor)"
    }

    public var isHTTP11: Bool {
        self == .http11
    }

    public var isHTTP10: Bool {
        self == .http10
    }

    public var isHTTP11OrHigher: Bool {
        major > 1 || (major == 1 && minor >= 1)
    }

}
