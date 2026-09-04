extension RFC_9112.Connection.Server {

    public enum Event: Equatable {

        case head(RFC_9112.Request.Head, connection: RFC_9112.Connection?)

        case end

        case close
    }
}
