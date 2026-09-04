extension RFC_9112.Connection.Client {

    public enum State: Equatable {

        case head

        case body(RFC_9112.Message.Body.Length)

        case tunnelled

        case finished
    }
}
