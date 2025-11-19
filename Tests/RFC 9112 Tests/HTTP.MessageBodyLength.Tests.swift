// HTTP.MessageBodyLength.Tests.swift
// swift-rfc-9112

import Testing
@testable import RFC_9112

@Suite("HTTP.MessageBodyLength Tests")
struct HTTPMessageBodyLengthTests {

    // MARK: - Response Tests

    @Test("Response - HEAD request has no body")
    func responseHeadRequest() async throws {
        let response = HTTP.Response(
            status: .ok,
            headers: [
                try .init(name: "Content-Length", value: "100")
            ]
        )

        let length = HTTP.MessageBodyLength.calculate(
            for: response,
            requestMethod: .head
        )

        #expect(length == .none)
    }

    @Test("Response - 1xx status has no body")
    func response1xx() async throws {
        let response = HTTP.Response(
            status: HTTP.Status(100),
            headers: []
        )

        let length = HTTP.MessageBodyLength.calculate(
            for: response,
            requestMethod: .get
        )

        #expect(length == .none)
    }

    @Test("Response - 204 status has no body")
    func response204() async throws {
        let response = HTTP.Response(
            status: HTTP.Status(204),
            headers: []
        )

        let length = HTTP.MessageBodyLength.calculate(
            for: response,
            requestMethod: .get
        )

        #expect(length == .none)
    }

    @Test("Response - 304 status has no body")
    func response304() async throws {
        let response = HTTP.Response(
            status: HTTP.Status(304),
            headers: []
        )

        let length = HTTP.MessageBodyLength.calculate(
            for: response,
            requestMethod: .get
        )

        #expect(length == .none)
    }

    @Test("Response - successful CONNECT has no body")
    func responseSuccessfulConnect() async throws {
        let response = HTTP.Response(
            status: .ok,
            headers: []
        )

        let length = HTTP.MessageBodyLength.calculate(
            for: response,
            requestMethod: .connect
        )

        #expect(length == .none)
    }

    @Test("Response - Transfer-Encoding: chunked")
    func responseTransferEncodingChunked() async throws {
        let response = HTTP.Response(
            status: .ok,
            headers: [
                try .init(name: "Transfer-Encoding", value: "chunked")
            ]
        )

        let length = HTTP.MessageBodyLength.calculate(
            for: response,
            requestMethod: .get
        )

        #expect(length == .chunked)
    }

    @Test("Response - Transfer-Encoding takes precedence over Content-Length")
    func responseTransferEncodingPrecedence() async throws {
        let response = HTTP.Response(
            status: .ok,
            headers: [
                try .init(name: "Transfer-Encoding", value: "chunked"),
                try .init(name: "Content-Length", value: "100")
            ]
        )

        let length = HTTP.MessageBodyLength.calculate(
            for: response,
            requestMethod: .get
        )

        #expect(length == .chunked)
    }

    @Test("Response - Content-Length")
    func responseContentLength() async throws {
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

        #expect(length == .length(42))
    }

    @Test("Response - multiple Content-Length with same value")
    func responseMultipleContentLengthSame() async throws {
        let response = HTTP.Response(
            status: .ok,
            headers: [
                try .init(name: "Content-Length", value: "42"),
                try .init(name: "Content-Length", value: "42")
            ]
        )

        let length = HTTP.MessageBodyLength.calculate(
            for: response,
            requestMethod: .get
        )

        #expect(length == .length(42))
    }

    @Test("Response - multiple Content-Length with different values")
    func responseMultipleContentLengthDifferent() async throws {
        let response = HTTP.Response(
            status: .ok,
            headers: [
                try .init(name: "Content-Length", value: "42"),
                try .init(name: "Content-Length", value: "100")
            ]
        )

        let length = HTTP.MessageBodyLength.calculate(
            for: response,
            requestMethod: .get
        )

        // Invalid - should return none
        #expect(length == .none)
    }

    @Test("Response - no length indicators")
    func responseNoLengthIndicators() async throws {
        let response = HTTP.Response(
            status: .ok,
            headers: []
        )

        let length = HTTP.MessageBodyLength.calculate(
            for: response,
            requestMethod: .get
        )

        #expect(length == .untilClose)
    }

    // MARK: - Request Tests

    @Test("Request - Transfer-Encoding: chunked")
    func requestTransferEncodingChunked() async throws {
        let request = HTTP.Request(
            method: .post,
            target: .origin(path: try .init("/api/data"), query: nil),
            headers: [
                try .init(name: "Transfer-Encoding", value: "chunked")
            ]
        )

        let length = HTTP.MessageBodyLength.calculate(for: request)

        #expect(length == .chunked)
    }

    @Test("Request - Content-Length")
    func requestContentLength() async throws {
        let request = HTTP.Request(
            method: .post,
            target: .origin(path: try .init("/api/data"), query: nil),
            headers: [
                try .init(name: "Content-Length", value: "100")
            ]
        )

        let length = HTTP.MessageBodyLength.calculate(for: request)

        #expect(length == .length(100))
    }

    @Test("Request - no length indicators")
    func requestNoLengthIndicators() async throws {
        let request = HTTP.Request(
            method: .post,
            target: try .origin(path: .init("/api/data"), query: nil),
            headers: []
        )

        let length = HTTP.MessageBodyLength.calculate(for: request)

        #expect(length == .none)
    }

    // MARK: - Helper Methods Tests

    @Test("hasBody - none")
    func hasBodyNone() async throws {
        #expect(HTTP.MessageBodyLength.none.hasBody == false)
    }

    @Test("hasBody - length zero")
    func hasBodyLengthZero() async throws {
        #expect(HTTP.MessageBodyLength.length(0).hasBody == false)
    }

    @Test("hasBody - length positive")
    func hasBodyLengthPositive() async throws {
        #expect(HTTP.MessageBodyLength.length(100).hasBody == true)
    }

    @Test("hasBody - chunked")
    func hasBodyChunked() async throws {
        #expect(HTTP.MessageBodyLength.chunked.hasBody == true)
    }

    @Test("hasBody - untilClose")
    func hasBodyUntilClose() async throws {
        #expect(HTTP.MessageBodyLength.untilClose.hasBody == true)
    }

    @Test("fixedLength - none")
    func fixedLengthNone() async throws {
        #expect(HTTP.MessageBodyLength.none.fixedLength == 0)
    }

    @Test("fixedLength - length")
    func fixedLengthLength() async throws {
        #expect(HTTP.MessageBodyLength.length(100).fixedLength == 100)
    }

    @Test("fixedLength - chunked")
    func fixedLengthChunked() async throws {
        #expect(HTTP.MessageBodyLength.chunked.fixedLength == nil)
    }

    @Test("fixedLength - untilClose")
    func fixedLengthUntilClose() async throws {
        #expect(HTTP.MessageBodyLength.untilClose.fixedLength == nil)
    }

    @Test("isChunked")
    func isChunked() async throws {
        #expect(HTTP.MessageBodyLength.chunked.isChunked == true)
        #expect(HTTP.MessageBodyLength.length(100).isChunked == false)
        #expect(HTTP.MessageBodyLength.none.isChunked == false)
    }

    @Test("isUntilClose")
    func isUntilClose() async throws {
        #expect(HTTP.MessageBodyLength.untilClose.isUntilClose == true)
        #expect(HTTP.MessageBodyLength.chunked.isUntilClose == false)
        #expect(HTTP.MessageBodyLength.length(100).isUntilClose == false)
    }

    @Test("Equality")
    func equality() async throws {
        #expect(HTTP.MessageBodyLength.none == .none)
        #expect(HTTP.MessageBodyLength.length(100) == .length(100))
        #expect(HTTP.MessageBodyLength.length(100) != .length(200))
        #expect(HTTP.MessageBodyLength.chunked == .chunked)
        #expect(HTTP.MessageBodyLength.untilClose == .untilClose)
    }
}
