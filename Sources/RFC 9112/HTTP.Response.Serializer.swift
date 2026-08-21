public import Byte_Primitives
import Standard_Library_Extensions

extension RFC_9110.Response {

    public struct Serializer {}
}

extension RFC_9110.Response.Serializer {

    public static func serialize(
        _ response: RFC_9110.Response,
        version: RFC_9110.Version = .http11,
        includeReasonPhrase: Bool = true
    ) -> [Byte] {
        var data = [Byte]()

        let statusLine = formatStatusLine(
            response,
            version: version,
            includeReasonPhrase: includeReasonPhrase
        )
        data.append(contentsOf: statusLine.utf8.map { Byte($0) })
        data.append(contentsOf: [0x0D, 0x0A])

        for header in response.headers {
            let fieldLine = "\(header.name): \(header.value)"
            data.append(contentsOf: fieldLine.utf8.map { Byte($0) })
            data.append(contentsOf: [0x0D, 0x0A])
        }

        data.append(contentsOf: [0x0D, 0x0A])

        if let body = response.body {
            data.append(contentsOf: body)
        }

        return data
    }

    private static func formatStatusLine(
        _ response: RFC_9110.Response,
        version: RFC_9110.Version,
        includeReasonPhrase: Bool
    ) -> String {
        let versionString = version.formatted
        let code = response.status.code

        if includeReasonPhrase, let reasonPhrase = response.status.reasonPhrase {
            return "\(versionString) \(code) \(reasonPhrase)"
        } else {

            return "\(versionString) \(code) "
        }
    }
}
