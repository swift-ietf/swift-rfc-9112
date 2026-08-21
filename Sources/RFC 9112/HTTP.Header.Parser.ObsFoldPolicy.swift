extension RFC_9110.Header.Parser {

    public enum ObsFoldPolicy {
        case reject
        case replaceWithSpace
        case discard
    }
}
