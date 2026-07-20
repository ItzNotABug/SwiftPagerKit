// swift-tools-version: 6.0
//
// Remote binary release manifest template.
// manifest.sh fills this file for binary release tags.

import PackageDescription

let swiftPagerKitCoreURL = "https://github.com/ItzNotABug/SwiftPagerKit/releases/download/0.1.0/SwiftPagerKitCore.xcframework.zip"
let swiftPagerKitCoreChecksum = "26733fbf66b6799f01cb4619100f4e2bf2702c139eeb61ef5d0f53937d247286"

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
        .binaryTarget(
            name: "SwiftPagerKitCore",
            url: swiftPagerKitCoreURL,
            checksum: swiftPagerKitCoreChecksum
        )
    ]
)
