extension RFC_9110.ChunkedEncoding {

    public enum ChunkedDecodingError: Swift.Error, Sendable, Equatable {

        case invalidFormat

        case invalidChunkSize

        case incompleteChunk

        case missingCRLF
    }
}
