#if Coder
    extension RFC_9112.Message.Coder {

        public enum Error: Swift::Error, Equatable {

            case bareCarriageReturn

            case headSectionTooLong(limit: Int)

            case bodyTooLong(limit: Int)

            case request(RFC_9112.Request.Head.Error)

            case response(RFC_9112.Response.Head.Error)

            case chunked(RFC_9112.Transfer.Coding.Chunked.Error)
        }
    }
#endif
