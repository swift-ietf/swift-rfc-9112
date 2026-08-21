extension RFC_9110.Host.Validator {
    public enum Error: Swift.Error, Sendable, Equatable {
        case missingHost
        case multipleHostHeaders(count: Int)
        case invalidHostFormat(String, reason: String)
        case invalidPort(String)
        case hostMismatchesAuthority(host: String, authority: String)
    }
}
