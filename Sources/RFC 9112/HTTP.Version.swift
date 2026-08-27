extension RFC_9112 {
    public enum Version {}
}

extension RFC_9112.Version {
    public static let value = try! RFC_9110.Version(major: 1, minor: 1)

    public static func parse(_ text: String) throws(Error) -> RFC_9110.Version {
        let parts = text.split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count == 2 else {
            throw .format(text)
        }
        guard parts[0] == "HTTP" else {
            throw .name(String(parts[0]))
        }

        let components = parts[1].split(separator: ".", omittingEmptySubsequences: false)
        guard components.count == 2,
            components[0].count == 1,
            components[1].count == 1,
            let major = UInt(components[0]),
            let minor = UInt(components[1])
        else {
            throw .number(String(parts[1]))
        }

        do throws(RFC_9110.Version.Error) {
            return try RFC_9110.Version(major: major, minor: minor)
        } catch {
            throw .number(String(parts[1]))
        }
    }

    public static func format(_ version: RFC_9110.Version) -> String {
        "HTTP/\(version.major).\(version.minor)"
    }
}
