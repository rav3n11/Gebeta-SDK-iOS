// swift-tools-version:5.9
import PackageDescription

// GebetaCore is Foundation-only and builds on Linux (cloud CI) as well as Apple
// platforms. GebetaMaps needs UIKit and the MapLibre.xcframework built from this
// repo by scripts/gebeta/build-xcframework.sh, so it is only declared on macOS hosts.

var products: [Product] = [
    .library(name: "GebetaCore", targets: ["GebetaCore"]),
]

var targets: [Target] = [
    .target(name: "GebetaCore", path: "Sources/GebetaCore"),
    .testTarget(name: "GebetaCoreTests", dependencies: ["GebetaCore"], path: "Tests/GebetaCoreTests"),
]

#if os(macOS)
products.append(.library(name: "GebetaMaps", targets: ["GebetaMaps"]))
targets += [
    .binaryTarget(name: "MapLibre", path: "Frameworks/MapLibre.xcframework"),
    .target(name: "GebetaMaps", dependencies: ["GebetaCore", "MapLibre"], path: "Sources/GebetaMaps"),
]
#endif

let package = Package(
    name: "GebetaMaps",
    platforms: [.iOS("15.5"), .macOS(.v12)],
    products: products,
    targets: targets
)
