// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "xload",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(
            name: "XLoadDynamic",
            type: .dynamic,
            targets: ["XLoad"],
        ),
        .library(
            name: "XLoad",
            targets: ["XLoad"],
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/xtool-org/InjectionLite",
            branch: "debug-trait",
            traits: [], // disable DEBUG_ONLY
        ),
    ],
    targets: [
        .target(
            name: "CXLoad"
        ),
        .target(
            name: "XLoad",
            dependencies: [
                "CXLoad",
                .product(name: "InjectionImpl", package: "InjectionLite"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
