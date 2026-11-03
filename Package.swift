// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "FixYourLife",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "FYLCore", targets: ["FYLCore"]),
    ],
    targets: [
        .target(name: "FYLCore"),
        .testTarget(name: "FYLCoreTests", dependencies: ["FYLCore"]),
    ]
)
