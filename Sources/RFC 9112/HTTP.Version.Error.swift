extension RFC_9112.Version {
    public enum Error: Swift.Error, Equatable {
        case format(String)
        case name(String)
        case number(String)
    }
}
