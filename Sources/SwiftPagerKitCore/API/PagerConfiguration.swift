import CoreGraphics

/// The axis SwiftPagerKit uses for page-to-page scrolling.
@frozen
public enum SwiftPagerDirection: Sendable, Equatable {
    /// Pages are laid out left to right and scroll horizontally.
    case horizontal
    /// Pages are laid out top to bottom and scroll vertically.
    case vertical
}

/// Controls when an attached page's SwiftUI root view is rebuilt.
public enum SwiftPagerContentUpdatePolicy: Sendable, Equatable {
    /// Rebuild the hosted SwiftUI root whenever the pager updates the host.
    case always
    /// Preserve the hosted SwiftUI root while the page ID is unchanged.
    case identity
    /// Rebuild when `SwiftPager.contentRefreshToken(_:)` changes.
    case refreshToken
}

struct SwiftPagerContentRefreshToken: @unchecked Sendable, Equatable {
    private let value: AnyHashable

    init<Token: Hashable & Sendable>(_ value: Token) {
        self.value = AnyHashable(value)
    }
}

/// Controls how the pager resolves page state across empty and reloaded data.
public enum SwiftPagerStateRestorationPolicy: Sendable, Equatable {
    /// Preserve the requested page through empty data and restore it when pages become available.
    case preserve
    /// Reset initial empty or unavailable page state to page zero.
    case reset
}

/// Hard safety caps for cache and reuse settings.
@frozen
public enum SwiftPagerLimits: Sendable {
    /// Maximum accepted preload or retention distance, measured in pages.
    public static let maximumCacheDistance = 32
    /// Maximum accepted reusable host count.
    public static let maximumReusePoolLimit = 256
}

/// A grouped cache budget for live, retained, and reusable pages.
public struct SwiftPagerCachePolicy: Sendable, Equatable {
    /// Additional pages to keep attached around the current page.
    ///
    /// The engine may keep one adjacent page live even when this is zero so
    /// bidirectional gestures stay continuous.
    public private(set) var preloadDistance: Int
    /// Pages to retain offscreen before they enter the reuse pool.
    public private(set) var retentionDistance: Int
    /// Reusable hosts to keep after pages leave retention.
    public private(set) var reusePoolLimit: Int

    /// Creates a cache policy with clamped, internally consistent values.
    public init(preloadDistance: Int, retentionDistance: Int, reusePoolLimit: Int) {
        let clampedPreloadDistance = Self.clampCacheDistance(preloadDistance)
        self.preloadDistance = clampedPreloadDistance
        self.retentionDistance = max(clampedPreloadDistance, Self.clampCacheDistance(retentionDistance))
        self.reusePoolLimit = Self.clampReusePoolLimit(reusePoolLimit)
    }

    /// Keeps only the visible page and the mandatory adjacent gesture page live.
    public static let minimal = SwiftPagerCachePolicy(
        preloadDistance: 0,
        retentionDistance: 0,
        reusePoolLimit: 0
    )

    /// Balanced defaults for most pagers.
    public static let balanced = SwiftPagerCachePolicy(
        preloadDistance: 1,
        retentionDistance: 2,
        reusePoolLimit: 5
    )

    /// A larger cache budget for heavy page transitions.
    public static let performance = SwiftPagerCachePolicy(
        preloadDistance: 2,
        retentionDistance: 4,
        reusePoolLimit: 10
    )

    static func clampCacheDistance(_ distance: Int) -> Int {
        min(max(0, distance), SwiftPagerLimits.maximumCacheDistance)
    }

    static func clampReusePoolLimit(_ limit: Int) -> Int {
        min(max(0, limit), SwiftPagerLimits.maximumReusePoolLimit)
    }
}

/// Runtime configuration for the pager engine.
struct SwiftPagerConfiguration: Sendable, Equatable {
    /// The page scroll axis.
    var direction: SwiftPagerDirection
    /// Space in points between neighboring pages.
    var pageSpacing: CGFloat {
        didSet {
            pageSpacing = max(0, pageSpacing)
        }
    }
    /// Extra pages kept attached around the current page.
    ///
    /// The runtime always keeps the visible page plus one adjacent page live for
    /// gesture continuity, even when this value is zero.
    var preloadDistance: Int {
        didSet {
            preloadDistance = SwiftPagerCachePolicy.clampCacheDistance(preloadDistance)
            retentionDistance = max(retentionDistance, preloadDistance)
        }
    }
    /// Offscreen pages kept alive before entering the reuse pool.
    var retentionDistance: Int {
        didSet {
            retentionDistance = max(preloadDistance, SwiftPagerCachePolicy.clampCacheDistance(retentionDistance))
        }
    }
    /// Maximum hosts kept in the local reuse pool.
    var reusePoolLimit: Int {
        didSet {
            reusePoolLimit = SwiftPagerCachePolicy.clampReusePoolLimit(reusePoolLimit)
        }
    }
    /// Policy used when rebinding an already-attached page host.
    var contentUpdatePolicy: SwiftPagerContentUpdatePolicy
    /// Token value used when `contentUpdatePolicy` is `.refreshToken`.
    var contentRefreshToken: SwiftPagerContentRefreshToken?
    /// Initial and empty-data restoration behavior.
    var stateRestorationPolicy: SwiftPagerStateRestorationPolicy

    /// Creates a pager configuration from individual cache values.
    init(
        direction: SwiftPagerDirection = .horizontal,
        pageSpacing: CGFloat = 0,
        preloadDistance: Int = 1,
        retentionDistance: Int = 2,
        reusePoolLimit: Int = 5,
        contentUpdatePolicy: SwiftPagerContentUpdatePolicy = .identity,
        contentRefreshToken: SwiftPagerContentRefreshToken? = nil,
        stateRestorationPolicy: SwiftPagerStateRestorationPolicy = .preserve
    ) {
        self.direction = direction
        let clampedPreloadDistance = SwiftPagerCachePolicy.clampCacheDistance(preloadDistance)
        self.pageSpacing = max(0, pageSpacing)
        self.preloadDistance = clampedPreloadDistance
        self.retentionDistance = max(clampedPreloadDistance, SwiftPagerCachePolicy.clampCacheDistance(retentionDistance))
        self.reusePoolLimit = SwiftPagerCachePolicy.clampReusePoolLimit(reusePoolLimit)
        self.contentUpdatePolicy = contentUpdatePolicy
        self.contentRefreshToken = contentRefreshToken
        self.stateRestorationPolicy = stateRestorationPolicy
    }

    /// Creates a pager configuration from a cache policy.
    init(
        direction: SwiftPagerDirection = .horizontal,
        pageSpacing: CGFloat = 0,
        cachePolicy: SwiftPagerCachePolicy,
        contentUpdatePolicy: SwiftPagerContentUpdatePolicy = .identity,
        contentRefreshToken: SwiftPagerContentRefreshToken? = nil,
        stateRestorationPolicy: SwiftPagerStateRestorationPolicy = .preserve
    ) {
        self.init(
            direction: direction,
            pageSpacing: pageSpacing,
            preloadDistance: cachePolicy.preloadDistance,
            retentionDistance: cachePolicy.retentionDistance,
            reusePoolLimit: cachePolicy.reusePoolLimit,
            contentUpdatePolicy: contentUpdatePolicy,
            contentRefreshToken: contentRefreshToken,
            stateRestorationPolicy: stateRestorationPolicy
        )
    }
}
