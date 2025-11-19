// HTTP.MessageBodyLength.Tests.swift
// swift-rfc-9112

import Testing
@testable import RFC_9112

@Suite
struct `HTTP.MessageBodyLength Tests` {

    // MARK: - Response Tests

    @Test
    func `Response - HEAD request has no body`() async throws {
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

    @Test
    func `Response - 1xx status has no body`() async throws {
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

    @Test
    func `Response - 204 status has no body`() async throws {
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

    @Test
    func `Response - 304 status has no body`() async throws {
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

    @Test
    func `Response - successful CONNECT has no body`() async throws {
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

    @Test
    func `Response - Transfer-Encoding: chunked`() async throws {
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

    @Test
    func `Response - Transfer-Encoding takes precedence over Content-Length`() async throws {
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

    @Test
    func `Response - Content-Length`() async throws {
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

    @Test
    func `Response - multiple Content-Length with same value`() async throws {
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

    @Test
    func `Response - multiple Content-Length with different values`() async throws {
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

    @Test
    func `Response - no length indicators`() async throws {
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

    @Test
    func `Request - Transfer-Encoding: chunked`() async throws {
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

    @Test
    func `Request - Content-Length`() async throws {
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

    @Test
    func `Request - no length indicators`() async throws {
        let request = HTTP.Request(
            method: .post,
            target: try .origin(path: .init("/api/data"), query: nil),
            headers: []
        )

        let length = HTTP.MessageBodyLength.calculate(for: request)

        #expect(length == .none)
    }

    // MARK: - Helper Methods Tests

    @Test
    func `hasBody - none`() async throws {
        #expect(HTTP.MessageBodyLength.none.hasBody == false)
    }

    @Test
    func `hasBody - length zero`() async throws {
        #expect(HTTP.MessageBodyLength.length(0).hasBody == false)
    }

    @Test
    func `hasBody - length positive`() async throws {
        #expect(HTTP.MessageBodyLength.length(100).hasBody == true)
    }

    @Test
    func `hasBody - chunked`() async throws {
        #expect(HTTP.MessageBodyLength.chunked.hasBody == true)
    }

    @Test
    func `hasBody - untilClose`() async throws {
        #expect(HTTP.MessageBodyLength.untilClose.hasBody == true)
    }

    @Test
    func `fixedLength - none`() async throws {
        #expect(HTTP.MessageBodyLength.none.fixedLength == 0)
    }

    @Test
    func `fixedLength - length`() async throws {
        #expect(HTTP.MessageBodyLength.length(100).fixedLength == 100)
    }

    @Test
    func `fixedLength - chunked`() async throws {
        #expect(HTTP.MessageBodyLength.chunked.fixedLength == nil)
    }

    @Test
    func `fixedLength - untilClose`() async throws {
        #expect(HTTP.MessageBodyLength.untilClose.fixedLength == nil)
    }

    @Test
    func `isChunked`() async throws {
        #expect(HTTP.MessageBodyLength.chunked.isChunked == true)
        #expect(HTTP.MessageBodyLength.length(100).isChunked == false)
        #expect(HTTP.MessageBodyLength.none.isChunked == false)
    }

    @Test
    func `isUntilClose`() async throws {
        #expect(HTTP.MessageBodyLength.untilClose.isUntilClose == true)
        #expect(HTTP.MessageBodyLength.chunked.isUntilClose == false)
        #expect(HTTP.MessageBodyLength.length(100).isUntilClose == false)
    }

    @Test
    func `Equality`() async throws {
        #expect(HTTP.MessageBodyLength.none == .none)
        #expect(HTTP.MessageBodyLength.length(100) == .length(100))
        #expect(HTTP.MessageBodyLength.length(100) != .length(200))
        #expect(HTTP.MessageBodyLength.chunked == .chunked)
        #expect(HTTP.MessageBodyLength.untilClose == .untilClose)
    }
}
