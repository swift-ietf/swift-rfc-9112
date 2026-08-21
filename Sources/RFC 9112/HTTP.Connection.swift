extension RFC_9110 {

    public struct Connection: Sendable, Equatable, Hashable {

        public let options: Set<String>

        public init(options: Set<String>) {
            self.options = Set(options.map { $0.lowercased() })
        }
    }
}

extension RFC_9110.Connection {

    public static let close = Self(options: ["close"])

    public static let keepAlive = Self(options: ["keep-alive"])

    public var headerValue: String {
        options.sorted().joined(separator: ", ")
    }

    public static func parse(_ headerValue: String) -> Self? {
        let opts = RFC_9110.Parse.tokens(in: headerValue).map { $0.lowercased() }

        guard !opts.isEmpty else {
            return nil
        }

        return Self(options: Set(opts))
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

extension RFC_9110.Connection: CustomStringConvertible {
    public var description: String {
        headerValue
    }
}

extension RFC_9110.Connection: Codable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)

        guard let parsed = Self.parse(string) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid Connection: \(string)"
            )
        }

        self = parsed
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(headerValue)
    }
}

extension RFC_9110.Connection: LosslessStringConvertible {

    public init?(_ description: String) {
        guard let parsed = Self.parse(description) else { return nil }
        self = parsed
    }
}

extension RFC_9110.Connection: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = Self.parse(value) ?? RFC_9110.Connection(options: [value])
    }
}
