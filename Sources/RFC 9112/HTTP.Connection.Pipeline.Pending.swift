public import RFC_5322
public import RFC_9110

extension RFC_9112.Connection.Pipeline {

    public struct Pending: Equatable {

        public let method: RFC_9110.Method

        public let moment: RFC_9110.Date

        public init(method: RFC_9110.Method, moment: RFC_9110.Date) {
            self.method = method
            self.moment = moment
        }
    }
}
