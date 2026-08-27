extension RFC_9112.Framing.Framer {

    internal struct Scan {

        let startLine: String

        let headers: RFC_9110.Message.Headers

        let octets: Int
    }
}
