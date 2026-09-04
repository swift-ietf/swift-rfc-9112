public import RFC_9110

extension RFC_9112 {
    public enum Version {}
}

extension RFC_9112.Version {
    public static var value: RFC_9110.Version {
        try! RFC_9110.Version(major: 1, minor: 1)
    }
}
