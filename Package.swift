// swift-tools-version:5.8
import PackageDescription

let package = Package(
    name: "Masaiki",
    platforms: [
        .macOS(.v12)
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "Masaiki",
            path: "Sources/Masaiki",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        )
    ]
)
