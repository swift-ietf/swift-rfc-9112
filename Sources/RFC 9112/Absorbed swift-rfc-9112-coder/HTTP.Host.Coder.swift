#if Coder
    public import Byte
    public import Coder
    public import Cursor
    import Parser
    import RFC_3986
    import RFC_9110
    import Serializer

    extension RFC_9112.Host {

        public struct Coder<
            Input: Cursor.`Protocol`<Byte, Never>,
            Buffer: RangeReplaceableCollection<Byte>
        >: Coding {

            public typealias Output = RFC_9112.Host

            public typealias Failure = RFC_9112.Host.Failure

            public init() {}

            public borrowing func parse(_ input: inout Input) throws(Failure) -> RFC_9112.Host {
                let token = Scanning.take(&input) { byte in
                    byte.bitPattern != 0x0D && byte.bitPattern != 0x0A
                }

                return try RFC_9112.Host(text: Scanning.trimmed(Scanning.text(token)))
            }

            public borrowing func serialize(
                _ output: RFC_9112.Host,
                into buffer: inout Buffer
            ) throws(Failure) {
                buffer.append(contentsOf: Scanning.bytes(output.description))
            }
        }

        public static var coder: Coder<ArraySlice<Byte>, [Byte]> { .init() }

        public enum Failure: Swift::Error, Equatable {

            case empty

            case whitespace(String)

            case unclosedBracket(String)

            case invalidPort(String)

            case missing

            case duplicated(count: Int)

            case mismatch(RFC_9112.Host, authority: RFC_9112.Host?)
        }
    }

    extension RFC_9112.Host {

        public init(text: String) throws(Failure) {
            guard !text.isEmpty else { throw .empty }
            guard !text.contains(where: \.isWhitespace) else { throw .whitespace(text) }

            if text.hasPrefix("[") {
                guard let close = text.firstIndex(of: "]") else { throw .unclosedBracket(text) }
                let name = String(text[...close])
                let remainder = text[text.index(after: close)...]
                guard !remainder.isEmpty else {
                    self.init(name: name)
                    return
                }
                guard remainder.hasPrefix(":") else { throw .unclosedBracket(text) }
                self.init(name: name, port: try Self.port(String(remainder.dropFirst())))
                return
            }

            guard let separator = text.lastIndex(of: ":") else {
                self.init(name: text)
                return
            }

            self.init(
                name: String(text[..<separator]),
                port: try Self.port(String(text[text.index(after: separator)...]))
            )
        }

        private static func port(_ text: String) throws(Failure) -> RFC_3986.URI.Port {
            guard let number = UInt16(text) else {
                throw .invalidPort(text)
            }
            return RFC_3986.URI.Port(number)
        }
    }

    extension RFC_9112.Message.Request {

        public var host: RFC_9112.Host? {
            get throws(RFC_9112.Host.Failure) {
                let values = headers.values(.host)

                guard let value = values.first else {
                    guard version < RFC_9112.Version.value else { throw .missing }
                    return nil
                }

                guard values.count == 1 else { throw .duplicated(count: values.count) }

                let host = try RFC_9112.Host(text: value.rawValue)

                guard case .absolute(let uri) = target else { return host }

                let authority = RFC_9112.Host(uri)
                guard authority == host else { throw .mismatch(host, authority: authority) }

                return host
            }
        }
    }
#endif
