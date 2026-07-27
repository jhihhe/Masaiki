// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Masaiki",
    platforms: [
        .macOS(.v13),
        .iOS(.v16)
    ],
    products: [
        .library(name: "MasaikiCore", targets: ["MasaikiCore"]),
        .executable(name: "Masaiki", targets: ["Masaiki"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "MasaikiCore",
            path: "Sources/MasaikiCore",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .executableTarget(
            name: "Masaiki",
            dependencies: ["MasaikiCore"],
            path: "Sources/Masaiki",
            exclude: [
                // Info.plist / entitlements / PrivacyInfo 由 scripts/build_macos.sh 单独复制到 .app 目录，
                // SwiftPM 不允许 Info.plist 作为顶级资源。
                "Resources/Info.plist",
                "Resources/Masaiki.entitlements",
                "Resources/PrivacyInfo.xcprivacy"
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "MasaikiCoreTests",
            dependencies: ["MasaikiCore"],
            path: "Tests/MasaikiCoreTests"
        )
    ]
)
