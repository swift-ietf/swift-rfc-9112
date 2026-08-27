extension RFC_9112.Framing {

    public enum Terminal: Equatable, Hashable {

        case clean

        case truncated(unconsumed: Int)
    }
}
