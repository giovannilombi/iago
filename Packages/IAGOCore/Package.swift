// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "IAGOCore",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "IAGOCore", targets: ["IAGOCore"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "IAGOCore",
            dependencies: []
        ),
        .testTarget(name: "IAGOCoreTests", dependencies: ["IAGOCore"]),
    ]
)
