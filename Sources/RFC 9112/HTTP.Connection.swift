public import RFC_9110

extension RFC_9112 {

    public struct Connection: Equatable, Hashable {

        public let options: Set<String>

        public init(options: Set<String>) {
            self.options = Set(options.map(RFC_9112.asciiLowercased))
        }
    }
}

extension RFC_9112.Connection {

    public static var close: Self { Self(options: ["close"]) }

    public static var keepAlive: Self { Self(options: ["keep-alive"]) }

    public var hasClose: Bool {
        options.contains("close")
    }

    public var hasKeepAlive: Bool {
        options.contains("keep-alive")
    }

    public func persists(over version: RFC_9110.Version) -> Bool {
        if hasClose { return false }
        if version >= RFC_9112.Version.value { return true }
        return hasKeepAlive
    }
}

extension RFC_9112.Connection: CustomStringConvertible {

    public var description: String {
        options.sorted().joined(separator: ", ")
    }
}
