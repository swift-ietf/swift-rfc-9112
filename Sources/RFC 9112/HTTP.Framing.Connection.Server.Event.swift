public import Byte_Primitives

extension RFC_9110.Framing.Connection.Server {

    public enum Event: Sendable, Equatable {

        case head(RFC_9110.Framing.RequestHead)

        case body([Byte])

        case end(trailers: RFC_9110.Headers, octets: Int)
    }
}
