extension RFC_9110.Framing.Framer {

    internal struct Scan {

        let startLine: String

        let headers: RFC_9110.Headers

        let octets: Int
    }
}
