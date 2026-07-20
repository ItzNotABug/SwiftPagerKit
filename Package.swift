// swift-tools-version: 6.0
//
// Remote binary release manifest template.
// manifest.sh fills this file for binary release tags.

import PackageDescription

let swiftPagerKitCoreURL = "https://github.com/ItzNotABug/SwiftPagerKit/releases/download/0.1.1/SwiftPagerKitCore.xcframework.zip"
let swiftPagerKitCoreChecksum = "fde920e0726c54909a529e9240306170770b91a2e77609ecfa4baea2fd419ecc"

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
