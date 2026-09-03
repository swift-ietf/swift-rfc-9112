public import RFC_9112
import RFC_3986
import RFC_9110
import Standard_Library_Extensions

extension RFC_9112.Request.Line {
    public static func parse(_ line: String) throws(Error) -> Self {
        guard let firstSpace = line.firstIndex(of: " ") else {
            throw .invalidFormat(reason: "Missing space after method")
        }

        let methodText = String(line[..<firstSpace])
        guard !methodText.isEmpty else {
            throw .emptyMethod
        }
        let method = RFC_9110.Method(rawValue: methodText)

        let afterMethod = line.index(after: firstSpace)
        guard let versionRange = line.range(of: " HTTP/") else {
            throw .invalidFormat(reason: "Missing HTTP version")
        }

        let targetText = String(line[afterMethod..<versionRange.lowerBound])
        guard !targetText.isEmpty else {
            throw .emptyTarget
        }
        guard !targetText.contains(where: \.isWhitespace) else {
            throw .targetContainsWhitespace
        }

        let versionText = String(line[line.index(after: versionRange.lowerBound)...])
        let version: RFC_9110.Version
        do throws(RFC_9112.Version.Error) {
            version = try RFC_9112.Version.parse(versionText)
        } catch {
            throw .invalidVersion(versionText)
        }

        return Self(
            method: method,
            target: try RFC_9112.Request.Line.target(targetText, method: method),
            version: version
        )
    }

}
