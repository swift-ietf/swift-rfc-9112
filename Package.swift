// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "swift-rfc-9112",
    platforms: [
        .macOS(.v15),
        .iOS(.v18),
        .tvOS(.v18),
        .watchOS(.v11)
    ],
    products: [
        .library(
            name: "RFC 9112",
            targets: ["RFC 9112"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/swift-standards/swift-rfc-9110", from: "0.1.0"),
        .package(url: "https://github.com/swift-standards/swift-standards", from: "0.1.0")
    ],
    targets: [
        .target(
            name: "RFC 9112",
            dependencies: [
                .product(name: "RFC 9110", package: "swift-rfc-9110"),
                .product(name: "Standards", package: "swift-standards")
            ]
        ),
        .testTarget(
            name: "RFC 9112".tests,
            dependencies: [
                "RFC 9112"
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)

extension String {
    var tests: Self { self + " Tests" }
    var foundation: Self { self + " Foundation" }
}

for target in package.targets where ![.system, .binary, .plugin].contains(target.type) {
    let existing = target.swiftSettings ?? []
    target.swiftSettings = existing + [
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility")
    ]
}
