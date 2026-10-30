#if Coder
    public import Byte
    public import Coder
    public import Cursor
    import Parser
    import RFC_9110
    import RFC_9110
    import Serializer

    extension RFC_9112.Transfer.Encoding {

        public struct Coder<Input: Cursor.`Protocol`<Byte, Never>, Buffer: RangeReplaceableCollection<Byte>>: Coding {

            public typealias Output = RFC_9112.Transfer.Encoding

            public typealias Failure = RFC_9112.Transfer.Encoding.Error

            public init() {}

            public borrowing func parse(_ input: inout Input) throws(Failure) -> Output {
                let tokens: [RFC_9110.Token]
                do {
                    tokens = try RFC_9110.Field.Value.List(RFC_9110.Token.Coder<Input, Buffer>())
                        .parse(&input)
                } catch {
                    throw .malformed
                }

                let codings = tokens.map { Output(codingName: $0.rawValue.lowercased()) }
                guard let first = codings.first else { throw .empty }
                return codings.count == 1 ? first : .list(codings)
            }

            public borrowing func serialize(_ output: Output, into buffer: inout Buffer) throws(Failure) {
                let tokens = output.codings.map { RFC_9110.Token(unchecked: $0) }
                do {
                    try RFC_9110.Field.Value.List(RFC_9110.Token.Coder<Input, Buffer>())
                        .serialize(tokens, into: &buffer)
                } catch {
                    throw .malformed
                }
            }
        }

        public static var coder: Coder<ArraySlice<Byte>, [Byte]> { .init() }

        public enum Error: Swift::Error, Equatable {

            case empty

            case malformed
        }
    }
#endif
