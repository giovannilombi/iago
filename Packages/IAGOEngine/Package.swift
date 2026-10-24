// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "IAGOEngine",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "IAGOEngine", targets: ["IAGOEngine"])
    ],
    dependencies: [
        .package(path: "../IAGOCore")
    ],
    targets: [
        .target(
            name: "IAGOEngine",
            dependencies: [.product(name: "IAGOCore", package: "IAGOCore")]
        ),
        .testTarget(name: "IAGOEngineTests", dependencies: ["IAGOEngine"]),
    ]
)
