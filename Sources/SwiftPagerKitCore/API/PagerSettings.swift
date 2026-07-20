#if canImport(UIKit)
import CoreGraphics
import SwiftUI

/// When the pager should call an `onLoadMore` handler.
public enum SwiftPagerLoadMoreTrigger: Sendable, Equatable {
    /// Trigger when the current page reaches `offsetFromEnd` pages from the end.
    case nearEnd(offsetFromEnd: Int = 3)
}

/// Convenience load-more triggers.
public extension SwiftPagerLoadMoreTrigger {
    /// Trigger when the last page becomes current.
    static var lastPage: Self {
        .nearEnd(offsetFromEnd: 0)
    }
}

/// Action performed by the built-in double-tap zoom gesture.
public enum SwiftPagerDoubleTapAction: Sendable, Equatable {
    /// Do not perform zoom on double tap.
    case disabled
    /// Toggle to a clamped fraction between minimum and maximum zoom.
    case zoom(toFraction: CGFloat)
}

/// Boundary reached by an overscroll gesture.
@frozen
public enum SwiftPagerBoundary: Sendable, Equatable {
    /// The user overscrolled before the first page.
    case beginning
    /// The user overscrolled after the last page.
    case end
}

/// Per-page zoom configuration.
public enum SwiftPagerZoomConfiguration: Sendable, Equatable {
    /// Disable pinch and double-tap zoom for the page.
    case disabled
    /// Enable zoom with a minimum scale, maximum scale, and optional double-tap action.
    case enabled(minimumScale: CGFloat = 1, maximumScale: CGFloat, doubleTapAction: SwiftPagerDoubleTapAction = .zoom(toFraction: 0.5))
}

/// Advanced pager settings used by `SwiftPager.configureSettings`.
///
/// Most apps should prefer the typed modifiers on `SwiftPager`. Use this type
/// when you need lower-level gesture thresholds or per-element zoom rules.
public struct SwiftPagerSettings<Element> {
    /// Optional binding updated while pull-to-dismiss changes backdrop opacity.
    public var dismissBackgroundOpacity: Binding<CGFloat>?
    /// Called after a pull-to-dismiss gesture passes its threshold.
    public var onDismiss: (() -> Void)?
    /// Called when the current page is tapped once.
    public var onTap: (() -> Void)?
    /// Called when the current page is tapped twice.
    public var onDoubleTap: (() -> Void)?
    /// Called when a page drag begins.
    public var onDragStart: (() -> Void)?
    /// Threshold used by `onLoadMore`.
    public var loadMoreTrigger: SwiftPagerLoadMoreTrigger
    /// Called once for each data count when the load-more threshold is reached.
    public var onLoadMore: (() -> Void)?
    /// Page scroll axis.
    public var direction: SwiftPagerDirection
    /// Whether the outer paging scroll view may rubber-band at the data boundaries.
    public var bounces: Bool
    /// Called when the user overscrolls beyond either data boundary.
    public var onOverscroll: ((SwiftPagerBoundary) -> Void)?
    /// Optional binding updated with the continuous fractional page index.
    public var continuousPageIndex: Binding<CGFloat>?
    /// Called with the continuous fractional page index after apply and during scrolling.
    ///
    /// Prefer this over `continuousPageIndex` when the value is used for local
    /// drawing or logging and does not need to drive SwiftUI state.
    public var onContinuousPageChange: ((CGFloat) -> Void)?
    /// Whether continuous page-change callbacks are coalesced onto the next main-queue turn.
    public var coalescesContinuousPageChanges: Bool
    /// Called before a page host view is added; may be deferred until after SwiftUI updates.
    public var onPageWillAttach: ((Int) -> Void)?
    /// Called after a page host view is removed; may be deferred until after SwiftUI updates.
    public var onPageDidDetach: ((Int) -> Void)?
    /// Per-element zoom configuration.
    public var zoomConfiguration: (Element) -> SwiftPagerZoomConfiguration
    /// Called whenever a zoomable page reports a zoom-scale change.
    public var onZoomChange: ((Element, CGFloat) -> Void)?
    /// Accessibility label used for the adjustable pager control.
    public var accessibilityLabel: String
    /// Accessibility value formatter used for the adjustable pager control and page-change announcements.
    public var accessibilityValue: (SwiftPagerState) -> String
    /// Space in points between neighboring pages.
    public var pageSpacing: CGFloat
    /// Extra attached pages around the current page.
    ///
    /// A value of zero disables extra preload, but the runtime may still keep
    /// one adjacent page attached for gesture continuity.
    public var preloadDistance: Int {
        didSet {
            preloadDistance = SwiftPagerCachePolicy.clampCacheDistance(preloadDistance)
        }
    }
    /// Minimum pull-to-dismiss velocity, in scroll-view velocity units.
    public var dismissVelocity: CGFloat
    /// Pull-to-dismiss distance as a fraction of the dismiss axis size.
    public var dismissTriggerOffset: CGFloat
    /// Pull-to-dismiss completion animation duration in seconds.
    public var dismissAnimationDuration: CGFloat
    /// Whether the dismiss callback runs inside a transaction with animations disabled.
    public var disablesSwiftUIAnimationsOnDismiss: Bool
    /// Fade distance as a fraction of the dismiss axis size.
    public var dismissFadeDistanceRatio: CGFloat
    /// Cross-axis content offset in points after which pinch is temporarily disabled.
    public var pinchGestureActivationOffset: Double
    /// Overscroll threshold as a fraction of one page.
    public var overscrollThreshold: Double

    /// Creates advanced settings with conservative defaults.
    public init(direction: SwiftPagerDirection = .horizontal, pageSpacing: CGFloat = 0, preloadDistance: Int = 1) {
        self.dismissBackgroundOpacity = nil
        self.onDismiss = nil
        self.onTap = nil
        self.onDoubleTap = nil
        self.onDragStart = nil
        self.loadMoreTrigger = .nearEnd(offsetFromEnd: 3)
        self.onLoadMore = nil
        self.direction = direction
        self.bounces = true
        self.onOverscroll = nil
        self.continuousPageIndex = nil
        self.onContinuousPageChange = nil
        self.coalescesContinuousPageChanges = true
        self.onPageWillAttach = nil
        self.onPageDidDetach = nil
        self.zoomConfiguration = { _ in .disabled }
        self.onZoomChange = nil
        self.accessibilityLabel = "Pager"
        self.accessibilityValue = { state in
            guard state.pageCount > 0 else { return "No pages" }
            return "Page \(state.currentPage + 1) of \(state.pageCount)"
        }
        self.pageSpacing = max(0, pageSpacing)
        self.preloadDistance = SwiftPagerCachePolicy.clampCacheDistance(preloadDistance)
        self.dismissVelocity = 1.3
        self.dismissTriggerOffset = 0.1
        self.dismissAnimationDuration = 0.2
        self.disablesSwiftUIAnimationsOnDismiss = true
        self.dismissFadeDistanceRatio = 0.2
        self.pinchGestureActivationOffset = 10
        self.overscrollThreshold = 0.15
    }
}

extension SwiftPagerSettings {
    var hasGestureCallbacks: Bool {
        onDismiss != nil ||
            onTap != nil ||
            onDoubleTap != nil ||
            onDragStart != nil
    }

    func requiresPageContainer(for element: Element) -> Bool {
        if hasGestureCallbacks {
            return true
        }

        switch zoomConfiguration(element) {
        case .disabled:
            return false
        case .enabled:
            return true
        }
    }

    func normalized() -> SwiftPagerSettings<Element> {
        var copy = self
        copy.pageSpacing = max(0, pageSpacing)
        copy.preloadDistance = SwiftPagerCachePolicy.clampCacheDistance(preloadDistance)
        copy.dismissVelocity = max(0, dismissVelocity)
        copy.dismissTriggerOffset = min(max(0, dismissTriggerOffset), 1)
        copy.dismissAnimationDuration = max(0, dismissAnimationDuration)
        copy.dismissFadeDistanceRatio = max(0.001, dismissFadeDistanceRatio)
        copy.pinchGestureActivationOffset = max(0, pinchGestureActivationOffset)
        copy.overscrollThreshold = min(max(0, overscrollThreshold), 1)
        return copy
    }
}
#endif
