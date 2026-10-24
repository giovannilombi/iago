// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "IAGOExport",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "IAGOExport", targets: ["IAGOExport"])
    ],
    dependencies: [
        .package(path: "../IAGOCore"),
        .package(path: "../IAGOStore"),
    ],
    targets: [
        .target(
            name: "IAGOExport",
            dependencies: [
                .product(name: "IAGOCore", package: "IAGOCore"),
                .product(name: "IAGOStore", package: "IAGOStore"),
            ]
        ),
        .testTarget(name: "IAGOExportTests", dependencies: ["IAGOExport"]),
    ]
)
