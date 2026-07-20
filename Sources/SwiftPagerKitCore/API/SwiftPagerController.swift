#if canImport(UIKit)
import Combine
import CoreGraphics

/// Current scroll interaction phase.
public enum SwiftPagerScrollPhase: Sendable, Equatable {
    /// No user or programmatic scroll is active.
    case idle
    /// The user is dragging the pager.
    case dragging
    /// The pager is decelerating after a drag.
    case decelerating
    /// The pager is animating to a settled page.
    case animating
}

/// Metadata for a page that currently has an attached host.
///
/// This type is not `Sendable` because `id` and `reuseType` erase user-provided
/// hashable values that may not be safe to move across actors.
public struct SwiftPagerPageInfo: Equatable {
    /// Page index for this attached host.
    public var index: Int
    /// Stable page identifier.
    public var id: AnyHashable
    /// Optional reuse type used to group compatible page hosts.
    public var reuseType: AnyHashable?

    /// Creates loaded-page metadata.
    public init(index: Int, id: AnyHashable, reuseType: AnyHashable?) {
        self.index = index
        self.id = id
        self.reuseType = reuseType
    }
}

/// Snapshot of pager runtime state.
///
/// This type is main-actor oriented and intentionally not `Sendable` because
/// `loadedPages` carries erased user-provided IDs.
public struct SwiftPagerState: Equatable {
    /// Resolved current page index.
    ///
    /// Empty data may report a requested restoration page when the restoration
    /// policy is `.preserve`; `.reset` reports zero for unavailable initial data.
    ///
    /// During animated programmatic scrolls this may update before the scroll
    /// animation has completed; check `targetPage` and `scrollPhase` for
    /// in-flight motion.
    public var currentPage: Int
    /// Number of pages in the current data source.
    public var pageCount: Int
    /// Inclusive range of indexes with attached hosts.
    public var loadedRange: ClosedRange<Int>?
    /// Metadata for attached page hosts, sorted by page index.
    public var loadedPages: [SwiftPagerPageInfo]
    /// Target page for an active animated scroll, when any.
    public var targetPage: Int?
    /// Current page scroll axis.
    public var direction: SwiftPagerDirection
    /// Current scroll interaction phase.
    public var scrollPhase: SwiftPagerScrollPhase
    /// Visibility fraction of the nearest page, from zero to one.
    public var visibleFraction: CGFloat
    /// Current resolved page viewport size.
    public var pageSize: CGSize

    /// Creates a pager-state snapshot.
    public init(
        currentPage: Int = 0,
        pageCount: Int = 0,
        loadedRange: ClosedRange<Int>? = nil,
        loadedPages: [SwiftPagerPageInfo] = [],
        targetPage: Int? = nil,
        direction: SwiftPagerDirection = .horizontal,
        scrollPhase: SwiftPagerScrollPhase = .idle,
        visibleFraction: CGFloat = 1,
        pageSize: CGSize = .zero
    ) {
        self.currentPage = currentPage
        self.pageCount = pageCount
        self.loadedRange = loadedRange
        self.loadedPages = loadedPages
        self.targetPage = targetPage
        self.direction = direction
        self.scrollPhase = scrollPhase
        self.visibleFraction = visibleFraction
        self.pageSize = pageSize
    }
}

/// Programmatic control and observable state for a `SwiftPager`.
@MainActor
public final class SwiftPagerController: ObservableObject {
    /// Latest coarse state published by the attached pager.
    ///
    /// Frame-level `visibleFraction` changes do not republish this observable
    /// state by themselves. Use `SwiftPager.onContinuousPageChange(_:)` or
    /// `SwiftPager.continuousPageIndex(_:)` for continuous scroll signals.
    @Published public private(set) var state: SwiftPagerState

    private weak var pager: (any SwiftPagerControlling)?
    private var pendingScroll: SwiftPagerScrollRequest?
    private var pendingReplayGeneration = 0
    private var hasAttached = false

    /// Creates a controller with an optional initial page.
    public init(initialPage: Int = 0) {
        self.state = SwiftPagerState(currentPage: max(0, initialPage), pageCount: 0, loadedRange: nil)
    }

    /// Resolved current page index.
    ///
    /// During animated programmatic scrolls this may update before the scroll
    /// animation has completed.
    public var currentPage: Int {
        state.currentPage
    }

    /// Number of pages in the attached pager.
    public var pageCount: Int {
        state.pageCount
    }

    /// Inclusive range of indexes with attached hosts.
    public var loadedRange: ClosedRange<Int>? {
        state.loadedRange
    }

    /// Attached page metadata, sorted by index.
    public var loadedPages: [SwiftPagerPageInfo] {
        state.loadedPages
    }

    /// Scrolls to a page index.
    ///
    /// Out-of-range indexes are clamped to the nearest available page. Calls
    /// made before attachment, or while an attached pager has no pages, are
    /// stored and replayed when a matching pager becomes available.
    public func scrollToPage(_ index: Int, animated: Bool = true) {
        let request = SwiftPagerScrollRequest(target: .index(index), animated: animated)
        performOrStore(request)
    }

    /// Scrolls to the page with the provided stable ID.
    ///
    /// Missing IDs are ignored when pages are available. Calls made before
    /// attachment, or while an attached pager has no pages, are stored and
    /// replayed when the ID can be resolved.
    public func scrollToPage<ID: Hashable>(id: ID, animated: Bool = true) {
        let request = SwiftPagerScrollRequest(target: .id(AnyHashable(id)), animated: animated)
        performOrStore(request)
    }

    /// Returns the current index for a stable ID when it can be resolved.
    public func indexOfPage<ID: Hashable>(id: ID) -> Int? {
        let erasedID = AnyHashable(id)
        if let pager {
            return pager.resolvePageIndex(forID: erasedID)
        }
        return state.loadedPages.first { $0.id == erasedID }?.index
    }

    /// Scrolls to the next page if one exists.
    public func scrollToNextPage(animated: Bool = true) {
        scrollToPage(currentPage + 1, animated: animated)
    }

    /// Scrolls to the previous page if one exists.
    public func scrollToPreviousPage(animated: Bool = true) {
        scrollToPage(currentPage - 1, animated: animated)
    }

    func attach(to pager: any SwiftPagerControlling) {
        self.pager = pager
        hasAttached = true

        schedulePendingScrollReplayIfNeeded(on: pager)
    }

    func detach(from pager: any SwiftPagerControlling) {
        guard let currentPager = self.pager,
              ObjectIdentifier(currentPager) == ObjectIdentifier(pager)
        else {
            return
        }

        self.pager = nil
        hasAttached = false
        pendingReplayGeneration += 1
    }

    func updateState(_ state: SwiftPagerState) {
        if !self.state.isControllerPublishEquivalent(to: state) {
            self.state = state
        }
    }

    private func performOrStore(_ request: SwiftPagerScrollRequest) {
        guard let pager else {
            if !hasAttached {
                pendingScroll = request
            }
            return
        }

        if !request.perform(on: pager), pager.pagerState.pageCount == 0 {
            pendingScroll = request
        } else {
            pendingScroll = nil
        }
    }

    private func schedulePendingScrollReplayIfNeeded(on pager: any SwiftPagerControlling) {
        guard pendingScroll != nil else { return }

        pendingReplayGeneration += 1
        let generation = pendingReplayGeneration
        let pagerID = ObjectIdentifier(pager)

        Task { @MainActor [weak self] in
            guard let self,
                  self.pendingReplayGeneration == generation,
                  let currentPager = self.pager,
                  ObjectIdentifier(currentPager) == pagerID
            else {
                return
            }

            self.replayPendingScrollIfPossible(on: currentPager)
        }
    }

    private func replayPendingScrollIfPossible(on pager: any SwiftPagerControlling) {
        guard let pendingScroll else { return }

        if pendingScroll.perform(on: pager) || pager.pagerState.pageCount > 0 {
            self.pendingScroll = nil
        }
    }
}

extension SwiftPagerState {
    func isControllerPublishEquivalent(to other: SwiftPagerState) -> Bool {
        currentPage == other.currentPage &&
            pageCount == other.pageCount &&
            loadedRange == other.loadedRange &&
            loadedPages == other.loadedPages &&
            targetPage == other.targetPage &&
            direction == other.direction &&
            scrollPhase == other.scrollPhase &&
            pageSize == other.pageSize
    }
}

@MainActor
protocol SwiftPagerControlling: AnyObject {
    var pagerState: SwiftPagerState { get }
    func performScroll(toPage index: Int, animated: Bool) -> Bool
    func performScroll(toPageID id: AnyHashable, animated: Bool) -> Bool
    func resolvePageIndex(forID id: AnyHashable) -> Int?
}

struct PagerCallbacks {
    var onPageChange: ((Int) -> Void)?
    var onPagerStateChange: ((SwiftPagerState) -> Void)?
    var onScrollPhaseChange: ((SwiftPagerScrollPhase) -> Void)?
}

@MainActor
private struct SwiftPagerScrollRequest {
    enum Target {
        case index(Int)
        case id(AnyHashable)
    }

    var target: Target
    var animated: Bool

    func perform(on pager: any SwiftPagerControlling) -> Bool {
        switch target {
        case let .index(index):
            pager.performScroll(toPage: index, animated: animated)
        case let .id(id):
            pager.performScroll(toPageID: id, animated: animated)
        }
    }
}
#endif
