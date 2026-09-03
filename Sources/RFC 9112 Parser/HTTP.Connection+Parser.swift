public import RFC_9112
import RFC_9110
import RFC_9110_Coder

extension RFC_9112.Connection {
    public static func parse(_ headerValue: String) -> Self? {
        let opts = RFC_9110.Field.Value.tokens(in: headerValue).map { $0.lowercased() }

        guard !opts.isEmpty else {
            return nil
        }

        return Self(options: Set(opts))
    }

}

extension RFC_9112.Connection: Codable {
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

extension RFC_9112.Connection: LosslessStringConvertible {

    public init?(_ description: String) {
        guard let parsed = Self.parse(description) else { return nil }
        self = parsed
    }
}

extension RFC_9112.Connection: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = Self.parse(value) ?? RFC_9112.Connection(options: [value])
    }
}
