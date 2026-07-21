# SwiftPagerKit

[![Swift](https://img.shields.io/badge/Swift-6.0-orange?style=flat)](https://swift.org)
[![iOS](https://img.shields.io/badge/iOS-15%2B-blue?style=flat)](https://developer.apple.com/ios/)
[![SwiftPM](https://img.shields.io/badge/SwiftPM-supported-brightgreen?style=flat)](https://www.swift.org/package-manager/)
[![License](https://img.shields.io/badge/license-Apache--2.0-green?style=flat)](LICENSE.md)
[![Binary](https://img.shields.io/badge/XCFramework-ready-informational?style=flat)](Package.binary.swift)
![Improved with Codex](https://img.shields.io/badge/Improved%20with-Codex-2F80ED?style=flat)

`SwiftPagerKit` is a SwiftUI pager backed by a UIKit paging engine. It is designed for media-heavy screens that need stable identity, bounded reuse, programmatic control, zoom, and interactive dismissal.

## Contents

- [Install](#install)
- [Quick Start](#quick-start)
- [API Surface](#api-surface)
- [Performance](#performance)
- [Demo](#demo)
- [Validate](#validate)
- [FAQ](#faq)
- [License](#license)

## Install

```swift
.package(url: "https://github.com/ItzNotABug/SwiftPagerKit.git", from: "0.1.2")
```

Add `SwiftPagerKit` to your app target and import the public module:

```swift
import SwiftPagerKit
```

Tagged releases use the XCFramework-backed manifest. Branch and path dependencies build from source.

## Quick Start

```swift
@State private var page = 0
@StateObject private var pager = SwiftPagerController()

SwiftPager(items, id: \.id, page: $page) { item in
    PhotoPage(item: item)
}
.controller(pager)
.cachePolicy(.balanced)
.zoomable(minScale: 1, maxScale: 4)
.onPageChange { page in
    print("Current page:", page)
}
```

Use stable, unique IDs. IDs drive scroll-by-ID, identity preservation, SwiftUI state isolation, and host reuse.

## API Surface

```swift
pager.scrollToPage(10)
pager.scrollToPage(10, animated: false)
pager.scrollToPage(id: item.id)
pager.scrollToNextPage()
pager.scrollToPreviousPage()
pager.indexOfPage(id: item.id)
```

```swift
SwiftPager(items, id: \.id, reuseType: \.kind, page: $page) { item in
    MediaPage(item)
}
.direction(.horizontal)
.pageSpacing(12)
.bounces(false)
.preloadDistance(1)
.retentionDistance(2)
.contentRefreshToken(version)
.onTap {
    hideChrome.toggle()
}
.onDoubleTap {
    resetZoom()
}
.onDragStart {
    isDragging = true
}
.onLoadMore(when: .nearEnd(offsetFromEnd: 3)) {
    loadMore()
}
.onPullToDismiss(backgroundOpacity: $opacity) {
    dismiss()
}
.onOverscroll { position in
    print(position)
}
.onStateChange { state in
    print(state.scrollPhase)
}
.onContinuousPageChange(coalesced: false) { position in
    print(position)
}
.continuousPageIndex($position)
.onPageWillAttach { index in
    print("Attach", index)
}
.onPageDidDetach { index in
    print("Detach", index)
}
.pagerAccessibilityLabel("Gallery")
```

Use `.contentRefreshToken(_:)` when a visible page should rebuild even though its ID stayed the same.

## Performance

| Policy         | Best for      | Preload | Retention | Pool |
|----------------|---------------|--------:|----------:|-----:|
| `.minimal`     | lowest memory |       0 |         0 |    0 |
| `.balanced`    | general use   |       1 |         2 |    5 |
| `.performance` | heavier media |       2 |         4 |   10 |

`preloadDistance` and `retentionDistance` are page counts around the current page. For page `10`, distance `1` covers `9...11`; distance `2` covers `8...12`.

The visible page plus one adjacent page stay live for gesture continuity, even with `.minimal`.

```swift
@State private var pool = SwiftPagerReusePool(limit: 8)

SwiftPager(items, id: \.id, page: $page) { item in
    PageView(item)
}
.reusePool(pool)
```

Shared pools keep reusable hosts warm across compatible pagers. Call `pool.removeAll()` or release the pool to discard cached SwiftUI subtrees.

## Demo

```sh
open Examples/SwiftPagerKitDemo/SwiftPagerKitDemo.xcworkspace
```

The demo includes a bundled image gallery, a fullscreen image pager, and a vertical reels-style pager.

## Validate

```sh
swift test
swift test -c release
scripts/test/binary.sh
```

`swift test` is a fast smoke check. UIKit behavior coverage runs through the simulator-backed scripts.
Run `scripts/test/demo.sh` when changing the sample app.

## FAQ

<details>
<summary>What is the layout contract?</summary>

SwiftPagerKit uses a full-bounds viewport with `contentInsetAdjustmentBehavior = .never`. Put safe-area padding inside page content.

</details>

<details>
<summary>How does RTL work?</summary>

Page `0` is physically first, forward scrolling advances to the next page, and hosted content mirrors automatically in RTL locales.

</details>

<details>
<summary>Which restoration policy should I use?</summary>

Use `.preserve` when page identity matters across empty/loading states. Use `.reset` when new data should start from page zero.

</details>

## License

Apache License 2.0. See [LICENSE.md](LICENSE.md).
