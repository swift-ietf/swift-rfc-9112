extension RFC_9110.Pipeline {

    struct PendingRequest: Sendable {
        let method: RFC_9110.Method
        let timestamp: RFC_9110.Date
    }
}
