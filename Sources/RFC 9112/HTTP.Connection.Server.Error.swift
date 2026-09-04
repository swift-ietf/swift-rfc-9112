extension RFC_9112.Connection.Server {

    public enum Error: Swift.Error, Equatable {

        case closeDelimitedRequest

        case unexpectedHead

        case unexpectedEnd
    }
}
