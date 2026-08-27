extension RFC_9112.Response.Line {
    public enum Error: Swift.Error, Equatable {
        case invalidFormat(reason: String)
        case invalidStatusCode(String)
        case statusCodeOutOfRange(Int)
        case invalidEncoding
    }
}
