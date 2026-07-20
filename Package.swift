// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SwiftPagerKit",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "SwiftPagerKit",
            targets: ["SwiftPagerKit"]
        )
    ],
    targets: [
        .target(
            name: "SwiftPagerKit",
            dependencies: ["SwiftPagerKitCore"]
        ),
        .target(
            name: "SwiftPagerKitCore"
        ),
        .testTarget(
            name: "SwiftPagerKitCoreTests",
            dependencies: ["SwiftPagerKitCore"]
        )
    ]
)
