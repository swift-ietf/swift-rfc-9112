#if Coder
    public import Byte
    public import Coder
    public import Cursor
    import Parser
    public import RFC_9110
    import Serializer

    extension RFC_9112.Field {

        public struct Coder<Input: Cursor.`Protocol`<Byte, Never>, Buffer: RangeReplaceableCollection<Byte>>: Coding {

            public typealias Output = RFC_9110.Field

            public typealias Failure = RFC_9112.Field.Error

            public let policy: RFC_9112.Field.ObsFold.Policy

            public init(policy: RFC_9112.Field.ObsFold.Policy = .reject) {
                self.policy = policy
            }

            public borrowing func parse(_ input: inout Input) throws(Failure) -> Output {
                let nameBytes = Scanning.take(&input) { byte in
                    byte.bitPattern != 0x3A && byte.bitPattern != 0x0D && byte.bitPattern != 0x0A
                }
                guard let colon = input.next(), colon.bitPattern == 0x3A else {
                    throw .missingColon
                }
                guard !nameBytes.isEmpty else { throw .emptyName }
                guard let last = nameBytes.last, last.bitPattern != 0x20, last.bitPattern != 0x09 else {
                    throw .whitespaceBeforeColon
                }

                var value = Scanning.trimmed(Scanning.text(Scanning.line(&input)))
                try fold(&input, into: &value)

                let name: RFC_9110.Field.Name
                do throws(RFC_9110.Field.Name.Error) {
                    name = try RFC_9110.Field.Name(Scanning.text(nameBytes))
                } catch {
                    throw .name(error)
                }

                do throws(RFC_9110.Field.Error) {
                    return RFC_9110.Field(name: name, value: try RFC_9110.Field.Value(value))
                } catch {
                    throw .value(value)
                }
            }

            public borrowing func serialize(_ output: Output, into buffer: inout Buffer) throws(Failure) {
                buffer.append(contentsOf: Scanning.bytes(output.name.rawValue))
                buffer.append(Byte(bitPattern: 0x3A))
                buffer.append(Scanning.space)
                buffer.append(contentsOf: Scanning.bytes(output.value.rawValue))
            }

            private borrowing func fold(_ input: inout Input, into value: inout String) throws(Failure) {
                while true {
                    let mark = input.checkpoint
                    guard Scanning.terminator(&input) else { return }

                    let continuation = input.checkpoint
                    guard let byte = input.next(),
                        byte.bitPattern == 0x20 || byte.bitPattern == 0x09
                    else {
                        input.seek(to: mark)
                        return
                    }

                    switch policy {
                    case .reject:
                        input.seek(to: mark)
                        throw .obsoleteLineFolding

                    case .space:
                        input.seek(to: continuation)
                        value += " " + Scanning.trimmed(Scanning.text(Scanning.line(&input)))

                    case .discard:
                        input.seek(to: continuation)
                        _ = Scanning.line(&input)
                    }
                }
            }
        }

        public static var coder: Coder<ArraySlice<Byte>, [Byte]> { .init() }

        public enum Error: Swift::Error, Equatable {

            case missingColon

            case emptyName

            case whitespaceBeforeColon

            case name(RFC_9110.Field.Name.Error)

            case value(String)

            case obsoleteLineFolding
        }
    }
#endif
