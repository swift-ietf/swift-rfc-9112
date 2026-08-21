extension RFC_9110.Framing {

    public enum Phase: Sendable, Equatable, Hashable {

        case head

        case body
    }
}

extension RFC_9110.Framing.Phase {

    internal func budget(under limits: RFC_9110.Framing.Limits) -> Int {
        switch self {
        case .head: limits.headSection
        case .body: limits.body
        }
    }

    internal func overrun(of budget: Int) -> RFC_9110.Framing.Error {
        switch self {
        case .head: .headSectionTooLong(limit: budget)
        case .body: .bodyTooLong(limit: budget)
        }
    }
}
