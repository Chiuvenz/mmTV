// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "mmTV",
    platforms: [.macOS(.v15)],
    products: ["Contracts", "Core", "MacHost", "Input", "DesignSystem", "Games", "TVApps", "Music", "PhotoGallery", "Home", "Assistant", "Remote"].map {
        .library(name: $0, targets: [$0])
    },
    targets: [
        .target(name: "Contracts"),
        .target(name: "Core", dependencies: ["Contracts"]),
        .target(name: "MacHost", dependencies: ["Contracts", "Core"]),
        .target(name: "Input", dependencies: ["Contracts"]),
        .target(name: "DesignSystem", dependencies: ["Contracts"]),
        .target(name: "Games", dependencies: ["Contracts"]),
        .target(name: "TVApps", dependencies: ["Contracts"]),
        .target(name: "Music", dependencies: ["Contracts"]),
        .target(name: "PhotoGallery", dependencies: ["Contracts"], path: "Sources/Photos"),
        .target(name: "Home", dependencies: ["Contracts"]),
        .target(name: "Assistant", dependencies: ["Contracts"]),
        .target(name: "Remote", dependencies: ["Contracts"]),
        .testTarget(name: "CoreTests", dependencies: ["Core", "Contracts", "MacHost", "Games", "TVApps", "Input"])
    ]
)
