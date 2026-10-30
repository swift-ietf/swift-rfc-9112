#if Coder
    public import Byte
    public import Coder
    public import Cursor
    import Parser
    import RFC_9110
    import Serializer

    extension RFC_9112.Request.Line {

        public struct Coder<Input: Cursor.`Protocol`<Byte, Never>, Buffer: RangeReplaceableCollection<Byte>>: Coding {

            public typealias Output = RFC_9112.Request.Line

            public typealias Failure = RFC_9112.Request.Line.Error

            public init() {}

            public borrowing func parse(_ input: inout Input) throws(Failure) -> Output {
                let methodToken = Scanning.take(&input) { byte in
                    byte.bitPattern != 0x20 && byte.bitPattern != 0x0D && byte.bitPattern != 0x0A
                }
                guard !methodToken.isEmpty else { throw .emptyMethod }
                guard let separator = input.next(), separator == Scanning.space else {
                    throw .expectedSpace
                }

                let method = RFC_9110.Method(rawValue: Scanning.text(methodToken))

                let target: RFC_9112.Request.Target
                do throws(RFC_9112.Request.Target.Failure) {
                    target = try RFC_9112.Request.Target.Coder<Input, Buffer>(method: method).parse(&input)
                } catch {
                    throw .target(error)
                }

                guard let space = input.next(), space == Scanning.space else { throw .expectedSpace }

                do throws(RFC_9112.Version.Error) {
                    return Output(
                        method: method,
                        target: target,
                        version: try RFC_9112.Version.Coder<Input, Buffer>().parse(&input)
                    )
                } catch {
                    throw .version(error)
                }
            }

            public borrowing func serialize(_ output: Output, into buffer: inout Buffer) throws(Failure) {
                buffer.append(contentsOf: Scanning.bytes(output.method.rawValue))
                buffer.append(Scanning.space)

                do throws(RFC_9112.Request.Target.Failure) {
                    try RFC_9112.Request.Target.Coder<Input, Buffer>(method: output.method)
                        .serialize(output.target, into: &buffer)
                } catch {
                    throw .target(error)
                }

                buffer.append(Scanning.space)

                do throws(RFC_9112.Version.Error) {
                    try RFC_9112.Version.Coder<Input, Buffer>().serialize(output.version, into: &buffer)
                } catch {
                    throw .version(error)
                }
            }
        }

        public static var coder: Coder<ArraySlice<Byte>, [Byte]> { .init() }

        public enum Error: Swift::Error, Equatable {

            case emptyMethod

            case expectedSpace

            case target(RFC_9112.Request.Target.Failure)

            case version(RFC_9112.Version.Error)
        }
    }
#endif
