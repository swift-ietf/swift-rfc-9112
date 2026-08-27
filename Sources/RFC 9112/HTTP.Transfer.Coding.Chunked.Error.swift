extension RFC_9112.Transfer.Coding.Chunked {

    public enum Error: Swift.Error, Equatable {

        case invalidFormat

        case invalidChunkSize

        case incompleteChunk

        case missingCRLF
    }
}
