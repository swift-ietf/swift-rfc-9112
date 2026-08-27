extension RFC_9112.Framing.Connection.Server {

    internal enum State: Equatable {

        case head

        case body(RFC_9112.Framing.Body.Length)

        case finished
    }
}

extension RFC_9112.Framing.Connection.Server.State {

    internal var phase: RFC_9112.Framing.Phase {
        switch self {
        case .head, .finished: .head
        case .body: .body
        }
    }
}
