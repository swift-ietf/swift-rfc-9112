extension RFC_9112.Connection.Client {

    public enum Error: Swift::Error, Equatable {

        case responseWithoutRequest

        case unexpectedHead

        case unexpectedEnd
    }
}
