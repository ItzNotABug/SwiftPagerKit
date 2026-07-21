// swift-tools-version: 6.0
//
// Remote binary release manifest template.
// manifest.sh fills this file for binary release tags.

import PackageDescription

let swiftPagerKitCoreURL = "https://github.com/ItzNotABug/SwiftPagerKit/releases/download/0.1.2/SwiftPagerKitCore.xcframework.zip"
let swiftPagerKitCoreChecksum = "052e526a9b858c7f554c6b0a7948fbf43c34686c78a2ec263ccef46fbb5d5a5e"

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
