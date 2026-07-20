// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SwiftPagerKitDemoFeature",
    platforms: [.iOS("26.0")],
    products: [
        .library(
            name: "SwiftPagerKitDemoFeature",
            targets: ["SwiftPagerKitDemoFeature"]
        ),
    ],
    dependencies: [
        .package(path: "../../..")
    ],
    targets: [
        .target(
            name: "SwiftPagerKitDemoFeature",
            dependencies: [
                .product(name: "SwiftPagerKit", package: "SwiftPagerKit")
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "SwiftPagerKitDemoFeatureTests",
            dependencies: [
                "SwiftPagerKitDemoFeature"
            ]
        ),
    ]
)
