// HTTP.Request.Target+Parsing.swift
// swift-rfc-9112

extension RFC_9110.Request.Target {
    /// Parses one request-target using the target-form laws of RFC 9112
    /// Section 3.2.
    ///
    /// The method participates in the grammar: authority-form is reserved for
    /// `CONNECT`, while asterisk-form is reserved for `OPTIONS`. Origin-form
    /// requires an absolute path, and absolute-form requires an absolute URI
    /// without a fragment.
    public static func parse(
        _ value: String,
        method: RFC_9110.Method
    ) throws(ParsingError) -> Self {
        guard !value.isEmpty, !value.contains(where: \.isWhitespace) else {
            throw .syntax(value)
        }

        if value == "*" {
            guard method == .options else {
                throw .form(value, method: method)
            }
            return .asterisk
        }

        if method == .connect {
            guard !value.contains("@") else {
                throw .syntax(value)
            }

            let authority: RFC_3986.URI.Authority
            do throws(RFC_3986.URI.Authority.Error) {
                authority = try RFC_3986.URI.Authority(value)
            } catch {
                throw .syntax(value)
            }

            guard authority.port != nil else {
                throw .syntax(value)
            }
            return .authority(authority)
        }

        if value.hasPrefix("/") {
            let components = value.split(
                separator: "?",
                maxSplits: 1,
                omittingEmptySubsequences: false
            )

            let path: RFC_3986.URI.Path
            guard !components[0].contains("#") else {
                throw .syntax(value)
            }
            do throws(RFC_3986.URI.Path.Error) {
                path = try RFC_3986.URI.Path(String(components[0]))
            } catch {
                throw .syntax(value)
            }

            let query: RFC_3986.URI.Query?
            if components.count == 2 {
                do throws(RFC_3986.URI.Query.Error) {
                    query = try RFC_3986.URI.Query(String(components[1]))
                } catch {
                    throw .syntax(value)
                }
            } else {
                query = nil
            }

            return .origin(path: path, query: query)
        }

        let uri: RFC_3986.URI
        do throws(RFC_3986.Error) {
            uri = try RFC_3986.URI(value)
        } catch {
            throw .syntax(value)
        }

        guard uri.scheme != nil, uri.fragment == nil else {
            throw .syntax(value)
        }
        return .absolute(uri)
    }
}
