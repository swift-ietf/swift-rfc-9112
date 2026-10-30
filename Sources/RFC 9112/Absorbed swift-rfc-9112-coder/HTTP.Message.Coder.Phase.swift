#if Coder
    extension RFC_9112.Message.Coder {

        public enum Phase: Equatable, Hashable {

            case head

            case body
        }
    }

    extension RFC_9112.Message.Coder.Phase {

        func budget(under limits: RFC_9112.Message.Coder.Limits) -> Int {
            switch self {
            case .head: limits.headSection
            case .body: limits.body
            }
        }

        func overrun(of budget: Int) -> RFC_9112.Message.Coder.Error {
            switch self {
            case .head: .headSectionTooLong(limit: budget)
            case .body: .bodyTooLong(limit: budget)
            }
        }
    }
#endif
