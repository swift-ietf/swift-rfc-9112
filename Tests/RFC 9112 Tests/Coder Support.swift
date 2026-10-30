#if Coder
    import Byte

    func bytes(_ text: String) -> [Byte] {
        [Byte](utf8: text)
    }

    func text(_ bytes: [Byte]) -> String {
        String(decoding: bytes, as: UTF8.self)
    }
#endif
