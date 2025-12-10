// RFC_9112.swift
// swift-rfc-9112
//
// RFC 9112: HTTP/1.1
// https://www.rfc-editor.org/rfc/rfc9112.html
//
// This module implements the HTTP/1.1 message syntax and connection management
// as defined in RFC 9112, which obsoletes parts of RFC 7230.

@_exported import RFC_9110

/// RFC 9112: HTTP/1.1
///
/// This namespace contains types for HTTP/1.1 message syntax, transfer encodings,
/// and connection management as defined in RFC 9112.
///
/// ## Overview
///
/// RFC 9112 specifies:
/// - HTTP/1.1 message format and parsing
/// - Transfer encodings (chunked, gzip, compress, deflate)
/// - Connection management and persistence
/// - Message body length determination
/// - Security considerations for request smuggling and response splitting
///
/// ## Reference
///
/// - [RFC 9112: HTTP/1.1](https://www.rfc-editor.org/rfc/rfc9112.html)
public enum RFC_9112 {}
