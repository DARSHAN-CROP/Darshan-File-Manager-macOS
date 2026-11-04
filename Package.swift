// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "DarshanFileManager",
    platforms: [.macOS(.v13), .iOS(.v16)],
    products: [
        .library(name: "DarshanCore", targets: ["DarshanCore"]),
        .library(name: "DarshanUI", targets: ["DarshanUI"]),
        .executable(name: "DarshanFileManager", targets: ["DarshanFileManager"]),
    ],
    targets: [
        .target(name: "DarshanCore"),
        .target(name: "DarshanUI", dependencies: ["DarshanCore"]),
        .executableTarget(name: "DarshanFileManager", dependencies: ["DarshanUI"], path: "Sources/MacApp"),
        .testTarget(name: "DarshanCoreTests", dependencies: ["DarshanCore"]),
        .testTarget(name: "DarshanUITests", dependencies: ["DarshanUI", "DarshanCore"]),
    ]
)
