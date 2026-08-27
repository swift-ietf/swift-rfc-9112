extension RFC_9112.Request.Line {
    public enum Error: Swift.Error, Equatable {
        case lineTooLong(length: Int, max: Int)
        case invalidFormat(reason: String)
        case emptyMethod
        case emptyTarget
        case targetContainsWhitespace
        case invalidEncoding
        case invalidVersion(String)
    }
}
