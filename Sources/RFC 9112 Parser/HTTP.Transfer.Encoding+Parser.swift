public import RFC_9112
import RFC_9110
import RFC_9110_Coder

extension RFC_9112.Transfer.Encoding {
    public static func parse(_ headerValue: String) -> Self? {
        let encodings =
            RFC_9110.Field.Value.tokens(in: headerValue)
            .map { name -> Self in
                switch name.lowercased() {
                case "chunked": return .chunked
                case "gzip": return .gzip
                case "compress", "x-compress": return .compress
                case "deflate": return .deflate
                default: return Self(codingName: name)
                }
            }

        guard !encodings.isEmpty else {
            return nil
        }

        if encodings.count == 1 {
            return encodings[0]
        }

        return .list(encodings)
    }

}

extension RFC_9112.Transfer.Encoding: Codable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)

        guard let parsed = Self.parse(string) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid Transfer-Encoding: \(string)"
            )
        }

        self = parsed
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(headerValue)
    }
}

extension RFC_9112.Transfer.Encoding: LosslessStringConvertible {

    public init?(_ description: String) {
        guard let parsed = Self.parse(description) else { return nil }
        self = parsed
    }
}

extension RFC_9112.Transfer.Encoding: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = Self.parse(value) ?? Self(codingName: value)
    }
}
