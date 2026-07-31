// HTTP.TransferEncoding.Storage.swift
// swift-rfc-9112

extension RFC_9110.TransferEncoding {
    enum Storage: Sendable, Equatable, Hashable {
        case single(String)
        case list([RFC_9110.TransferEncoding])
    }
}
