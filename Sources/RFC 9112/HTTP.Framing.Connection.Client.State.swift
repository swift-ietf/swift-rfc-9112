extension RFC_9110.Framing.Connection.Client {

    internal enum State: Sendable, Equatable {

        case head

        case body(RFC_9110.Framing.BodyLength)

        case tunnelled

        case finished
    }
}

extension RFC_9110.Framing.Connection.Client.State {

    internal var phase: RFC_9110.Framing.Phase {
        switch self {
        case .head, .tunnelled, .finished: .head
        case .body: .body
        }
    }
}
