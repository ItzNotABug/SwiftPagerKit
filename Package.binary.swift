// swift-tools-version: 6.0
//
// Local binary validation manifest.
// Run scripts/build/xcframework.sh before using this manifest. For remote
// releases, generate Package.swift from scripts/build/Package.swift.template and fill
// in the uploaded artifact URL/checksum.

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
        .binaryTarget(
            name: "SwiftPagerKitCore",
            path: ".build/xcframework/output/SwiftPagerKitCore.xcframework.zip"
        )
    ]
)
