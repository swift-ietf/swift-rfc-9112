extension RFC_9112.Transfer.Encoding {
    enum Storage: Equatable, Hashable {
        case single(String)
        case list([RFC_9112.Transfer.Encoding])
    }
}
