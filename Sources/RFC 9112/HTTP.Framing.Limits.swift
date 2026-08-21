extension RFC_9110.Framing {

    public struct Limits: Sendable, Equatable, Hashable {

        public var startLine: Int

        public var fieldSection: Int

        public var body: Int

        public init(startLine: Int, fieldSection: Int, body: Int) {
            self.startLine = startLine
            self.fieldSection = fieldSection
            self.body = body
        }
    }
}

extension RFC_9110.Framing.Limits {

    public var headSection: Int { startLine + fieldSection }
}

extension RFC_9110.Framing.Limits {

    public static let `default` = Self(
        startLine: 8_000,
        fieldSection: 64 * 1_024,
        body: 16 * 1_024 * 1_024
    )
}
