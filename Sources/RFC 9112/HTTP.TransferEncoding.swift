extension RFC_9110 {

    public struct TransferEncoding: Sendable, Equatable, Hashable {

        private let storage: Storage

        public init(codingName: String) {
            self.storage = .single(codingName)
        }

        private init(storage: Storage) {
            self.storage = storage
        }
    }
}

extension RFC_9110.TransferEncoding {

    public static let chunked = Self(codingName: "chunked")

    public static let gzip = Self(codingName: "gzip")

    public static let compress = Self(codingName: "compress")

    public static let deflate = Self(codingName: "deflate")

    public static func list(_ encodings: [Self]) -> Self {
        Self(storage: .list(encodings))
    }

    public var headerValue: String {
        switch storage {
        case .single(let name):
            return name

        case .list(let encodings):
            return encodings.map { $0.headerValue }.joined(separator: ", ")
        }
    }

    public static func parse(_ headerValue: String) -> Self? {
        let encodings =
            RFC_9110.Parse.tokens(in: headerValue)
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

    public var isChunked: Bool {
        switch storage {
        case .single(let name):
            return name == "chunked"

        case .list:
            return false
        }
    }

    public var hasChunked: Bool {
        switch storage {
        case .single(let name):
            return name == "chunked"

        case .list(let encodings):
            return encodings.contains { $0.isChunked }
        }
    }

    public var isChunkedFinal: Bool {
        switch storage {
        case .single(let name):
            return name == "chunked"

        case .list(let encodings):
            return encodings.last?.isChunked ?? false
        }
    }

    public var chunkedCount: Int {
        switch storage {
        case .single(let name):
            return name == "chunked" ? 1 : 0

        case .list(let encodings):
            return encodings.filter { $0.isChunked }.count
        }
    }
}

extension RFC_9110.TransferEncoding: CustomStringConvertible {
    public var description: String {
        headerValue
    }
}

extension RFC_9110.TransferEncoding: Codable {
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

extension RFC_9110.TransferEncoding: LosslessStringConvertible {

    public init?(_ description: String) {
        guard let parsed = Self.parse(description) else { return nil }
        self = parsed
    }
}

extension RFC_9110.TransferEncoding: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = Self.parse(value) ?? Self(codingName: value)
    }
}
