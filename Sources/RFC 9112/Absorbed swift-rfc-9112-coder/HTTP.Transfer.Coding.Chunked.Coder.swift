#if Coder
    public import Byte
    public import Coder
    public import Cursor
    import Parser
    import RFC_9110
    import Serializer

    extension RFC_9112.Transfer.Coding.Chunked {

        public struct Coder<Input: Cursor.`Protocol`<Byte, Never>, Buffer: RangeReplaceableCollection<Byte>>: Coding {

            public typealias Output = RFC_9112.Transfer.Coding.Chunked.Result

            public typealias Failure = RFC_9112.Transfer.Coding.Chunked.Error

            public let size: RFC_9112.Transfer.Coding.Chunked.Size

            public init(size: RFC_9112.Transfer.Coding.Chunked.Size = .default) {
                self.size = size
            }

            public borrowing func parse(_ input: inout Input) throws(Failure) -> Output {
                var data: [Byte] = []
                var extensions: [[RFC_9112.Transfer.Coding.Chunked.Extension]] = []
                var trailers: [RFC_9110.Field] = []

                while true {
                    let header = Scanning.text(Scanning.line(&input))
                    guard Scanning.terminator(&input) else { throw .invalidFormat }

                    let parts = header.split(separator: ";", maxSplits: 1)
                    guard let sizeText = parts.first.map({ Scanning.trimmed(String($0)) }),
                        !sizeText.isEmpty,
                        sizeText.utf8.allSatisfy(Self.isHexadecimal),
                        let count = Int(sizeText, radix: 16)
                    else {
                        throw .invalidChunkSize
                    }

                    let chunkExtensions =
                        parts.count > 1
                        ? RFC_9112.Transfer.Coding.Chunked.Extension.list(in: String(parts[1]))
                        : []

                    guard count > 0 else {
                        if !chunkExtensions.isEmpty { extensions.append(chunkExtensions) }

                        while true {
                            let line = Scanning.line(&input)
                            guard Scanning.terminator(&input) else { throw .invalidFormat }
                            guard !line.isEmpty else {
                                return Output(data: data, extensions: extensions, trailers: trailers)
                            }
                            if let trailer = Self.trailer(Scanning.text(line)) {
                                trailers.append(trailer)
                            }
                        }
                    }

                    extensions.append(chunkExtensions)

                    for _ in 0..<count {
                        guard let byte = input.next() else { throw .incompleteChunk }
                        data.append(byte)
                    }
                    guard Scanning.terminator(&input) else { throw .missingCRLF }
                }
            }

            public borrowing func serialize(_ output: Output, into buffer: inout Buffer) throws(Failure) {
                var offset = output.data.startIndex
                var chunk = 0

                while offset < output.data.endIndex {
                    let end = min(offset + size.rawValue, output.data.endIndex)
                    let slice = output.data[offset..<end]

                    buffer.append(contentsOf: Scanning.bytes(String(slice.count, radix: 16)))
                    if chunk < output.extensions.count {
                        for element in output.extensions[chunk] {
                            buffer.append(contentsOf: Scanning.bytes(element.text))
                        }
                    }
                    buffer.append(contentsOf: Scanning.crlf)
                    buffer.append(contentsOf: slice)
                    buffer.append(contentsOf: Scanning.crlf)

                    offset = end
                    chunk += 1
                }

                buffer.append(contentsOf: Scanning.bytes("0"))
                buffer.append(contentsOf: Scanning.crlf)

                for trailer in output.trailers {
                    buffer.append(
                        contentsOf: Scanning.bytes("\(trailer.name.rawValue): \(trailer.value.description)")
                    )
                    buffer.append(contentsOf: Scanning.crlf)
                }

                buffer.append(contentsOf: Scanning.crlf)
            }

            private static func isHexadecimal(_ byte: UInt8) -> Bool {
                switch byte {
                case 0x30...0x39, 0x41...0x46, 0x61...0x66: true
                default: false
                }
            }

            private static func trailer(_ line: String) -> RFC_9110.Field? {
                let parts = line.split(separator: ":", maxSplits: 1)
                guard parts.count == 2 else { return nil }
                return try? RFC_9110.Field(
                    name: Scanning.trimmed(String(parts[0])),
                    value: Scanning.trimmed(String(parts[1]))
                )
            }
        }

        public static var coder: Coder<ArraySlice<Byte>, [Byte]> { .init() }
    }

    extension RFC_9112.Transfer.Coding.Chunked.Result {

        public static var coder: RFC_9112.Transfer.Coding.Chunked.Coder<ArraySlice<Byte>, [Byte]> {
            RFC_9112.Transfer.Coding.Chunked.coder
        }
    }

    extension RFC_9112.Transfer.Coding.Chunked.Extension {

        public var text: String {
            guard let value else { return ";\(name)" }

            if value.contains(where: { $0 == ";" || $0.isWhitespace }) {
                return ";\(name)=\"\(value)\""
            }
            return ";\(name)=\(value)"
        }

        static func list(in text: String) -> [Self] {
            var elements: [Self] = []

            for part in text.split(separator: ";", omittingEmptySubsequences: true) {
                let trimmed = Scanning.trimmed(String(part))

                guard trimmed.contains("=") else {
                    elements.append(Self(name: trimmed))
                    continue
                }

                let components = trimmed.split(separator: "=", maxSplits: 1)
                guard components.count == 2 else { continue }

                let name = Scanning.trimmed(String(components[0]))
                var value = Scanning.trimmed(String(components[1]))
                if value.hasPrefix("\"") && value.hasSuffix("\"") && value.count > 1 {
                    value = String(value.dropFirst().dropLast())
                }
                elements.append(Self(name: name, value: value))
            }

            return elements
        }
    }
#endif
