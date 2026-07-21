// swift-tools-version: 6.0
//
// Remote binary release manifest template.
// manifest.sh fills this file for binary release tags.

import PackageDescription

let swiftPagerKitCoreURL = "https://github.com/ItzNotABug/SwiftPagerKit/releases/download/0.1.3/SwiftPagerKitCore.xcframework.zip"
let swiftPagerKitCoreChecksum = "2e115a5dff93205e58acc09c926a976d4b5f7d01dd44ba3e34f28e1ffb9e1728"

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
