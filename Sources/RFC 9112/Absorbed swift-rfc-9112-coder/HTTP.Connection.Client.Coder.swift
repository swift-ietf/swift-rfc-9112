#if Coder
    public import Byte
    public import RFC_9110

    extension RFC_9112.Connection.Client {

        public struct Coder: ~Copyable {

            private var messages: RFC_9112.Message.Coder

            private var client: RFC_9112.Connection.Client

            private var pending: Event?

            private var closed: Bool

            public init(
                limits: RFC_9112.Message.Coder.Limits = .default,
                policy: RFC_9112.Field.ObsFold.Policy = .reject
            ) {
                self.messages = RFC_9112.Message.Coder(limits: limits, policy: policy)
                self.client = RFC_9112.Connection.Client()
                self.pending = nil
                self.closed = false
            }
        }
    }

    extension RFC_9112.Connection.Client.Coder {

        public enum Event: Equatable {

            case head(RFC_9112.Response.Head)

            case body([Byte])

            case end(RFC_9110.Message.Trailers)

            case tunnel
        }

        public enum Error: Swift::Error, Equatable {

            case message(RFC_9112.Message.Coder.Error)

            case connection(RFC_9112.Connection.Client.Error)
        }
    }

    extension RFC_9112.Connection.Client.Coder {

        public var unconsumed: Int { messages.unconsumed }

        public var outstanding: Int { client.outstanding }

        public var isReusable: Bool { client.isReusable }

        public mutating func expect(_ method: RFC_9110.Method) {
            client.expect(method)
        }

        public mutating func receive(_ bytes: [Byte]) throws(Error) {
            let phase: RFC_9112.Message.Coder.Phase
            if case .body = client.state { phase = .body } else { phase = .head }

            do throws(RFC_9112.Message.Coder.Error) {
                try messages.append(bytes, accumulating: phase)
            } catch {
                throw .message(error)
            }
        }

        public mutating func peerClosed() {
            closed = true
        }
    }

    extension RFC_9112.Connection.Client.Coder {

        public mutating func next() throws(Error) -> Event? {
            if let queued = pending {
                pending = nil
                return queued
            }

            switch client.state {
            case .tunnelled, .finished:
                return nil

            case .head:
                guard let method = client.answering else {
                    throw .connection(.responseWithoutRequest)
                }

                let head: RFC_9112.Response.Head?
                do throws(RFC_9112.Message.Coder.Error) {
                    head = try messages.response(answering: method)
                } catch {
                    throw .message(error)
                }
                guard let head else { return nil }

                do throws(RFC_9112.Connection.Client.Error) {
                    try client.apply(.head(head, connection: Framing.connection(in: head.headers)))
                } catch {
                    throw .connection(error)
                }

                if case .tunnelled = client.state { pending = .tunnel }
                return .head(head)

            case .body(let length):
                return try body(length)
            }
        }

        private mutating func body(
            _ length: RFC_9112.Message.Body.Length
        ) throws(Error) -> Event? {
            guard length != .untilClose else { return untilClose() }

            let body: RFC_9112.Message.Body?
            do throws(RFC_9112.Message.Coder.Error) {
                body = try messages.body(length)
            } catch {
                throw .message(error)
            }
            guard let body else { return nil }

            do throws(RFC_9112.Connection.Client.Error) {
                try client.apply(.end)
            } catch {
                throw .connection(error)
            }

            guard !body.content.isEmpty else { return .end(body.trailers) }
            pending = .end(body.trailers)
            return .body(body.content)
        }

        private mutating func untilClose() -> Event? {
            let chunk = messages.take()
            guard chunk.isEmpty else { return .body(chunk) }
            guard closed else { return nil }

            try? client.apply(.close)
            return .end(RFC_9110.Message.Trailers())
        }
    }

    extension RFC_9112.Connection.Client.Coder {

        public consuming func surrender() -> [Byte] {
            messages.surrender()
        }

        public consuming func finish() -> RFC_9112.Message.Coder.Terminal {
            messages.finish()
        }
    }
#endif
