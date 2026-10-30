#if Coder
    public import Byte
    public import RFC_9110

    extension RFC_9112.Connection.Server {

        public struct Coder: ~Copyable {

            private var messages: RFC_9112.Message.Coder

            private var server: RFC_9112.Connection.Server

            private var pending: Event?

            public init(
                limits: RFC_9112.Message.Coder.Limits = .default,
                policy: RFC_9112.Field.ObsFold.Policy = .reject
            ) {
                self.messages = RFC_9112.Message.Coder(limits: limits, policy: policy)
                self.server = RFC_9112.Connection.Server()
                self.pending = nil
            }
        }
    }

    extension RFC_9112.Connection.Server.Coder {

        public enum Event: Equatable {

            case head(RFC_9112.Request.Head)

            case body([Byte])

            case end(RFC_9110.Message.Trailers)
        }

        public enum Error: Swift::Error, Equatable {

            case message(RFC_9112.Message.Coder.Error)

            case connection(RFC_9112.Connection.Server.Error)
        }
    }

    extension RFC_9112.Connection.Server.Coder {

        public var unconsumed: Int { messages.unconsumed }

        public var isReusable: Bool { server.isReusable }

        public var isReadingBody: Bool { server.isReadingBody }

        public mutating func receive(_ bytes: [Byte]) throws(Error) {
            let phase: RFC_9112.Message.Coder.Phase
            if case .body = server.state { phase = .body } else { phase = .head }

            do throws(RFC_9112.Message.Coder.Error) {
                try messages.append(bytes, accumulating: phase)
            } catch {
                throw .message(error)
            }
        }
    }

    extension RFC_9112.Connection.Server.Coder {

        public mutating func next() throws(Error) -> Event? {
            if let queued = pending {
                pending = nil
                return queued
            }

            switch server.state {
            case .finished:
                return nil

            case .head:
                let head: RFC_9112.Request.Head?
                do throws(RFC_9112.Message.Coder.Error) {
                    head = try messages.request()
                } catch {
                    throw .message(error)
                }
                guard let head else { return nil }

                do throws(RFC_9112.Connection.Server.Error) {
                    try server.apply(.head(head, connection: Framing.connection(in: head.headers)))
                } catch {
                    throw .connection(error)
                }

                return .head(head)

            case .body(let length):
                let body: RFC_9112.Message.Body?
                do throws(RFC_9112.Message.Coder.Error) {
                    body = try messages.body(length)
                } catch {
                    throw .message(error)
                }
                guard let body else { return nil }

                do throws(RFC_9112.Connection.Server.Error) {
                    try server.apply(.end)
                } catch {
                    throw .connection(error)
                }

                guard !body.content.isEmpty else { return .end(body.trailers) }
                pending = .end(body.trailers)
                return .body(body.content)
            }
        }
    }

    extension RFC_9112.Connection.Server.Coder {

        public consuming func finish() -> RFC_9112.Message.Coder.Terminal {
            messages.finish()
        }
    }
#endif
