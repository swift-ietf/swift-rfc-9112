#if Coder
    extension RFC_9112.Transfer.Coding.Chunked {

        public struct Size: Equatable, Hashable, Sendable {

            public let rawValue: Int

            public init?(_ rawValue: Int) {
                guard rawValue > 0 else { return nil }
                self.rawValue = rawValue
            }

            private init(positive rawValue: Int) {
                self.rawValue = rawValue
            }
        }
    }

    extension RFC_9112.Transfer.Coding.Chunked.Size {

        public static var `default`: Self { Self(positive: 8_192) }
    }
#endif
