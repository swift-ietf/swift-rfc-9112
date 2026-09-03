extension RFC_9112.Framing {

    public enum Phase: Equatable, Hashable {

        case head

        case body
    }
}

extension RFC_9112.Framing.Phase {

    package func budget(under limits: RFC_9112.Framing.Limits) -> Int {
        switch self {
        case .head: limits.headSection
        case .body: limits.body
        }
    }

    package func overrun(of budget: Int) -> RFC_9112.Framing.Error {
        switch self {
        case .head: .headSectionTooLong(limit: budget)
        case .body: .bodyTooLong(limit: budget)
        }
    }
}
