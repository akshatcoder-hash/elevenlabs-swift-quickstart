// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ElevenLabsQuickstart",
    platforms: [.macOS(.v13), .iOS(.v16)],
    products: [
        .library(name: "ElevenLabsQuickstart", targets: ["ElevenLabsQuickstart"]),
        .executable(name: "eleven", targets: ["eleven"]),
    ],
    targets: [
        .target(name: "ElevenLabsQuickstart"),
        .executableTarget(name: "eleven", dependencies: ["ElevenLabsQuickstart"]),
        .testTarget(name: "ElevenLabsQuickstartTests", dependencies: ["ElevenLabsQuickstart"]),
    ]
)
