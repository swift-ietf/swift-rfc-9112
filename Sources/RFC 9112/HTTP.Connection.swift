import RFC_9110

extension RFC_9112 {

    public struct Connection: Equatable, Hashable {

        public let options: Set<String>

        public init(options: Set<String>) {
            self.options = Set(options.map { $0.lowercased() })
        }
    }
}

extension RFC_9112.Connection {

    public static var close: Self { Self(options: ["close"]) }

    public static var keepAlive: Self { Self(options: ["keep-alive"]) }

    public var headerValue: String {
        options.sorted().joined(separator: ", ")
    }

    public var hasClose: Bool {
        options.contains("close")
    }

    public var hasKeepAlive: Bool {
        options.contains("keep-alive")
    }

    public func shouldPersist(version: String = "HTTP/1.1") -> Bool {
        if hasClose {
            return false
        }

        if version.hasPrefix("HTTP/1.1") {
            return true
        }

        if version.hasPrefix("HTTP/1.0") {
            return hasKeepAlive
        }

        return false
    }
}

extension RFC_9112.Connection: CustomStringConvertible {
    public var description: String {
        headerValue
    }
}



