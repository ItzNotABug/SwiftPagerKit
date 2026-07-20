#if canImport(UIKit)
import SwiftUI
import UIKit

/// A SwiftUI pager backed by a UIKit paging engine.
///
/// `SwiftPager` keeps a bounded window of hosted SwiftUI pages attached,
/// preserves identity through stable IDs, and exposes programmatic page control
/// through `SwiftPagerController`.
public struct SwiftPager<Element, DataCollection: RandomAccessCollection, Content: View>: UIViewControllerRepresentable where DataCollection.Element == Element {
    private let data: DataCollection
    private let idProvider: (Int, Element) -> AnyHashable
    private let reuseTypeProvider: (Int, Element) -> AnyHashable?
    private let content: (Element) -> Content
    private var providedPage: Binding<Int>?
    private var controller: SwiftPagerController?
    private var sharedReusePool: SwiftPagerReusePool?
    private var callbacks = PagerCallbacks()
    private var configuration: SwiftPagerConfiguration
    private var settings: SwiftPagerSettings<Element>

    @State private var defaultPage: Int?
    @State private var idLookupCache = PagerIDLookupCache()

    private var page: Binding<Int> {
        providedPage ?? Binding(
            get: { defaultPage ?? controller?.currentPage ?? 0 },
            set: { defaultPage = $0 }
        )
    }

    /// Creates a pager that identifies pages by collection offset.
    ///
    /// Prefer an ID-based initializer when the collection can insert, remove,
    /// or reorder elements. Pass `page` to bind the current page index; when
    /// `page` is nil the pager keeps internal page state.
    public init(
        _ data: DataCollection,
        page: Binding<Int>? = nil,
        direction: SwiftPagerDirection = .horizontal,
        @ViewBuilder content: @escaping (Element) -> Content
    ) {
        self.data = data
        self.idProvider = { index, _ in AnyHashable(index) }
        self.reuseTypeProvider = { _, _ in nil }
        self.content = content
        self.providedPage = page
        self.controller = nil
        self.sharedReusePool = nil
        self.configuration = SwiftPagerConfiguration(direction: direction)
        self.settings = SwiftPagerSettings(direction: direction, preloadDistance: self.configuration.preloadDistance)
    }

    /// Creates a pager that identifies pages with a stable element key path.
    ///
    /// Pass `page` to bind the current page index; when `page` is nil the
    /// pager keeps internal page state.
    public init<ID: Hashable>(
        _ data: DataCollection,
        id: KeyPath<Element, ID>,
        page: Binding<Int>? = nil,
        direction: SwiftPagerDirection = .horizontal,
        @ViewBuilder content: @escaping (Element) -> Content
    ) {
        self.data = data
        self.idProvider = { _, element in AnyHashable(element[keyPath: id]) }
        self.reuseTypeProvider = { _, _ in nil }
        self.content = content
        self.providedPage = page
        self.controller = nil
        self.sharedReusePool = nil
        self.configuration = SwiftPagerConfiguration(direction: direction)
        self.settings = SwiftPagerSettings(direction: direction, preloadDistance: self.configuration.preloadDistance)
    }

    /// Creates a pager with stable IDs and a reuse-type key path.
    ///
    /// Use `reuseType` when only some pages can safely reuse the same hosted
    /// view structure. Pass `page` to bind the current page index; when `page`
    /// is nil the pager keeps internal page state.
    public init<ID: Hashable, ReuseType: Hashable>(
        _ data: DataCollection,
        id: KeyPath<Element, ID>,
        reuseType: KeyPath<Element, ReuseType>,
        page: Binding<Int>? = nil,
        direction: SwiftPagerDirection = .horizontal,
        @ViewBuilder content: @escaping (Element) -> Content
    ) {
        self.data = data
        self.idProvider = { _, element in AnyHashable(element[keyPath: id]) }
        self.reuseTypeProvider = { _, element in AnyHashable(element[keyPath: reuseType]) }
        self.content = content
        self.providedPage = page
        self.controller = nil
        self.sharedReusePool = nil
        self.configuration = SwiftPagerConfiguration(direction: direction)
        self.settings = SwiftPagerSettings(direction: direction, preloadDistance: self.configuration.preloadDistance)
    }

    /// Creates the UIKit pager controller used by SwiftUI.
    public func makeUIViewController(context: Context) -> UIViewController {
        let viewController = PagerViewController<Element, Content>()
        viewController.apply(
            dataSource: makeDataSource(),
            page: page,
            controller: controller,
            sharedReusePool: sharedReusePool,
            callbacks: callbacks,
            settings: settings,
            configuration: configuration,
            content: content,
            deferExternalUpdates: true
        )
        return viewController
    }

    /// Updates the UIKit pager controller after SwiftUI state changes.
    public func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        guard let pagerViewController = uiViewController as? PagerViewController<Element, Content> else {
            assertionFailure("SwiftPager received an unexpected UIKit controller type.")
            return
        }

        pagerViewController.apply(
            dataSource: makeDataSource(),
            page: page,
            controller: controller,
            sharedReusePool: sharedReusePool,
            callbacks: callbacks,
            settings: settings,
            configuration: configuration,
            content: content,
            animated: context.transaction.animation != nil,
            deferExternalUpdates: true
        )
    }

    /// Tears down hosted pages when SwiftUI removes the representable.
    public static func dismantleUIViewController(_ uiViewController: UIViewController, coordinator: ()) {
        (uiViewController as? PagerViewController<Element, Content>)?.teardown()
    }

    /// Sets spacing in points between neighboring pages.
    public func pageSpacing(_ spacing: CGFloat) -> Self {
        var copy = self
        copy.configuration.pageSpacing = max(0, spacing)
        copy.settings.pageSpacing = copy.configuration.pageSpacing
        return copy
    }

    /// Sets extra pages kept attached around the current page.
    ///
    /// A value of zero disables extra preload, but the runtime may still keep
    /// one adjacent page attached for gesture continuity.
    public func preloadDistance(_ distance: Int) -> Self {
        var copy = self
        copy.configuration.preloadDistance = SwiftPagerCachePolicy.clampCacheDistance(distance)
        copy.configuration.retentionDistance = max(copy.configuration.retentionDistance, copy.configuration.preloadDistance)
        copy.settings.preloadDistance = copy.configuration.preloadDistance
        return copy
    }

    /// Sets pages retained offscreen before reuse.
    public func retentionDistance(_ distance: Int) -> Self {
        var copy = self
        copy.configuration.retentionDistance = max(
            copy.configuration.preloadDistance,
            SwiftPagerCachePolicy.clampCacheDistance(distance)
        )
        return copy
    }

    /// Sets the local reusable host limit.
    public func reusePoolLimit(_ limit: Int) -> Self {
        var copy = self
        copy.configuration.reusePoolLimit = SwiftPagerCachePolicy.clampReusePoolLimit(limit)
        return copy
    }

    /// Applies a grouped cache policy.
    public func cachePolicy(_ policy: SwiftPagerCachePolicy) -> Self {
        var copy = self
        copy.configuration.preloadDistance = policy.preloadDistance
        copy.configuration.retentionDistance = policy.retentionDistance
        copy.configuration.reusePoolLimit = policy.reusePoolLimit
        copy.settings.preloadDistance = policy.preloadDistance
        return copy
    }

    /// Attaches a programmatic pager controller.
    public func controller(_ controller: SwiftPagerController?) -> Self {
        var copy = self
        copy.controller = controller
        return copy
    }

    /// Uses a shared reuse pool instead of the pager's local pool.
    public func reusePool(_ pool: SwiftPagerReusePool?) -> Self {
        var copy = self
        copy.sharedReusePool = pool
        return copy
    }

    /// Runs when the current page changes.
    public func onPageChange(_ action: @escaping (Int) -> Void) -> Self {
        var copy = self
        copy.callbacks.onPageChange = action
        return copy
    }

    /// Runs when the pager publishes a coarse state snapshot.
    ///
    /// This callback is not called for every sub-page scroll delta. Use
    /// `onContinuousPageChange(_:)` for frame-level progress work.
    public func onStateChange(_ action: @escaping (SwiftPagerState) -> Void) -> Self {
        var copy = self
        copy.callbacks.onPagerStateChange = action
        return copy
    }

    /// Runs when the scroll phase changes.
    public func onScrollPhaseChange(_ action: @escaping (SwiftPagerScrollPhase) -> Void) -> Self {
        var copy = self
        copy.callbacks.onScrollPhaseChange = action
        return copy
    }

    /// Sets the accessibility label for the adjustable pager control.
    public func pagerAccessibilityLabel(_ label: String) -> Self {
        var copy = self
        copy.settings.accessibilityLabel = label
        return copy
    }

    /// Sets the accessibility value formatter for the adjustable pager control.
    public func pagerAccessibilityValue(_ value: @escaping (SwiftPagerState) -> String) -> Self {
        var copy = self
        copy.settings.accessibilityValue = value
        return copy
    }

    /// Sets the hosted root update policy for unchanged stable IDs.
    public func contentUpdatePolicy(_ policy: SwiftPagerContentUpdatePolicy) -> Self {
        var copy = self
        copy.configuration.contentUpdatePolicy = policy
        return copy
    }

    /// Sets the initial and empty-data restoration policy.
    public func restorationPolicy(_ policy: SwiftPagerStateRestorationPolicy) -> Self {
        var copy = self
        copy.configuration.stateRestorationPolicy = policy
        return copy
    }

    /// Rebuilds loaded hosted pages when the token changes.
    public func contentRefreshToken<Token: Hashable & Sendable>(_ token: Token) -> Self {
        var copy = self
        copy.configuration.contentUpdatePolicy = .refreshToken
        copy.configuration.contentRefreshToken = SwiftPagerContentRefreshToken(token)
        return copy
    }

    /// Enables cross-axis pull-to-dismiss.
    ///
    /// Horizontal pagers dismiss with a vertical pull. Vertical pagers dismiss
    /// with a horizontal pull.
    public func onPullToDismiss(backgroundOpacity: Binding<CGFloat>? = nil, _ action: @escaping () -> Void) -> Self {
        var copy = self
        copy.settings.dismissBackgroundOpacity = backgroundOpacity
        copy.settings.onDismiss = action
        return copy
    }

    /// Runs when a page receives a single tap.
    public func onTap(_ action: @escaping () -> Void) -> Self {
        var copy = self
        copy.settings.onTap = action
        return copy
    }

    /// Runs when a page receives a double tap.
    public func onDoubleTap(_ action: @escaping () -> Void) -> Self {
        var copy = self
        copy.settings.onDoubleTap = action
        return copy
    }

    /// Runs when a page drag begins.
    public func onDragStart(_ action: @escaping () -> Void) -> Self {
        var copy = self
        copy.settings.onDragStart = action
        return copy
    }

    /// Runs when the current page reaches the load-more trigger.
    public func onLoadMore(
        when trigger: SwiftPagerLoadMoreTrigger = .nearEnd(offsetFromEnd: 3),
        _ action: @escaping () -> Void
    ) -> Self {
        var copy = self
        copy.settings.loadMoreTrigger = trigger
        copy.settings.onLoadMore = action
        return copy
    }

    /// Enables the same zoom configuration for every page.
    public func zoomable(
        minScale: CGFloat,
        maxScale: CGFloat,
        doubleTapAction: SwiftPagerDoubleTapAction = .zoom(toFraction: 0.5)
    ) -> Self {
        var copy = self
        copy.settings.zoomConfiguration = { _ in
            .enabled(minimumScale: minScale, maximumScale: maxScale, doubleTapAction: doubleTapAction)
        }
        return copy
    }

    /// Enables per-element zoom configuration.
    public func zoomable(configurationFor elementConfiguration: @escaping (Element) -> SwiftPagerZoomConfiguration) -> Self {
        var copy = self
        copy.settings.zoomConfiguration = elementConfiguration
        return copy
    }

    /// Mutates advanced settings directly.
    public func configureSettings(_ adjust: @escaping (inout SwiftPagerSettings<Element>) -> Void) -> Self {
        var copy = self
        adjust(&copy.settings)
        copy.settings = copy.settings.normalized()
        copy.configuration.direction = copy.settings.direction
        copy.configuration.pageSpacing = copy.settings.pageSpacing
        copy.configuration.preloadDistance = copy.settings.preloadDistance
        copy.configuration.retentionDistance = max(copy.configuration.retentionDistance, copy.configuration.preloadDistance)
        return copy
    }

    /// Runs when the user overscrolls beyond either end of the data set.
    public func onOverscroll(_ action: @escaping (SwiftPagerBoundary) -> Void) -> Self {
        var copy = self
        copy.settings.onOverscroll = action
        return copy
    }

    /// Binds the continuous fractional page index.
    public func continuousPageIndex(_ index: Binding<CGFloat>? = nil) -> Self {
        var copy = self
        copy.settings.continuousPageIndex = index
        return copy
    }

    /// Runs with the continuous fractional page index after apply and during scrolling.
    ///
    /// This callback does not write SwiftUI state by itself. Use it for lightweight
    /// progress work that should avoid the extra invalidation cost of a binding.
    public func onContinuousPageChange(_ action: @escaping (CGFloat) -> Void) -> Self {
        var copy = self
        copy.settings.onContinuousPageChange = action
        return copy
    }

    /// Runs when a zoomable page reports a zoom-scale change.
    public func onZoomChange(_ action: @escaping (Element, CGFloat) -> Void) -> Self {
        var copy = self
        copy.settings.onZoomChange = action
        return copy
    }

    private func makeDataSource() -> PagerDataSource<Element> {
        let idIndex = PagerIDIndex(
            data: data,
            idProvider: idProvider,
            sharedCache: idLookupCache,
            assumesUniqueIDs: true
        )

        return PagerDataSource(
            count: data.count,
            item: { offset in
                guard offset >= 0, offset < data.count else { return nil }
                let collectionIndex = data.index(data.startIndex, offsetBy: offset)
                let element = data[collectionIndex]
                return PagerItem(
                    index: offset,
                    element: element,
                    id: idProvider(offset, element),
                    reuseType: reuseTypeProvider(offset, element)
                )
            },
            indexOfID: { idIndex.indexOfPage(id: $0) },
            isIDIndexAuthoritative: true
        )
    }
}

/// Convenience initializers for identifiable data.
public extension SwiftPager where Element: Identifiable {
    /// Creates a pager that identifies pages with `Element.ID`.
    init(
        _ data: DataCollection,
        page: Binding<Int>? = nil,
        direction: SwiftPagerDirection = .horizontal,
        @ViewBuilder content: @escaping (Element) -> Content
    ) {
        self.data = data
        self.idProvider = { _, element in AnyHashable(element.id) }
        self.reuseTypeProvider = { _, _ in nil }
        self.content = content
        self.providedPage = page
        self.controller = nil
        self.sharedReusePool = nil
        self.configuration = SwiftPagerConfiguration(direction: direction)
        self.settings = SwiftPagerSettings(direction: direction, preloadDistance: self.configuration.preloadDistance)
    }
}
#endif
