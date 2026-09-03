public import RFC_9112
extension RFC_9112.Host.Validator {
    public enum Error: Swift.Error, Equatable {
        case missingHost
        case multipleHostHeaders(count: Int)
        case invalidHostFormat(String, reason: String)
        case invalidPort(String)
        case hostMismatchesAuthority(host: String, authority: String)
    }
}
