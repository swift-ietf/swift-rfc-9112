import RFC_9110
@testable import RFC_9112
@testable import RFC_9112_Parser
@testable import RFC_9112_Serializer

typealias HTTP = RFC_9112

var http10: RFC_9110.Version { try! RFC_9110.Version(major: 1, minor: 0) }
