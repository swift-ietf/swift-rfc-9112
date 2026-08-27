public import RFC_9110

extension RFC_9112.Framing {

    public enum Context: Equatable, Hashable {

        case request

        case response(status: Int, request: RFC_9110.Method)
    }
}

extension RFC_9112.Framing.Context {

    public var isRequest: Bool {
        switch self {
        case .request: true
        case .response: false
        }
    }
}
