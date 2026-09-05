// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LimitMeter",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(name: "LimitMeterCore", targets: ["LimitMeterCore"]),
        .executable(name: "LimitMeter", targets: ["LimitMeter"]),
    ],
    targets: [
        .target(
            name: "LimitMeterCore",
            path: "LimitMeter",
            exclude: [
                "Assets.xcassets",
                "Info.plist",
                "LimitMeter.entitlements",
            ]
        ),
        .executableTarget(
            name: "LimitMeter",
            dependencies: ["LimitMeterCore"],
            path: "LimitMeterApp",
            resources: [
                .process("Assets.xcassets"),
                .process("Resources"),
            ]
        ),
        .testTarget(
            name: "LimitMeterCoreTests",
            dependencies: ["LimitMeterCore"],
            path: "LimitMeterTests",
            resources: [
                .process("Fixtures"),
            ]
        ),
    ]
)
