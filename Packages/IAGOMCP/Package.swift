// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "IAGOMCP",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "IAGOMCP", targets: ["IAGOMCP"]),
        .executable(name: "iago-mcp", targets: ["iago-mcp"]),
    ],
    dependencies: [
        .package(path: "../IAGOCore"),
        .package(path: "../IAGOStore"),
        .package(path: "../IAGOIntelligence"),
        .package(path: "../IAGOExport"),
        .package(path: "../IAGOIngest"),
    ],
    targets: [
        .target(
            name: "IAGOMCP",
            dependencies: [
                .product(name: "IAGOCore", package: "IAGOCore"),
                .product(name: "IAGOStore", package: "IAGOStore"),
                .product(name: "IAGOIntelligence", package: "IAGOIntelligence"),
                .product(name: "IAGOExport", package: "IAGOExport"),
                .product(name: "IAGOIngest", package: "IAGOIngest"),
            ]
        ),
        .executableTarget(
            name: "iago-mcp",
            dependencies: [
                "IAGOMCP",
                .product(name: "IAGOStore", package: "IAGOStore"),
            ]
        ),
        .testTarget(name: "IAGOMCPTests", dependencies: ["IAGOMCP"]),
    ]
)
