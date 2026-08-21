extension RFC_9110.Framing {

    public enum Terminal: Sendable, Equatable, Hashable {

        case clean

        case truncated(unconsumed: Int)
    }
}
