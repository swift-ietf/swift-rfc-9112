#if Coder
    public import Byte
    public import Coder
    public import Cursor
    import Parser
    public import RFC_9110
    import Serializer

    extension RFC_9112.Version {

        public struct Coder<Input: Cursor.`Protocol`<Byte, Never>, Buffer: RangeReplaceableCollection<Byte>>: Coding {

            public typealias Output = RFC_9110.Version

            public typealias Failure = RFC_9112.Version.Error

            public init() {}

            public borrowing func parse(_ input: inout Input) throws(Failure) -> RFC_9110.Version {
                let token = Scanning.take(&input) { byte in
                    byte.bitPattern != 0x20 && byte.bitPattern != 0x0D && byte.bitPattern != 0x0A
                }
                return try RFC_9112.Version.number(Scanning.text(token))
            }

            public borrowing func serialize(
                _ output: RFC_9110.Version,
                into buffer: inout Buffer
            ) throws(Failure) {
                buffer.append(contentsOf: Scanning.bytes("HTTP/\(output.major).\(output.minor)"))
            }
        }

        public static var coder: Coder<ArraySlice<Byte>, [Byte]> { .init() }

        public enum Error: Swift::Error, Equatable {

            case format(String)

            case name(String)

            case number(String)
        }
    }

    extension RFC_9112.Version {

        static func number(_ text: String) throws(Error) -> RFC_9110.Version {
            let parts = text.split(separator: "/", omittingEmptySubsequences: false)
            guard parts.count == 2 else { throw .format(text) }
            guard parts[0] == "HTTP" else { throw .name(String(parts[0])) }

            let components = parts[1].split(separator: ".", omittingEmptySubsequences: false)
            guard components.count == 2,
                components[0].count == 1,
                components[1].count == 1,
                let major = UInt(components[0]),
                let minor = UInt(components[1])
            else {
                throw .number(String(parts[1]))
            }

            do throws(RFC_9110.Version.Error) {
                return try RFC_9110.Version(major: major, minor: minor)
            } catch {
                throw .number(String(parts[1]))
            }
        }
    }
#endif
