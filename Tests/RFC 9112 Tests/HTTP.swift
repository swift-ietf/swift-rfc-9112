import RFC_9110

@testable import RFC_9112

typealias HTTP = RFC_9112

var http10: RFC_9110.Version {
    do {
        return try RFC_9110.Version(major: 1, minor: 0)
    } catch {
        preconditionFailure("HTTP/1.0 is a valid version: \(error)")
    }
}
