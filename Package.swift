// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "xload",
    platforms: [
        .macOS(.v15),
        .iOS(.v18),
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
        .package(
            url: "https://github.com/kabiroberai/ellekit",
            branch: "swiftpm-fixes",
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
                .product(name: "ellekit", package: "ellekit"),
            ]
        ),
        .executableTarget(
            name: "XLoadPlayground",
            dependencies: ["XLoad"],
            swiftSettings: [
                .enableExperimentalFeature("OpaqueTypeErasure"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
