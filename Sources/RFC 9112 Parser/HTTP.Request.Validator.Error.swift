public import RFC_9112
extension RFC_9112.Request.Validator {
    public enum Error: Swift.Error, Equatable {
        case ambiguousMessageFraming(reason: String)
        case invalidTransferEncoding(String)
        case invalidContentLength(reason: String)
        case multipleContentLengthValues([Int])
        case chunkedNotFinalEncoding
        case chunkedAppliedMultipleTimes
    }
}
