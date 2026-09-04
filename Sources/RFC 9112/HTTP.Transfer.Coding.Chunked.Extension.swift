extension RFC_9112.Transfer.Coding.Chunked {

    public struct Extension: Equatable, Hashable {
        public let name: String
        public let value: String?

        public init(name: String, value: String? = nil) {
            self.name = name
            self.value = value
        }
    }
}
