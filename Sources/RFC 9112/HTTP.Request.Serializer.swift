public import Byte_Primitives
import Standard_Library_Extensions

extension RFC_9110.Request {

    public struct Serializer {}
}

extension RFC_9110.Request.Serializer {

    public static func serialize(
        _ request: RFC_9110.Request,
        version: RFC_9110.Version = .http11
    ) -> [Byte] {
        var data = [Byte]()

        let requestLine = formatRequestLine(request, version: version)
        data.append(contentsOf: requestLine.utf8.map { Byte($0) })
        data.append(contentsOf: [0x0D, 0x0A])

        for header in request.headers {
            let fieldLine = "\(header.name): \(header.value)"
            data.append(contentsOf: fieldLine.utf8.map { Byte($0) })
            data.append(contentsOf: [0x0D, 0x0A])
        }

        data.append(contentsOf: [0x0D, 0x0A])

        if let body = request.body {
            data.append(contentsOf: body)
        }

        return data
    }

    private static func formatRequestLine(
        _ request: RFC_9110.Request,
        version: RFC_9110.Version
    ) -> String {
        let method = request.method.description
        let target = formatTarget(request.target)
        let versionString = version.formatted

        return "\(method) \(target) \(versionString)"
    }

    private static func formatTarget(_ target: RFC_9110.Request.Target) -> String {
        switch target {
        case .origin(let path, let query):
            if let query {
                return "\(path.description)?\(query.description)"
            }
            return path.description

        case .absolute(let uri):
            return uri.description

        case .authority(let authority):

            if let port = authority.port {
                return "\(authority.host.description):\(port.value)"
            }
            return authority.host.description

        case .asterisk:
            return "*"
        }
    }
}
