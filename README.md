# swift-rfc-9112

Swift implementation of RFC 9112: HTTP/1.1

## Overview

This package implements [RFC 9112 - HTTP/1.1](https://www.rfc-editor.org/rfc/rfc9112.html), which obsoletes RFC 7230 (June 2022).

RFC 9112 defines the HTTP/1.1 message syntax and routing, including message framing, transfer encodings, connection management, and message body length determination.

## Status

**Alpha** - Initial implementation complete

### Implemented

- ✅ `HTTP.TransferEncoding` - Transfer-Encoding header (Section 6)
  - Standard encodings: chunked, gzip, compress, deflate
  - Custom encodings support
  - Multiple encoding lists
  - Chunked validation: `hasChunked`, `isChunkedFinal`
  - Full conformances: Sendable, Equatable, Hashable, Codable, LosslessStringConvertible, ExpressibleByStringLiteral

- ✅ `HTTP.Connection` - Connection header (Section 9.6)
  - Connection options: close, keep-alive, upgrade, custom
  - Persistence determination based on HTTP version
  - HTTP/1.1 persistent connections by default
  - HTTP/1.0 close by default
  - Full conformances: Sendable, Equatable, Hashable, Codable, LosslessStringConvertible, ExpressibleByStringLiteral

- ✅ `HTTP.ChunkedEncoding` - Chunked transfer encoding codec (Section 7.1)
  - Encode data into chunked format
  - Decode chunked data
  - Trailer field support
  - Configurable chunk size
  - Comprehensive error handling: invalidFormat, invalidChunkSize, incompleteChunk, missingCRLF

- ✅ `HTTP.MessageBodyLength` - Message body length calculation (Section 6.3)
  - 8-rule precedence system from RFC 9112
  - Request and response handling
  - HEAD request special handling
  - Status code special cases (1xx, 204, 304)
  - CONNECT tunnel handling
  - Transfer-Encoding precedence over Content-Length
  - Multiple Content-Length validation
  - Helpers: `hasBody`, `fixedLength`, `isChunked`, `isUntilClose`

## Usage

### Transfer-Encoding

```swift
import RFC_9112

// Creating Transfer-Encoding headers
let te = HTTP.TransferEncoding.chunked
print(te.headerValue)  // "chunked"

// Multiple encodings
let multiple = HTTP.TransferEncoding.list([.gzip, .chunked])
print(multiple.headerValue)  // "gzip, chunked"

// Validation
multiple.hasChunked        // true
multiple.isChunkedFinal    // true (chunked is last)

// Parsing
let parsed = HTTP.TransferEncoding.parse("gzip, chunked")
// parsed == .list([.gzip, .chunked])

// String literal support
let te2: HTTP.TransferEncoding = "chunked"
```

### Connection

```swift
import RFC_9112

// Standard connection options
let conn = HTTP.Connection.close
print(conn.headerValue)  // "close"

// Persistence checking
conn.shouldPersist(version: "HTTP/1.1")  // false (close)

let keepAlive = HTTP.Connection.keepAlive
keepAlive.shouldPersist(version: "HTTP/1.1")  // true

// HTTP/1.1 defaults to persistent
let empty = HTTP.Connection(options: [])
empty.shouldPersist(version: "HTTP/1.1")  // true
empty.shouldPersist(version: "HTTP/1.0")  // false

// Custom options
let custom = HTTP.Connection(options: ["close", "upgrade"])
print(custom.headerValue)  // "close, upgrade"

// Parsing
let parsed = HTTP.Connection.parse("close")
// parsed == .close

// String literal support
let conn2: HTTP.Connection = "keep-alive"
```

### Chunked Encoding

```swift
import RFC_9112

// Encode data into chunked format
let data = Data("Hello, World!".utf8)
let chunked = try HTTP.ChunkedEncoding.encode(data)
print(String(data: chunked, encoding: .utf8)!)
// "d\r\nHello, World!\r\n0\r\n\r\n"

// Custom chunk size
let chunked2 = try HTTP.ChunkedEncoding.encode(data, chunkSize: 5)

// With trailers
let trailers = [
    try HTTP.Header.Field(name: "X-Checksum", value: "abc123")
]
let chunkedWithTrailers = try HTTP.ChunkedEncoding.encode(
    data,
    trailers: trailers
)

// Decode chunked data
let chunkedData = Data("5\r\nHello\r\n0\r\n\r\n".utf8)
let (decoded, decodedTrailers) = try HTTP.ChunkedEncoding.decode(chunkedData)
print(String(data: decoded, encoding: .utf8)!)  // "Hello"

// Error handling
do {
    try HTTP.ChunkedEncoding.decode(Data("invalid".utf8))
} catch HTTP.ChunkedEncoding.ChunkedDecodingError.invalidFormat {
    print("Invalid chunked format")
}
```

### Message Body Length

```swift
import RFC_9112

// Response body length calculation
let response = HTTP.Response(
    status: .ok,
    headers: [
        try .init(name: "Content-Length", value: "42")
    ]
)

let length = HTTP.MessageBodyLength.calculate(
    for: response,
    requestMethod: .get
)
// length == .length(42)

length.hasBody      // true
length.fixedLength  // 42
length.isChunked    // false

// HEAD request has no body
let headLength = HTTP.MessageBodyLength.calculate(
    for: response,
    requestMethod: .head
)
// headLength == .none

// Transfer-Encoding: chunked
let chunkedResponse = HTTP.Response(
    status: .ok,
    headers: [
        try .init(name: "Transfer-Encoding", value: "chunked")
    ]
)

let chunkedLength = HTTP.MessageBodyLength.calculate(
    for: chunkedResponse,
    requestMethod: .get
)
// chunkedLength == .chunked

// Request body length
let request = HTTP.Request(
    method: .post,
    target: try .origin(path: .init("/api/data"), query: nil),
    headers: [
        try .init(name: "Content-Length", value: "100")
    ]
)

let requestLength = HTTP.MessageBodyLength.calculate(for: request)
// requestLength == .length(100)
```

## Requirements

- Swift 6.0+
- macOS 14.0+, iOS 17.0+, tvOS 17.0+, watchOS 10.0+

## Dependencies

- [swift-rfc-9110](https://github.com/coenttb/swift-rfc-9110) - HTTP Semantics

## Installation

```swift
dependencies: [
    .package(url: "https://github.com/swift-standards/swift-rfc-9112", from: "0.1.0")
],
targets: [
    .target(
        name: "YourTarget",
        dependencies: [
            .product(name: "RFC 9112", package: "swift-rfc-9112")
        ]
    )
]
```

## Relationship to Other RFCs

- **RFC 9110** - HTTP Semantics (swift-rfc-9110)
- **RFC 9111** - HTTP Caching (swift-rfc-9111)
- **RFC 9112** (this package) - HTTP/1.1 Message Syntax

Together, these three RFCs replace the obsolete RFC 7230-7235 series.

## Design Principles

Following the established patterns from swift-rfc-9110:

- ✅ Types extend `RFC_9110` namespace
- ✅ Convenience typealias: `HTTP = RFC_9110`
- ✅ Comprehensive conformances: Sendable, Equatable, Hashable, Codable
- ✅ Full documentation with RFC section references
- ✅ Swift 6.0 strict concurrency enabled
- ✅ Security-focused: prevents request smuggling via proper message framing

## Testing

```bash
swift test
```

Current test coverage: 83 tests, all passing

- 18 tests for HTTP.TransferEncoding
- 19 tests for HTTP.Connection
- 20 tests for HTTP.ChunkedEncoding
- 26 tests for HTTP.MessageBodyLength

## License

[Apache 2.0](LICENSE)

## References

- [RFC 9112: HTTP/1.1](https://www.rfc-editor.org/rfc/rfc9112.html)
- [RFC 9112 Section 6: Message Body Length](https://www.rfc-editor.org/rfc/rfc9112.html#section-6)
- [RFC 9112 Section 6.3: Message Body Length Determination](https://www.rfc-editor.org/rfc/rfc9112.html#section-6.3)
- [RFC 9112 Section 7.1: Chunked Transfer Coding](https://www.rfc-editor.org/rfc/rfc9112.html#section-7.1)
- [RFC 9112 Section 9.6: Connection](https://www.rfc-editor.org/rfc/rfc9112.html#section-9.6)
