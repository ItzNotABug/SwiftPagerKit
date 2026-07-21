#if canImport(UIKit)
import SwiftUI
import Testing
@testable import SwiftPagerKitCore

@Suite
@MainActor
struct SwiftPagerModifierTests {
    @Test
    func cachePolicyModifierAppliesAllCacheBudgets() throws {
        let pager = SwiftPager(Array(0..<3)) { value in
            Text("\(value)")
        }
        .cachePolicy(.performance)

        let configuration = try pagerConfiguration(in: pager)

        #expect(configuration.preloadDistance == 2)
        #expect(configuration.retentionDistance == 4)
        #expect(configuration.reusePoolLimit == 10)
    }

    @Test
    func individualCacheModifiersCanOverridePolicyValues() throws {
        let pager = SwiftPager(Array(0..<3)) { value in
            Text("\(value)")
        }
        .cachePolicy(.performance)
        .preloadDistance(0)
        .retentionDistance(1)
        .reusePoolLimit(2)

        let configuration = try pagerConfiguration(in: pager)

        #expect(configuration.preloadDistance == 0)
        #expect(configuration.retentionDistance == 1)
        #expect(configuration.reusePoolLimit == 2)
    }

    @Test
    func cacheModifiersCapExtremeValues() throws {
        let pager = SwiftPager(Array(0..<3)) { value in
            Text("\(value)")
        }
        .preloadDistance(Int.max)
        .retentionDistance(Int.max)
        .reusePoolLimit(Int.max)

        let configuration = try pagerConfiguration(in: pager)
        let settings = try pagerSettings(in: pager)

        #expect(configuration.preloadDistance == SwiftPagerLimits.maximumCacheDistance)
        #expect(configuration.retentionDistance == SwiftPagerLimits.maximumCacheDistance)
        #expect(configuration.reusePoolLimit == SwiftPagerLimits.maximumReusePoolLimit)
        #expect(settings.preloadDistance == SwiftPagerLimits.maximumCacheDistance)
    }

    @Test
    func settingsModifierCapsExtremePreloadDistance() throws {
        let pager = SwiftPager(Array(0..<3)) { value in
            Text("\(value)")
        }
        .configureSettings { settings in
            settings.preloadDistance = Int.max
        }

        let configuration = try pagerConfiguration(in: pager)
        let settings = try pagerSettings(in: pager)

        #expect(configuration.preloadDistance == SwiftPagerLimits.maximumCacheDistance)
        #expect(configuration.retentionDistance == SwiftPagerLimits.maximumCacheDistance)
        #expect(settings.preloadDistance == SwiftPagerLimits.maximumCacheDistance)
    }

    @Test
    func controllerPoolAndRestorationPolicyModifiersApply() throws {
        let controller = SwiftPagerController()
        let pool = SwiftPagerReusePool(limit: 3)
        let pager = SwiftPager(Array(0..<3)) { value in
            Text("\(value)")
        }
        .controller(controller)
        .reusePool(pool)
        .restorationPolicy(.reset)

        let configuration = try pagerConfiguration(in: pager)
        let reflectedController = try #require(Mirror(reflecting: pager).descendant("controller") as? SwiftPagerController)
        let reflectedPool = try #require(Mirror(reflecting: pager).descendant("sharedReusePool") as? SwiftPagerReusePool)

        #expect(reflectedController === controller)
        #expect(reflectedPool === pool)
        #expect(configuration.stateRestorationPolicy == .reset)
    }

    @Test
    func controllerPoolAndRestorationPolicyModifiersAllowAlternateValues() throws {
        let controller = SwiftPagerController()
        let pool = SwiftPagerReusePool(limit: 3)
        let pager = SwiftPager(Array(0..<3)) { value in
            Text("\(value)")
        }
        .controller(controller)
        .reusePool(pool)
        .restorationPolicy(.preserve)

        let configuration = try pagerConfiguration(in: pager)
        let reflectedController = try #require(Mirror(reflecting: pager).descendant("controller") as? SwiftPagerController)
        let reflectedPool = try #require(Mirror(reflecting: pager).descendant("sharedReusePool") as? SwiftPagerReusePool)

        #expect(reflectedController === controller)
        #expect(reflectedPool === pool)
        #expect(configuration.stateRestorationPolicy == .preserve)
    }

    @Test
    func gestureAndLoadingModifiersApplySettings() throws {
        let pager = SwiftPager(Array(0..<3)) { value in
            Text("\(value)")
        }
        .pageSpacing(4)
        .zoomable(minScale: 1, maxScale: 4, doubleTapAction: .zoom(toFraction: 0.75))
        .onLoadMore(when: .nearEnd(offsetFromEnd: 1)) {}
        .onOverscroll { _ in }
        .onTap {}
        .onDoubleTap {}
        .onDragStart {}
        .onZoomChange { _, _ in }

        let configuration = try pagerConfiguration(in: pager)
        let settings = try pagerSettings(in: pager)

        #expect(configuration.pageSpacing == 4)
        #expect(settings.pageSpacing == 4)
        #expect(settings.loadMoreTrigger == .nearEnd(offsetFromEnd: 1))
        #expect(settings.pageContainerStyle(for: 0) == .scroll)
        #expect(settings.zoomConfiguration(0) == .enabled(minimumScale: 1, maximumScale: 4, doubleTapAction: .zoom(toFraction: 0.75)))
    }

    @Test
    func tapAndDragCallbacksDoNotRequireNestedScrollContainer() throws {
        var settings = SwiftPagerSettings<Int>()
        settings.onTap = {}
        settings.onDoubleTap = {}
        settings.onDragStart = {}

        #expect(settings.pageContainerStyle(for: 0) == .gesture)

        settings.onTap = nil
        settings.onDoubleTap = nil

        #expect(settings.pageContainerStyle(for: 0) == .direct)
    }

    @Test
    func bounceModifierAppliesSettings() throws {
        let pager = SwiftPager(Array(0..<3)) { value in
            Text("\(value)")
        }
        .bounces(false)

        let settings = try pagerSettings(in: pager)

        #expect(settings.bounces == false)
    }

    @Test
    func accessibilityModifiersApplySettings() throws {
        let pager = SwiftPager(Array(0..<3)) { value in
            Text("\(value)")
        }
        .pagerAccessibilityLabel("Gallery pages")
        .pagerAccessibilityValue { state in
            "Slide \(state.currentPage + 1) / \(state.pageCount)"
        }

        let settings = try pagerSettings(in: pager)

        #expect(settings.accessibilityLabel == "Gallery pages")
        #expect(settings.accessibilityValue(SwiftPagerState(currentPage: 1, pageCount: 3)) == "Slide 2 / 3")
    }

    @Test
    func continuousPageChangeModifierAppliesSettings() throws {
        var reportedPosition: CGFloat?
        let pager = SwiftPager(Array(0..<3)) { value in
            Text("\(value)")
        }
        .onContinuousPageChange { position in
            reportedPosition = position
        }

        let settings = try pagerSettings(in: pager)
        settings.onContinuousPageChange?(1.25)

        #expect(reportedPosition == 1.25)
    }

    @Test
    func continuousPageChangeModifierCanDisableCoalescing() throws {
        let pager = SwiftPager(Array(0..<3)) { value in
            Text("\(value)")
        }
        .onContinuousPageChange(coalesced: false) { _ in }

        let settings = try pagerSettings(in: pager)

        #expect(settings.onContinuousPageChange != nil)
        #expect(settings.coalescesContinuousPageChanges == false)
    }

    @Test
    func pageLifecycleModifiersApplySettings() throws {
        var didAttachIndex: Int?
        var didDetachIndex: Int?
        let pager = SwiftPager(Array(0..<3)) { value in
            Text("\(value)")
        }
        .onPageWillAttach { index in
            didAttachIndex = index
        }
        .onPageDidDetach { index in
            didDetachIndex = index
        }

        let settings = try pagerSettings(in: pager)
        settings.onPageWillAttach?(1)
        settings.onPageDidDetach?(2)

        #expect(didAttachIndex == 1)
        #expect(didDetachIndex == 2)
    }

    @Test
    func pullToDismissAppliesToVerticalPagers() throws {
        let pager = SwiftPager(Array(0..<3), direction: .vertical) { value in
            Text("\(value)")
        }
        .onPullToDismiss {}

        let settings = try pagerSettings(in: pager)

        #expect(settings.onDismiss != nil)
        #expect(settings.pageContainerStyle(for: 0) == .scroll)
    }

    @Test
    func settingsModifierMirrorsAdvancedValuesIntoConfiguration() throws {
        let pager = SwiftPager(Array(0..<3)) { value in
            Text("\(value)")
        }
        .configureSettings { config in
            config.direction = .vertical
            config.pageSpacing = 7
            config.preloadDistance = 3
            config.dismissVelocity = -1
            config.dismissTriggerOffset = 2
            config.overscrollThreshold = -1
        }

        let configuration = try pagerConfiguration(in: pager)
        let settings = try pagerSettings(in: pager)

        #expect(configuration.direction == .vertical)
        #expect(configuration.pageSpacing == 7)
        #expect(configuration.preloadDistance == 3)
        #expect(configuration.retentionDistance == 3)
        #expect(settings.dismissVelocity == 0)
        #expect(settings.dismissTriggerOffset == 1)
        #expect(settings.overscrollThreshold == 0)
    }

}

@MainActor
private func pagerConfiguration<Element, DataCollection: RandomAccessCollection, Content: View>(
    in pager: SwiftPager<Element, DataCollection, Content>
) throws -> SwiftPagerConfiguration where DataCollection.Element == Element {
    try #require(Mirror(reflecting: pager).descendant("configuration") as? SwiftPagerConfiguration)
}

@MainActor
private func pagerSettings<Element, DataCollection: RandomAccessCollection, Content: View>(
    in pager: SwiftPager<Element, DataCollection, Content>
) throws -> SwiftPagerSettings<Element> where DataCollection.Element == Element {
    try #require(Mirror(reflecting: pager).descendant("settings") as? SwiftPagerSettings<Element>)
}

#endif
