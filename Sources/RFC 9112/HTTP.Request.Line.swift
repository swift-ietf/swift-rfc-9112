import INCITS_4_1986

extension RFC_9110.Request {

    public struct Line: Sendable, Equatable {
        public let method: RFC_9110.Method
        public let target: String
        public let version: RFC_9110.Version

        public init(method: RFC_9110.Method, target: String, version: RFC_9110.Version) {
            self.method = method
            self.target = target
            self.version = version
        }
    }
}

extension RFC_9110.Request.Line {

    public static func parse(_ line: String) throws(ParsingError) -> Self {

        guard let firstSpace = line.firstIndex(of: " ") else {
            throw ParsingError.invalidFormat(reason: "Missing space after method")
        }

        let methodString = String(line[..<firstSpace])
        guard !methodString.isEmpty else {
            throw ParsingError.emptyMethod
        }

        let method = RFC_9110.Method(rawValue: methodString)

        let afterMethod = line.index(after: firstSpace)
        guard let httpRange = line.range(of: " HTTP/") else {
            throw ParsingError.invalidFormat(reason: "Missing HTTP version")
        }

        let targetString = String(line[afterMethod..<httpRange.lowerBound])
        guard !targetString.isEmpty else {
            throw ParsingError.emptyTarget
        }

        guard !targetString.contains(where: \.ascii.isWhitespace) else {
            throw ParsingError.targetContainsWhitespace
        }

        let versionString = String(line[line.index(after: httpRange.lowerBound)...])
        let version: RFC_9110.Version
        do throws(RFC_9110.Version.ParsingError) {
            version = try RFC_9110.Version.parse(versionString)
        } catch {
            throw ParsingError.invalidVersion(versionString)
        }

        return Self(method: method, target: targetString, version: version)
    }

    public var formatted: String {
        "\(method) \(target) \(version.formatted)"
    }

    public func validate(maxLength: Int = 8000) throws(Error) {
        let formattedLength = formatted.utf8.count
        guard formattedLength <= maxLength else {
            throw Error.lineTooLong(length: formattedLength, max: maxLength)
        }

    }

}
