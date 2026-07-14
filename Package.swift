// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SharedFlagCore",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "SharedFlagCore", targets: ["SharedFlagCore"])
    ],
    targets: [
        .target(name: "SharedFlagCore"),
        .testTarget(name: "SharedFlagCoreTests", dependencies: ["SharedFlagCore"])
    ]
)
