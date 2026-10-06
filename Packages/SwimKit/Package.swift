// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "SwimKit",
    platforms: [
        .iOS(.v17),
        .watchOS(.v10),
        .macOS(.v14),
    ],
    products: [
        .library(name: "SwimCore", targets: ["SwimCore"]),
        .library(name: "SwimHealth", targets: ["SwimHealth"]),
    ],
    targets: [
        .target(name: "SwimCore"),
        .target(name: "SwimHealth", dependencies: ["SwimCore"]),
        .testTarget(name: "SwimCoreTests", dependencies: ["SwimCore"]),
        .testTarget(name: "SwimHealthTests", dependencies: ["SwimHealth"]),
    ],
    swiftLanguageVersions: [.v5]
)
