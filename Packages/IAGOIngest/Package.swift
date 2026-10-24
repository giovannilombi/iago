// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "IAGOIngest",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "IAGOIngest", targets: ["IAGOIngest"])
    ],
    dependencies: [
        .package(path: "../IAGOCore")
    ],
    targets: [
        .target(
            name: "IAGOIngest",
            dependencies: [
                .product(name: "IAGOCore", package: "IAGOCore")
            ]
        ),
        .testTarget(name: "IAGOIngestTests", dependencies: ["IAGOIngest"]),
    ]
)
