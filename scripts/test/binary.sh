#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
PACKAGE_DIR="$(cd -- "$SCRIPT_DIR/../.." && pwd -P)"
BUILD_DIR="$PACKAGE_DIR/.build/validation"
CONSUMER_DIR="$BUILD_DIR/binary-consumer"
REMOTE_CONSUMER_DIR="$BUILD_DIR/remote-binary-consumer"
REMOTE_MANIFEST_DIR="$BUILD_DIR/remote-manifest"
REMOTE_MANIFEST_TEMPLATE="$PACKAGE_DIR/scripts/build/Package.swift.template"
ARTIFACT_ZIP="$PACKAGE_DIR/.build/xcframework/output/SwiftPagerKitCore.xcframework.zip"
CONSUMER_ARTIFACT_ZIP="$CONSUMER_DIR/SwiftPagerKitCore.xcframework.zip"
REMOTE_ARTIFACT_ZIP="$REMOTE_CONSUMER_DIR/SwiftPagerKitCore.xcframework.zip"
SIMULATOR_ID="${SIMULATOR_ID:-}"
REQUIRE_REMOTE_BINARY_MANIFEST="${REQUIRE_REMOTE_BINARY_MANIFEST:-0}"

log() {
    printf '[binary] %s\n' "$*" >&2
}

if [[ ! -f "$REMOTE_MANIFEST_TEMPLATE" ]]; then
    printf 'error: expected remote manifest template missing at %s\n' "$REMOTE_MANIFEST_TEMPLATE" >&2
    exit 1
fi

remote_url="$(sed -nE 's/^let swiftPagerKitCoreURL = "([^"]+)"/\1/p' "$REMOTE_MANIFEST_TEMPLATE")"
remote_checksum="$(sed -nE 's/^let swiftPagerKitCoreChecksum = "([^"]+)"/\1/p' "$REMOTE_MANIFEST_TEMPLATE")"

if [[ "$REQUIRE_REMOTE_BINARY_MANIFEST" == "1" ]]; then
    if [[ "$remote_url" == *VERSION* || "$remote_checksum" == *REPLACE_WITH* ]]; then
        printf 'error: release package template still contains release placeholders\n' >&2
        exit 1
    fi
    if [[ ! "$remote_checksum" =~ ^[0-9a-f]{64}$ ]]; then
        printf 'error: release package template checksum is not a 64-character hex checksum\n' >&2
        exit 1
    fi
fi

rm -rf "$BUILD_DIR"
mkdir -p "$CONSUMER_DIR/Sources/SwiftPagerKit" "$CONSUMER_DIR/Sources/BinaryConsumerProbe" "$REMOTE_CONSUMER_DIR"

if [[ -z "$SIMULATOR_ID" ]]; then
    SIMULATOR_ID="$("$PACKAGE_DIR/scripts/test/simulator.sh")"
fi

if [[ -z "$SIMULATOR_ID" ]]; then
    printf 'error: no available iPhone simulator found\n' >&2
    exit 1
fi

log "building source package for iOS Simulator"
(
    cd "$PACKAGE_DIR"
    xcodebuild \
        -quiet \
        -scheme SwiftPagerKit \
        -configuration Release \
        -destination 'generic/platform=iOS Simulator' \
        -derivedDataPath "$BUILD_DIR/source-derived-data" \
        CODE_SIGNING_ALLOWED=NO \
        build
)

log "running UIKit behavior tests on iOS Simulator"
(
    cd "$PACKAGE_DIR"
    xcodebuild \
        -quiet \
        -scheme SwiftPagerKit \
        -configuration Debug \
        -destination "id=$SIMULATOR_ID" \
        -derivedDataPath "$BUILD_DIR/test-derived-data" \
        CODE_SIGNING_ALLOWED=NO \
        test
)

log "building XCFramework artifact"
"$PACKAGE_DIR/scripts/build/xcframework.sh"

if [[ ! -f "$ARTIFACT_ZIP" ]]; then
    printf 'error: expected artifact zip missing at %s\n' "$ARTIFACT_ZIP" >&2
    exit 1
fi

artifact_checksum="$(swift package compute-checksum "$ARTIFACT_ZIP")"
log "local artifact checksum: $artifact_checksum"

if [[ "$REQUIRE_REMOTE_BINARY_MANIFEST" == "1" ]]; then
    log "downloading remote binary artifact"
    curl --fail --location --silent --show-error "$remote_url" --output "$REMOTE_ARTIFACT_ZIP"
    downloaded_checksum="$(swift package compute-checksum "$REMOTE_ARTIFACT_ZIP")"
    if [[ "$downloaded_checksum" != "$remote_checksum" ]]; then
        printf 'error: release package template checksum %s does not match downloaded artifact %s\n' "$remote_checksum" "$downloaded_checksum" >&2
        exit 1
    fi

    log "remote binary checksum matches downloaded artifact"
elif [[ "$remote_checksum" =~ ^[0-9a-f]{64}$ ]]; then
    log "remote binary manifest has a concrete checksum; set REQUIRE_REMOTE_BINARY_MANIFEST=1 to verify the uploaded artifact"
else
    log "remote binary manifest uses a release-time checksum placeholder"
fi

cp "$ARTIFACT_ZIP" "$CONSUMER_ARTIFACT_ZIP"

log "checking remote binary manifest template syntax"
mkdir -p "$REMOTE_MANIFEST_DIR/Sources/SwiftPagerKit"
cp "$REMOTE_MANIFEST_TEMPLATE" "$REMOTE_MANIFEST_DIR/Package.swift"
cp "$PACKAGE_DIR/Sources/SwiftPagerKit/SwiftPagerKit.swift" "$REMOTE_MANIFEST_DIR/Sources/SwiftPagerKit/SwiftPagerKit.swift"
(
    cd "$REMOTE_MANIFEST_DIR"
    swift package dump-package >/dev/null
)

cat > "$CONSUMER_DIR/Package.swift" <<EOF
// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "BinaryConsumer",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(name: "BinaryConsumerProbe", targets: ["BinaryConsumerProbe"])
    ],
    targets: [
        .target(
            name: "SwiftPagerKit",
            dependencies: ["SwiftPagerKitCore"]
        ),
        .binaryTarget(
            name: "SwiftPagerKitCore",
            path: "SwiftPagerKitCore.xcframework.zip"
        ),
        .target(
            name: "BinaryConsumerProbe",
            dependencies: ["SwiftPagerKit"]
        )
    ]
)
EOF

cat > "$CONSUMER_DIR/Sources/SwiftPagerKit/SwiftPagerKit.swift" <<'EOF'
@_exported import SwiftPagerKitCore
EOF

cat > "$CONSUMER_DIR/Sources/BinaryConsumerProbe/BinaryConsumerProbe.swift" <<'EOF'
import SwiftPagerKit
import SwiftUI

public struct BinaryConsumerProbe: View {
    @State private var page = 0
    @State private var backgroundOpacity: CGFloat = 1
    @State private var continuousIndex: CGFloat = 0
    @StateObject private var pager = SwiftPagerController()
    @State private var sharedPool = SwiftPagerReusePool(limit: 5)

    public init() {}

    public var body: some View {
        VStack {
            SwiftPager(Array(0..<3), page: $page) { value in
                Text("\(value)")
            }
            .controller(pager)
            .bounces(false)
            .reusePool(sharedPool)
            .cachePolicy(.balanced)
            .reusePoolLimit(4)
            .contentRefreshToken(page)
            .restorationPolicy(.preserve)
            .zoomable(minScale: 1, maxScale: 4, doubleTapAction: .zoom(toFraction: 0.5))
            .onTap {}
            .onDoubleTap {}
            .onDragStart {}
            .onZoomChange { value, scale in
                _ = value
                _ = scale
            }
            .onLoadMore(when: .nearEnd(offsetFromEnd: 1)) {}
            .onOverscroll { position in
                _ = position
            }
            .continuousPageIndex($continuousIndex)
            .onContinuousPageChange { position in
                _ = position
            }
            .onContinuousPageChange(coalesced: false) { position in
                _ = position
            }
            .onPageChange { page in
                _ = page
            }
            .onPageWillAttach { index in
                _ = index
            }
            .onPageDidDetach { index in
                _ = index
            }
            .onStateChange { state in
                _ = state.currentPage
                _ = state.targetPage
                _ = state.direction
                _ = state.scrollPhase
                _ = state.visibleFraction
                _ = state.pageSize
                _ = state.loadedPages.first?.id
            }
            .onScrollPhaseChange { phase in
                switch phase {
                case .idle, .dragging, .decelerating, .animating:
                    break
                @unknown default:
                    break
                }
            }

            SwiftPager(Array(0..<3), page: $page) { value in
                Text("\(value)")
            }
            .pageSpacing(2)
            .zoomable(configurationFor: { value in
                value == 0 ? .disabled : .enabled(minimumScale: 1, maximumScale: 4, doubleTapAction: .zoom(toFraction: 0.5))
            })
            .onPullToDismiss(backgroundOpacity: $backgroundOpacity) {}
            .onTap {}
            .onDoubleTap {}
            .onDragStart {}
            .onZoomChange { value, scale in
                _ = value
                _ = scale
            }
            .onLoadMore(when: .nearEnd(offsetFromEnd: 1)) {}
            .onOverscroll { position in
                _ = position
            }
            .continuousPageIndex($continuousIndex)
            .configureSettings { config in
                config.bounces = false
                config.coalescesContinuousPageChanges = false
                config.dismissVelocity = 1.3
                config.onPageWillAttach = { _ in }
                config.onPageDidDetach = { _ in }
            }
            .background(PagerClearBackground())
        }
        .onAppear {
            _ = SwiftPagerLoadMoreTrigger.nearEnd(offsetFromEnd: 0)
            _ = SwiftPagerDoubleTapAction.disabled
            _ = SwiftPagerDoubleTapAction.zoom(toFraction: 0.5)
            _ = SwiftPagerDirection.horizontal
            _ = SwiftPagerBoundary.beginning
            _ = SwiftPagerBoundary.end
            _ = SwiftPagerZoomConfiguration.disabled
            _ = SwiftPagerZoomConfiguration.enabled(minimumScale: 1, maximumScale: 2, doubleTapAction: .disabled)
            let pagerView = SwiftPager(Array(0..<3)) { value in
                Text("\(value)")
            }
            acceptsUIViewControllerRepresentable(pagerView)
            _ = SwiftPagerCachePolicy.minimal
            _ = SwiftPagerCachePolicy.balanced
            _ = SwiftPagerCachePolicy.performance
            _ = SwiftPagerCachePolicy(preloadDistance: 1, retentionDistance: 2, reusePoolLimit: 3)
            _ = SwiftPagerLimits.maximumReusePoolLimit
            _ = SwiftPagerContentUpdatePolicy.refreshToken
            _ = SwiftPagerReusePool(limit: 3)
            sharedPool.limit = 5
            sharedPool.removeAll()
            _ = SwiftPagerStateRestorationPolicy.preserve
            _ = SwiftPagerStateRestorationPolicy.reset
            pager.scrollToPage(1, animated: false)
            pager.scrollToPage(id: 2, animated: false)
            pager.scrollToNextPage(animated: false)
            pager.scrollToPreviousPage(animated: false)
            _ = pager.indexOfPage(id: 2)
        }
    }
}

private func acceptsUIViewControllerRepresentable<R: UIViewControllerRepresentable>(_ representable: R) {}
EOF

log "building binary consumer against local artifact"
(
    cd "$CONSUMER_DIR"
    xcodebuild \
        -quiet \
        -scheme BinaryConsumer \
        -configuration Release \
        -destination 'generic/platform=iOS Simulator' \
        -derivedDataPath "$BUILD_DIR/binary-consumer-derived-data" \
        CODE_SIGNING_ALLOWED=NO \
        build
)

if [[ "$REQUIRE_REMOTE_BINARY_MANIFEST" == "1" ]]; then
    log "checking remote binary artifact URL"
    curl --fail --silent --show-error --location --head "$remote_url" >/dev/null

    log "building clean binary consumer against remote artifact"
    mkdir -p "$REMOTE_CONSUMER_DIR/Sources/SwiftPagerKit" "$REMOTE_CONSUMER_DIR/Sources/BinaryConsumerProbe"
    cp "$CONSUMER_DIR/Sources/SwiftPagerKit/SwiftPagerKit.swift" "$REMOTE_CONSUMER_DIR/Sources/SwiftPagerKit/SwiftPagerKit.swift"
    cp "$CONSUMER_DIR/Sources/BinaryConsumerProbe/BinaryConsumerProbe.swift" "$REMOTE_CONSUMER_DIR/Sources/BinaryConsumerProbe/BinaryConsumerProbe.swift"

    cat > "$REMOTE_CONSUMER_DIR/Package.swift" <<EOF
// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "RemoteBinaryConsumer",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(name: "BinaryConsumerProbe", targets: ["BinaryConsumerProbe"])
    ],
    targets: [
        .target(
            name: "SwiftPagerKit",
            dependencies: ["SwiftPagerKitCore"]
        ),
        .binaryTarget(
            name: "SwiftPagerKitCore",
            url: "$remote_url",
            checksum: "$remote_checksum"
        ),
        .target(
            name: "BinaryConsumerProbe",
            dependencies: ["SwiftPagerKit"]
        )
    ]
)
EOF

    (
        cd "$REMOTE_CONSUMER_DIR"
        xcodebuild \
            -quiet \
            -scheme RemoteBinaryConsumer \
            -configuration Release \
            -destination 'generic/platform=iOS Simulator' \
            -derivedDataPath "$BUILD_DIR/remote-binary-consumer-derived-data" \
            CODE_SIGNING_ALLOWED=NO \
            build
    )
fi

log "binary validation complete"
