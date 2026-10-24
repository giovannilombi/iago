// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "IAGOIntelligence",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "IAGOIntelligence", targets: ["IAGOIntelligence"])
    ],
    dependencies: [
        .package(path: "../IAGOCore"),
        .package(path: "../IAGOStore"),
    ],
    targets: [
        .target(
            name: "IAGOIntelligence",
            dependencies: [
                .product(name: "IAGOCore", package: "IAGOCore"),
                .product(name: "IAGOStore", package: "IAGOStore"),
            ]
        ),
        .testTarget(name: "IAGOIntelligenceTests", dependencies: ["IAGOIntelligence"]),
    ]
)
