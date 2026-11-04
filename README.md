# swift-rfc-9112

Use this package when you read or write HTTP/1.1 messages on a byte stream and need RFC 9112 framing: request and status lines, field lines, chunked bodies, body length and connection reuse. To drive one connection, start from `RFC_9112.Connection.Client.Coder` or `RFC_9112.Connection.Server.Coder`, which turn received bytes into head, body and end events. For framing without connection state, start from `RFC_9112.Message.Coder`. To decide only how long a body is, start from `RFC_9112.Message.Body.Length`. Methods, status codes, fields and other version-independent semantics come from swift-rfc-9110, and caching from swift-rfc-9111.

## Laws

- `RFC_9112.Message.Body.Length` applies the RFC 9112 rules in this order. A response to HEAD has no body, whatever its fields say. A 1xx, 204 or 304 response has no body, and a Transfer-Encoding on it fails. A successful response to CONNECT is a tunnel. Transfer-Encoding together with Content-Length fails. Chunked applied more than once fails. Chunked as the final coding frames the body as chunked. Otherwise Content-Length gives a fixed length. With neither field, a request has no body and a response reads until the connection closes.
- When chunked is present but not final, a request fails and a response reads until close. A request with a Transfer-Encoding that lacks chunked fails, and a response with one reads until close.
- Content-Length may repeat, in several fields or as a comma list, only if every value is the same. Differing values fail with all of them reported.
- Transfer coding names and connection options are lowercased on input, ASCII letters only. A Kelvin sign is not read as `k`, so it doesn't make `keep-alive`.
- `RFC_9112.Connection.persists(over:)`: `close` ends persistence on any version. HTTP/1.1 and later persist by default. HTTP/1.0 persists only with `keep-alive`. In `RFC_9112.Connection.State` a close stays in effect until `RFC_9112.Connection.State.reset(version:)`.
- `RFC_9112.Connection.Client` matches responses to the methods passed to `RFC_9112.Connection.Client.expect(_:)`, in order. A response with no expected method fails. After a response with a `close` option the connection is finished, and after a tunnel it can't carry more messages. A peer close finishes a body that reads until close.
- `RFC_9112.Connection.Server` refuses a request whose body would read until close. After a request with a `close` option the connection is finished.
- `RFC_9112.Connection.Pipeline` refuses a new request while a non-idempotent request is pending, and refuses a second pending request when pipelining is off.
- `RFC_9112.Message.Coder` accepts lines ending in CRLF or a bare LF. A CR not followed by LF fails. By default the start line may be 8000 octets, the start line and fields together 8000 plus 64 KiB, and a body 16 MiB. Appending bytes that would exceed the limit of the current phase fails, and the bytes are not kept.
- `RFC_9112.Message.Coder.body(_:)` returns nil while a fixed length or chunked body is incomplete, and always for a body that reads until close or a tunnel.
- `RFC_9112.Connection.Client.Coder` delivers a body as one body event followed by end, or only end when it is empty. A body that reads until close is delivered as bytes arrive and ends only after `RFC_9112.Connection.Client.Coder.peerClosed()`. A successful CONNECT response is followed by a tunnel event.
- Obsolete line folding in a field fails by default. With `RFC_9112.Field.ObsFold.Policy.space` the continuation is joined to the value with one space. Whitespace between a field name and its colon fails.
- A status line needs a three digit code from 100 to 599. The reason phrase is optional.
- An HTTP/1.1 request must have exactly one Host field. With an absolute target the Host must name the same host as the target. `RFC_9112.Host` keeps an IPv6 address in its brackets, and a port above 65535 fails.
