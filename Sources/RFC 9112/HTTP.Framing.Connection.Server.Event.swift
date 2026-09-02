public import RFC_9110

public import Byte

extension RFC_9112.Framing.Connection.Server {

    public enum Event: Equatable {

        case head(RFC_9112.Framing.Request.Head)

        case body([Byte])

        case end(trailers: RFC_9110.Message.Trailers, octets: Int)
    }
}
