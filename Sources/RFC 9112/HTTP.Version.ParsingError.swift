extension RFC_9110.Version {
    public enum ParsingError: Swift.Error, Sendable, Equatable {
        case invalidFormat(reason: String)
        case invalidHTTPName(String)
        case invalidVersionNumber
    }
}
