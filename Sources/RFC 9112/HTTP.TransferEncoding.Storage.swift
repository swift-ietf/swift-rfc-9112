extension RFC_9110.TransferEncoding {
    enum Storage: Sendable, Equatable, Hashable {
        case single(String)
        case list([RFC_9110.TransferEncoding])
    }
}
