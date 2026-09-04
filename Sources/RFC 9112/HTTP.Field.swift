extension RFC_9112 {
    public enum Field {}
}

extension RFC_9112.Field {

    public enum ObsFold {}
}

extension RFC_9112.Field.ObsFold {

    public enum Policy: Equatable, Hashable {

        case reject

        case space

        case discard
    }
}
