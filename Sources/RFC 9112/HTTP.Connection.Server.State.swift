extension RFC_9112.Connection.Server {

    public enum State: Equatable {

        case head

        case body(RFC_9112.Message.Body.Length)

        case finished
    }
}
