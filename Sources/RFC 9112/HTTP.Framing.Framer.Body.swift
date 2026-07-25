// HTTP.Framing.Framer.Body.swift
// swift-rfc-9112
//
// RFC 9112 Section 6: Message Body
// RFC 9112 Section 7.1: Chunked Transfer Coding
// https://www.rfc-editor.org/rfc/rfc9112.html#section-7.1
//
// Body framing over the framer's owned buffer, with exact consumed accounting.

import Byte_Primitives
import INCITS_4_1986

// MARK: - Scanning a chunked body
//
// `nextBody` itself lives beside the other framing entry points in
// `HTTP.Framing.Framer.swift`, because it mutates the private buffer. The scan
// below takes the buffer as a borrowed parameter and so needs no such access.

extension RFC_9110.Framing.Framer {
    /// One complete chunked body, described but not yet removed from the buffer.
    internal struct ChunkedScan {
        /// The decoded payload octets.
        let content: [Byte]

        /// Octets the whole chunked body occupies — every chunk-size line,
        /// extension, CRLF, the zero chunk, the trailer section and the final
        /// CRLF included.
        let octets: Int

        /// The trailer section.
        let trailers: RFC_9110.Headers
    }

    /// Scans one complete chunked body out of `buffer` **without consuming it**.
    /// Returns `nil` when the body is not yet complete.
    ///
    /// Every octet is accounted by advancing an offset, so the reported count is
    /// the true wire length rather than a decoded-size estimate. That is why the
    /// scan is here and not delegated to `ChunkedEncoding.decode`, whose
    /// `DecodeResult` has no field for a consumed count — the very absence that
    /// forces `Message.Deserializer` to estimate.
    ///
    /// Like `scanHead`, it does not consume on failure: a throw or a `nil`
    /// leaves the buffer byte-for-byte unchanged, so a malformed chunk cannot
    /// leave the framer half-advanced into a desynchronised state.
    internal static func scanChunkedBody(
        _ buffer: borrowing [Byte],
        limit: Int
    ) throws(RFC_9110.Framing.Error) -> ChunkedScan? {
        var content: [Byte] = []
        var index = 0

        while true {
            // chunk-size [ chunk-ext ] CRLF
            guard let sizeLineEnd = Self.indexOfCRLF(buffer, from: index) else { return nil }
            let sizeLine = Array(buffer[index..<sizeLineEnd])
            // chunk-ext begins at the first ';'; the size is what precedes it.
            let sizeToken: [Byte]
            if let semicolon = sizeLine.firstIndex(of: 0x3B) {  // ';'
                sizeToken = Array(sizeLine[sizeLine.startIndex..<semicolon])
            } else {
                sizeToken = sizeLine
            }
            guard let size = Self.hexValue(sizeToken) else {
                throw .invalidChunkSize(Self.text(sizeLine))
            }
            index = sizeLineEnd + 2  // past CRLF

            if size == 0 {
                // last-chunk reached; parse the trailer section up to the final
                // CRLF, which terminates the whole chunked body.
                var fields: [RFC_9110.Header.Field] = []
                while true {
                    if buffer.indices.contains(index + 1), buffer[index] == 0x0D,
                        buffer[index + 1] == 0x0A
                    {
                        index += 2
                        return ChunkedScan(
                            content: content,
                            octets: index,
                            trailers: RFC_9110.Headers(fields)
                        )
                    }
                    guard let lineEnd = Self.indexOfCRLF(buffer, from: index) else { return nil }
                    let line = Array(buffer[index..<lineEnd])
                    guard let colon = line.firstIndex(of: 0x3A) else {  // ':'
                        throw .malformedChunk(Self.text(line))
                    }
                    let nameBytes = Array(line[line.startIndex..<colon])
                    guard Self.isFieldName(nameBytes) else {
                        throw .malformedChunk(Self.text(line))
                    }
                    let name = Self.text(nameBytes)
                    let value = Self.text(Array(line[line.index(after: colon)...]))
                        .trimming(.ascii.whitespaces)
                    do throws(RFC_9110.Header.Field.Error) {
                        fields.append(try RFC_9110.Header.Field(name: name, value: value))
                    } catch {
                        throw .malformedChunk(Self.text(line))
                    }
                    index = lineEnd + 2
                }
            }

            // chunk-data ( size octets ) CRLF
            guard index + size + 2 <= buffer.count else { return nil }
            content.append(contentsOf: buffer[index..<(index + size)])
            if content.count > limit { throw .bodyTooLong(limit: limit) }
            guard buffer[index + size] == 0x0D, buffer[index + size + 1] == 0x0A else {
                throw .malformedChunk("missing CRLF after chunk data")
            }
            index += size + 2
        }
    }

    /// Index of the CR of the next CRLF at or after `from`, or `nil` if none is
    /// buffered yet.
    ///
    /// Only a CR immediately followed by LF qualifies; a CR at the very end of
    /// what has arrived is treated as not-yet-terminated, so an incremental read
    /// that splits a CRLF waits rather than mis-reading — the same rule
    /// `scanHead` applies to the head section.
    internal static func indexOfCRLF(_ buffer: borrowing [Byte], from: Int) -> Int? {
        var index = from
        while buffer.indices.contains(index + 1) {
            if buffer[index] == 0x0D, buffer[index + 1] == 0x0A { return index }
            index += 1
        }
        return nil
    }

    /// Parses `1*HEXDIG` into its value, or `nil` if empty or non-hex.
    ///
    /// RFC 9112 Section 7.1: `chunk-size = 1*HEXDIG`. Validated against the hex
    /// digit set before conversion so that a sign or other `Int(_:radix:)`-
    /// tolerated form the ABNF forbids is rejected, mirroring how `BodyLength`
    /// guards `Content-Length` against `1*DIGIT`. Written over the token's UTF-8
    /// (`UInt8`) rather than `Byte` to stay clear of arithmetic at the byte
    /// domain.
    internal static func hexValue(_ bytes: [Byte]) -> Int? {
        let string = Self.text(bytes)
        guard !string.isEmpty, string.utf8.allSatisfy(Self.isHexDigit) else { return nil }
        return Int(string, radix: 16)
    }

    /// RFC 5234 `HEXDIG`, extended with lowercase per RFC 9110's case-insensitive
    /// use of it.
    private static func isHexDigit(_ byte: UInt8) -> Bool {
        switch byte {
        case 0x30...0x39, 0x41...0x46, 0x61...0x66: true  // 0-9, A-F, a-f
        default: false
        }
    }
}
