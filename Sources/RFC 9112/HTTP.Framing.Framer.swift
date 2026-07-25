// HTTP.Framing.Framer.swift
// swift-rfc-9112
//
// RFC 9112 Section 2.2: Message Parsing
// https://www.rfc-editor.org/rfc/rfc9112.html#section-2.2
//
// Incremental, buffer-owning HTTP/1.1 message framer.

public import Byte_Primitives
import INCITS_4_1986

extension RFC_9110.Framing {
    /// Incremental HTTP/1.1 framer over a caller-supplied byte stream.
    ///
    /// Sans-I/O: it never reads a socket, it is fed by one.
    ///
    /// ## Why it owns the buffer
    ///
    /// Every framing defect in this package's whole-buffer surface is a
    /// consumed-count defect. `HTTP.Message.Deserializer` estimates consumed
    /// octets from *decoded* size, which is wrong whenever framing overhead
    /// exists, and `ChunkedEncoding.DecodeResult` cannot express a consumed
    /// count at all — so the deserializer estimates because the type it calls
    /// offers nothing better.
    ///
    /// **The framer retains the unconsumed remainder itself, so no consumed
    /// count crosses the API boundary.** A caller never computes an offset into
    /// its own buffer, which makes that entire defect class unreachable rather
    /// than corrected. `octets` on a framed head is reported for accounting and
    /// tests; nothing needs it to locate the next message.
    ///
    /// ## Scope
    ///
    /// This increment frames **head sections only** — start line and field
    /// section — and reports how the body that follows is delimited. Body
    /// framing, including chunked decoding with exact accounting, is a
    /// subsequent increment, and there is deliberately **no** `next()` that
    /// frames some bodies and not others: a call that must either mis-frame a
    /// chunked message or throw "not implemented" is the shape of the trapping
    /// entry points this package has just removed.
    ///
    /// ## Roles
    ///
    /// There is no role set at construction. A response's framing depends on
    /// the **method of the request it answers** (RFC 9112 Section 6.3 rules 1
    /// and 2), and on a persistent connection that varies per exchange —
    /// Section 9.2 is about exactly that association. The role therefore rides
    /// on the call, and the two calls carry exactly the data their role needs,
    /// so a wrong combination is unrepresentable rather than merely rejected.
    public struct Framer: ~Copyable {
        /// Unconsumed octets, oldest first.
        private var buffer: [Byte]

        /// Bounds enforced during accumulation.
        public let limits: Limits

        public init(limits: Limits = .default) {
            self.buffer = []
            self.limits = limits
        }
    }
}

extension RFC_9110.Framing.Framer {
    /// Octets received and not yet consumed by a framed message.
    public var unconsumed: Int { buffer.count }
}

// MARK: - Feeding

extension RFC_9110.Framing.Framer {
    /// Accepts received octets.
    ///
    /// The head-section budget is checked **before** the octets are retained,
    /// so an over-long head is refused rather than stored and complained about
    /// afterwards. A limit that can only be checked after acceptance has
    /// already lost the memory it was meant to protect.
    ///
    /// - Throws: `headSectionTooLong` if accepting these octets would push an
    ///   unterminated head past `limits.headSection`.
    public mutating func append(_ bytes: [Byte]) throws(RFC_9110.Framing.Error) {
        let projected = buffer.count + bytes.count
        // 2c: this guard bounds the HEAD-accumulation phase only, but the framer
        // is stateless about phase (by design — body delimitation rides on the
        // per-call `nextBody(_:)`, not on stored state). So a large IDENTITY body
        // delivered incrementally, with no head terminator among its bytes, is
        // measured against `headSection` and can be wrongly refused once it
        // exceeds it. The body budget (`limits.body`) is enforced inside
        // `nextBody`; the pre-retention body-phase guard belongs with the
        // connection drive, which is what knows a body is in progress — the
        // framer knows messages, the drive knows connections. Tracked for 2c.
        if projected > limits.headSection && !Self.containsHeadTerminator(buffer) {
            throw .headSectionTooLong(limit: limits.headSection)
        }
        buffer.append(contentsOf: bytes)
    }
}

// MARK: - Framing

extension RFC_9110.Framing.Framer {
    /// Frames the next request head, or returns `nil` when more octets are
    /// needed.
    ///
    /// `nil` is the ordinary path on a partial read, not an error. It does
    /// **not** distinguish "incomplete" from "the peer closed mid-message" —
    /// that is what `finish()` is for.
    public mutating func nextRequestHead() throws(RFC_9110.Framing.Error)
        -> RFC_9110.Framing.RequestHead?
    {
        guard let scan = try Self.scanHead(buffer, limits: limits) else { return nil }

        let line: RFC_9110.Request.Line
        do throws(RFC_9110.Request.Line.ParsingError) {
            line = try RFC_9110.Request.Line.parse(scan.startLine)
        } catch {
            throw .malformedStartLine(scan.startLine)
        }

        let bodyLength = try RFC_9110.Framing.BodyLength.determine(
            context: .request,
            headers: scan.headers
        )

        buffer.removeFirst(scan.octets)
        return RFC_9110.Framing.RequestHead(
            line: line,
            headers: scan.headers,
            bodyLength: bodyLength,
            octets: scan.octets
        )
    }

    /// Frames the next response head, or returns `nil` when more octets are
    /// needed.
    ///
    /// - Parameter requestMethod: the method of the request this response
    ///   answers. Required because RFC 9112 Section 6.3 rules 1 and 2 make the
    ///   body's delimitation depend on it — a response to `HEAD` has no body
    ///   whatever its `Content-Length` says, and a 2xx to `CONNECT` becomes a
    ///   tunnel — and on a persistent connection it differs per exchange.
    public mutating func nextResponseHead(
        answering requestMethod: RFC_9110.Method
    ) throws(RFC_9110.Framing.Error) -> RFC_9110.Framing.ResponseHead? {
        guard let scan = try Self.scanHead(buffer, limits: limits) else { return nil }

        let line: RFC_9110.Response.Line
        do throws(RFC_9110.Response.Line.ParsingError) {
            line = try RFC_9110.Response.Line.parse(scan.startLine)
        } catch {
            throw .malformedStartLine(scan.startLine)
        }

        let bodyLength = try RFC_9110.Framing.BodyLength.determine(
            context: .response(statusCode: line.statusCode, requestMethod: requestMethod),
            headers: scan.headers
        )

        buffer.removeFirst(scan.octets)
        return RFC_9110.Framing.ResponseHead(
            line: line,
            headers: scan.headers,
            bodyLength: bodyLength,
            octets: scan.octets
        )
    }
}

// MARK: - Termination

extension RFC_9110.Framing.Framer {
    /// Declares the stream ended and reports how.
    ///
    /// `consuming`, so a framer cannot be fed after its stream is over. RFC
    /// 9112 Section 8 governs incomplete messages, and distinguishing a clean
    /// close from a truncated one is the distinction a `nil` from a framing
    /// call cannot express.
    public consuming func finish() throws(RFC_9110.Framing.Error)
        -> RFC_9110.Framing.Terminal
    {
        buffer.isEmpty ? .clean : .truncated(unconsumed: buffer.count)
    }
}

// MARK: - Framing the body

extension RFC_9110.Framing.Framer {
    /// Frames the body that follows a head, or returns `nil` when more octets
    /// are needed.
    ///
    /// The delimitation is supplied by the caller from the head it just framed
    /// (`RequestHead.bodyLength` / `ResponseHead.bodyLength`), so the framer
    /// holds no per-message state between a head and its body — exactly as the
    /// response's per-exchange method rides on `nextResponseHead(answering:)`
    /// rather than on construction. When it returns a `Body`, the framer has
    /// removed exactly `Body.octets` from its buffer, so the next message begins
    /// at the head of the buffer and **no consumed count crosses the API for a
    /// caller to get wrong** — the property that makes the consumed-count defect
    /// class unreachable rather than merely fixed.
    ///
    /// Handles the three **self-delimiting** framings:
    ///
    /// - `.none` — an empty body, complete immediately.
    /// - `.length(n)` — complete once `n` octets are buffered.
    /// - `.chunked` — complete at the last chunk, its trailer section and the
    ///   terminating CRLF, with the exact wire length reported.
    ///
    /// `.untilClose` and `.tunnel` are delimited by the connection closing, not
    /// by the byte stream, so their end is not knowable here: this call returns
    /// `nil` for them rather than inventing a boundary the stream does not
    /// contain. Delivering a close-delimited body is the connection drive's
    /// responsibility, because the drive is what observes the close — the framer
    /// knows messages, the drive knows connections.
    ///
    /// - Throws: `invalidChunkSize` / `malformedChunk` on malformed chunked
    ///   framing, and `bodyTooLong` if the body exceeds `limits.body`. A throw
    ///   leaves the buffer byte-for-byte unchanged, as `nil` does.
    public mutating func nextBody(
        _ bodyLength: RFC_9110.Framing.BodyLength
    ) throws(RFC_9110.Framing.Error) -> RFC_9110.Framing.Body? {
        switch bodyLength {
        case .none:
            return RFC_9110.Framing.Body(content: [], octets: 0, trailers: RFC_9110.Headers([]))

        case .length(let expected):
            if expected > limits.body { throw .bodyTooLong(limit: limits.body) }
            guard buffer.count >= expected else { return nil }
            let content = Array(buffer[..<expected])
            buffer.removeFirst(expected)
            return RFC_9110.Framing.Body(
                content: content,
                octets: expected,
                trailers: RFC_9110.Headers([])
            )

        case .chunked:
            guard let framed = try Self.scanChunkedBody(buffer, limit: limits.body) else {
                return nil
            }
            buffer.removeFirst(framed.octets)
            return RFC_9110.Framing.Body(
                content: framed.content,
                octets: framed.octets,
                trailers: framed.trailers
            )

        case .untilClose, .tunnel:
            return nil
        }
    }
}

// MARK: - Scanning

extension RFC_9110.Framing.Framer {
    /// True when a complete head terminator is already buffered.
    ///
    /// Used to decide whether the head budget still applies: once the head is
    /// complete the remaining octets are body, which the head budget does not
    /// govern.
    internal static func containsHeadTerminator(_ buffer: borrowing [Byte]) -> Bool {
        var index = 0
        var lineStart = 0
        while index < buffer.count {
            switch buffer[index] {
            case 0x0D:  // CR
                guard buffer.indices.contains(index + 1), buffer[index + 1] == 0x0A else {
                    return false
                }
                if index == lineStart { return true }
                index += 2
                lineStart = index
            case 0x0A:  // bare LF, tolerated as a line terminator
                if index == lineStart { return true }
                index += 1
                lineStart = index
            default:
                index += 1
            }
        }
        return false
    }

    /// Scans a complete head out of `buffer` without consuming it.
    ///
    /// Returns `nil` when the head is not yet complete.
    internal static func scanHead(
        _ buffer: borrowing [Byte],
        limits: RFC_9110.Framing.Limits
    ) throws(RFC_9110.Framing.Error) -> Self.Scan? {
        var lines: [[Byte]] = []
        var index = 0
        var lineStart = 0
        var headEnd: Int?

        scan: while index < buffer.count {
            switch buffer[index] {
            case 0x0D:  // CR
                // A CR at the very end of what has arrived is not yet a bare CR
                // — the LF may be in the next read. Only a CR followed by a
                // non-LF octet is a violation.
                guard buffer.indices.contains(index + 1) else { return nil }
                guard buffer[index + 1] == 0x0A else { throw .bareCarriageReturn }
                let line = Array(buffer[lineStart..<index])
                index += 2
                if line.isEmpty {
                    headEnd = index
                    break scan
                }
                lines.append(line)
                lineStart = index

            case 0x0A:  // RFC 9112 Section 2.2: a recipient MAY treat bare LF as a terminator
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

        var fields: [RFC_9110.Header.Field] = []
        for fieldLine in lines.dropFirst() {
            // RFC 9112 Section 5.2: a field line starting with SP or HTAB is
            // obsolete line folding. Rejected rather than unfolded: forwarding
            // a folded field is a smuggling vector when a downstream recipient
            // unfolds it differently.
            if let first = fieldLine.first, first == 0x20 || first == 0x09 {
                throw .obsoleteLineFolding
            }
            guard let colon = fieldLine.firstIndex(of: 0x3A) else {  // ':'
                throw .malformedFieldLine(Self.text(fieldLine))
            }
            // RFC 9112 Section 5.1: no whitespace is allowed between the field
            // name and the colon, and a recipient MUST reject a message that
            // contains it — accepting `Host : example.com` is a request-smuggling
            // vector, because a downstream recipient may split the line
            // differently. The general rule is that the name is a token; the
            // whitespace-before-colon case is one instance of a non-token name.
            let nameBytes = Array(fieldLine[fieldLine.startIndex..<colon])
            guard Self.isFieldName(nameBytes) else {
                throw .malformedFieldLine(Self.text(fieldLine))
            }
            let name = Self.text(nameBytes)
            let value = Self.text(Array(fieldLine[fieldLine.index(after: colon)...]))
                .trimming(.ascii.whitespaces)
            do throws(RFC_9110.Header.Field.Error) {
                fields.append(try RFC_9110.Header.Field(name: name, value: value))
            } catch {
                throw .malformedFieldLine(Self.text(fieldLine))
            }
        }

        return Scan(
            startLine: Self.text(startLineBytes),
            headers: RFC_9110.Headers(fields),
            octets: octets
        )
    }

    /// Renders octets as text for parsing and diagnostics.
    ///
    /// HTTP field content is ASCII-superset; invalid sequences are replaced
    /// rather than dropped so a malformed line still reaches an error message
    /// intact enough to identify.
    internal static func text(_ bytes: [Byte]) -> String {
        String(decoding: bytes, as: UTF8.self)
    }

    /// True when `bytes` are a valid field-name token.
    ///
    /// RFC 9110 Section 5.6.2: `field-name = token = 1*tchar`. Validated here,
    /// at the protocol level, because `RFC_9110.Header.Field.Name` deliberately
    /// performs no validation of its own. An empty name, or any byte that is not
    /// a `tchar` — most importantly the whitespace before a colon that RFC 9112
    /// Section 5.1 forbids — makes the field line malformed.
    internal static func isFieldName(_ bytes: [Byte]) -> Bool {
        guard !bytes.isEmpty else { return false }
        return bytes.allSatisfy(Self.isTchar)
    }

    /// RFC 9110 Section 5.6.2 `tchar`.
    ///
    /// The canonical predicate is `RFC_9110.Parse.Token.isTchar`, but it is a
    /// static on a parser generic over `Byte.Input`, and importing the module
    /// that defines `Byte.Input` shadows the standard-library `Array` this file
    /// relies on. The byte set is therefore stated here, kept in lockstep with
    /// RFC 9110's definition and matching the local `isDigits` in `BodyLength`.
    private static func isTchar(_ byte: Byte) -> Bool {
        switch byte {
        case 0x21, 0x23, 0x24, 0x25, 0x26, 0x27, 0x2A, 0x2B,
            0x2D, 0x2E, 0x5E, 0x5F, 0x60, 0x7C, 0x7E:
            true
        case 0x30...0x39: true  // DIGIT
        case 0x41...0x5A: true  // ALPHA upper
        case 0x61...0x7A: true  // ALPHA lower
        default: false
        }
    }
}
