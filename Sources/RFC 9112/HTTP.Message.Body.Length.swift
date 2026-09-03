public import RFC_9110

import INCITS_4_1986

extension RFC_9112.Message.Body {
    public enum Length: Equatable {

        case none

        case length(Int)

        case chunked

        case untilClose
    }
}
