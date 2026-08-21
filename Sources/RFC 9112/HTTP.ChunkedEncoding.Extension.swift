import INCITS_4_1986
import Standard_Library_Extensions

extension RFC_9110.ChunkedEncoding {

    public struct Extension: Sendable, Equatable, Hashable {
        public let name: String
        public let value: String?

        public init(name: String, value: String? = nil) {
            self.name = name
            self.value = value
        }
    }
}

extension RFC_9110.ChunkedEncoding.Extension {

    public var formatted: String {
        if let value {

            if value.contains(where: { $0 == ";" || $0.isWhitespace }) {
                return ";\(name)=\"\(value)\""
            } else {
                return ";\(name)=\(value)"
            }
        } else {
            return ";\(name)"
        }
    }

    static func parseExtensions(_ string: String) -> [Self] {
        var extensions: [Self] = []
        let parts = string.split(separator: ";", omittingEmptySubsequences: true)

        for part in parts {
            let trimmed = part.trimming(.ascii.whitespaces)
            if trimmed.contains("=") {
                let components = trimmed.split(separator: "=", maxSplits: 1)
                if components.count == 2 {
                    let name = String(components[0]).trimming(.ascii.whitespaces)
                    var value = String(components[1]).trimming(.ascii.whitespaces)

                    if value.hasPrefix("\"") && value.hasSuffix("\"") {
                        value = String(value.dropFirst().dropLast())
                    }

                    extensions.append(Self(name: name, value: value))
                }
            } else {
                extensions.append(Self(name: trimmed, value: nil))
            }
        }

        return extensions
    }
}
