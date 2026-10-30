#if Coder
    public import Byte
    import Cursor
    public import RFC_9110

    extension RFC_9112.Message {

        public struct Coder: ~Copyable {

            private var buffer: [Byte]

            public let limits: Limits

            public let policy: RFC_9112.Field.ObsFold.Policy

            public init(
                limits: Limits = .default,
                policy: RFC_9112.Field.ObsFold.Policy = .reject
            ) {
                self.buffer = []
                self.limits = limits
                self.policy = policy
            }
        }
    }

    extension RFC_9112.Message.Coder {

        public var unconsumed: Int { buffer.count }

        public mutating func append(
            _ bytes: [Byte],
            accumulating phase: Phase
        ) throws(Error) {
            let budget = phase.budget(under: limits)
            guard buffer.count + bytes.count <= budget else {
                throw phase.overrun(of: budget)
            }
            buffer.append(contentsOf: bytes)
        }

        public mutating func take() -> [Byte] {
            defer { buffer.removeAll(keepingCapacity: true) }
            return buffer
        }

        public consuming func surrender() -> [Byte] {
            buffer
        }

        public consuming func finish() -> Terminal {
            buffer.isEmpty ? .clean : .truncated(unconsumed: buffer.count)
        }
    }

    extension RFC_9112.Message.Coder {

        public mutating func request() throws(Error) -> RFC_9112.Request.Head? {
            guard let end = try head() else { return nil }

            var input = buffer[..<end]
            let head: RFC_9112.Request.Head
            do throws(RFC_9112.Request.Head.Error) {
                head = try RFC_9112.Request.Head.Coder<ArraySlice<Byte>, [Byte]>(policy: policy)
                    .parse(&input)
            } catch {
                throw .request(error)
            }

            buffer.removeFirst(end)
            return head
        }

        public mutating func response(
            answering method: RFC_9110.Method
        ) throws(Error) -> RFC_9112.Response.Head? {
            guard let end = try head() else { return nil }

            var input = buffer[..<end]
            let head: RFC_9112.Response.Head
            do throws(RFC_9112.Response.Head.Error) {
                head = try RFC_9112.Response.Head.Coder<ArraySlice<Byte>, [Byte]>(
                    answering: method,
                    policy: policy
                ).parse(&input)
            } catch {
                throw .response(error)
            }

            buffer.removeFirst(end)
            return head
        }

        private borrowing func head() throws(Error) -> Int? {
            var index = 0
            var lineStart = 0
            var first = true

            scan: while index < buffer.count {
                let byte = buffer[index].bitPattern

                if byte == 0x0D {
                    guard index + 1 < buffer.count else { break scan }
                    guard buffer[index + 1].bitPattern == 0x0A else { throw .bareCarriageReturn }
                    let empty = index == lineStart
                    try measure(index - lineStart, first: first)
                    index += 2
                    if empty { return try within(index) }
                    lineStart = index
                    first = false
                    continue
                }

                if byte == 0x0A {
                    let empty = index == lineStart
                    try measure(index - lineStart, first: first)
                    index += 1
                    if empty { return try within(index) }
                    lineStart = index
                    first = false
                    continue
                }

                index += 1
            }

            guard buffer.count <= limits.headSection else {
                throw .headSectionTooLong(limit: limits.headSection)
            }
            return nil
        }

        private borrowing func measure(_ length: Int, first: Bool) throws(Error) {
            guard first, length > limits.startLine else { return }
            throw .headSectionTooLong(limit: limits.startLine)
        }

        private borrowing func within(_ octets: Int) throws(Error) -> Int {
            guard octets <= limits.headSection else {
                throw .headSectionTooLong(limit: limits.headSection)
            }
            return octets
        }
    }

    extension RFC_9112.Message.Coder {

        public mutating func body(
            _ length: RFC_9112.Message.Body.Length
        ) throws(Error) -> RFC_9112.Message.Body? {
            switch length {
            case .none:
                return RFC_9112.Message.Body(content: [])

            case .length(let expected):
                guard expected <= limits.body else { throw .bodyTooLong(limit: limits.body) }
                guard buffer.count >= expected else { return nil }
                let content = Array(buffer[..<expected])
                buffer.removeFirst(expected)
                return RFC_9112.Message.Body(content: content)

            case .chunked:
                var input = buffer[...]
                let result: RFC_9112.Transfer.Coding.Chunked.Result
                do throws(RFC_9112.Transfer.Coding.Chunked.Error) {
                    result = try RFC_9112.Transfer.Coding.Chunked.coder.parse(&input)
                } catch {
                    switch error {
                    case .incompleteChunk, .invalidFormat: return nil
                    case .invalidChunkSize, .missingCRLF: throw .chunked(error)
                    }
                }

                guard result.data.count <= limits.body else {
                    throw .bodyTooLong(limit: limits.body)
                }

                buffer.removeFirst(buffer.count - input.count)
                return RFC_9112.Message.Body(
                    content: result.data,
                    trailers: RFC_9110.Message.Trailers(result.trailers)
                )

            case .untilClose, .tunnel:
                return nil
            }
        }
    }
#endif
