// HTTP.Version.Tests.swift
// swift-rfc-9112

import Testing
@testable import RFC_9112

@Suite("HTTP.Version Tests")
struct HTTPVersionTests {

    @Test("Parse HTTP/1.1")
    func parseHTTP11() async throws {
        let version = try RFC_9110.Version.parse("HTTP/1.1")

        #expect(version.major == 1)
        #expect(version.minor == 1)
        #expect(version.isHTTP11)
        #expect(version.isHTTP11OrHigher)
    }

    @Test("Parse HTTP/1.0")
    func parseHTTP10() async throws {
        let version = try RFC_9110.Version.parse("HTTP/1.0")

        #expect(version.major == 1)
        #expect(version.minor == 0)
        #expect(version.isHTTP10)
        #expect(!version.isHTTP11)
        #expect(!version.isHTTP11OrHigher)
    }

    @Test("Parse HTTP/2.0")
    func parseHTTP20() async throws {
        let version = try RFC_9110.Version.parse("HTTP/2.0")

        #expect(version.major == 2)
        #expect(version.minor == 0)
        #expect(!version.isHTTP10)
        #expect(!version.isHTTP11)
        #expect(version.isHTTP11OrHigher)
    }

    @Test("Parse HTTP/3.0")
    func parseHTTP30() async throws {
        let version = try RFC_9110.Version.parse("HTTP/3.0")

        #expect(version.major == 3)
        #expect(version.minor == 0)
        #expect(version.isHTTP11OrHigher)
    }

    @Test("Format HTTP/1.1")
    func formatHTTP11() async throws {
        let version = RFC_9110.Version.http11

        #expect(version.formatted == "HTTP/1.1")
    }

    @Test("Format HTTP/1.0")
    func formatHTTP10() async throws {
        let version = RFC_9110.Version.http10

        #expect(version.formatted == "HTTP/1.0")
    }

    @Test("Format custom version")
    func formatCustomVersion() async throws {
        let version = RFC_9110.Version(major: 2, minor: 0)

        #expect(version.formatted == "HTTP/2.0")
    }

    @Test("Static constants")
    func staticConstants() async throws {
        #expect(RFC_9110.Version.http10.major == 1)
        #expect(RFC_9110.Version.http10.minor == 0)

        #expect(RFC_9110.Version.http11.major == 1)
        #expect(RFC_9110.Version.http11.minor == 1)
    }

    @Test("Equality")
    func equality() async throws {
        let v1 = RFC_9110.Version(major: 1, minor: 1)
        let v2 = RFC_9110.Version.http11
        let v3 = RFC_9110.Version.http10

        #expect(v1 == v2)
        #expect(v1 != v3)
    }

    @Test("Hashability")
    func hashability() async throws {
        let v1 = RFC_9110.Version.http11
        let v2 = RFC_9110.Version.http10

        var set = Set<RFC_9110.Version>()
        set.insert(v1)
        set.insert(v2)

        #expect(set.count == 2)
        #expect(set.contains(v1))
        #expect(set.contains(v2))
    }

    @Test("Parse - invalid format (missing HTTP prefix)")
    func parseInvalidMissingHTTP() async throws {
        #expect(throws: RFC_9110.Version.ParsingError.self) {
            try RFC_9110.Version.parse("1.1")
        }
    }

    @Test("Parse - invalid format (wrong case)")
    func parseInvalidWrongCase() async throws {
        #expect(throws: RFC_9110.Version.ParsingError.self) {
            try RFC_9110.Version.parse("http/1.1")
        }
    }

    @Test("Parse - invalid format (missing slash)")
    func parseInvalidMissingSlash() async throws {
        #expect(throws: RFC_9110.Version.ParsingError.self) {
            try RFC_9110.Version.parse("HTTP 1.1")
        }
    }

    @Test("Parse - invalid format (missing dot)")
    func parseInvalidMissingDot() async throws {
        #expect(throws: RFC_9110.Version.ParsingError.self) {
            try RFC_9110.Version.parse("HTTP/11")
        }
    }

    @Test("Parse - invalid version numbers (non-numeric major)")
    func parseInvalidNonNumericMajor() async throws {
        #expect(throws: RFC_9110.Version.ParsingError.self) {
            try RFC_9110.Version.parse("HTTP/X.1")
        }
    }

    @Test("Parse - invalid version numbers (non-numeric minor)")
    func parseInvalidNonNumericMinor() async throws {
        #expect(throws: RFC_9110.Version.ParsingError.self) {
            try RFC_9110.Version.parse("HTTP/1.Y")
        }
    }

    @Test("Parse - empty string")
    func parseEmptyString() async throws {
        #expect(throws: RFC_9110.Version.ParsingError.self) {
            try RFC_9110.Version.parse("")
        }
    }

    @Test("isHTTP11OrHigher - various versions")
    func isHTTP11OrHigherVariousVersions() async throws {
        #expect(!RFC_9110.Version(major: 1, minor: 0).isHTTP11OrHigher)
        #expect(RFC_9110.Version(major: 1, minor: 1).isHTTP11OrHigher)
        #expect(RFC_9110.Version(major: 1, minor: 2).isHTTP11OrHigher)
        #expect(RFC_9110.Version(major: 2, minor: 0).isHTTP11OrHigher)
        #expect(RFC_9110.Version(major: 3, minor: 0).isHTTP11OrHigher)
    }

    @Test("Sendable conformance")
    func sendableConformance() async throws {
        let version = RFC_9110.Version.http11

        // This test verifies that Version can be safely sent across concurrency boundaries
        await Task {
            _ = version
        }.value
    }
}
