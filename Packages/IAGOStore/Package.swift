// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "IAGOStore",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "IAGOStore", targets: ["IAGOStore"])
    ],
    dependencies: [
        .package(path: "../IAGOCore"),
        .package(url: "https://github.com/groue/GRDB.swift.git", exact: "7.11.1"),
    ],
    targets: [
        .target(
            name: "IAGOStore",
            dependencies: [
                .product(name: "IAGOCore", package: "IAGOCore"),
                .product(name: "GRDB", package: "GRDB.swift"),
            ]
        ),
        .testTarget(name: "IAGOStoreTests", dependencies: ["IAGOStore"]),
    ]
)
