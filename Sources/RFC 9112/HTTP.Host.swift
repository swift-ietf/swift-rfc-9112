public import RFC_3986

extension RFC_9112 {

    public struct Host {

        public let name: String

        public let port: RFC_3986.URI.Port?

        public init(name: String, port: RFC_3986.URI.Port? = nil) {
            self.name = name
            self.port = port
        }
    }
}

extension RFC_9112.Host: Hashable {

    public func hash(into hasher: inout Hasher) {
        hasher.combine(name.lowercased())
        hasher.combine(port)
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.name.lowercased() == rhs.name.lowercased() && lhs.port == rhs.port
    }
}

extension RFC_9112.Host: CustomStringConvertible {

    public var description: String {
        guard let port else { return name }
        return "\(name):\(port)"
    }
}

extension RFC_9112.Host {

    public init?(_ uri: RFC_3986.URI) {
        guard let host = uri.host else { return nil }
        self.init(name: host.description, port: uri.port)
    }
}
