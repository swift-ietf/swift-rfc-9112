#if Coder
    extension RFC_9112.Message.Coder {

        public enum Terminal: Equatable, Hashable {

            case clean

            case truncated(unconsumed: Int)
        }
    }
#endif
