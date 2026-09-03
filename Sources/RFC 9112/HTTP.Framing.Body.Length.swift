public import RFC_9110

import INCITS_4_1986

extension RFC_9112.Framing.Body {
    public enum Length: Equatable, Hashable {

        case none

        case length(Int)

        case chunked

        case untilClose

        case tunnel
    }
}
