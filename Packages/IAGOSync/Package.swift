// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "IAGOSync",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "IAGOSync", targets: ["IAGOSync"])
    ],
    dependencies: [
        .package(path: "../IAGOCore")
    ],
    targets: [
        .target(
            name: "IAGOSync",
            dependencies: [
                .product(name: "IAGOCore", package: "IAGOCore")
            ]
        ),
        .testTarget(name: "IAGOSyncTests", dependencies: ["IAGOSync"]),
    ]
)
