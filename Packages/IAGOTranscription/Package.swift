// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "IAGOTranscription",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "IAGOTranscription", targets: ["IAGOTranscription"]),
        .executable(name: "iago-bench", targets: ["iago-bench"]),
    ],
    dependencies: [
        .package(path: "../IAGOCore"),
        .package(url: "https://github.com/FluidInference/FluidAudio.git", exact: "0.17.7"),
    ],
    targets: [
        .binaryTarget(
            name: "whisper",
            url: "https://github.com/ggml-org/whisper.cpp/releases/download/v1.9.2/whisper-v1.9.2-xcframework.zip",
            checksum: "af74fed13ea7f2d5ca2a39d9f58ec177713fafd7cab63aef4e27b79f3ceca80b"
        ),
        .target(
            name: "IAGOTranscription",
            dependencies: [
                .product(name: "IAGOCore", package: "IAGOCore"),
                .product(name: "FluidAudio", package: "FluidAudio"),
                "whisper",
            ]
        ),
        .executableTarget(name: "iago-bench", dependencies: ["IAGOTranscription"]),
        .testTarget(name: "IAGOTranscriptionTests", dependencies: ["IAGOTranscription"]),
    ]
)
