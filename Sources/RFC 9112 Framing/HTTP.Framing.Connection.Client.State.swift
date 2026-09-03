public import RFC_9112
import RFC_9112_Parser
extension RFC_9112.Framing.Connection.Client {

    internal enum State: Equatable {

        case head

        case body(RFC_9112.Framing.Body.Length)

        case tunnelled

        case finished
    }
}

extension RFC_9112.Framing.Connection.Client.State {

    internal var phase: RFC_9112.Framing.Phase {
        switch self {
        case .head, .tunnelled, .finished: .head
        case .body: .body
        }
    }
}
