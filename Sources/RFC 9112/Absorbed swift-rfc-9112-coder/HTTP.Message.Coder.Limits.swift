#if Coder
    extension RFC_9112.Message.Coder {

        public struct Limits: Equatable, Hashable {

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

    extension RFC_9112.Message.Coder.Limits {

        public var headSection: Int { startLine + fieldSection }

        public static var `default`: Self {
            Self(
                startLine: 8_000,
                fieldSection: 64 * 1_024,
                body: 16 * 1_024 * 1_024
            )
        }
    }
#endif
