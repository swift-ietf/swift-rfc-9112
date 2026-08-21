extension RFC_9110.Framing.Connection.Server {

    internal enum State: Sendable, Equatable {

        case head

        case body(RFC_9110.Framing.BodyLength)

        case finished
    }
}

extension RFC_9110.Framing.Connection.Server.State {

    internal var phase: RFC_9110.Framing.Phase {
        switch self {
        case .head, .finished: .head
        case .body: .body
        }
    }
}
