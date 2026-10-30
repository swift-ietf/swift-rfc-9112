// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "swift-rfc-9112",
    platforms: [
        .macOS(.v27),
        .iOS(.v27),
        .tvOS(.v27),
        .watchOS(.v27),
        .visionOS(.v27),
    ],
    products: [
        .library(name: "RFC 9112", targets: ["RFC 9112"])
    ],
    traits: [
        .trait(name: "Coder", description: "Wire coders for RFC 9112 types")
    ],
    dependencies: [
        .package(url: "https://github.com/swift-atoms/swift-byte.git", branch: "main"),
        .package(url: "https://github.com/swift-ietf/swift-rfc-3986.git", branch: "main", traits: ["Coder"]),
        .package(url: "https://github.com/swift-atoms/swift-ascii.git", branch: "main"),
        .package(url: "https://github.com/swift-ietf/swift-rfc-5322.git", branch: "main"),
        .package(
            url: "https://github.com/swift-ietf/swift-rfc-9110.git",
            branch: "main",
            traits: [.trait(name: "Coder", condition: .when(traits: ["Coder"]))]
        ),
        .package(
            url: "https://github.com/swift-atoms/swift-coder.git",
            branch: "main",
            traits: [
                .trait(name: "Checkpoint", condition: .when(traits: ["Coder"])),
                .trait(name: "Choice", condition: .when(traits: ["Coder"])),
                .trait(name: "Either", condition: .when(traits: ["Coder"])),
                .trait(name: "IteratorLeaves", condition: .when(traits: ["Coder"])),
                .trait(name: "Map", condition: .when(traits: ["Coder"])),
                .trait(name: "Pair", condition: .when(traits: ["Coder"])),
                .trait(name: "Predicate", condition: .when(traits: ["Coder"])),
                .trait(name: "Repetition", condition: .when(traits: ["Coder"])),
                .trait(name: "Skip", condition: .when(traits: ["Coder"])),
            ]
        ),
        .package(url: "https://github.com/swift-atoms/swift-cursor.git", branch: "main"),
        .package(
            url: "https://github.com/swift-atoms/swift-parser.git",
            branch: "main",
            traits: [
                .trait(name: "Always", condition: .when(traits: ["Coder"])),
                .trait(name: "Append", condition: .when(traits: ["Coder"])),
                .trait(name: "Choice", condition: .when(traits: ["Coder"])),
                .trait(name: "Either", condition: .when(traits: ["Coder"])),
                .trait(name: "FlatMap", condition: .when(traits: ["Coder"])),
                .trait(name: "Iterator", condition: .when(traits: ["Coder"])),
                .trait(name: "IteratorLeaves", condition: .when(traits: ["Coder"])),
                .trait(name: "Map", condition: .when(traits: ["Coder"])),
                .trait(name: "Pair", condition: .when(traits: ["Coder"])),
                .trait(name: "Predicate", condition: .when(traits: ["Coder"])),
                .trait(name: "Product", condition: .when(traits: ["Coder"])),
                .trait(name: "Repetition", condition: .when(traits: ["Coder"])),
                .trait(name: "Skip", condition: .when(traits: ["Coder"])),
            ]
        ),
        .package(
            url: "https://github.com/swift-atoms/swift-serializer.git",
            branch: "main",
            traits: [
                .trait(name: "Either", condition: .when(traits: ["Coder"])),
                .trait(name: "Map", condition: .when(traits: ["Coder"])),
                .trait(name: "Pair", condition: .when(traits: ["Coder"])),
                .trait(name: "Repetition", condition: .when(traits: ["Coder"])),
            ]
        ),
    ],
    targets: [
        .target(
            name: "RFC 9112",
            dependencies: [
                .product(name: "ASCII", package: "swift-ascii"),
                .product(name: "Byte", package: "swift-byte"),
                .product(name: "RFC 3986", package: "swift-rfc-3986"),
                .product(name: "RFC 5322", package: "swift-rfc-5322"),
                .product(name: "RFC 9110", package: "swift-rfc-9110"),
                .product(name: "Coder", package: "swift-coder", condition: .when(traits: ["Coder"])),
                .product(name: "Cursor", package: "swift-cursor", condition: .when(traits: ["Coder"])),
                .product(name: "Parser", package: "swift-parser", condition: .when(traits: ["Coder"])),
                .product(name: "Serializer", package: "swift-serializer", condition: .when(traits: ["Coder"])),
            ]
        ),
        .testTarget(
            name: "RFC 9112 Tests",
            dependencies: [
                .target(name: "RFC 9112"),
                .product(name: "Byte", package: "swift-byte"),
                .product(name: "RFC 3986", package: "swift-rfc-3986"),
                .product(name: "RFC 9110", package: "swift-rfc-9110"),
                .product(name: "Coder", package: "swift-coder", condition: .when(traits: ["Coder"])),
                .product(name: "Cursor", package: "swift-cursor", condition: .when(traits: ["Coder"])),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    target.swiftSettings =
        (target.swiftSettings ?? []) + [
            .strictMemorySafety(),
            .enableUpcomingFeature("ExistentialAny"),
            .enableUpcomingFeature("InternalImportsByDefault"),
            .enableUpcomingFeature("MemberImportVisibility"),
            .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
            .enableUpcomingFeature("InferIsolatedConformances"),
            .enableExperimentalFeature("Lifetimes"),
            .treatAllWarnings(as: .error),
        ]
}
