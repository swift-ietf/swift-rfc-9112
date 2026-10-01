
extension RFC_9112.Transfer {
    public struct Encoding: Equatable, Hashable {

        private let storage: Storage

        public init(codingName: String) {
            self.storage = .single(RFC_9112.asciiLowercased(codingName))
        }

        private init(storage: Storage) {
            self.storage = storage
        }
    }
}

extension RFC_9112.Transfer.Encoding {

    public static var chunked: Self { Self(codingName: "chunked") }

    public static var gzip: Self { Self(codingName: "gzip") }

    public static var compress: Self { Self(codingName: "compress") }

    public static var deflate: Self { Self(codingName: "deflate") }

    public static func list(_ encodings: [Self]) -> Self {
        Self(storage: .list(encodings))
    }

    public var codings: [String] {
        switch storage {
        case .single(let name):
            return [name]

        case .list(let encodings):
            return encodings.flatMap { $0.codings }
        }
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

extension RFC_9112.Transfer.Encoding: CustomStringConvertible {
    public var description: String {
        codings.joined(separator: ", ")
    }
}

extension RFC_9112 {

    static func asciiLowercased(_ token: String) -> String {
        String(String.UnicodeScalarView(token.unicodeScalars.map {
            (0x41...0x5A).contains($0.value) ? Unicode.Scalar($0.value + 0x20)! : $0
        }))
    }
}
