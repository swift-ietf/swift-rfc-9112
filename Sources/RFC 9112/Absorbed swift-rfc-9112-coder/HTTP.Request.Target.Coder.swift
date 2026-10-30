#if Coder
    public import Byte
    public import Coder
    public import Cursor
    import Parser
    import RFC_3986
    import RFC_3986
    public import RFC_9110
    import Serializer

    extension RFC_9112.Request.Target {

        public struct Coder<Input: Cursor.`Protocol`<Byte, Never>, Buffer: RangeReplaceableCollection<Byte>>: Coding {

            public typealias Output = RFC_9112.Request.Target

            public typealias Failure = RFC_9112.Request.Target.Failure

            public let method: RFC_9110.Method

            public init(method: RFC_9110.Method = .get) {
                self.method = method
            }

            public borrowing func parse(_ input: inout Input) throws(Failure) -> Output {
                let token = Scanning.take(&input) { byte in
                    byte.bitPattern != 0x20 && byte.bitPattern != 0x0D && byte.bitPattern != 0x0A
                }
                guard !token.isEmpty else { throw .empty }
                return try RFC_9112.Request.Target(Scanning.text(token), method: method)
            }

            public borrowing func serialize(_ output: Output, into buffer: inout Buffer) throws(Failure) {
                buffer.append(contentsOf: Scanning.bytes(output.text))
            }
        }

        public static var coder: Coder<ArraySlice<Byte>, [Byte]> { .init() }

        public enum Failure: Swift::Error, Equatable {

            case empty

            case absolute

            case authority

            case path

            case query
        }
    }

    extension RFC_9112.Request.Target {

        init(_ text: String, method: RFC_9110.Method) throws(Failure) {
            if text == "*" {
                self = .asterisk
                return
            }

            if text.contains("://") {
                do throws(RFC_3986.Error) {
                    self = .absolute(try RFC_3986.URI(text))
                    return
                } catch {
                    throw .absolute
                }
            }

            if method == .connect {
                do throws(RFC_3986.URI.Authority.Error) {
                    self = .authority(try RFC_3986.URI.Authority(text))
                    return
                } catch {
                    throw .authority
                }
            }

            let components = text.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)

            let path: RFC_3986.URI.Path
            do throws(RFC_3986.URI.Path.Error) {
                path = try RFC_3986.URI.Path(String(components[0]))
            } catch {
                throw .path
            }

            guard components.count == 2 else {
                self = .origin(path: path, query: nil)
                return
            }

            do throws(RFC_3986.URI.Query.Error) {
                self = .origin(path: path, query: try RFC_3986.URI.Query(String(components[1])))
            } catch {
                throw .query
            }
        }

        var text: String {
            switch self {
            case .origin(let path, let query):
                guard let query else { return "\(path)" }
                return "\(path)?\(query)"

            case .absolute(let uri):
                return uri.value

            case .authority(let authority):
                var bytes: [Byte] = []
                RFC_3986.URI.Authority.serialize(authority, into: &bytes)
                return Scanning.text(bytes)

            case .asterisk:
                return "*"
            }
        }
    }
#endif
