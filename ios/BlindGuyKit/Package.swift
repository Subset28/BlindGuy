// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BlindGuyKit",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
    ],
    products: [
        .library(name: "BlindGuyKit", targets: ["BlindGuyKit"]),
    ],
    targets: [
        .target(
            name: "BlindGuyKit",
            path: "Sources/BlindGuyKit"
        ),
        .testTarget(
            name: "BlindGuyKitTests",
            dependencies: ["BlindGuyKit"],
            path: "Tests/BlindGuyKitTests"
        ),
    ]
)
