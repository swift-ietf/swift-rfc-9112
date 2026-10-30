#if Coder
    public import Byte
    public import Coder
    public import Cursor
    import Parser
    import RFC_9110
    import Serializer

    extension RFC_9112.Response.Line {

        public struct Coder<Input: Cursor.`Protocol`<Byte, Never>, Buffer: RangeReplaceableCollection<Byte>>: Coding {

            public typealias Output = RFC_9112.Response.Line

            public typealias Failure = RFC_9112.Response.Line.Error

            public init() {}

            public borrowing func parse(_ input: inout Input) throws(Failure) -> Output {
                let version: RFC_9110.Version
                do throws(RFC_9112.Version.Error) {
                    version = try RFC_9112.Version.Coder<Input, Buffer>().parse(&input)
                } catch {
                    throw .version(error)
                }

                guard let space = input.next(), space == Scanning.space else { throw .expectedSpace }

                let codeToken = Scanning.take(&input) { byte in
                    byte.bitPattern != 0x20 && byte.bitPattern != 0x0D && byte.bitPattern != 0x0A
                }
                let codeText = Scanning.text(codeToken)
                guard codeToken.count == 3, let code = Int(codeText) else {
                    throw .status(codeText)
                }
                guard (100...599).contains(code) else { throw .statusOutOfRange(code) }

                let mark = input.checkpoint
                guard let separator = input.next(), separator == Scanning.space else {
                    input.seek(to: mark)
                    return Output(version: version, status: RFC_9110.Status(code))
                }

                let reason = Scanning.line(&input)
                return Output(
                    version: version,
                    status: RFC_9110.Status(code),
                    reason: reason.isEmpty ? nil : RFC_9110.Status.Reason(reason)
                )
            }

            public borrowing func serialize(_ output: Output, into buffer: inout Buffer) throws(Failure) {
                do throws(RFC_9112.Version.Error) {
                    try RFC_9112.Version.Coder<Input, Buffer>().serialize(output.version, into: &buffer)
                } catch {
                    throw .version(error)
                }

                buffer.append(Scanning.space)
                buffer.append(contentsOf: Scanning.bytes(String(output.status.code)))

                guard let reason = output.reason else { return }
                buffer.append(Scanning.space)
                buffer.append(contentsOf: reason.bytes)
            }
        }

        public static var coder: Coder<ArraySlice<Byte>, [Byte]> { .init() }

        public enum Error: Swift::Error, Equatable {

            case version(RFC_9112.Version.Error)

            case expectedSpace

            case status(String)

            case statusOutOfRange(Int)
        }
    }
#endif
