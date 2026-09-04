extension RFC_9112.Connection.Client {

    public enum Event: Equatable {

        case head(RFC_9112.Response.Head, connection: RFC_9112.Connection?)

        case end

        case close
    }
}
