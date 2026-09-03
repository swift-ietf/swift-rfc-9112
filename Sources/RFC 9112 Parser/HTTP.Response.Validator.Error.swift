public import RFC_9112
extension RFC_9112.Response.Validator {
    public enum Error: Swift.Error, Equatable {
        case invalidTransferEncoding(String)
        case invalidContentLength(reason: String)
        case multipleContentLengthValues([Int])
        case chunkedNotFinalEncoding
        case chunkedAppliedMultipleTimes
        case invalidStatusCode(Int)
        case transferEncodingWithIncompatibleStatus(Int)
        case transferEncodingWithContentLength
    }
}
