public import RFC_9110

public import Byte
import Byte_Standard_Library_Integration
import INCITS_4_1986

extension RFC_9112.Framing {

    public struct Framer: ~Copyable {

        private var buffer: [Byte]

        public let limits: Limits

        public init(limits: Limits = .default) {
            self.buffer = []
            self.limits = limits
        }
    }
}

extension RFC_9112.Framing.Framer {

    public var unconsumed: Int { buffer.count }
}

extension RFC_9112.Framing.Framer {

    public mutating func append(
        _ bytes: [Byte],
        accumulating phase: RFC_9112.Framing.Phase
    ) throws(RFC_9112.Framing.Error) {
        let budget = phase.budget(under: limits)
        guard buffer.count + bytes.count <= budget else {
            throw phase.overrun(of: budget)
        }
        buffer.append(contentsOf: bytes)
    }
}

extension RFC_9112.Framing.Framer {

    internal mutating func takeBuffered() -> [Byte] {
        defer { buffer.removeAll(keepingCapacity: true) }
        return buffer
    }

    internal consuming func surrenderUnconsumed() -> [Byte] {
        buffer
    }
}

extension RFC_9112.Framing.Framer {

    public mutating func nextRequestHead() throws(RFC_9112.Framing.Error)
        -> RFC_9112.Framing.Request.Head?
    {
        guard let scan = try Self.scanHead(buffer, limits: limits) else { return nil }

        let line: RFC_9112.Request.Line
        do throws(RFC_9112.Request.Line.Error) {
            line = try RFC_9112.Request.Line.parse(scan.startLine)
        } catch {
            throw .malformedStartLine(scan.startLine)
        }

        let bodyLength = try RFC_9112.Framing.Body.Length.determine(
            context: .request,
            headers: scan.headers
        )

        buffer.removeFirst(scan.octets)
        return RFC_9112.Framing.Request.Head(
            line: line,
            headers: scan.headers,
            length: bodyLength,
            octets: scan.octets
        )
    }

    public mutating func nextResponseHead(
        answering requestMethod: RFC_9110.Method
    ) throws(RFC_9112.Framing.Error) -> RFC_9112.Framing.Response.Head? {
        guard let scan = try Self.scanHead(buffer, limits: limits) else { return nil }

        let line: RFC_9112.Response.Line
        do throws(RFC_9112.Response.Line.Error) {
            line = try RFC_9112.Response.Line.parse(scan.startLine)
        } catch {
            throw .malformedStartLine(scan.startLine)
        }

        let bodyLength = try RFC_9112.Framing.Body.Length.determine(
            context: .response(status: line.status.code, request: requestMethod),
            headers: scan.headers
        )

        buffer.removeFirst(scan.octets)
        return RFC_9112.Framing.Response.Head(
            line: line,
            headers: scan.headers,
            length: bodyLength,
            octets: scan.octets
        )
    }
}

extension RFC_9112.Framing.Framer {

    public consuming func finish() throws(RFC_9112.Framing.Error)
        -> RFC_9112.Framing.Terminal
    {
        buffer.isEmpty ? .clean : .truncated(unconsumed: buffer.count)
    }
}

extension RFC_9112.Framing.Framer {

    public mutating func nextBody(
        _ length: RFC_9112.Framing.Body.Length
    ) throws(RFC_9112.Framing.Error) -> RFC_9112.Framing.Body? {
        switch length {
        case .none:
            return RFC_9112.Framing.Body(
                content: [],
                octets: 0,
                trailers: RFC_9110.Message.Trailers()
            )

        case .length(let expected):
            if expected > limits.body { throw .bodyTooLong(limit: limits.body) }
            guard buffer.count >= expected else { return nil }
            let content = Array(buffer[..<expected])
            buffer.removeFirst(expected)
            return RFC_9112.Framing.Body(
                content: content,
                octets: expected,
                trailers: RFC_9110.Message.Trailers()
            )

        case .chunked:
            guard let framed = try Self.scanChunkedBody(buffer, limit: limits.body) else {
                return nil
            }
            buffer.removeFirst(framed.octets)
            return RFC_9112.Framing.Body(
                content: framed.content,
                octets: framed.octets,
                trailers: framed.trailers
            )

        case .untilClose, .tunnel:
            return nil
        }
    }
}

extension RFC_9112.Framing.Framer {

    internal static func scanHead(
        _ buffer: borrowing [Byte],
        limits: RFC_9112.Framing.Limits
    ) throws(RFC_9112.Framing.Error) -> Self.Scan? {
        var lines: [[Byte]] = []
        var index = 0
        var lineStart = 0
        var headEnd: Int?

        scan: while index < buffer.count {
            switch buffer[index].bitPattern {
            case 0x0D:

                guard buffer.indices.contains(index + 1) else { return nil }
                guard buffer[index + 1] == Byte(bitPattern: 0x0A) else { throw .bareCarriageReturn }
                let line = Array(buffer[lineStart..<index])
                index += 2
                if line.isEmpty {
                    headEnd = index
                    break scan
                }
                lines.append(line)
                lineStart = index

            case 0x0A:
                let line = Array(buffer[lineStart..<index])
                index += 1
                if line.isEmpty {
                    headEnd = index
                    break scan
                }
                lines.append(line)
                lineStart = index

            default:
                index += 1
            }
        }

        guard let octets = headEnd else { return nil }
        guard let startLineBytes = lines.first else { throw .malformedStartLine("") }
        guard startLineBytes.count <= limits.startLine else {
            throw .headSectionTooLong(limit: limits.startLine)
        }
        guard octets <= limits.headSection else {
            throw .headSectionTooLong(limit: limits.headSection)
        }

        var fields: [RFC_9110.Field] = []
        for fieldLine in lines.dropFirst() {

            if let first = fieldLine.first,
                first == Byte(bitPattern: 0x20) || first == Byte(bitPattern: 0x09)
            {
                throw .obsoleteLineFolding
            }
            guard let colon = fieldLine.firstIndex(of: Byte(bitPattern: 0x3A)) else {
                throw .malformedFieldLine(Self.text(fieldLine))
            }

            let nameBytes = Array(fieldLine[fieldLine.startIndex..<colon])
            guard Self.isFieldName(nameBytes) else {
                throw .malformedFieldLine(Self.text(fieldLine))
            }
            let name = Self.text(nameBytes)
            let value = Self.text(Array(fieldLine[fieldLine.index(after: colon)...]))
                .trimming(.ascii.whitespaces)
            do throws(RFC_9110.Field.Error) {
                fields.append(try RFC_9110.Field(name: name, value: value))
            } catch {
                throw .malformedFieldLine(Self.text(fieldLine))
            }
        }

        return Scan(
            startLine: Self.text(startLineBytes),
            headers: RFC_9110.Message.Headers(fields),
            octets: octets
        )
    }

    internal static func text(_ bytes: [Byte]) -> String {
        String(decoding: bytes, as: UTF8.self)
    }

    internal static func isFieldName(_ bytes: [Byte]) -> Bool {
        guard !bytes.isEmpty else { return false }
        return bytes.allSatisfy(Self.isTchar)
    }

    private static func isTchar(_ byte: Byte) -> Bool {
        switch byte.bitPattern {
        case 0x21, 0x23, 0x24, 0x25, 0x26, 0x27, 0x2A, 0x2B,
            0x2D, 0x2E, 0x5E, 0x5F, 0x60, 0x7C, 0x7E:
            true

        case 0x30...0x39: true
        case 0x41...0x5A: true
        case 0x61...0x7A: true
        default: false
        }
    }
}
