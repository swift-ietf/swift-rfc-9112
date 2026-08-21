@_exported import RFC_3986

extension RFC_9110.Host {

    public enum Validator {}
}

extension RFC_9110.Host.Validator {

    public static func validate(
        request: RFC_9110.Request,
        version: RFC_9110.Version
    ) throws(Error) {

        guard version.isHTTP11OrHigher else {
            return
        }

        let hostHeaders = request.headers.filter { $0.name.description.lowercased() == "host" }

        guard !hostHeaders.isEmpty else {
            throw Error.missingHost
        }

        guard hostHeaders.count == 1 else {
            throw Error.multipleHostHeaders(count: hostHeaders.count)
        }

        let hostValue = hostHeaders[0].value.description

        try validateHostFormat(hostValue)

        if case .absolute(let uri) = request.target {
            try validateHostMatchesAuthority(hostValue: hostValue, uri: uri)
        }
    }

    private static func validateHostFormat(_ host: String) throws(Error) {

        if host.isEmpty {
            throw Error.invalidHostFormat(host, reason: "Host value cannot be empty")
        }

        if host.hasPrefix("[") {

            guard host.hasSuffix("]") || host.contains("]:") else {
                throw Error.invalidHostFormat(
                    host,
                    reason: "IPv6 address must be bracketed"
                )
            }
        }

        guard !host.contains(where: \.isWhitespace) else {
            throw Error.invalidHostFormat(host, reason: "Host contains whitespace")
        }

        if let portSeparatorIndex = host.lastIndex(of: ":") {
            let portString = host[host.index(after: portSeparatorIndex)...]

            if !host.hasPrefix("[") {
                guard let port = Int(portString), port >= 0 && port <= 65535 else {
                    throw Error.invalidPort(String(portString))
                }
            }
        }
    }

    private static func validateHostMatchesAuthority(
        hostValue: String,
        uri: RFC_3986.URI
    ) throws(Error) {
        guard let host = uri.host else {

            if !hostValue.isEmpty {
                throw Error.hostMismatchesAuthority(
                    host: hostValue,
                    authority: "(none)"
                )
            }
            return
        }

        let expectedHost: String
        if let port = uri.port {
            expectedHost = "\(host.description):\(port.value)"
        } else {
            expectedHost = host.description
        }

        guard hostValue.lowercased() == expectedHost.lowercased() else {
            throw Error.hostMismatchesAuthority(
                host: hostValue,
                authority: expectedHost
            )
        }
    }

    public static func parseHost(_ value: String) -> (host: String, port: Int?) {

        if value.hasPrefix("[") {
            if let closeBracket = value.firstIndex(of: "]") {
                let host = String(value[..<value.index(after: closeBracket)])
                let remainder = value[value.index(after: closeBracket)...]

                if remainder.hasPrefix(":"), let port = Int(remainder.dropFirst()) {
                    return (host: host, port: port)
                }
                return (host: host, port: nil)
            }
        }

        if let lastColon = value.lastIndex(of: ":") {
            let host = String(value[..<lastColon])
            let portString = value[value.index(after: lastColon)...]
            if let port = Int(portString) {
                return (host: host, port: port)
            }
        }

        return (host: value, port: nil)
    }
}
