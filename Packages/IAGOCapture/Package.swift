// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "IAGOCapture",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "IAGOCapture", targets: ["IAGOCapture"]),
        .executable(name: "iago-spike", targets: ["iago-spike"]),
    ],
    dependencies: [
        .package(path: "../IAGOCore")
    ],
    targets: [
        .target(
            name: "IAGOCapture",
            dependencies: [
                .product(name: "IAGOCore", package: "IAGOCore")
            ]
        ),
        .executableTarget(name: "iago-spike", dependencies: ["IAGOCapture"]),
        .testTarget(name: "IAGOCaptureTests", dependencies: ["IAGOCapture"]),
    ]
)
