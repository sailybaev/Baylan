// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BaylanCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "BaylanCore",
            targets: ["BaylanCore"]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/apple/swift-protobuf.git",
            from: "1.25.0"
        ),
        .package(
            url: "https://github.com/apple/swift-collections.git",
            from: "1.1.0"
        )
    ],
    targets: [
        .target(
            name: "BaylanCore",
            dependencies: [
                .product(name: "SwiftProtobuf", package: "swift-protobuf"),
                .product(name: "Collections", package: "swift-collections")
            ],
            path: "Sources/BaylanCore",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "BaylanCoreTests",
            dependencies: ["BaylanCore"],
            path: "Tests/BaylanCoreTests"
        )
    ]
)
