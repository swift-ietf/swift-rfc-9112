import RFC_3986
public import RFC_9110
import Standard_Library_Extensions

extension RFC_9112.Request {
    public struct Line: Equatable {
        public let method: RFC_9110.Method
        public let target: RFC_9112.Request.Target
        public let version: RFC_9110.Version

        public init(
            method: RFC_9110.Method,
            target: RFC_9112.Request.Target,
            version: RFC_9110.Version
        ) {
            self.method = method
            self.target = target
            self.version = version
        }
    }
}

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
            target: try target(targetText, method: method),
            version: version
        )
    }

    public var formatted: String {
        "\(method) \(target.text) \(RFC_9112.Version.format(version))"
    }

    public func validate(maxLength: Int = 8000) throws(Error) {
        let length = formatted.utf8.count
        guard length <= maxLength else {
            throw .lineTooLong(length: length, max: maxLength)
        }
    }

    private static func target(
        _ text: String,
        method: RFC_9110.Method
    ) throws(Error) -> RFC_9112.Request.Target {
        if text == "*" {
            return .asterisk
        }

        if text.contains("://") {
            do throws(RFC_3986.Error) {
                return .absolute(try RFC_3986.URI(text))
            } catch {
                throw .invalidFormat(reason: "Invalid absolute request target")
            }
        }

        if method == .connect {
            do throws(RFC_3986.URI.Authority.Error) {
                return .authority(try RFC_3986.URI.Authority(text))
            } catch {
                throw .invalidFormat(reason: "Invalid authority request target")
            }
        }

        let components = text.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
        let path: RFC_3986.URI.Path
        do throws(RFC_3986.URI.Path.Error) {
            path = try RFC_3986.URI.Path(String(components[0]))
        } catch {
            throw .invalidFormat(reason: "Invalid origin request target path")
        }

        let query: RFC_3986.URI.Query?
        if components.count == 2 {
            do throws(RFC_3986.URI.Query.Error) {
                query = try RFC_3986.URI.Query(String(components[1]))
            } catch {
                throw .invalidFormat(reason: "Invalid origin request target query")
            }
        } else {
            query = nil
        }

        return .origin(path: path, query: query)
    }
}
