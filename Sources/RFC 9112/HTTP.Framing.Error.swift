extension RFC_9110.Framing {

    public enum Error: Swift.Error, Sendable, Equatable, Hashable {

        case invalidContentLength(String)

        case conflictingContentLength([String])

        case transferEncodingWithContentLength

        case chunkedNotFinal

        case transferEncodingWithoutChunked

        case malformedTransferEncoding(String)

        case headSectionTooLong(limit: Int)

        case malformedStartLine(String)

        case malformedFieldLine(String)

        case bareCarriageReturn

        case obsoleteLineFolding

        case truncatedMessage

        case invalidChunkSize(String)

        case malformedChunk(String)

        case bodyTooLong(limit: Int)

        case responseWithoutRequest

        case closeDelimitedRequest
    }
}
