extension RFC_9110.Framing {

    public enum Context: Sendable, Equatable, Hashable {

        case request

        case response(statusCode: Int, requestMethod: RFC_9110.Method)
    }
}

extension RFC_9110.Framing.Context {

    public var isRequest: Bool {
        switch self {
        case .request: true
        case .response: false
        }
    }
}
