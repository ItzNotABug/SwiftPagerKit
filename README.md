# SwiftPagerKit

[![Swift](https://img.shields.io/badge/Swift-6.0-orange?style=flat)](https://swift.org)
[![iOS](https://img.shields.io/badge/iOS-15%2B-blue?style=flat)](https://developer.apple.com/ios/)
[![SwiftPM](https://img.shields.io/badge/SwiftPM-supported-brightgreen?style=flat)](https://www.swift.org/package-manager/)
[![License](https://img.shields.io/badge/license-Apache--2.0-green?style=flat)](LICENSE)
[![Binary](https://img.shields.io/badge/XCFramework-ready-informational?style=flat)](Package.binary.swift)
![Status](https://img.shields.io/badge/status-public--preview-yellow?style=flat)
![Improved with Codex](https://img.shields.io/badge/Improved%20with-Codex-2F80ED?style=flat)

`SwiftPagerKit` is a performance-focused SwiftUI pager backed by a UIKit frame-based paging core. It targets paging screens that need stable IDs, bounded view reuse, programmatic page control, rich pager gestures, and SwiftPM binary distribution.

## Why SwiftPagerKit

- SwiftUI-first API with a UIKit paging engine underneath.
- Stable ID lookup for insertions, removals, reorders, and scroll-by-ID.
- Bounded host reuse with reuse types, retention caching, and shared pools.
- Zoom, tap, drag, pull-to-dismiss, overscroll, and load-more hooks.
- Source and XCFramework-based SwiftPM distribution paths.

## Install

Add the package:

```swift
.package(url: "https://github.com/ItzNotABug/SwiftPagerKit.git", from: "0.1.0")
```

Then add `SwiftPagerKit` to your app target dependencies.

Use `import SwiftPagerKit` in application code. `SwiftPagerKitCore` is an implementation target used by the source and binary manifests, not a supported import surface.

For local development:

```swift
.package(path: "SwiftPagerKit")
```

For binary validation, build the local XCFramework and use `Package.binary.swift` as the manifest source in a copied test package:

```sh
scripts/build/xcframework.sh
```

The default XCFramework zip omits dSYMs to keep the SwiftPM artifact small and free of debug-path metadata. Set `SWIFTPAGERKIT_INCLUDE_DEBUG_SYMBOLS=1` when you want a local symbol build.

## Basic Use

```swift
import SwiftPagerKit

SwiftPager(items, id: \.id, page: $page) { item in
    PageView(item: item)
}
```

IDs must be stable and unique within the current data set. They drive ID lookup, identity-preserving updates, SwiftUI state isolation, and cached host reuse. For non-`Identifiable` elements, `SwiftPager(data)` uses collection offsets as IDs, so prefer `SwiftPager(data, id: ...)` for collections that can insert, delete, or reorder items.

## Pager Features

```swift
SwiftPager(items, id: \.id, page: $page) { item in
    MediaView(item: item)
}
.zoomable(minScale: 1, maxScale: 4, doubleTapAction: .zoom(toFraction: 0.5))
.onZoomChange { item, scale in
    print(item.id, scale)
}
.onTap {}
.onDoubleTap {}
.onDragStart {}
.onLoadMore(when: .nearEnd(offsetFromEnd: 3)) {}
.onOverscroll { position in
    print(position)
}
.continuousPageIndex($continuousIndex)
.pagerAccessibilityLabel("Gallery")
.pagerAccessibilityValue { state in
    "Slide \(state.currentPage + 1) of \(state.pageCount)"
}
.onPullToDismiss(backgroundOpacity: $backgroundOpacity) {
    dismiss()
}
```

`zoom(toFraction:)` is clamped to `0...1` between the configured minimum and maximum scale.
Use `.zoomable(configurationFor:)` instead when zoom should vary by item.

Advanced SwiftPager settings are exposed through `.configureSettings { }`, including `preloadDistance`, dismiss thresholds, fade distance, pinch offset, overscroll threshold, and accessibility text. Pull-to-dismiss uses the cross-axis gesture: vertical pull in horizontal pagers and horizontal pull in vertical pagers. Cache distances are capped by `SwiftPagerLimits.maximumCacheDistance`; reuse pools are capped by `SwiftPagerLimits.maximumReusePoolLimit`. `PagerClearBackground` is included for full-screen cover use.

## Control

```swift
@StateObject private var pager = SwiftPagerController()

SwiftPager(items, id: \.id, page: $page) { item in
    PageView(item: item)
}
.controller(pager)

pager.scrollToPage(10)
pager.scrollToPage(10, animated: false)
pager.scrollToPage(id: item.id)
pager.scrollToPage(id: item.id, animated: false)
pager.scrollToNextPage()
pager.scrollToPreviousPage()
pager.indexOfPage(id: item.id)
```

## Tuning

```swift
SwiftPager(items, id: \.id, reuseType: \.kind, page: $page) { item in
    PageView(item: item)
}
.cachePolicy(.balanced)
.preloadDistance(1)
.retentionDistance(2)
.restorationPolicy(.preserve)
.contentRefreshToken(contentRefreshToken)
```

Cache presets:

| Policy         | Preload | Retention | Reuse Pool |
|----------------|--------:|----------:|-----------:|
| `.minimal`     |       0 |         0 |          0 |
| `.balanced`    |       1 |         2 |          5 |
| `.performance` |       2 |         4 |         10 |

The runtime always keeps the visible page plus one adjacent page live for gesture continuity. `.minimal` disables extra preload, retention caching, and reuse pooling, but it does not shrink the live gesture window below that adjacent page.

`preloadDistance` and `retentionDistance` are measured in pages away from the current page. For page `10`, a distance of `1` covers pages `9...11`; a distance of `2` covers pages `8...12`.

By default, SwiftPagerKit preserves attached SwiftUI roots when the page ID is unchanged. If page content depends on external state captured by the page builder, change `.contentRefreshToken(token)` when loaded page content should rebuild. This refreshes the attached pager window, not every item in the collection. Use `.contentUpdatePolicy(.always)` only for pages that must rebuild on every pager update.

Restoration policies control initial empty or unavailable data. The default `.preserve` keeps the requested page through empty data and restores it when pages become available. `.reset` starts from page zero instead.

Use a shared pool when compatible pager instances should reuse hosts:

```swift
@State private var pool = SwiftPagerReusePool(limit: 8)

SwiftPager(items, id: \.id, page: $page) { item in
    PageView(item: item)
}
.reusePool(pool)
```

When `.reusePool(pool)` is set, the pool object owns the reuse limit through `SwiftPagerReusePool(limit:)` or `pool.limit`. Per-pager `cachePolicy` and `reusePoolLimit` still affect local pools, but they do not resize an explicitly shared pool.

A shared pool intentionally retains hosting controllers that already entered reuse so compatible pagers can use them later. Tearing down a pager still discards its currently active and retained pages. Call `pool.removeAll()` or release the pool when cached reusable SwiftUI subtrees should be discarded; an attached pager may also clear the pool during a system memory warning.

## State

```swift
SwiftPager(items, id: \.id, page: $page) { item in
    PageView(item: item)
}
.onPageChange { page in
    print(page)
}
.onStateChange { state in
    print(state.currentPage, state.scrollPhase)
}
.onContinuousPageChange { position in
    print(position)
}
.onScrollPhaseChange { phase in
    print(phase)
}
```

`SwiftPagerState` includes `currentPage`, `pageCount`, `loadedRange`, `loadedPages`, `targetPage`, `direction`, `scrollPhase`, `visibleFraction`, and `pageSize`. `SwiftPagerController.state` and `.onStateChange` publish coarse changes; use `.onContinuousPageChange` or `.continuousPageIndex` for resolved page position and frame-level scroll progress.

## Internals

Internally, the pager computes a small desired page window, diffs it against attached hosts, and reuses or retains hosting controllers as pages move offscreen. ID lookup is bounded, page settling is velocity-aware, and optional shared pools let compatible pagers reuse warm hosts.

RTL locales use stable paging mechanics: page `0` is physically first, forward scrolling advances to the next page regardless of locale, and hosted content mirrors automatically. Do not add an extra layout-direction flip around the pager.

SwiftPagerKit uses a full-bounds viewport with `contentInsetAdjustmentBehavior = .never`. Safe-area padding belongs inside your page content. The pager preserves page position across bounds changes such as rotation; Dynamic Type changes affect hosted content layout, not the page size.

SwiftPagerKit is designed for `NavigationStack`, `sheet`, and `fullScreenCover` embedding. The library supports iOS 15 and newer; the demo app targets iOS 26 to exercise current SwiftUI visual APIs.

## FAQ

### Does SwiftPagerKit use UIKit?

Yes. The public API is SwiftUI, but the paging core is UIKit-backed for frame-level control, host reuse, and predictable gesture behavior.

### What does `preloadDistance` mean?

It is the number of pages to keep prepared on each side of the current page. It is similar in intent to ViewPager2's offscreen page limit.

### Can SwiftPagerKit ship as a binary SwiftPM package?

Yes. The repository includes local XCFramework build scripts, a local binary manifest, and a remote binary manifest template used by release tags.

## Validate

```sh
SIMULATOR_ID="$(scripts/test/simulator.sh)"
xcodebuild -scheme SwiftPagerKit -destination "id=$SIMULATOR_ID" -configuration Debug test
swift test
swift test -c release
scripts/test/binary.sh
scripts/test/demo.sh
```

Plain `swift test` / SwiftPM CLI tests are useful smoke checks, but the UIKit behavior tests must pass through the iOS simulator path above. The validation scripts pick the newest available iPhone simulator by default; set `SIMULATOR_ID=<simulator-udid>` to pin a specific device.

The demo app lives at:

```sh
Examples/SwiftPagerKitDemo/SwiftPagerKitDemo.xcworkspace
```

## License

`SwiftPagerKit` is released under the Apache License 2.0.
