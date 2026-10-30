#if Coder
    public import Byte
    public import Coder
    public import Cursor
    import Parser
    public import RFC_9110
    import Serializer

    extension RFC_9112.Response.Head {

        public struct Coder<Input: Cursor.`Protocol`<Byte, Never>, Buffer: RangeReplaceableCollection<Byte>>: Coding {

            public typealias Output = RFC_9112.Response.Head

            public typealias Failure = RFC_9112.Response.Head.Error

            public let answering: RFC_9110.Method

            public let policy: RFC_9112.Field.ObsFold.Policy

            public init(
                answering: RFC_9110.Method = .get,
                policy: RFC_9112.Field.ObsFold.Policy = .reject
            ) {
                self.answering = answering
                self.policy = policy
            }

            public borrowing func parse(_ input: inout Input) throws(Failure) -> Output {
                let line: RFC_9112.Response.Line
                do throws(RFC_9112.Response.Line.Error) {
                    line = try RFC_9112.Response.Line.Coder<Input, Buffer>().parse(&input)
                } catch {
                    throw .line(error)
                }
                guard Scanning.terminator(&input) else { throw .expectedTerminator }

                var fields: [RFC_9110.Field] = []
                while true {
                    let mark = input.checkpoint
                    if Scanning.terminator(&input) { break }
                    input.seek(to: mark)

                    do throws(RFC_9112.Field.Error) {
                        fields.append(
                            try RFC_9112.Field.Coder<Input, Buffer>(policy: policy).parse(&input)
                        )
                    } catch {
                        throw .field(error)
                    }
                    guard Scanning.terminator(&input) else { throw .expectedTerminator }
                }

                let headers = RFC_9110.Message.Headers(fields)

                let transferEncoding: RFC_9112.Transfer.Encoding?
                let contentLength: Int?
                do throws(Framing.Error) {
                    transferEncoding = try Framing.transferEncoding(in: headers)
                    contentLength = try Framing.contentLength(in: headers)
                } catch {
                    throw Failure(error)
                }

                let length: RFC_9112.Message.Body.Length
                do throws(RFC_9112.Message.Body.Length.Error) {
                    length = try RFC_9112.Message.Body.Length(
                        .response(status: line.status, to: answering),
                        transferEncoding: transferEncoding,
                        contentLength: contentLength
                    )
                } catch {
                    throw .length(error)
                }

                return Output(line: line, headers: headers, length: length)
            }

            public borrowing func serialize(_ output: Output, into buffer: inout Buffer) throws(Failure) {
                do throws(RFC_9112.Response.Line.Error) {
                    try RFC_9112.Response.Line.Coder<Input, Buffer>().serialize(output.line, into: &buffer)
                } catch {
                    throw .line(error)
                }
                buffer.append(contentsOf: Scanning.crlf)

                for field in output.headers {
                    do throws(RFC_9112.Field.Error) {
                        try RFC_9112.Field.Coder<Input, Buffer>(policy: policy)
                            .serialize(field, into: &buffer)
                    } catch {
                        throw .field(error)
                    }
                    buffer.append(contentsOf: Scanning.crlf)
                }

                buffer.append(contentsOf: Scanning.crlf)
            }
        }

        public static var coder: Coder<ArraySlice<Byte>, [Byte]> { .init() }

        public enum Error: Swift::Error, Equatable {

            case line(RFC_9112.Response.Line.Error)

            case expectedTerminator

            case field(RFC_9112.Field.Error)

            case transferEncoding(String)

            case contentLength(String)

            case conflictingContentLength([String])

            case length(RFC_9112.Message.Body.Length.Error)
        }
    }

    extension RFC_9112.Response.Head.Error {

        init(_ framing: Framing.Error) {
            switch framing {
            case .transferEncoding(let value): self = .transferEncoding(value)
            case .contentLength(let value): self = .contentLength(value)
            case .conflictingContentLength(let values): self = .conflictingContentLength(values)
            }
        }
    }
#endif
