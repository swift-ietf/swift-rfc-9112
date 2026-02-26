// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "swift-rfc-9112",
    platforms: [
        .macOS(.v26),
        .iOS(.v26),
        .tvOS(.v26),
        .watchOS(.v26)
    ],
    products: [
        .library(
            name: "RFC 9112",
            targets: ["RFC 9112"]
        )
    ],
    dependencies: [
        .package(path: "../swift-rfc-9110"),
        .package(path: "../../swift-primitives/swift-standard-library-extensions")
    ],
    targets: [
        .target(
            name: "RFC 9112",
            dependencies: [
                .product(name: "RFC 9110", package: "swift-rfc-9110"),
                .product(name: "Standard Library Extensions", package: "swift-standard-library-extensions")
    ]
        ),
        .testTarget(
            name: "RFC 9112 Tests",
            dependencies: [
                "RFC 9112",
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)

extension String {
    var tests: Self { self + " Tests" }
    var foundation: Self { self + " Foundation" }
}

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    let ecosystem: [SwiftSetting] = [
        .strictMemorySafety(),
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
        .enableExperimentalFeature("Lifetimes"),
        .enableExperimentalFeature("SuppressedAssociatedTypes"),
        .enableExperimentalFeature("SuppressedAssociatedTypesWithDefaults"),
    ]

    let package: [SwiftSetting] = []

    target.swiftSettings = (target.swiftSettings ?? []) + ecosystem + package
}
