#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
PACKAGE_DIR="$(cd -- "$SCRIPT_DIR/../.." && pwd -P)"
BUILD_DIR="$PACKAGE_DIR/.build/xcframework"
WORK_DIR="${SWIFTPAGERKIT_XCFRAMEWORK_WORK_DIR:-/tmp/swiftpagerkit-xcframework}"
ARCHIVES_DIR="$WORK_DIR/archives"
OUTPUT_DIR="$BUILD_DIR/output"
BUILD_PACKAGE_DIR="$WORK_DIR/package"
DERIVED_DATA_DIR="$WORK_DIR/DerivedData"

SCHEME="${SCHEME:-SwiftPagerKitCore}"
CONFIGURATION="${CONFIGURATION:-Release}"
INCLUDE_DEBUG_SYMBOLS="${SWIFTPAGERKIT_INCLUDE_DEBUG_SYMBOLS:-0}"

rm -rf "$BUILD_DIR" "$WORK_DIR"
mkdir -p "$ARCHIVES_DIR" "$OUTPUT_DIR" "$BUILD_PACKAGE_DIR"
trap 'rm -rf "$WORK_DIR"' EXIT

cp -R "$PACKAGE_DIR/Sources" "$BUILD_PACKAGE_DIR/Sources"
cat > "$BUILD_PACKAGE_DIR/Package.swift" <<'EOF'
// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SwiftPagerKitCore",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "SwiftPagerKitCore",
            type: .dynamic,
            targets: ["SwiftPagerKitCore"]
        )
    ],
    targets: [
        .target(
            name: "SwiftPagerKitCore",
            path: "Sources/SwiftPagerKitCore"
        )
    ]
)
EOF

archive() {
    local destination="$1"
    local archive_path="$2"
    local platform_suffix="$3"
    local inherited_flags="${OTHER_SWIFT_FLAGS:-\$(inherited)}"
    local swift_flags="$inherited_flags -debug-prefix-map $WORK_DIR=SwiftPagerKit -file-prefix-map $WORK_DIR=SwiftPagerKit"
    local debug_information_format="dwarf"
    local generate_debug_symbols="NO"

    if [[ "$INCLUDE_DEBUG_SYMBOLS" == "1" ]]; then
        debug_information_format="dwarf-with-dsym"
        generate_debug_symbols="YES"
    fi

    xcodebuild archive \
        -quiet \
        -scheme "$SCHEME" \
        -configuration "$CONFIGURATION" \
        -destination "$destination" \
        -archivePath "$archive_path" \
        -derivedDataPath "$DERIVED_DATA_DIR" \
        BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
        DEBUG_INFORMATION_FORMAT="$debug_information_format" \
        GCC_GENERATE_DEBUGGING_SYMBOLS="$generate_debug_symbols" \
        OTHER_SWIFT_FLAGS="$swift_flags" \
        SKIP_INSTALL=NO \
        CODE_SIGNING_ALLOWED=NO

    local framework_path="$archive_path.xcarchive/Products/usr/local/lib/$SCHEME.framework"
    local module_source="$DERIVED_DATA_DIR/Build/Intermediates.noindex/ArchiveIntermediates/$SCHEME/BuildProductsPath/$CONFIGURATION-$platform_suffix/$SCHEME.swiftmodule"
    local module_destination="$framework_path/Modules"

    if [[ ! -d "$module_source" ]]; then
        printf 'error: missing Swift module metadata at %s\n' "$module_source" >&2
        return 1
    fi

    mkdir -p "$module_destination"
    rm -rf "$module_destination/$SCHEME.swiftmodule"
    cp -R "$module_source" "$module_destination/"
}

(
    cd "$BUILD_PACKAGE_DIR"
    archive "generic/platform=iOS" "$ARCHIVES_DIR/ios" "iphoneos"
    archive "generic/platform=iOS Simulator" "$ARCHIVES_DIR/ios-simulator" "iphonesimulator"

    ios_framework="$ARCHIVES_DIR/ios.xcarchive/Products/usr/local/lib/$SCHEME.framework"
    ios_simulator_framework="$ARCHIVES_DIR/ios-simulator.xcarchive/Products/usr/local/lib/$SCHEME.framework"
    ios_dsym="$ARCHIVES_DIR/ios.xcarchive/dSYMs/$SCHEME.framework.dSYM"
    ios_simulator_dsym="$ARCHIVES_DIR/ios-simulator.xcarchive/dSYMs/$SCHEME.framework.dSYM"
    xcframework_args=(
        -create-xcframework
        -framework "$ios_framework"
    )
    if [[ "$INCLUDE_DEBUG_SYMBOLS" == "1" && -d "$ios_dsym" ]]; then
        xcframework_args+=(-debug-symbols "$ios_dsym")
    fi
    xcframework_args+=(-framework "$ios_simulator_framework")
    if [[ "$INCLUDE_DEBUG_SYMBOLS" == "1" && -d "$ios_simulator_dsym" ]]; then
        xcframework_args+=(-debug-symbols "$ios_simulator_dsym")
    fi

    xcodebuild "${xcframework_args[@]}" \
        -output "$OUTPUT_DIR/$SCHEME.xcframework"

    (
        cd "$OUTPUT_DIR"
        rm -f "$SCHEME.xcframework.zip"
        zip -qry -X "$SCHEME.xcframework.zip" "$SCHEME.xcframework"
    )

    swift package compute-checksum "$OUTPUT_DIR/$SCHEME.xcframework.zip" \
        > "$OUTPUT_DIR/checksum.txt"
)

printf 'XCFramework: %s\n' "$OUTPUT_DIR/$SCHEME.xcframework"
printf 'Zip: %s\n' "$OUTPUT_DIR/$SCHEME.xcframework.zip"
printf 'Checksum: %s\n' "$(cat "$OUTPUT_DIR/checksum.txt")"
