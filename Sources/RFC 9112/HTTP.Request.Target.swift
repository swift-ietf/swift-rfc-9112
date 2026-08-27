public import RFC_3986
public import RFC_9110

extension RFC_9112.Request {
    public enum Target: Equatable, Hashable {
        case origin(path: RFC_3986.URI.Path, query: RFC_3986.URI.Query?)
        case absolute(RFC_3986.URI)
        case authority(RFC_3986.URI.Authority)
        case asterisk
    }
}

extension RFC_9112.Request.Target {
    public init(_ target: RFC_9110.Target) throws(Error) {
        switch target {
        case .resource(let resource):
            if resource.scheme != nil {
                self = .absolute(resource)
            } else if let path = resource.path {
                self = .origin(path: path, query: resource.query)
            } else {
                throw .path
            }

        case .authority(let authority):
            self = .authority(authority)

        case .asterisk:
            self = .asterisk
        }
    }

    public var semantic: RFC_9110.Target {
        switch self {
        case .origin(let path, let query):
            let suffix = query.map { "?\($0)" } ?? ""
            return .resource(RFC_3986.URI(unchecked: "\(path)\(suffix)"))

        case .absolute(let resource):
            return .resource(resource)

        case .authority(let authority):
            return .authority(authority)

        case .asterisk:
            return .asterisk
        }
    }

    public var text: String {
        switch self {
        case .origin(let path, let query):
            if let query {
                return "\(path)?\(query)"
            }
            return "\(path)"

        case .absolute(let uri):
            return uri.value

        case .authority(let authority):
            return authority.rawValue

        case .asterisk:
            return "*"
        }
    }
}
