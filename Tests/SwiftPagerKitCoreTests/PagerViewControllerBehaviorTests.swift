#if canImport(UIKit)
import Combine
import SwiftUI
import Testing
import UIKit
@testable import SwiftPagerKitCore

@MainActor
@Suite(.serialized)
struct PagerViewControllerBehaviorTests {
    @Test
    func scrollViewUsesLeftToRightSemanticsForStableIndexMath() throws {
        let controller = makeController()
        let scrollView = try pagerScrollView(in: controller)

        #expect(scrollView.semanticContentAttribute == .forceLeftToRight)
    }

    @Test
    func pageContentKeepsParentSemanticDirectionWhenScrollMechanicsAreLeftToRight() throws {
        let box = PageBox(0)
        let controller = makeController()
        controller.view.semanticContentAttribute = .forceRightToLeft
        let scrollView = try pagerScrollView(in: controller)

        controller.apply(
            dataSource: dataSource(count: 1),
            page: box.binding,
            configuration: SwiftPagerConfiguration(),
            content: { Text("\($0)") }
        )

        let pageView = try horizontalSubview(in: scrollView, at: 0)
        #expect(scrollView.semanticContentAttribute == .forceLeftToRight)
        #expect(pageView.semanticContentAttribute == .forceRightToLeft)
    }

    @Test
    func zoomContainerKeepsLeftToRightMechanicsWhileContentMirrorsRightToLeft() throws {
        let box = PageBox(0)
        let controller = makeController()
        controller.view.semanticContentAttribute = .forceRightToLeft
        let scrollView = try pagerScrollView(in: controller)
        var settings = SwiftPagerSettings<Int>()
        settings.zoomConfiguration = { _ in .enabled(minimumScale: 1, maximumScale: 4) }

        controller.apply(
            dataSource: dataSource(count: 1),
            page: box.binding,
            settings: settings,
            configuration: SwiftPagerConfiguration(),
            content: { Text("\($0)") }
        )

        let zoomContainer = try #require(scrollView.subviews.compactMap { $0 as? PagerZoomContainer<Int> }.first)
        let hostedView = try #require(zoomContainer.subviews.first)
        #expect(zoomContainer.semanticContentAttribute == .forceLeftToRight)
        #expect(hostedView.semanticContentAttribute == .forceRightToLeft)
    }

    @Test
    func horizontalPagerCanDisableBoundaryBounce() throws {
        let box = PageBox(0)
        let controller = makeController()
        let scrollView = try pagerScrollView(in: controller)
        var settings = SwiftPagerSettings<Int>()
        settings.bounces = false

        controller.apply(
            dataSource: dataSource(count: 3),
            page: box.binding,
            settings: settings,
            configuration: SwiftPagerConfiguration(),
            content: { Text("\($0)") }
        )

        #expect(scrollView.bounces == false)
        #expect(scrollView.alwaysBounceHorizontal == false)
        #expect(scrollView.alwaysBounceVertical == false)
    }

    @Test
    func verticalPagerCanDisableBoundaryBounce() throws {
        let box = PageBox(0)
        let controller = makeController()
        let scrollView = try pagerScrollView(in: controller)
        var settings = SwiftPagerSettings<Int>()
        settings.bounces = false

        controller.apply(
            dataSource: dataSource(count: 3),
            page: box.binding,
            settings: settings,
            configuration: SwiftPagerConfiguration(direction: .vertical),
            content: { Text("\($0)") }
        )

        #expect(scrollView.bounces == false)
        #expect(scrollView.alwaysBounceHorizontal == false)
        #expect(scrollView.alwaysBounceVertical == false)
    }

    @Test
    func pagerBouncesByDefaultWhenMultiplePagesAreAvailable() throws {
        let box = PageBox(0)
        let controller = makeController()
        let scrollView = try pagerScrollView(in: controller)

        controller.apply(
            dataSource: dataSource(count: 3),
            page: box.binding,
            configuration: SwiftPagerConfiguration(),
            content: { Text("\($0)") }
        )

        #expect(scrollView.bounces)
        #expect(scrollView.alwaysBounceHorizontal)
        #expect(scrollView.alwaysBounceVertical == false)
    }

    @Test
    func scrollViewPublishesAccessiblePageValue() throws {
        let box = PageBox(1)
        let controller = makeController()
        let scrollView = try pagerScrollView(in: controller)
        let accessibilityControl = try pagerAccessibilityControl(in: controller)

        controller.apply(
            dataSource: dataSource(count: 3),
            page: box.binding,
            configuration: SwiftPagerConfiguration(),
            content: { Text("\($0)") }
        )

        #expect(!scrollView.isAccessibilityElement)
        #expect(accessibilityControl.accessibilityLabel == "Pager")
        #expect(accessibilityControl.isAccessibilityElement)
        #expect(accessibilityControl.accessibilityTraits.contains(.adjustable))
        #expect(accessibilityControl.accessibilityValue == "Page 2 of 3")
    }

    @Test
    func customAccessibilityTextIsApplied() throws {
        let box = PageBox(1)
        let controller = makeController()
        let accessibilityControl = try pagerAccessibilityControl(in: controller)
        var settings = SwiftPagerSettings<Int>()
        settings.accessibilityLabel = "Gallery pages"
        settings.accessibilityValue = { state in
            "Slide \(state.currentPage + 1) / \(state.pageCount)"
        }

        controller.apply(
            dataSource: dataSource(count: 3),
            page: box.binding,
            settings: settings,
            configuration: SwiftPagerConfiguration(),
            content: { Text("\($0)") }
        )

        #expect(accessibilityControl.accessibilityLabel == "Gallery pages")
        #expect(accessibilityControl.accessibilityValue == "Slide 2 / 3")
    }

    @Test
    func replacingAccessibilityValueFormatterRefreshesCurrentValue() throws {
        let box = PageBox(1)
        let controller = makeController()
        let accessibilityControl = try pagerAccessibilityControl(in: controller)
        var settings = SwiftPagerSettings<Int>()
        settings.accessibilityValue = { state in
            "First formatter \(state.currentPage + 1) / \(state.pageCount)"
        }

        controller.apply(
            dataSource: dataSource(count: 3),
            page: box.binding,
            settings: settings,
            configuration: SwiftPagerConfiguration(),
            content: { Text("\($0)") }
        )

        #expect(accessibilityControl.accessibilityValue == "First formatter 2 / 3")

        settings.accessibilityValue = { state in
            "Second formatter \(state.currentPage + 1) / \(state.pageCount)"
        }
        controller.apply(
            dataSource: dataSource(count: 3),
            page: box.binding,
            settings: settings,
            configuration: SwiftPagerConfiguration(),
            content: { Text("\($0)") }
        )

        #expect(accessibilityControl.accessibilityValue == "Second formatter 2 / 3")
    }

    @Test
    func accessibilityAdjustsCurrentPage() throws {
        let box = PageBox(1)
        let controller = makeController()
        let accessibilityControl = try pagerAccessibilityControl(in: controller)

        controller.apply(
            dataSource: dataSource(count: 3),
            page: box.binding,
            configuration: SwiftPagerConfiguration(),
            content: { Text("\($0)") }
        )

        accessibilityControl.accessibilityIncrement()
        #expect(box.value == 2)

        accessibilityControl.accessibilityDecrement()
        #expect(box.value == 1)
    }

    @Test
    func accessibilityScrollReportsWhetherPageChanged() throws {
        let box = PageBox(1)
        let controller = makeController()
        let accessibilityControl = try pagerAccessibilityControl(in: controller)

        controller.apply(
            dataSource: dataSource(count: 3),
            page: box.binding,
            configuration: SwiftPagerConfiguration(),
            content: { Text("\($0)") }
        )

        #expect(accessibilityControl.accessibilityScroll(.left))
        #expect(box.value == 2)
        #expect(!accessibilityControl.accessibilityScroll(.left))
        #expect(box.value == 2)
        #expect(accessibilityControl.accessibilityScroll(.right))
        #expect(box.value == 1)
    }

    @Test
    func accessibilityActionsDoNotMutateAfterTeardown() throws {
        let box = PageBox(1)
        let controller = makeController()
        let scrollView = try pagerScrollView(in: controller)
        let accessibilityControl = try pagerAccessibilityControl(in: controller)

        controller.apply(
            dataSource: dataSource(count: 3),
            page: box.binding,
            configuration: SwiftPagerConfiguration(),
            content: { Text("\($0)") }
        )
        controller.teardown()

        accessibilityControl.accessibilityIncrement()

        #expect(box.value == 1)
        #expect(scrollView.subviews.isEmpty)
    }

    @Test
    func teardownReleasesAccessibilityValueFormatterCapture() throws {
        let box = PageBox(0)
        let controller = makeController()
        let accessibilityControl = try pagerAccessibilityControl(in: controller)
        weak var weakCapture: AccessibilityFormatterCapture?

        do {
            let capture = AccessibilityFormatterCapture()
            weakCapture = capture
            var settings = SwiftPagerSettings<Int>()
            settings.accessibilityLabel = "Custom pager"
            settings.accessibilityValue = { [capture] state in
                "\(capture.token)-\(state.currentPage)"
            }

            controller.apply(
                dataSource: dataSource(count: 3),
                page: box.binding,
                settings: settings,
                configuration: SwiftPagerConfiguration(),
                content: { Text("\($0)") }
            )
        }

        #expect(accessibilityControl.accessibilityLabel == "Custom pager")
        #expect(accessibilityControl.accessibilityValue == "capture-0")
        #expect(weakCapture != nil)
        controller.teardown()
        #expect(weakCapture == nil)
        #expect(accessibilityControl.accessibilityLabel == "Pager")
        #expect(accessibilityControl.accessibilityValue == nil)
    }

    @Test
    func outOfRangePageCorrectionIsDeferred() async throws {
        let box = PageBox(99)
        let controller = makeController()

        controller.apply(
            dataSource: dataSource(count: 3),
            page: box.binding,
            configuration: SwiftPagerConfiguration(),
            content: { Text("\($0)") }
        )

        #expect(box.value == 99)

        await waitUntil {
            box.value == 2
        }

        #expect(box.value == 2)
    }

    @Test
    func emptyDataRemovesAttachedAndCachedHosts() throws {
        let box = PageBox(0)
        let controller = makeController()
        let scrollView = try pagerScrollView(in: controller)

        controller.apply(
            dataSource: dataSource(count: 3),
            page: box.binding,
            configuration: SwiftPagerConfiguration(),
            content: { Text("\($0)") }
        )

        #expect(!scrollView.subviews.isEmpty)

        controller.apply(
            dataSource: dataSource(count: 0),
            page: box.binding,
            configuration: SwiftPagerConfiguration(),
            content: { Text("\($0)") }
        )

        #expect(scrollView.subviews.isEmpty)
        #expect(controller.children.isEmpty)
    }

    @Test
    func teardownDetachesHostsAndController() throws {
        let box = PageBox(0)
        let pagerController = SwiftPagerController()
        let controller = makeController()
        let scrollView = try pagerScrollView(in: controller)

        controller.apply(
            dataSource: dataSource(count: 3),
            page: box.binding,
            controller: pagerController,
            configuration: SwiftPagerConfiguration(),
            content: { Text("\($0)") }
        )

        #expect(!scrollView.subviews.isEmpty)

        controller.teardown()
        pagerController.scrollToPage(2, animated: false)

        #expect(scrollView.subviews.isEmpty)
        #expect(controller.children.isEmpty)
        #expect(box.value == 0)
        #expect(pagerController.currentPage == 0)
    }

    @Test
    func teardownAllowsControllerAndHostsToDeallocate() async throws {
        weak var weakController: PagerViewController<Int, Text>?
        weak var weakHostController: UIViewController?
        weak var weakHostView: UIView?

        do {
            let box = PageBox(0)
            var controller: PagerViewController<Int, Text>? = makeController()
            let liveController = try #require(controller)

            liveController.apply(
                dataSource: dataSource(count: 3),
                page: box.binding,
                configuration: SwiftPagerConfiguration(),
                content: { Text("\($0)") }
            )

            let scrollView = try pagerScrollView(in: liveController)
            let hostView = scrollView.subviews.first
            let hostController = liveController.children.first
            #expect(hostView != nil)
            #expect(hostController != nil)
            weakHostView = hostView
            weakHostController = hostController
            weakController = liveController

            liveController.teardown()
            controller = nil
        }

        await waitUntil {
            weakController == nil &&
                weakHostController == nil &&
                weakHostView == nil
        }

        #expect(weakController == nil)
        #expect(weakHostController == nil)
        #expect(weakHostView == nil)
    }

    @Test
    func preservePolicyRestoresPageAfterDataLoads() throws {
        let box = PageBox(2)
        let controller = makeController()
        let scrollView = try pagerScrollView(in: controller)
        let configuration = SwiftPagerConfiguration(stateRestorationPolicy: .preserve)

        controller.apply(
            dataSource: dataSource(count: 0),
            page: box.binding,
            configuration: configuration,
            content: { Text("\($0)") }
        )

        #expect(box.value == 2)
        #expect(controller.pagerState.pageCount == 0)
        #expect(controller.pagerState.currentPage == 2)

        controller.apply(
            dataSource: dataSource(count: 4),
            page: box.binding,
            configuration: configuration,
            content: { Text("\($0)") }
        )

        #expect(box.value == 2)
        #expect(controller.pagerState.currentPage == 2)
        #expect(Int(scrollView.contentOffset.x.rounded()) == 200)
    }

    @Test
    func resetPolicyIgnoresInitialRestoredPageAfterDataLoads() async throws {
        let box = PageBox(2)
        let controller = makeController()
        let scrollView = try pagerScrollView(in: controller)
        let configuration = SwiftPagerConfiguration(stateRestorationPolicy: .reset)

        controller.apply(
            dataSource: dataSource(count: 0),
            page: box.binding,
            configuration: configuration,
            content: { Text("\($0)") }
        )

        #expect(box.value == 2)

        controller.apply(
            dataSource: dataSource(count: 4),
            page: box.binding,
            configuration: configuration,
            content: { Text("\($0)") }
        )

        #expect(controller.pagerState.currentPage == 0)
        #expect(Int(scrollView.contentOffset.x.rounded()) == 0)

        await waitUntil {
            box.value == 0
        }

        #expect(box.value == 0)
    }

    @Test
    func resetPolicyDoesNotResetAfterTemporaryEmptyData() throws {
        let box = PageBox(2)
        let pagerController = SwiftPagerController()
        let controller = makeController()
        let scrollView = try pagerScrollView(in: controller)
        let configuration = SwiftPagerConfiguration(stateRestorationPolicy: .reset)

        controller.apply(
            dataSource: dataSource(count: 5),
            page: box.binding,
            controller: pagerController,
            configuration: configuration,
            content: { Text("\($0)") }
        )

        #expect(pagerController.currentPage == 0)

        pagerController.scrollToPage(3, animated: false)

        #expect(box.value == 3)
        #expect(pagerController.currentPage == 3)

        controller.apply(
            dataSource: dataSource(count: 0),
            page: box.binding,
            controller: pagerController,
            configuration: configuration,
            content: { Text("\($0)") }
        )

        controller.apply(
            dataSource: dataSource(count: 5),
            page: box.binding,
            controller: pagerController,
            configuration: configuration,
            content: { Text("\($0)") }
        )

        #expect(box.value == 3)
        #expect(pagerController.currentPage == 3)
        #expect(Int(scrollView.contentOffset.x.rounded()) == 300)
    }

    @Test
    func controllerInitialPageSurvivesInitialEmptyDataWithoutExplicitBinding() throws {
        let pagerController = SwiftPagerController(initialPage: 2)
        let fallbackPage = FallbackPageBox(controller: pagerController)
        let controller = makeController()
        let scrollView = try pagerScrollView(in: controller)

        controller.apply(
            dataSource: dataSource(count: 0),
            page: fallbackPage.binding,
            controller: pagerController,
            configuration: SwiftPagerConfiguration(),
            content: { Text("\($0)") }
        )

        #expect(pagerController.currentPage == 2)

        controller.apply(
            dataSource: dataSource(count: 4),
            page: fallbackPage.binding,
            controller: pagerController,
            configuration: SwiftPagerConfiguration(),
            content: { Text("\($0)") }
        )

        #expect(pagerController.currentPage == 2)
        #expect(Int(scrollView.contentOffset.x.rounded()) == 200)
    }

    @Test
    func pendingControllerScrollReplaysWhenEmptyDataLoads() async throws {
        let box = PageBox(0)
        let pagerController = SwiftPagerController()
        let controller = makeController()
        let scrollView = try pagerScrollView(in: controller)

        pagerController.scrollToPage(id: 13, animated: false)

        controller.apply(
            dataSource: dataSource(count: 0),
            page: box.binding,
            controller: pagerController,
            configuration: SwiftPagerConfiguration(),
            content: { Text("\($0)") }
        )

        #expect(box.value == 0)
        #expect(pagerController.currentPage == 0)

        controller.apply(
            dataSource: dataSource(ids: [10, 11, 12, 13, 14]),
            page: box.binding,
            controller: pagerController,
            configuration: SwiftPagerConfiguration(),
            content: { Text("\($0)") }
        )

        await waitUntil {
            box.value == 3 && pagerController.currentPage == 3
        }

        #expect(box.value == 3)
        #expect(pagerController.currentPage == 3)
        #expect(Int(scrollView.contentOffset.x.rounded()) == 300)
    }

    @Test
    func missingPendingIDScrollClearsAfterNonEmptyDataArrives() async throws {
        let box = PageBox(0)
        let pagerController = SwiftPagerController()
        let controller = makeController()
        let scrollView = try pagerScrollView(in: controller)

        pagerController.scrollToPage(id: 99, animated: false)

        controller.apply(
            dataSource: dataSource(count: 0),
            page: box.binding,
            controller: pagerController,
            configuration: SwiftPagerConfiguration(),
            content: { Text("\($0)") }
        )

        controller.apply(
            dataSource: dataSource(ids: [10, 11, 12]),
            page: box.binding,
            controller: pagerController,
            configuration: SwiftPagerConfiguration(),
            content: { Text("\($0)") }
        )

        await drainMainActorWork()

        #expect(pagerController.currentPage == 0)
        #expect(Int(scrollView.contentOffset.x.rounded()) == 0)

        controller.apply(
            dataSource: dataSource(ids: [10, 11, 12, 99]),
            page: box.binding,
            controller: pagerController,
            configuration: SwiftPagerConfiguration(),
            content: { Text("\($0)") }
        )

        await drainMainActorWork()

        #expect(pagerController.currentPage == 0)
        #expect(Int(scrollView.contentOffset.x.rounded()) == 0)
    }

    @Test
    func preloadDistanceZeroStillKeepsAdjacentHostLive() throws {
        let box = PageBox(0)
        let controller = makeController()
        let scrollView = try pagerScrollView(in: controller)

        controller.apply(
            dataSource: dataSource(count: 4),
            page: box.binding,
            configuration: SwiftPagerConfiguration(preloadDistance: 0, retentionDistance: 0),
            content: { Text("\($0)") }
        )

        let frameOrigins = horizontalFrameOrigins(in: scrollView)
        #expect(frameOrigins == [0, 100])
    }

    @Test
    func cachePolicyControlsLiveWindowBudget() throws {
        let box = PageBox(2)
        let controller = makeController()
        let scrollView = try pagerScrollView(in: controller)

        controller.apply(
            dataSource: dataSource(count: 8),
            page: box.binding,
            configuration: SwiftPagerConfiguration(cachePolicy: .performance),
            content: { Text("\($0)") }
        )

        let frameOrigins = horizontalFrameOrigins(in: scrollView)
        #expect(frameOrigins == [0, 100, 200, 300, 400])
    }

    @Test
    func idleApplyPrewarmsAttachedPageLayouts() throws {
        let box = PageBox(0)
        let recorder = LayoutPassRecorder()
        let controller = makeController(contentType: LayoutProbePage.self)
        let window = attachToWindow(controller)

        controller.apply(
            dataSource: dataSource(count: 3),
            page: box.binding,
            configuration: SwiftPagerConfiguration(preloadDistance: 1, retentionDistance: 1),
            content: { LayoutProbePage(value: $0, recorder: recorder) }
        )

        #expect(recorder.layoutCount(for: 0) > 0)
        #expect(recorder.layoutCount(for: 1) > 0)
        _ = window
    }

    @Test
    func memoryWarningDiscardsRetainedHosts() async throws {
        let box = PageBox(0)
        let controller = makeController()
        let scrollView = try pagerScrollView(in: controller)
        let configuration = SwiftPagerConfiguration(preloadDistance: 0, retentionDistance: 2, reusePoolLimit: 0)
        weak var weakRetainedView: UIView?

        controller.apply(
            dataSource: dataSource(count: 5),
            page: box.binding,
            configuration: configuration,
            content: { Text("\($0)") }
        )

        do {
            let retainedView = try horizontalSubview(in: scrollView, at: 100)
            weakRetainedView = retainedView
        }

        box.value = 3
        controller.apply(
            dataSource: dataSource(count: 5),
            page: box.binding,
            configuration: configuration,
            content: { Text("\($0)") }
        )

        #expect(weakRetainedView != nil)

        controller.didReceiveMemoryWarning()
        await waitUntil {
            weakRetainedView == nil
        }

        #expect(weakRetainedView == nil)
    }

    @Test
    func memoryWarningDiscardsReusableHosts() async throws {
        let box = PageBox(3)
        let controller = makeController()
        let scrollView = try pagerScrollView(in: controller)
        let configuration = SwiftPagerConfiguration(preloadDistance: 0, retentionDistance: 0, reusePoolLimit: 3)
        weak var weakReusableView: UIView?

        controller.apply(
            dataSource: dataSource(count: 5),
            page: box.binding,
            configuration: configuration,
            content: { Text("\($0)") }
        )

        do {
            let reusableView = try horizontalSubview(in: scrollView, at: 200)
            weakReusableView = reusableView
        }

        box.value = 0
        controller.apply(
            dataSource: dataSource(count: 5),
            page: box.binding,
            configuration: configuration,
            content: { Text("\($0)") }
        )

        #expect(weakReusableView != nil)

        controller.didReceiveMemoryWarning()
        await waitUntil {
            weakReusableView == nil
        }

        #expect(weakReusableView == nil)
    }

    @Test
    func memoryWarningDiscardsSharedReusableHosts() async throws {
        let sharedPool = SwiftPagerReusePool(limit: 3)
        let box = PageBox(3)
        let controller = makeController()
        let scrollView = try pagerScrollView(in: controller)
        let configuration = SwiftPagerConfiguration(preloadDistance: 0, retentionDistance: 0, reusePoolLimit: 3)
        weak var weakReusableView: UIView?

        controller.apply(
            dataSource: dataSource(count: 5),
            page: box.binding,
            sharedReusePool: sharedPool,
            configuration: configuration,
            content: { Text("\($0)") }
        )

        do {
            let reusableView = try horizontalSubview(in: scrollView, at: 200)
            weakReusableView = reusableView
        }

        box.value = 0
        controller.apply(
            dataSource: dataSource(count: 5),
            page: box.binding,
            sharedReusePool: sharedPool,
            configuration: configuration,
            content: { Text("\($0)") }
        )

        #expect(weakReusableView != nil)

        controller.didReceiveMemoryWarning()
        await waitUntil {
            weakReusableView == nil
        }

        #expect(weakReusableView == nil)
    }

    @Test
    func loadMoreFiresNearEndAndThrottlesPerDataCount() async throws {
        let box = PageBox(3)
        let controller = makeController()
        var loadMoreCount = 0
        var settings = SwiftPagerSettings<Int>()
        settings.loadMoreTrigger = .nearEnd(offsetFromEnd: 1)
        settings.onLoadMore = {
            loadMoreCount += 1
        }

        controller.apply(
            dataSource: dataSource(count: 5),
            page: box.binding,
            settings: settings,
            configuration: SwiftPagerConfiguration(),
            content: { Text("\($0)") }
        )

        await waitUntil {
            loadMoreCount == 1
        }

        controller.apply(
            dataSource: dataSource(count: 5),
            page: box.binding,
            settings: settings,
            configuration: SwiftPagerConfiguration(),
            content: { Text("\($0)") }
        )

        await drainMainActorWork()
        #expect(loadMoreCount == 1)

        box.value = 4
        controller.apply(
            dataSource: dataSource(count: 5),
            page: box.binding,
            settings: settings,
            configuration: SwiftPagerConfiguration(),
            content: { Text("\($0)") }
        )

        await drainMainActorWork()
        #expect(loadMoreCount == 1)

        box.value = 1
        controller.apply(
            dataSource: dataSource(count: 5),
            page: box.binding,
            settings: settings,
            configuration: SwiftPagerConfiguration(),
            content: { Text("\($0)") }
        )

        box.value = 3
        controller.apply(
            dataSource: dataSource(count: 5),
            page: box.binding,
            settings: settings,
            configuration: SwiftPagerConfiguration(),
            content: { Text("\($0)") }
        )

        await drainMainActorWork()

        #expect(loadMoreCount == 1)

        box.value = 4
        controller.apply(
            dataSource: dataSource(count: 6),
            page: box.binding,
            settings: settings,
            configuration: SwiftPagerConfiguration(),
            content: { Text("\($0)") }
        )

        await waitUntil {
            loadMoreCount == 2
        }

        #expect(loadMoreCount == 2)
    }

    @Test
    func pendingLoadMoreDoesNotFireAfterTeardown() async throws {
        let box = PageBox(3)
        let controller = makeController()
        var didLoadMore = false
        var settings = SwiftPagerSettings<Int>()
        settings.loadMoreTrigger = .nearEnd(offsetFromEnd: 1)
        settings.onLoadMore = {
            didLoadMore = true
        }

        controller.apply(
            dataSource: dataSource(count: 5),
            page: box.binding,
            settings: settings,
            configuration: SwiftPagerConfiguration(),
            content: { Text("\($0)") }
        )
        controller.teardown()

        await drainMainActorWork()

        #expect(!didLoadMore)
    }

    @Test
    func deferredApplyPublishesControllerStateAfterViewUpdateTurn() async {
        let box = PageBox(0)
        let pagerController = SwiftPagerController()
        let controller = makeController()
        var stateChangeCount = 0

        controller.apply(
            dataSource: dataSource(count: 3),
            page: box.binding,
            controller: pagerController,
            callbacks: PagerCallbacks(onPagerStateChange: { _ in stateChangeCount += 1 }),
            configuration: SwiftPagerConfiguration(),
            content: { Text("\($0)") },
            deferExternalUpdates: true
        )

        #expect(pagerController.pageCount == 0)
        #expect(stateChangeCount == 0)

        await drainMainActorWork()

        #expect(pagerController.pageCount == 3)
        #expect(stateChangeCount == 1)
    }

    @Test
    func overscrollReportsEachBoundaryOncePerDrag() throws {
        let box = PageBox(0)
        let controller = makeController()
        let scrollView = try pagerScrollView(in: controller)
        var positions: [SwiftPagerBoundary] = []
        var settings = SwiftPagerSettings<Int>()
        settings.overscrollThreshold = 0.1
        settings.onOverscroll = { positions.append($0) }

        controller.apply(
            dataSource: dataSource(count: 3),
            page: box.binding,
            settings: settings,
            configuration: SwiftPagerConfiguration(),
            content: { Text("\($0)") }
        )

        controller.scrollViewWillBeginDragging(scrollView)
        scrollView.contentOffset = CGPoint(x: -12, y: 0)
        controller.scrollViewDidScroll(scrollView)
        controller.scrollViewDidScroll(scrollView)

        #expect(positions == [.beginning])

        controller.scrollViewWillBeginDragging(scrollView)
        scrollView.contentOffset = CGPoint(x: 212, y: 0)
        controller.scrollViewDidScroll(scrollView)

        #expect(positions == [.beginning, .end])
    }

    @Test
    func continuousPageIndexTracksContinuousOffset() async throws {
        let box = PageBox(0)
        let positionBox = CGFloatBox(0)
        let controller = makeController()
        let scrollView = try pagerScrollView(in: controller)
        var settings = SwiftPagerSettings<Int>()
        settings.continuousPageIndex = positionBox.binding

        controller.apply(
            dataSource: dataSource(count: 4),
            page: box.binding,
            settings: settings,
            configuration: SwiftPagerConfiguration(),
            content: { Text("\($0)") }
        )

        scrollView.contentOffset = CGPoint(x: 150, y: 0)
        controller.scrollViewDidScroll(scrollView)

        await waitUntil {
            positionBox.value == 1.5
        }

        #expect(positionBox.value == 1.5)
    }

    @Test
    func continuousPageIndexDefersApplyWriteUntilOffsetIsResolved() async throws {
        let box = PageBox(2)
        let positionBox = CGFloatBox(-1)
        let controller = makeController()
        var settings = SwiftPagerSettings<Int>()
        settings.continuousPageIndex = positionBox.binding

        controller.apply(
            dataSource: dataSource(count: 4),
            page: box.binding,
            settings: settings,
            configuration: SwiftPagerConfiguration(),
            content: { Text("\($0)") }
        )

        #expect(positionBox.value == -1)

        await waitUntil {
            positionBox.value == 2
        }

        #expect(positionBox.value == 2)
    }

    @Test
    func onContinuousPageChangeTracksContinuousOffsetWithoutStateBinding() async throws {
        let box = PageBox(0)
        let controller = makeController()
        let scrollView = try pagerScrollView(in: controller)
        var positions: [CGFloat] = []
        var settings = SwiftPagerSettings<Int>()
        settings.onContinuousPageChange = { positions.append($0) }

        controller.apply(
            dataSource: dataSource(count: 4),
            page: box.binding,
            settings: settings,
            configuration: SwiftPagerConfiguration(),
            content: { Text("\($0)") }
        )

        scrollView.contentOffset = CGPoint(x: 150, y: 0)
        controller.scrollViewDidScroll(scrollView)

        await waitUntil {
            positions.contains(1.5)
        }

        #expect(positions.contains(1.5))
    }

    @Test
    func continuousPageChangeCoalescesTinyScrollDeltas() async throws {
        let box = PageBox(0)
        let controller = makeController()
        let scrollView = try pagerScrollView(in: controller)
        var positions: [CGFloat] = []
        var settings = SwiftPagerSettings<Int>()
        settings.onContinuousPageChange = { positions.append($0) }

        controller.apply(
            dataSource: dataSource(count: 4),
            page: box.binding,
            settings: settings,
            configuration: SwiftPagerConfiguration(),
            content: { Text("\($0)") }
        )

        await waitUntil {
            positions.last == 0
        }
        let countAfterInitialPublish = positions.count

        scrollView.contentOffset = CGPoint(x: 0.4, y: 0)
        controller.scrollViewDidScroll(scrollView)
        await drainMainActorWork()

        #expect(positions.count == countAfterInitialPublish)
    }

    @Test
    func continuousPageChangeCanPublishEveryScrollTickWithoutCoalescing() throws {
        let box = PageBox(0)
        let controller = makeController()
        let scrollView = try pagerScrollView(in: controller)
        var positions: [CGFloat] = []
        var settings = SwiftPagerSettings<Int>()
        settings.coalescesContinuousPageChanges = false
        settings.onContinuousPageChange = { positions.append($0) }

        controller.apply(
            dataSource: dataSource(count: 4),
            page: box.binding,
            settings: settings,
            configuration: SwiftPagerConfiguration(),
            content: { Text("\($0)") }
        )

        scrollView.contentOffset = CGPoint(x: 0.4, y: 0)
        controller.scrollViewDidScroll(scrollView)

        let expectedPosition = scrollView.contentOffset.x / scrollView.bounds.width
        #expect(abs((positions.last ?? -1) - expectedPosition) < 0.0001)
    }

    @Test
    func pendingContinuousPageChangeIsCancelledByTeardown() async throws {
        let box = PageBox(0)
        let controller = makeController()
        var positions: [CGFloat] = []
        var settings = SwiftPagerSettings<Int>()
        settings.onContinuousPageChange = { positions.append($0) }

        controller.apply(
            dataSource: dataSource(count: 4),
            page: box.binding,
            settings: settings,
            configuration: SwiftPagerConfiguration(),
            content: { Text("\($0)") }
        )

        controller.teardown()
        await drainMainActorWork()

        #expect(positions.isEmpty)
    }

    @Test
    func zoomablePagesUseNestedScrollContainerOnlyWhenNeeded() throws {
        let box = PageBox(0)
        let controller = makeController()
        let scrollView = try pagerScrollView(in: controller)
        var settings = SwiftPagerSettings<Int>()
        settings.zoomConfiguration = { _ in .enabled(minimumScale: 1, maximumScale: 4, doubleTapAction: .zoom(toFraction: 0.5)) }

        controller.apply(
            dataSource: dataSource(count: 2),
            page: box.binding,
            settings: settings,
            configuration: SwiftPagerConfiguration(preloadDistance: 0, retentionDistance: 0),
            content: { Text("\($0)") }
        )

        #expect(scrollView.subviews.contains { $0 is PagerZoomContainer<Int> })

        settings.zoomConfiguration = { _ in .disabled }
        controller.apply(
            dataSource: dataSource(count: 2),
            page: box.binding,
            settings: settings,
            configuration: SwiftPagerConfiguration(preloadDistance: 0, retentionDistance: 0),
            content: { Text("\($0)") }
        )

        #expect(!scrollView.subviews.contains { $0 is PagerZoomContainer<Int> })
    }

    @Test
    func zoomContainerConfigureDoesNotResetActiveTransform() {
        let container = PagerZoomContainer<Int>()
        let hostedView = UIView()
        let transform = CGAffineTransform(translationX: 0, y: 40)

        container.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        container.setHostedView(hostedView)
        container.transform = transform
        container.configure(
            element: 0,
            settings: SwiftPagerSettings<Int>(),
            direction: .horizontal
        )

        #expect(container.transform == transform)

        container.prepareForReuse()

        #expect(container.transform == .identity)
    }

    @Test
    func zoomContainerLayoutDoesNotCollapseActiveZoomedContent() {
        let container = PagerZoomContainer<Int>()
        let hostedView = UIView()
        var settings = SwiftPagerSettings<Int>()
        settings.zoomConfiguration = { _ in .enabled(minimumScale: 1, maximumScale: 4, doubleTapAction: .zoom(toFraction: 0.5)) }

        container.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        container.setHostedView(hostedView)
        container.configure(element: 0, settings: settings, direction: .horizontal)
        container.layoutSubviews()

        hostedView.frame = CGRect(x: 0, y: 0, width: 200, height: 200)
        container.setZoomScale(2, animated: false)
        container.layoutSubviews()

        #expect(hostedView.frame.size.width >= 200)
        #expect(hostedView.frame.size.height >= 200)
    }

    @Test
    func zoomContainerReuseResetsToNextElementMinimumZoom() {
        let container = PagerZoomContainer<Int>()
        let hostedView = UIView()
        var settings = SwiftPagerSettings<Int>()
        settings.zoomConfiguration = { value in
            value == 0
                ? .enabled(minimumScale: 2, maximumScale: 4, doubleTapAction: .zoom(toFraction: 0.5))
                : .enabled(minimumScale: 1, maximumScale: 4, doubleTapAction: .zoom(toFraction: 0.5))
        }

        container.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        container.setHostedView(hostedView)
        container.configure(element: 0, settings: settings, direction: .horizontal)

        #expect(container.zoomScale == 2)

        container.prepareForReuse()
        container.configure(element: 1, settings: settings, direction: .horizontal)

        #expect(container.minimumZoomScale == 1)
        #expect(container.zoomScale == 1)
    }

    @Test
    func dismissPullDisablesPinchInPullDirection() {
        let container = PagerZoomContainer<Int>()
        let hostedView = UIView()
        var settings = SwiftPagerSettings<Int>()
        settings.onDismiss = {}
        settings.pinchGestureActivationOffset = 10
        settings.zoomConfiguration = { _ in .enabled(minimumScale: 1, maximumScale: 4) }

        container.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        container.setHostedView(hostedView)
        container.configure(element: 0, settings: settings, direction: .horizontal)
        container.layoutSubviews()

        #expect(container.pinchGestureRecognizer?.isEnabled == true)

        container.setContentOffset(CGPoint(x: 0, y: -12), animated: false)
        container.scrollViewDidScroll(container)

        #expect(container.pinchGestureRecognizer?.isEnabled == false)

        container.setContentOffset(.zero, animated: false)
        container.scrollViewDidScroll(container)

        #expect(container.pinchGestureRecognizer?.isEnabled == true)
    }

    @Test
    func dismissRequiresSignedDismissVelocity() async {
        let container = PagerZoomContainer<Int>()
        let hostedView = UIView()
        var didDismiss = false
        var settings = SwiftPagerSettings<Int>()
        settings.onDismiss = { didDismiss = true }
        settings.dismissTriggerOffset = 0.1
        settings.dismissVelocity = 1
        settings.dismissAnimationDuration = 0

        container.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        container.setHostedView(hostedView)
        container.configure(element: 0, settings: settings, direction: .horizontal)
        container.setContentOffset(CGPoint(x: 0, y: -20), animated: false)

        var targetOffset = CGPoint.zero
        container.scrollViewWillEndDragging(
            container,
            withVelocity: CGPoint(x: 0, y: 2),
            targetContentOffset: &targetOffset
        )

        await drainMainActorWork()
        #expect(!didDismiss)

        container.setContentOffset(CGPoint(x: 0, y: -20), animated: false)
        container.scrollViewWillEndDragging(
            container,
            withVelocity: CGPoint(x: 0, y: -2),
            targetContentOffset: &targetOffset
        )

        await waitUntil {
            didDismiss
        }

        #expect(didDismiss)
    }

    @Test
    func dismissRestoresContainerWhenCallbackDoesNotRemovePager() async {
        let container = PagerZoomContainer<Int>()
        let hostedView = UIView()
        var didDismiss = false
        var backgroundOpacity: CGFloat = 1
        var settings = SwiftPagerSettings<Int>()
        settings.dismissBackgroundOpacity = Binding(
            get: { backgroundOpacity },
            set: { backgroundOpacity = $0 }
        )
        settings.onDismiss = { didDismiss = true }
        settings.dismissTriggerOffset = 0.1
        settings.dismissVelocity = 1
        settings.dismissAnimationDuration = 0

        container.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        container.setHostedView(hostedView)
        container.configure(element: 0, settings: settings, direction: .horizontal)
        container.setContentOffset(CGPoint(x: 0, y: -20), animated: false)

        var targetOffset = CGPoint.zero
        container.scrollViewWillEndDragging(
            container,
            withVelocity: CGPoint(x: 0, y: -2),
            targetContentOffset: &targetOffset
        )

        await waitUntil {
            didDismiss
        }

        #expect(container.transform == .identity)
        #expect(container.isUserInteractionEnabled)
        #expect(container.contentOffset == .zero)
        #expect(backgroundOpacity == 1)
    }

    @Test
    func cancelledDismissAnimationDoesNotCallDismissAfterRemoval() async {
        let container = PagerZoomContainer<Int>()
        let hostedView = UIView()
        var didDismiss = false
        var settings = SwiftPagerSettings<Int>()
        settings.onDismiss = { didDismiss = true }
        settings.dismissTriggerOffset = 0.1
        settings.dismissVelocity = 1
        settings.dismissAnimationDuration = 0.05

        container.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        container.setHostedView(hostedView)
        container.configure(element: 0, settings: settings, direction: .horizontal)
        container.setContentOffset(CGPoint(x: 0, y: -20), animated: false)

        var targetOffset = CGPoint.zero
        container.scrollViewWillEndDragging(
            container,
            withVelocity: CGPoint(x: 0, y: -2),
            targetContentOffset: &targetOffset
        )
        container.prepareForRemoval()

        try? await Task.sleep(nanoseconds: 100_000_000)

        #expect(!didDismiss)
        #expect(container.transform == .identity)
        #expect(container.contentOffset == .zero)
    }

    @Test
    func staleDismissCompletionDoesNotCallPreviousCallbackAfterReuse() async {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let container = PagerZoomContainer<Int>()
        let hostedView = UIView()
        var firstDismissCount = 0
        var secondDismissCount = 0
        var firstSettings = SwiftPagerSettings<Int>()
        firstSettings.onDismiss = { firstDismissCount += 1 }
        firstSettings.dismissTriggerOffset = 0.1
        firstSettings.dismissVelocity = 1
        firstSettings.dismissAnimationDuration = 0.05

        container.frame = window.bounds
        window.addSubview(container)
        window.makeKeyAndVisible()
        container.setHostedView(hostedView)
        container.configure(element: 0, settings: firstSettings, direction: .horizontal)
        container.setContentOffset(CGPoint(x: 0, y: -20), animated: false)

        var targetOffset = CGPoint.zero
        container.scrollViewWillEndDragging(
            container,
            withVelocity: CGPoint(x: 0, y: -2),
            targetContentOffset: &targetOffset
        )

        try? await Task.sleep(nanoseconds: 10_000_000)

        var secondSettings = SwiftPagerSettings<Int>()
        secondSettings.onDismiss = { secondDismissCount += 1 }
        secondSettings.dismissTriggerOffset = 0.1
        secondSettings.dismissVelocity = 1
        secondSettings.dismissAnimationDuration = 0.2

        container.prepareForReuse()
        container.configure(element: 1, settings: secondSettings, direction: .horizontal)
        container.setContentOffset(CGPoint(x: 0, y: -20), animated: false)
        container.scrollViewWillEndDragging(
            container,
            withVelocity: CGPoint(x: 0, y: -2),
            targetContentOffset: &targetOffset
        )

        try? await Task.sleep(nanoseconds: 100_000_000)

        #expect(firstDismissCount == 0)
        _ = secondDismissCount
        _ = window
    }

    @Test
    func dismissBackgroundOpacityOnlyWritesChangedValues() {
        let container = PagerZoomContainer<Int>()
        let hostedView = UIView()
        var backgroundOpacity: CGFloat = 1
        var opacityWrites = 0
        var settings = SwiftPagerSettings<Int>()
        settings.dismissBackgroundOpacity = Binding(
            get: { backgroundOpacity },
            set: {
                opacityWrites += 1
                backgroundOpacity = $0
            }
        )
        settings.onDismiss = {}
        settings.dismissFadeDistanceRatio = 0.2

        container.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        container.setHostedView(hostedView)
        container.configure(element: 0, settings: settings, direction: .horizontal)

        container.setContentOffset(.zero, animated: false)
        container.scrollViewDidScroll(container)

        #expect(opacityWrites == 0)

        container.setContentOffset(CGPoint(x: 0, y: -10), animated: false)
        container.scrollViewDidScroll(container)

        #expect(opacityWrites == 1)
        #expect(backgroundOpacity == 0.5)

        container.scrollViewDidScroll(container)

        #expect(opacityWrites == 1)
    }

    @Test
    func reconfigureWithSameDismissBindingDoesNotResetActiveDismissOpacity() async {
        let container = PagerZoomContainer<Int>()
        let hostedView = UIView()
        var backgroundOpacity: CGFloat = 1
        var settings = SwiftPagerSettings<Int>()
        settings.dismissBackgroundOpacity = Binding(
            get: { backgroundOpacity },
            set: { backgroundOpacity = $0 }
        )
        settings.onDismiss = {}
        settings.dismissFadeDistanceRatio = 0.2

        container.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        container.setHostedView(hostedView)
        container.configure(element: 0, settings: settings, direction: .horizontal)
        container.setContentOffset(CGPoint(x: 0, y: -10), animated: false)
        container.scrollViewDidScroll(container)

        #expect(backgroundOpacity == 0.5)

        container.configure(element: 0, settings: settings, direction: .horizontal)
        await drainMainActorWork()

        #expect(backgroundOpacity == 0.5)
    }

    @Test
    func reconfigureWithDifferentPageIDRestoresPreviousDismissBinding() async {
        let container = PagerZoomContainer<Int>()
        let hostedView = UIView()
        var firstOpacity: CGFloat = 0.5
        var secondOpacity: CGFloat = 0.5
        var firstSettings = SwiftPagerSettings<Int>()
        firstSettings.dismissBackgroundOpacity = Binding(
            get: { firstOpacity },
            set: { firstOpacity = $0 }
        )
        firstSettings.onDismiss = {}

        var secondSettings = SwiftPagerSettings<Int>()
        secondSettings.dismissBackgroundOpacity = Binding(
            get: { secondOpacity },
            set: { secondOpacity = $0 }
        )
        secondSettings.onDismiss = {}

        container.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        container.setHostedView(hostedView)
        container.configure(pageID: "first", element: 0, settings: firstSettings, direction: .horizontal)
        container.configure(pageID: "second", element: 1, settings: secondSettings, direction: .horizontal)
        await drainMainActorWork()

        #expect(firstOpacity == 1)
        #expect(secondOpacity == 0.5)
    }

    @Test
    func reconfigureSamePageWithDifferentDismissBindingRestoresPreviousBinding() async {
        let container = PagerZoomContainer<Int>()
        let hostedView = UIView()
        var firstOpacity: CGFloat = 0.5
        var secondOpacity: CGFloat = 1
        var firstSettings = SwiftPagerSettings<Int>()
        firstSettings.dismissBackgroundOpacity = Binding(
            get: { firstOpacity },
            set: { firstOpacity = $0 }
        )
        firstSettings.onDismiss = {}

        var secondSettings = SwiftPagerSettings<Int>()
        secondSettings.dismissBackgroundOpacity = Binding(
            get: { secondOpacity },
            set: { secondOpacity = $0 }
        )
        secondSettings.onDismiss = {}

        container.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        container.setHostedView(hostedView)
        container.configure(pageID: "same", element: 0, settings: firstSettings, direction: .horizontal)
        container.configure(pageID: "same", element: 0, settings: secondSettings, direction: .horizontal)
        await drainMainActorWork()

        #expect(firstOpacity == 1)
        #expect(secondOpacity == 1)
    }

    @Test
    func discardDuringDismissPullRestoresBackgroundOpacity() async throws {
        let box = PageBox(0)
        let controller = makeController()
        let scrollView = try pagerScrollView(in: controller)
        var backgroundOpacity: CGFloat = 1
        var settings = SwiftPagerSettings<Int>()
        settings.dismissBackgroundOpacity = Binding(
            get: { backgroundOpacity },
            set: { backgroundOpacity = $0 }
        )
        settings.onDismiss = {}
        settings.dismissFadeDistanceRatio = 0.2

        controller.apply(
            dataSource: dataSource(count: 1),
            page: box.binding,
            settings: settings,
            configuration: SwiftPagerConfiguration(),
            content: { Text("\($0)") }
        )

        let container = try #require(scrollView.subviews.compactMap { $0 as? PagerZoomContainer<Int> }.first)
        container.setContentOffset(CGPoint(x: 0, y: -10), animated: false)
        container.scrollViewDidScroll(container)

        #expect(backgroundOpacity == 0.5)

        controller.apply(
            dataSource: dataSource(count: 0),
            page: box.binding,
            settings: settings,
            configuration: SwiftPagerConfiguration(),
            content: { Text("\($0)") }
        )

        await drainMainActorWork()

        #expect(backgroundOpacity == 1)
    }

    @Test
    func retainedHostClearsDismissAndZoomStateWhenLeavingLiveWindow() async throws {
        let box = PageBox(0)
        let controller = makeController()
        let scrollView = try pagerScrollView(in: controller)
        var backgroundOpacity: CGFloat = 1
        var settings = SwiftPagerSettings<Int>()
        settings.dismissBackgroundOpacity = Binding(
            get: { backgroundOpacity },
            set: { backgroundOpacity = $0 }
        )
        settings.onDismiss = {}
        settings.dismissFadeDistanceRatio = 0.2
        settings.zoomConfiguration = { _ in .enabled(minimumScale: 1, maximumScale: 4) }

        controller.apply(
            dataSource: dataSource(count: 5),
            page: box.binding,
            settings: settings,
            configuration: SwiftPagerConfiguration(),
            content: { Text("\($0)") }
        )

        let firstPage = try #require(horizontalSubview(in: scrollView, at: 0) as? PagerZoomContainer<Int>)
        firstPage.layoutSubviews()
        firstPage.setContentOffset(CGPoint(x: 0, y: -10), animated: false)
        firstPage.scrollViewDidScroll(firstPage)
        firstPage.setZoomScale(2, animated: false)

        #expect(firstPage.zoomScale == 2)
        #expect(backgroundOpacity == 0.5)

        box.value = 2
        controller.apply(
            dataSource: dataSource(count: 5),
            page: box.binding,
            settings: settings,
            configuration: SwiftPagerConfiguration(),
            content: { Text("\($0)") }
        )
        await drainMainActorWork()

        #expect(backgroundOpacity == 1)

        box.value = 0
        controller.apply(
            dataSource: dataSource(count: 5),
            page: box.binding,
            settings: settings,
            configuration: SwiftPagerConfiguration(),
            content: { Text("\($0)") }
        )

        let restoredFirstPage = try #require(horizontalSubview(in: scrollView, at: 0) as? PagerZoomContainer<Int>)
        #expect(restoredFirstPage.zoomScale == restoredFirstPage.minimumZoomScale)
        #expect(restoredFirstPage.contentOffset == .zero)
    }

    @Test
    func zoomContainerReusesTapRecognizersWhenEffectiveShapeIsUnchanged() throws {
        let container = PagerZoomContainer<Int>()
        let hostedView = UIView()
        var settings = SwiftPagerSettings<Int>()
        settings.onTap = {}
        settings.onDoubleTap = {}

        container.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        container.setHostedView(hostedView)
        container.configure(element: 0, settings: settings, direction: .horizontal)

        let initialSingleTap = try tapRecognizer(in: container, taps: 1)
        let initialDoubleTap = try tapRecognizer(in: container, taps: 2)

        settings.onTap = {}
        settings.onDoubleTap = {}
        container.configure(element: 0, settings: settings, direction: .horizontal)

        #expect(try tapRecognizer(in: container, taps: 1) === initialSingleTap)
        #expect(try tapRecognizer(in: container, taps: 2) === initialDoubleTap)
    }

    @Test
    func zoomedHorizontalPagerKeepsVerticalDominantEdgePanInZoomContainer() {
        let container = PagerZoomContainer<Int>()
        let hostedView = UIView()
        var settings = SwiftPagerSettings<Int>()
        settings.zoomConfiguration = { _ in .enabled(minimumScale: 1, maximumScale: 4) }

        container.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        container.setHostedView(hostedView)
        container.configure(element: 0, settings: settings, direction: .horizontal)
        container.layoutSubviews()
        container.setZoomScale(2, animated: false)
        container.contentSize = CGSize(width: 200, height: 200)
        container.contentOffset = CGPoint(x: 100, y: 50)

        #expect(container.shouldBeginPanGesture(with: CGPoint(x: -1, y: 20)))
        #expect(!container.shouldBeginPanGesture(with: CGPoint(x: -20, y: 1)))
    }

    @Test
    func verticalPagerDismissesWithHorizontalPull() async {
        let container = PagerZoomContainer<Int>()
        let hostedView = UIView()
        var didDismiss = false
        var settings = SwiftPagerSettings<Int>()
        settings.onDismiss = { didDismiss = true }
        settings.dismissTriggerOffset = 0.1
        settings.dismissVelocity = 1
        settings.dismissAnimationDuration = 0

        container.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        container.setHostedView(hostedView)
        container.configure(element: 0, settings: settings, direction: .vertical)
        container.layoutSubviews()
        container.setContentOffset(CGPoint(x: -20, y: 0), animated: false)

        var targetOffset = CGPoint.zero
        container.scrollViewWillEndDragging(
            container,
            withVelocity: CGPoint(x: -2, y: 0),
            targetContentOffset: &targetOffset
        )

        await waitUntil {
            didDismiss
        }

        #expect(didDismiss)
        #expect(container.transform == .identity)
    }

    @Test
    func pageLifecycleCallbacksFireWhenPagesEnterAndLeaveLiveWindow() throws {
        let box = PageBox(0)
        let controller = makeController()
        let scrollView = try pagerScrollView(in: controller)
        var events: [String] = []
        var settings = SwiftPagerSettings<Int>()
        settings.onPageWillAttach = { events.append("attach:\($0)") }
        settings.onPageDidDetach = { events.append("detach:\($0)") }

        controller.apply(
            dataSource: dataSource(count: 5),
            page: box.binding,
            settings: settings,
            configuration: SwiftPagerConfiguration(preloadDistance: 0, retentionDistance: 0),
            content: { Text("\($0)") }
        )

        #expect(events == ["attach:0", "attach:1"])

        events.removeAll()
        scrollView.contentOffset = CGPoint(x: 200, y: 0)
        controller.scrollViewDidScroll(scrollView)

        #expect(events == ["detach:0", "attach:2", "attach:3"])
    }

    @Test
    func pageLifecycleCallbacksDeferDuringSwiftUIApply() async throws {
        let box = PageBox(0)
        let controller = makeController()
        var events: [String] = []
        var settings = SwiftPagerSettings<Int>()
        settings.onPageWillAttach = { events.append("attach:\($0)") }
        settings.onPageDidDetach = { events.append("detach:\($0)") }

        controller.apply(
            dataSource: dataSource(count: 5),
            page: box.binding,
            settings: settings,
            configuration: SwiftPagerConfiguration(preloadDistance: 0, retentionDistance: 0),
            content: { Text("\($0)") },
            deferExternalUpdates: true
        )

        #expect(events.isEmpty)

        await waitUntil {
            events == ["attach:0", "attach:1"]
        }

        #expect(events == ["attach:0", "attach:1"])
    }

    @Test
    func pageLifecycleCallbacksDeferDuringTeardown() async throws {
        let box = PageBox(0)
        var controller: PagerViewController<Int, Text>? = makeController()
        var events: [String] = []
        var settings = SwiftPagerSettings<Int>()
        settings.onPageWillAttach = { events.append("attach:\($0)") }
        settings.onPageDidDetach = { events.append("detach:\($0)") }

        controller?.apply(
            dataSource: dataSource(count: 3),
            page: box.binding,
            settings: settings,
            configuration: SwiftPagerConfiguration(preloadDistance: 0, retentionDistance: 0),
            content: { Text("\($0)") }
        )

        events.removeAll()
        controller?.teardown()
        controller = nil

        #expect(events.isEmpty)

        await waitUntil {
            events.contains("detach:0") && events.contains("detach:1")
        }

        #expect(events.filter { $0.hasPrefix("detach:") }.count == 2)
    }

    @Test
    func pageLifecycleCallbacksStayBalancedWhenLiveHostWrapperChanges() throws {
        let box = PageBox(0)
        let controller = makeController()
        var events: [String] = []
        var settings = SwiftPagerSettings<Int>()
        settings.onPageWillAttach = { events.append("attach:\($0)") }
        settings.onPageDidDetach = { events.append("detach:\($0)") }
        let configuration = SwiftPagerConfiguration(preloadDistance: 0, retentionDistance: 0)

        controller.apply(
            dataSource: dataSource(count: 2),
            page: box.binding,
            settings: settings,
            configuration: configuration,
            content: { Text("\($0)") }
        )

        events.removeAll()
        settings.zoomConfiguration = { _ in .enabled(minimumScale: 1, maximumScale: 4) }
        controller.apply(
            dataSource: dataSource(count: 2),
            page: box.binding,
            settings: settings,
            configuration: configuration,
            content: { Text("\($0)") }
        )

        #expect(events.filter { $0 == "detach:0" }.count == 1)
        #expect(events.filter { $0 == "attach:0" }.count == 1)
        #expect(events.filter { $0 == "detach:1" }.count == 1)
        #expect(events.filter { $0 == "attach:1" }.count == 1)
    }

    @Test
    func pageLifecycleCallbacksFireWhenRetainedPageReattaches() throws {
        let box = PageBox(0)
        let controller = makeController()
        let scrollView = try pagerScrollView(in: controller)
        var events: [String] = []
        var settings = SwiftPagerSettings<Int>()
        settings.onPageWillAttach = { events.append("attach:\($0)") }
        settings.onPageDidDetach = { events.append("detach:\($0)") }
        let configuration = SwiftPagerConfiguration(preloadDistance: 0, retentionDistance: 2)

        controller.apply(
            dataSource: dataSource(count: 5),
            page: box.binding,
            settings: settings,
            configuration: configuration,
            content: { Text("\($0)") }
        )

        events.removeAll()
        scrollView.contentOffset = CGPoint(x: 200, y: 0)
        controller.scrollViewDidScroll(scrollView)
        #expect(events.contains("detach:0"))

        events.removeAll()
        scrollView.contentOffset = CGPoint(x: 0, y: 0)
        controller.scrollViewDidScroll(scrollView)

        #expect(events.contains("attach:0"))
    }

    @Test
    func pageLifecycleCallbacksFireWhenReusableHostReattaches() throws {
        let box = PageBox(2)
        let controller = makeController()
        let scrollView = try pagerScrollView(in: controller)
        var events: [String] = []
        var settings = SwiftPagerSettings<Int>()
        settings.onPageWillAttach = { events.append("attach:\($0)") }
        settings.onPageDidDetach = { events.append("detach:\($0)") }
        let configuration = SwiftPagerConfiguration(preloadDistance: 0, retentionDistance: 0, reusePoolLimit: 2)

        controller.apply(
            dataSource: dataSource(count: 4),
            page: box.binding,
            settings: settings,
            configuration: configuration,
            content: { Text("\($0)") }
        )

        events.removeAll()
        scrollView.contentOffset = CGPoint(x: 0, y: 0)
        controller.scrollViewDidScroll(scrollView)

        #expect(events.contains("detach:2"))
        #expect(events.contains("attach:0"))
    }

    @Test
    func sharedReusePoolReusesHostAcrossCompatiblePagers() throws {
        let sharedPool = SwiftPagerReusePool(limit: 2)
        let firstBox = PageBox(2)
        let firstController = makeController()
        let firstScrollView = try pagerScrollView(in: firstController)
        let configuration = SwiftPagerConfiguration(preloadDistance: 0, retentionDistance: 0)

        firstController.apply(
            dataSource: dataSource(count: 4),
            page: firstBox.binding,
            sharedReusePool: sharedPool,
            configuration: configuration,
            content: { Text("\($0)") }
        )

        let originalViews = firstScrollView.subviews
        let originalChildren = originalViews.compactMap { originalView in
            firstController.children.first { $0.view === originalView }
        }

        firstBox.value = 0
        firstController.apply(
            dataSource: dataSource(count: 4),
            page: firstBox.binding,
            sharedReusePool: sharedPool,
            configuration: configuration,
            content: { Text("\($0)") }
        )

        let detachedOriginalViews = originalViews.filter { $0.superview == nil }
        #expect(!detachedOriginalViews.isEmpty)
        for detachedView in detachedOriginalViews {
            let detachedChild = originalChildren.first { $0.view === detachedView }
            #expect(detachedChild?.parent == nil)
        }

        let secondBox = PageBox(0)
        let secondController = makeController()
        let secondScrollView = try pagerScrollView(in: secondController)

        secondController.apply(
            dataSource: dataSource(count: 1),
            page: secondBox.binding,
            sharedReusePool: sharedPool,
            configuration: configuration,
            content: { Text("\($0)") }
        )

        let reusedView = try horizontalSubview(in: secondScrollView, at: 0)
        let reusedChild = try #require(secondController.children.first { $0.view === reusedView })
        #expect(originalViews.contains { $0 === reusedView })
        #expect(reusedChild.parent === secondController)
    }

    @Test
    func sharedReusePoolRemoveAllDiscardsCachedHosts() throws {
        let sharedPool = SwiftPagerReusePool(limit: 2)
        let firstBox = PageBox(2)
        let firstController = makeController()
        let firstScrollView = try pagerScrollView(in: firstController)
        let configuration = SwiftPagerConfiguration(preloadDistance: 0, retentionDistance: 0)

        firstController.apply(
            dataSource: dataSource(count: 4),
            page: firstBox.binding,
            sharedReusePool: sharedPool,
            configuration: configuration,
            content: { Text("\($0)") }
        )

        let originalView = try horizontalSubview(in: firstScrollView, at: 200)

        firstBox.value = 0
        firstController.apply(
            dataSource: dataSource(count: 4),
            page: firstBox.binding,
            sharedReusePool: sharedPool,
            configuration: configuration,
            content: { Text("\($0)") }
        )

        sharedPool.removeAll()

        let secondBox = PageBox(0)
        let secondController = makeController()
        let secondScrollView = try pagerScrollView(in: secondController)

        secondController.apply(
            dataSource: dataSource(count: 1),
            page: secondBox.binding,
            sharedReusePool: sharedPool,
            configuration: configuration,
            content: { Text("\($0)") }
        )

        let newView = try horizontalSubview(in: secondScrollView, at: 0)
        #expect(newView !== originalView)
    }

    @Test
    func sharedReusePoolLimitMutationTrimsCachedHosts() throws {
        let sharedPool = SwiftPagerReusePool(limit: 2)
        let firstBox = PageBox(2)
        let firstController = makeController()
        let firstScrollView = try pagerScrollView(in: firstController)
        let configuration = SwiftPagerConfiguration(preloadDistance: 0, retentionDistance: 0)

        firstController.apply(
            dataSource: dataSource(count: 4),
            page: firstBox.binding,
            sharedReusePool: sharedPool,
            configuration: configuration,
            content: { Text("\($0)") }
        )

        let originalView = try horizontalSubview(in: firstScrollView, at: 200)

        firstBox.value = 0
        firstController.apply(
            dataSource: dataSource(count: 4),
            page: firstBox.binding,
            sharedReusePool: sharedPool,
            configuration: configuration,
            content: { Text("\($0)") }
        )

        sharedPool.limit = 0

        let secondBox = PageBox(0)
        let secondController = makeController()
        let secondScrollView = try pagerScrollView(in: secondController)

        secondController.apply(
            dataSource: dataSource(count: 1),
            page: secondBox.binding,
            sharedReusePool: sharedPool,
            configuration: configuration,
            content: { Text("\($0)") }
        )

        let newView = try horizontalSubview(in: secondScrollView, at: 0)
        #expect(newView !== originalView)
    }

    @Test
    func sharedReusePoolSeparatesReuseTypes() throws {
        let sharedPool = SwiftPagerReusePool(limit: 2)
        let firstBox = PageBox(2)
        let firstController = makeController()
        let firstScrollView = try pagerScrollView(in: firstController)
        let configuration = SwiftPagerConfiguration(preloadDistance: 0, retentionDistance: 0)

        firstController.apply(
            dataSource: dataSource(count: 4, reuseType: AnyHashable("card")),
            page: firstBox.binding,
            sharedReusePool: sharedPool,
            configuration: configuration,
            content: { Text("\($0)") }
        )

        let originalView = try horizontalSubview(in: firstScrollView, at: 200)

        firstBox.value = 0
        firstController.apply(
            dataSource: dataSource(count: 4, reuseType: AnyHashable("card")),
            page: firstBox.binding,
            sharedReusePool: sharedPool,
            configuration: configuration,
            content: { Text("\($0)") }
        )

        let secondBox = PageBox(0)
        let secondController = makeController()
        let secondScrollView = try pagerScrollView(in: secondController)

        secondController.apply(
            dataSource: dataSource(count: 1, reuseType: AnyHashable("detail")),
            page: secondBox.binding,
            sharedReusePool: sharedPool,
            configuration: configuration,
            content: { Text("\($0)") }
        )

        let newView = try horizontalSubview(in: secondScrollView, at: 0)
        #expect(newView !== originalView)
    }

    @Test
    func sharedReusePoolSeparatesIncompatibleContentTypes() throws {
        let sharedPool = SwiftPagerReusePool(limit: 2)
        let firstBox = PageBox(2)
        let firstController = makeController()
        let firstScrollView = try pagerScrollView(in: firstController)
        let configuration = SwiftPagerConfiguration(preloadDistance: 0, retentionDistance: 0)

        firstController.apply(
            dataSource: dataSource(count: 4),
            page: firstBox.binding,
            sharedReusePool: sharedPool,
            configuration: configuration,
            content: { Text("\($0)") }
        )

        let originalView = try horizontalSubview(in: firstScrollView, at: 200)

        firstBox.value = 0
        firstController.apply(
            dataSource: dataSource(count: 4),
            page: firstBox.binding,
            sharedReusePool: sharedPool,
            configuration: configuration,
            content: { Text("\($0)") }
        )

        let secondBox = PageBox(0)
        let secondController = makeController(contentType: Color.self)
        let secondScrollView = try pagerScrollView(in: secondController)

        secondController.apply(
            dataSource: dataSource(count: 1),
            page: secondBox.binding,
            sharedReusePool: sharedPool,
            configuration: configuration,
            content: { _ in Color.red }
        )

        let newView = try horizontalSubview(in: secondScrollView, at: 0)
        #expect(newView !== originalView)
    }

    @Test
    func reusedHostResetsSwiftUIStateWhenPageIDChanges() async throws {
        let box = PageBox(0)
        let recorder = StateTokenRecorder()
        let controller = makeController(contentType: StatefulProbePage.self)
        let window = attachToWindow(controller)
        let configuration = SwiftPagerConfiguration(preloadDistance: 0, retentionDistance: 0, reusePoolLimit: 1)

        controller.apply(
            dataSource: dataSource(count: 3),
            page: box.binding,
            configuration: configuration,
            content: { StatefulProbePage(value: $0, recorder: recorder) }
        )
        controller.view.layoutIfNeeded()
        await waitUntil {
            recorder.token(for: 0) != nil
        }

        let firstToken = try #require(recorder.token(for: 0))

        box.value = 2
        controller.apply(
            dataSource: dataSource(count: 3),
            page: box.binding,
            configuration: configuration,
            content: { StatefulProbePage(value: $0, recorder: recorder) }
        )
        controller.view.layoutIfNeeded()
        await waitUntil {
            recorder.token(for: 2) != nil
        }

        let reusedToken = try #require(recorder.token(for: 2))
        #expect(reusedToken != firstToken)
        _ = window
    }

    @Test
    func defaultIdentityPolicyDoesNotRefreshContentWhenStableIDIsUnchanged() async throws {
        let box = PageBox(0)
        let recorder = StateTokenRecorder()
        let controller = makeController(contentType: StatefulProbePage.self)
        let window = attachToWindow(controller)

        controller.apply(
            dataSource: dataSource(elements: [100], ids: [7]),
            page: box.binding,
            configuration: SwiftPagerConfiguration(),
            content: { StatefulProbePage(value: $0, recorder: recorder) }
        )
        controller.view.layoutIfNeeded()
        await waitUntil {
            recorder.token(for: 100) != nil
        }

        let firstToken = try #require(recorder.token(for: 100))

        controller.apply(
            dataSource: dataSource(elements: [200], ids: [7]),
            page: box.binding,
            configuration: SwiftPagerConfiguration(),
            content: { StatefulProbePage(value: $0, recorder: recorder) }
        )
        controller.view.layoutIfNeeded()
        await drainMainActorWork()

        #expect(recorder.token(for: 100) == firstToken)
        #expect(recorder.token(for: 200) == nil)
        _ = window
    }

    @Test
    func alwaysPolicyRefreshesContentWhilePreservingSwiftUIStateWhenStableIDIsUnchanged() async throws {
        let box = PageBox(0)
        let recorder = StateTokenRecorder()
        let controller = makeController(contentType: StatefulProbePage.self)
        let window = attachToWindow(controller)
        let configuration = SwiftPagerConfiguration(contentUpdatePolicy: .always)

        controller.apply(
            dataSource: dataSource(elements: [100], ids: [7]),
            page: box.binding,
            configuration: configuration,
            content: { StatefulProbePage(value: $0, recorder: recorder) }
        )
        controller.view.layoutIfNeeded()
        await waitUntil {
            recorder.token(for: 100) != nil
        }

        let firstToken = try #require(recorder.token(for: 100))

        controller.apply(
            dataSource: dataSource(elements: [200], ids: [7]),
            page: box.binding,
            configuration: configuration,
            content: { StatefulProbePage(value: $0, recorder: recorder) }
        )
        controller.view.layoutIfNeeded()
        await waitUntil {
            recorder.token(for: 200) != nil
        }

        let updatedToken = try #require(recorder.token(for: 200))
        #expect(updatedToken == firstToken)
        _ = window
    }

    @Test
    func switchingFromLocalToSharedReusePoolClearsLocalCache() throws {
        let sharedPool = SwiftPagerReusePool(limit: 2)
        let box = PageBox(2)
        let controller = makeController()
        let scrollView = try pagerScrollView(in: controller)
        let configuration = SwiftPagerConfiguration(preloadDistance: 0, retentionDistance: 0, reusePoolLimit: 2)

        controller.apply(
            dataSource: dataSource(count: 4),
            page: box.binding,
            configuration: configuration,
            content: { Text("\($0)") }
        )

        let locallyCachedView = try horizontalSubview(in: scrollView, at: 200)

        box.value = 0
        controller.apply(
            dataSource: dataSource(count: 4),
            page: box.binding,
            configuration: configuration,
            content: { Text("\($0)") }
        )

        controller.apply(
            dataSource: dataSource(count: 4),
            page: box.binding,
            sharedReusePool: sharedPool,
            configuration: configuration,
            content: { Text("\($0)") }
        )

        controller.apply(
            dataSource: dataSource(count: 0),
            page: box.binding,
            sharedReusePool: sharedPool,
            configuration: configuration,
            content: { Text("\($0)") }
        )

        box.value = 0
        controller.apply(
            dataSource: dataSource(count: 1),
            page: box.binding,
            configuration: configuration,
            content: { Text("\($0)") }
        )

        let newView = try horizontalSubview(in: scrollView, at: 0)
        #expect(newView !== locallyCachedView)
    }

    @Test
    func animatedExternalJumpKeepsCurrentHostAttached() throws {
        let box = PageBox(0)
        let controller = makeController()
        let window = attachToWindow(controller)
        let scrollView = try pagerScrollView(in: controller)

        controller.apply(
            dataSource: dataSource(count: 5),
            page: box.binding,
            configuration: SwiftPagerConfiguration(),
            content: { Text("\($0)") }
        )

        #expect(horizontalFrameOrigins(in: scrollView).contains(0))

        box.value = 4
        controller.apply(
            dataSource: dataSource(count: 5),
            page: box.binding,
            configuration: SwiftPagerConfiguration(),
            content: { Text("\($0)") },
            animated: true
        )

        #expect(horizontalFrameOrigins(in: scrollView).contains(0))
        _ = window
    }

    @Test
    func slowDragSettlesToNearestPage() throws {
        let box = PageBox(0)
        let controller = makeController()
        let scrollView = try pagerScrollView(in: controller)

        controller.apply(
            dataSource: dataSource(count: 4),
            page: box.binding,
            configuration: SwiftPagerConfiguration(),
            content: { Text("\($0)") }
        )

        var targetOffset = CGPoint(x: 40, y: 0)
        controller.scrollViewWillEndDragging(
            scrollView,
            withVelocity: CGPoint(x: 0.1, y: 0),
            targetContentOffset: &targetOffset
        )

        #expect(Int(targetOffset.x.rounded()) == 0)
    }

    @Test
    func flickVelocityAdvancesBeforeMidpoint() throws {
        let box = PageBox(0)
        let controller = makeController()
        let scrollView = try pagerScrollView(in: controller)

        controller.apply(
            dataSource: dataSource(count: 4),
            page: box.binding,
            configuration: SwiftPagerConfiguration(),
            content: { Text("\($0)") }
        )

        var targetOffset = CGPoint(x: 30, y: 0)
        controller.scrollViewWillEndDragging(
            scrollView,
            withVelocity: CGPoint(x: 0.5, y: 0),
            targetContentOffset: &targetOffset
        )

        #expect(Int(targetOffset.x.rounded()) == 100)
    }

    @Test
    func flickVelocityDoesNotSkipPastAdjacentPage() throws {
        let box = PageBox(0)
        let controller = makeController()
        let scrollView = try pagerScrollView(in: controller)

        controller.apply(
            dataSource: dataSource(count: 4),
            page: box.binding,
            configuration: SwiftPagerConfiguration(),
            content: { Text("\($0)") }
        )

        controller.scrollViewWillBeginDragging(scrollView)
        scrollView.contentOffset = CGPoint(x: 60, y: 0)

        var targetOffset = CGPoint(x: 280, y: 0)
        controller.scrollViewWillEndDragging(
            scrollView,
            withVelocity: CGPoint(x: 0.5, y: 0),
            targetContentOffset: &targetOffset
        )

        #expect(Int(targetOffset.x.rounded()) == 100)
    }

    @Test
    func externalPageChangeDuringDragClearsStaleDragStartIndex() throws {
        let box = PageBox(0)
        let controller = makeController()
        let scrollView = try pagerScrollView(in: controller)

        controller.apply(
            dataSource: dataSource(count: 5),
            page: box.binding,
            configuration: SwiftPagerConfiguration(),
            content: { Text("\($0)") }
        )

        controller.scrollViewWillBeginDragging(scrollView)

        box.value = 3
        controller.apply(
            dataSource: dataSource(count: 5),
            page: box.binding,
            configuration: SwiftPagerConfiguration(),
            content: { Text("\($0)") }
        )

        var targetOffset = CGPoint(x: 300, y: 0)
        controller.scrollViewWillEndDragging(
            scrollView,
            withVelocity: CGPoint(x: 0.5, y: 0),
            targetContentOffset: &targetOffset
        )

        #expect(Int(targetOffset.x.rounded()) == 400)
    }

    @Test
    func flickPrewarmsAheadOfCurrentPage() throws {
        let box = PageBox(0)
        let controller = makeController()
        let scrollView = try pagerScrollView(in: controller)

        controller.apply(
            dataSource: dataSource(count: 6),
            page: box.binding,
            configuration: SwiftPagerConfiguration(preloadDistance: 1, retentionDistance: 1),
            content: { Text("\($0)") }
        )

        #expect(horizontalFrameOrigins(in: scrollView) == [0, 100])

        controller.scrollViewWillBeginDragging(scrollView)
        var targetOffset = CGPoint(x: 30, y: 0)
        controller.scrollViewWillEndDragging(
            scrollView,
            withVelocity: CGPoint(x: 0.5, y: 0),
            targetContentOffset: &targetOffset
        )

        #expect(horizontalFrameOrigins(in: scrollView) == [0, 100, 200])
    }

    @Test
    func dragProgressPrewarmsAheadBeforeNearestPageChanges() throws {
        let box = PageBox(0)
        let controller = makeController()
        let scrollView = try pagerScrollView(in: controller)

        controller.apply(
            dataSource: dataSource(count: 6),
            page: box.binding,
            configuration: SwiftPagerConfiguration(preloadDistance: 1, retentionDistance: 1),
            content: { Text("\($0)") }
        )

        #expect(horizontalFrameOrigins(in: scrollView) == [0, 100])

        controller.scrollViewWillBeginDragging(scrollView)
        scrollView.contentOffset = CGPoint(x: 6, y: 0)
        controller.scrollViewDidScroll(scrollView)

        #expect(horizontalFrameOrigins(in: scrollView) == [0, 100, 200])
        #expect(box.value == 0)
    }

    @Test
    func animatedProgrammaticScrollPrewarmsTowardTargetPage() throws {
        let box = PageBox(0)
        let pagerController = SwiftPagerController()
        let controller = makeController()
        let window = attachToWindow(controller)
        let scrollView = try pagerScrollView(in: controller)

        controller.apply(
            dataSource: dataSource(count: 6),
            page: box.binding,
            controller: pagerController,
            configuration: SwiftPagerConfiguration(preloadDistance: 1, retentionDistance: 1),
            content: { Text("\($0)") }
        )

        #expect(horizontalFrameOrigins(in: scrollView) == [0, 100])

        pagerController.scrollToPage(4, animated: true)

        #expect(horizontalFrameOrigins(in: scrollView) == [0, 100, 200])
        _ = window
    }

    @Test
    func dragBeginRestoresSymmetricWindowAfterBiasedPrewarm() throws {
        let box = PageBox(5)
        let pagerController = SwiftPagerController()
        let controller = makeController()
        let window = attachToWindow(controller)
        let scrollView = try pagerScrollView(in: controller)
        var stateChanges: [SwiftPagerState] = []

        controller.apply(
            dataSource: dataSource(count: 8),
            page: box.binding,
            controller: pagerController,
            callbacks: PagerCallbacks(onPagerStateChange: { stateChanges.append($0) }),
            configuration: SwiftPagerConfiguration(preloadDistance: 1, retentionDistance: 1),
            content: { Text("\($0)") }
        )

        pagerController.scrollToPage(7, animated: true)

        #expect(horizontalFrameOrigins(in: scrollView) == [500, 600, 700])

        controller.scrollViewWillBeginDragging(scrollView)

        #expect(horizontalFrameOrigins(in: scrollView) == [400, 500, 600])
        #expect(box.value == 5)
        #expect(pagerController.currentPage == 5)
        #expect(stateChanges.last?.currentPage == 5)
        #expect(stateChanges.last?.targetPage == nil)
        _ = window
    }

    @Test
    func backwardFlickPrewarmsBehindCurrentPage() throws {
        let box = PageBox(4)
        let controller = makeController()
        let scrollView = try pagerScrollView(in: controller)

        controller.apply(
            dataSource: dataSource(count: 6),
            page: box.binding,
            configuration: SwiftPagerConfiguration(preloadDistance: 1, retentionDistance: 1),
            content: { Text("\($0)") }
        )

        #expect(horizontalFrameOrigins(in: scrollView) == [300, 400, 500])

        controller.scrollViewWillBeginDragging(scrollView)
        var targetOffset = CGPoint(x: 370, y: 0)
        controller.scrollViewWillEndDragging(
            scrollView,
            withVelocity: CGPoint(x: -0.5, y: 0),
            targetContentOffset: &targetOffset
        )

        #expect(horizontalFrameOrigins(in: scrollView) == [200, 300, 400])
    }

    @Test
    func verticalFlickPrewarmsAheadOfCurrentPage() throws {
        let box = PageBox(0)
        let controller = makeController()
        let scrollView = try pagerScrollView(in: controller)

        controller.apply(
            dataSource: dataSource(count: 6),
            page: box.binding,
            configuration: SwiftPagerConfiguration(direction: .vertical, preloadDistance: 1, retentionDistance: 1),
            content: { Text("\($0)") }
        )

        #expect(verticalFrameOrigins(in: scrollView) == [0, 100])

        controller.scrollViewWillBeginDragging(scrollView)
        var targetOffset = CGPoint(x: 0, y: 30)
        controller.scrollViewWillEndDragging(
            scrollView,
            withVelocity: CGPoint(x: 0, y: 0.5),
            targetContentOffset: &targetOffset
        )

        #expect(verticalFrameOrigins(in: scrollView) == [0, 100, 200])
    }

    @Test
    func pagerControllerScrollsByIndexAndID() throws {
        let box = PageBox(0)
        let pagerController = SwiftPagerController()
        let controller = makeController()
        let scrollView = try pagerScrollView(in: controller)

        controller.apply(
            dataSource: dataSource(count: 5),
            page: box.binding,
            controller: pagerController,
            configuration: SwiftPagerConfiguration(),
            content: { Text("\($0)") }
        )

        pagerController.scrollToPage(3, animated: false)

        #expect(box.value == 3)
        #expect(pagerController.currentPage == 3)
        #expect(pagerController.loadedPages.map(\.index) == [2, 3, 4])
        #expect(pagerController.indexOfPage(id: 4) == 4)
        #expect(Int(scrollView.contentOffset.x.rounded()) == 300)

        pagerController.scrollToPage(id: 1, animated: false)

        #expect(box.value == 1)
        #expect(pagerController.currentPage == 1)
        #expect(Int(scrollView.contentOffset.x.rounded()) == 100)
    }

    @Test
    func callbacksPublishPageStateAndScrollPhaseChanges() throws {
        let box = PageBox(0)
        let pagerController = SwiftPagerController()
        let controller = makeController()
        let scrollView = try pagerScrollView(in: controller)
        var pageChanges: [Int] = []
        var stateChanges: [SwiftPagerState] = []
        var phaseChanges: [SwiftPagerScrollPhase] = []
        let callbacks = PagerCallbacks(
            onPageChange: { pageChanges.append($0) },
            onPagerStateChange: { stateChanges.append($0) },
            onScrollPhaseChange: { phaseChanges.append($0) }
        )

        controller.apply(
            dataSource: dataSource(count: 4),
            page: box.binding,
            controller: pagerController,
            callbacks: callbacks,
            configuration: SwiftPagerConfiguration(),
            content: { Text("\($0)") }
        )

        #expect(pageChanges.isEmpty)
        #expect(phaseChanges.isEmpty)
        #expect(stateChanges.last?.currentPage == 0)
        #expect(stateChanges.last?.scrollPhase == .idle)
        #expect(stateChanges.last?.direction == .horizontal)
        #expect(stateChanges.last?.visibleFraction == 1)
        #expect(stateChanges.last?.pageSize == CGSize(width: 100, height: 100))

        pagerController.scrollToPage(2, animated: false)

        #expect(pageChanges == [2])
        #expect(stateChanges.last?.currentPage == 2)

        controller.scrollViewWillBeginDragging(scrollView)

        #expect(phaseChanges == [.dragging])
        #expect(stateChanges.last?.scrollPhase == .dragging)

        var targetOffset = CGPoint(x: 300, y: 0)
        controller.scrollViewWillEndDragging(
            scrollView,
            withVelocity: CGPoint(x: 0.5, y: 0),
            targetContentOffset: &targetOffset
        )
        controller.scrollViewDidEndDragging(scrollView, willDecelerate: true)

        #expect(phaseChanges == [.dragging, .decelerating])
        #expect(stateChanges.last?.targetPage == 3)

        scrollView.contentOffset = targetOffset
        controller.scrollViewDidEndDecelerating(scrollView)

        #expect(phaseChanges == [.dragging, .decelerating, .idle])
        #expect(stateChanges.last?.targetPage == nil)
    }

    @Test
    func layoutPublishesResolvedPageSize() throws {
        let box = PageBox(0)
        let controller = PagerViewController<Int, Text>()
        controller.loadViewIfNeeded()
        controller.view.frame = .zero
        controller.view.layoutIfNeeded()
        var stateChanges: [SwiftPagerState] = []

        controller.apply(
            dataSource: dataSource(count: 3),
            page: box.binding,
            callbacks: PagerCallbacks(onPagerStateChange: { stateChanges.append($0) }),
            configuration: SwiftPagerConfiguration(),
            content: { Text("\($0)") }
        )

        #expect(stateChanges.last?.pageSize == .zero)

        controller.view.frame = CGRect(x: 0, y: 0, width: 120, height: 80)
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()

        #expect(stateChanges.last?.pageSize == CGSize(width: 120, height: 80))
    }

    @Test
    func layoutSizeChangeDoesNotSnapOffsetWhileDragging() throws {
        let box = PageBox(1)
        let controller = makeController()
        let scrollView = try pagerScrollView(in: controller)

        controller.apply(
            dataSource: dataSource(count: 4),
            page: box.binding,
            configuration: SwiftPagerConfiguration(),
            content: { Text("\($0)") }
        )

        controller.scrollViewWillBeginDragging(scrollView)
        scrollView.contentOffset = CGPoint(x: 150, y: 0)
        controller.scrollViewDidScroll(scrollView)
        controller.view.frame = CGRect(x: 0, y: 0, width: 120, height: 100)
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()

        #expect(scrollView.contentOffset.x == 180)
        #expect(box.value == 1)
    }

    @Test
    func layoutSizeChangeDuringSnapAnimationFinishesAtTarget() throws {
        let box = PageBox(0)
        let controller = makeController()
        let window = attachToWindow(controller)
        let scrollView = try pagerScrollView(in: controller)

        controller.apply(
            dataSource: dataSource(count: 4),
            page: box.binding,
            configuration: SwiftPagerConfiguration(),
            content: { Text("\($0)") }
        )

        controller.scrollViewWillBeginDragging(scrollView)
        scrollView.contentOffset = CGPoint(x: 60, y: 0)
        controller.scrollViewDidScroll(scrollView)

        var targetOffset = CGPoint(x: 100, y: 0)
        controller.scrollViewWillEndDragging(
            scrollView,
            withVelocity: .zero,
            targetContentOffset: &targetOffset
        )
        controller.scrollViewDidEndDragging(scrollView, willDecelerate: false)

        controller.view.frame = CGRect(x: 0, y: 0, width: 120, height: 100)
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()

        #expect(scrollView.contentOffset.x == 120)
        #expect(controller.pagerState.scrollPhase == .idle)
        #expect(controller.pagerState.targetPage == nil)
        _ = window
    }

    @Test
    func layoutSizeChangePreservesProgrammaticAnimationTarget() throws {
        let box = PageBox(0)
        let pagerController = SwiftPagerController()
        let controller = makeController()
        let window = attachToWindow(controller)
        let scrollView = try pagerScrollView(in: controller)
        var stateChanges: [SwiftPagerState] = []

        controller.apply(
            dataSource: dataSource(count: 4),
            page: box.binding,
            controller: pagerController,
            callbacks: PagerCallbacks(onPagerStateChange: { stateChanges.append($0) }),
            configuration: SwiftPagerConfiguration(),
            content: { Text("\($0)") }
        )

        pagerController.scrollToPage(3, animated: true)
        #expect(stateChanges.last?.scrollPhase == .animating)
        controller.view.frame = CGRect(x: 0, y: 0, width: 120, height: 100)
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()

        #expect(scrollView.contentOffset.x == 360)
        #expect(box.value == 3)
        #expect(stateChanges.last?.scrollPhase == .idle)
        #expect(stateChanges.last?.targetPage == nil)
        _ = window
    }

    @Test
    func layoutSizeChangeDuringPartialProgrammaticAnimationFinishesAtTarget() throws {
        let box = PageBox(0)
        let pagerController = SwiftPagerController()
        let controller = makeController()
        let window = attachToWindow(controller)
        let scrollView = try pagerScrollView(in: controller)
        var stateChanges: [SwiftPagerState] = []

        controller.apply(
            dataSource: dataSource(count: 4),
            page: box.binding,
            controller: pagerController,
            callbacks: PagerCallbacks(onPagerStateChange: { stateChanges.append($0) }),
            configuration: SwiftPagerConfiguration(),
            content: { Text("\($0)") }
        )

        pagerController.scrollToPage(3, animated: true)
        scrollView.contentOffset = CGPoint(x: 150, y: 0)
        controller.scrollViewDidScroll(scrollView)

        controller.view.frame = CGRect(x: 0, y: 0, width: 120, height: 100)
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()

        #expect(scrollView.contentOffset.x == 360)
        #expect(stateChanges.last?.scrollPhase == .idle)
        #expect(stateChanges.last?.targetPage == nil)
        _ = window
    }

    @Test
    func sameSizeLayoutDuringProgrammaticAnimationDoesNotFinishEarly() throws {
        let box = PageBox(0)
        let pagerController = SwiftPagerController()
        let controller = makeController()
        let window = attachToWindow(controller)
        let scrollView = try pagerScrollView(in: controller)
        var stateChanges: [SwiftPagerState] = []

        controller.apply(
            dataSource: dataSource(count: 4),
            page: box.binding,
            controller: pagerController,
            callbacks: PagerCallbacks(onPagerStateChange: { stateChanges.append($0) }),
            configuration: SwiftPagerConfiguration(),
            content: { Text("\($0)") }
        )

        pagerController.scrollToPage(3, animated: true)
        scrollView.contentOffset = CGPoint(x: 150, y: 0)
        controller.scrollViewDidScroll(scrollView)
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()

        #expect(scrollView.contentOffset.x == 150)
        #expect(stateChanges.last?.scrollPhase == .animating)
        #expect(stateChanges.last?.targetPage == 3)
        _ = window
    }

    @Test
    func reapplyDuringProgrammaticAnimationPreservesMatchingTargetAnimation() throws {
        let box = PageBox(0)
        let pagerController = SwiftPagerController()
        let controller = makeController()
        let window = attachToWindow(controller)
        let scrollView = try pagerScrollView(in: controller)
        var stateChanges: [SwiftPagerState] = []

        controller.apply(
            dataSource: dataSource(count: 4),
            page: box.binding,
            controller: pagerController,
            callbacks: PagerCallbacks(onPagerStateChange: { stateChanges.append($0) }),
            configuration: SwiftPagerConfiguration(),
            content: { Text("\($0)") }
        )

        pagerController.scrollToPage(3, animated: true)
        #expect(stateChanges.last?.scrollPhase == .animating)
        #expect(stateChanges.last?.targetPage == 3)

        controller.apply(
            dataSource: dataSource(count: 4),
            page: box.binding,
            controller: pagerController,
            callbacks: PagerCallbacks(onPagerStateChange: { stateChanges.append($0) }),
            configuration: SwiftPagerConfiguration(),
            content: { Text("\($0)") }
        )

        #expect(box.value == 3)
        #expect(stateChanges.last?.scrollPhase == .animating)
        #expect(stateChanges.last?.targetPage == 3)

        scrollView.contentOffset = CGPoint(x: 300, y: 0)
        controller.scrollViewDidEndScrollingAnimation(scrollView)

        #expect(stateChanges.last?.scrollPhase == .idle)
        #expect(stateChanges.last?.targetPage == nil)
        _ = window
    }

    @Test
    func reapplyDuringPartialProgrammaticAnimationPreservesMatchingTargetAnimation() throws {
        let box = PageBox(0)
        let pagerController = SwiftPagerController()
        let controller = makeController()
        let window = attachToWindow(controller)
        let scrollView = try pagerScrollView(in: controller)
        var stateChanges: [SwiftPagerState] = []

        controller.apply(
            dataSource: dataSource(count: 4),
            page: box.binding,
            controller: pagerController,
            callbacks: PagerCallbacks(onPagerStateChange: { stateChanges.append($0) }),
            configuration: SwiftPagerConfiguration(),
            content: { Text("\($0)") }
        )

        pagerController.scrollToPage(3, animated: true)
        scrollView.contentOffset = CGPoint(x: 150, y: 0)
        controller.scrollViewDidScroll(scrollView)

        let reapplyStartIndex = stateChanges.count
        controller.apply(
            dataSource: dataSource(count: 4),
            page: box.binding,
            controller: pagerController,
            callbacks: PagerCallbacks(onPagerStateChange: { stateChanges.append($0) }),
            configuration: SwiftPagerConfiguration(),
            content: { Text("\($0)") }
        )

        #expect(scrollView.contentOffset.x == 150)
        #expect(!stateChanges[reapplyStartIndex...].contains {
            $0.scrollPhase == .idle || $0.targetPage == nil
        })
        #expect(stateChanges.last?.currentPage == 3)
        #expect(stateChanges.last?.scrollPhase == .animating)
        #expect(stateChanges.last?.targetPage == 3)

        scrollView.contentOffset = CGPoint(x: 300, y: 0)
        controller.scrollViewDidEndScrollingAnimation(scrollView)

        #expect(stateChanges.last?.scrollPhase == .idle)
        #expect(stateChanges.last?.targetPage == nil)
        _ = window
    }

    @Test
    func reapplyAtProgrammaticTargetOffsetWaitsForAnimationEndDelegate() throws {
        let box = PageBox(0)
        let pagerController = SwiftPagerController()
        let controller = makeController()
        let window = attachToWindow(controller)
        let scrollView = try pagerScrollView(in: controller)
        var stateChanges: [SwiftPagerState] = []

        controller.apply(
            dataSource: dataSource(count: 4),
            page: box.binding,
            controller: pagerController,
            callbacks: PagerCallbacks(onPagerStateChange: { stateChanges.append($0) }),
            configuration: SwiftPagerConfiguration(),
            content: { Text("\($0)") }
        )

        pagerController.scrollToPage(3, animated: true)
        scrollView.contentOffset = CGPoint(x: 300, y: 0)
        controller.scrollViewDidScroll(scrollView)

        let reapplyStartIndex = stateChanges.count
        controller.apply(
            dataSource: dataSource(count: 4),
            page: box.binding,
            controller: pagerController,
            callbacks: PagerCallbacks(onPagerStateChange: { stateChanges.append($0) }),
            configuration: SwiftPagerConfiguration(),
            content: { Text("\($0)") }
        )

        #expect(scrollView.contentOffset.x == 300)
        #expect(!stateChanges[reapplyStartIndex...].contains {
            $0.scrollPhase == .idle || $0.targetPage == nil
        })
        #expect(stateChanges.last?.scrollPhase == .animating)
        #expect(stateChanges.last?.targetPage == 3)

        controller.scrollViewDidEndScrollingAnimation(scrollView)

        #expect(stateChanges.last?.scrollPhase == .idle)
        #expect(stateChanges.last?.targetPage == nil)
        _ = window
    }

    @Test
    func externalApplyToCurrentInFlightOffsetCancelsProgrammaticAnimation() throws {
        let box = PageBox(0)
        let pagerController = SwiftPagerController()
        let controller = makeController()
        let window = attachToWindow(controller)
        let scrollView = try pagerScrollView(in: controller)
        var stateChanges: [SwiftPagerState] = []

        controller.apply(
            dataSource: dataSource(count: 4),
            page: box.binding,
            controller: pagerController,
            callbacks: PagerCallbacks(onPagerStateChange: { stateChanges.append($0) }),
            configuration: SwiftPagerConfiguration(),
            content: { Text("\($0)") }
        )

        pagerController.scrollToPage(3, animated: true)
        scrollView.contentOffset = CGPoint(x: 100.25, y: 0)
        controller.scrollViewDidScroll(scrollView)

        box.value = 1
        let reapplyStartIndex = stateChanges.count
        controller.apply(
            dataSource: dataSource(count: 4),
            page: box.binding,
            controller: pagerController,
            callbacks: PagerCallbacks(onPagerStateChange: { stateChanges.append($0) }),
            configuration: SwiftPagerConfiguration(),
            content: { Text("\($0)") }
        )

        #expect(scrollView.contentOffset.x == 100)
        #expect(!stateChanges[reapplyStartIndex...].contains {
            $0.currentPage == 0 && $0.scrollPhase == .animating
        })
        #expect(stateChanges.last?.currentPage == 1)
        #expect(stateChanges.last?.scrollPhase == .idle)
        #expect(stateChanges.last?.targetPage == nil)
        _ = window
    }

    @Test
    func externalApplyToDifferentPageDuringProgrammaticAnimationCancelsAnimation() throws {
        let box = PageBox(0)
        let pagerController = SwiftPagerController()
        let controller = makeController()
        let window = attachToWindow(controller)
        let scrollView = try pagerScrollView(in: controller)
        var stateChanges: [SwiftPagerState] = []

        controller.apply(
            dataSource: dataSource(count: 4),
            page: box.binding,
            controller: pagerController,
            callbacks: PagerCallbacks(onPagerStateChange: { stateChanges.append($0) }),
            configuration: SwiftPagerConfiguration(),
            content: { Text("\($0)") }
        )

        pagerController.scrollToPage(3, animated: true)
        scrollView.contentOffset = CGPoint(x: 150, y: 0)
        controller.scrollViewDidScroll(scrollView)

        box.value = 2
        let reapplyStartIndex = stateChanges.count
        controller.apply(
            dataSource: dataSource(count: 4),
            page: box.binding,
            controller: pagerController,
            callbacks: PagerCallbacks(onPagerStateChange: { stateChanges.append($0) }),
            configuration: SwiftPagerConfiguration(),
            content: { Text("\($0)") }
        )

        #expect(scrollView.contentOffset.x == 200)
        #expect(!stateChanges[reapplyStartIndex...].contains {
            $0.scrollPhase == .animating || $0.targetPage != nil
        })
        #expect(stateChanges.last?.currentPage == 2)
        #expect(stateChanges.last?.scrollPhase == .idle)
        #expect(stateChanges.last?.targetPage == nil)
        _ = window
    }

    @Test
    func dataShrinkDuringProgrammaticAnimationSettlesInterruptedState() throws {
        let box = PageBox(0)
        let pagerController = SwiftPagerController()
        let controller = makeController()
        let window = attachToWindow(controller)
        let scrollView = try pagerScrollView(in: controller)
        var stateChanges: [SwiftPagerState] = []

        controller.apply(
            dataSource: dataSource(count: 4),
            page: box.binding,
            controller: pagerController,
            callbacks: PagerCallbacks(onPagerStateChange: { stateChanges.append($0) }),
            configuration: SwiftPagerConfiguration(),
            content: { Text("\($0)") }
        )

        pagerController.scrollToPage(3, animated: true)
        #expect(stateChanges.last?.targetPage == 3)
        scrollView.contentOffset = CGPoint(x: 150, y: 0)
        controller.scrollViewDidScroll(scrollView)

        controller.apply(
            dataSource: dataSource(count: 3),
            page: box.binding,
            controller: pagerController,
            callbacks: PagerCallbacks(onPagerStateChange: { stateChanges.append($0) }),
            configuration: SwiftPagerConfiguration(),
            content: { Text("\($0)") }
        )

        #expect(scrollView.contentOffset.x == 200)
        #expect(stateChanges.last?.pageCount == 3)
        #expect(stateChanges.last?.currentPage == 2)
        #expect(stateChanges.last?.scrollPhase == .idle)
        #expect(stateChanges.last?.targetPage == nil)
        #expect(pagerController.state.targetPage == nil)
        _ = window
    }

    @Test
    func dataShrinkWhileDraggingClampsLiveOffsetToNewBounds() throws {
        let box = PageBox(2)
        let controller = makeController()
        let scrollView = try pagerScrollView(in: controller)

        controller.apply(
            dataSource: dataSource(count: 4),
            page: box.binding,
            configuration: SwiftPagerConfiguration(),
            content: { Text("\($0)") }
        )

        controller.scrollViewWillBeginDragging(scrollView)
        scrollView.contentOffset = CGPoint(x: 350, y: 0)
        controller.scrollViewDidScroll(scrollView)

        controller.apply(
            dataSource: dataSource(count: 2),
            page: box.binding,
            configuration: SwiftPagerConfiguration(),
            content: { Text("\($0)") }
        )

        #expect(scrollView.contentOffset.x == 100)
        #expect(controller.pagerState.currentPage == 1)
        #expect(controller.pagerState.targetPage == nil)
    }

    @Test
    func decelerationEndSnapPreservesPositionUntilAnimationCompletes() throws {
        let box = PageBox(0)
        let controller = makeController()
        let window = attachToWindow(controller)
        let scrollView = try pagerScrollView(in: controller)
        var stateChanges: [SwiftPagerState] = []

        controller.apply(
            dataSource: dataSource(count: 3),
            page: box.binding,
            callbacks: PagerCallbacks(onPagerStateChange: { stateChanges.append($0) }),
            configuration: SwiftPagerConfiguration(),
            content: { Text("\($0)") }
        )

        controller.scrollViewWillBeginDragging(scrollView)
        scrollView.contentOffset = CGPoint(x: 60, y: 0)
        controller.scrollViewDidScroll(scrollView)

        var targetOffset = CGPoint(x: 100, y: 0)
        controller.scrollViewWillEndDragging(
            scrollView,
            withVelocity: .zero,
            targetContentOffset: &targetOffset
        )
        controller.scrollViewDidEndDragging(scrollView, willDecelerate: true)
        controller.scrollViewDidEndDecelerating(scrollView)

        #expect(stateChanges.last?.currentPage == 1)
        #expect(stateChanges.last?.targetPage == 1)
        #expect(stateChanges.last?.scrollPhase == .animating)

        controller.view.frame = CGRect(x: 0, y: 0, width: 120, height: 100)
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()

        #expect(scrollView.contentOffset.x == 120)
        #expect(stateChanges.last?.scrollPhase == .idle)
        #expect(stateChanges.last?.targetPage == nil)
        _ = window
    }

    @Test
    func verticalLayoutSizeChangePreservesPositionWhileDragging() throws {
        let box = PageBox(1)
        let controller = makeController()
        let scrollView = try pagerScrollView(in: controller)

        controller.apply(
            dataSource: dataSource(count: 4),
            page: box.binding,
            configuration: SwiftPagerConfiguration(direction: .vertical),
            content: { Text("\($0)") }
        )

        controller.scrollViewWillBeginDragging(scrollView)
        scrollView.contentOffset = CGPoint(x: 0, y: 150)
        controller.scrollViewDidScroll(scrollView)
        controller.view.frame = CGRect(x: 0, y: 0, width: 100, height: 120)
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()

        #expect(scrollView.contentOffset.y == 180)
        #expect(box.value == 1)
    }

    @Test
    func onContinuousPageChangePublishesDuringSamePageScroll() async throws {
        let box = PageBox(0)
        let controller = makeController()
        let scrollView = try pagerScrollView(in: controller)
        var positions: [CGFloat] = []
        var settings = SwiftPagerSettings<Int>()
        settings.onContinuousPageChange = { positions.append($0) }

        controller.apply(
            dataSource: dataSource(count: 3),
            page: box.binding,
            settings: settings,
            configuration: SwiftPagerConfiguration(),
            content: { Text("\($0)") }
        )

        scrollView.contentOffset = CGPoint(x: 25, y: 0)
        controller.scrollViewDidScroll(scrollView)

        await waitUntil {
            positions.contains(0.25)
        }

        #expect(positions.contains(0.25))
    }

    @Test
    func onStateChangeDoesNotPublishVisibleFractionOnlyChanges() throws {
        let box = PageBox(0)
        let controller = makeController()
        let scrollView = try pagerScrollView(in: controller)
        var stateChanges: [SwiftPagerState] = []

        controller.apply(
            dataSource: dataSource(count: 3),
            page: box.binding,
            callbacks: PagerCallbacks(onPagerStateChange: { stateChanges.append($0) }),
            configuration: SwiftPagerConfiguration(),
            content: { Text("\($0)") }
        )

        let countAfterInitialState = stateChanges.count
        scrollView.contentOffset = CGPoint(x: 25, y: 0)
        controller.scrollViewDidScroll(scrollView)

        #expect(stateChanges.count == countAfterInitialState)
        #expect(abs(controller.pagerState.visibleFraction - 0.75) < 0.001)
    }

    @Test
    func controllerStateDoesNotPublishVisibleFractionOnlyChanges() throws {
        let box = PageBox(0)
        let pagerController = SwiftPagerController()
        let controller = makeController()
        let scrollView = try pagerScrollView(in: controller)
        var publishedStates: [SwiftPagerState] = []

        controller.apply(
            dataSource: dataSource(count: 3),
            page: box.binding,
            controller: pagerController,
            configuration: SwiftPagerConfiguration(),
            content: { Text("\($0)") }
        )

        let cancellable = pagerController.$state.dropFirst().sink {
            publishedStates.append($0)
        }

        scrollView.contentOffset = CGPoint(x: 25, y: 0)
        controller.scrollViewDidScroll(scrollView)

        #expect(publishedStates.isEmpty)

        pagerController.scrollToPage(1, animated: false)

        #expect(publishedStates.last?.currentPage == 1)
        withExtendedLifetime(cancellable) {}
    }

    @Test
    func nonDeceleratingDragReportsAnimatingUntilSnapCompletes() throws {
        let box = PageBox(0)
        let controller = makeController()
        let window = attachToWindow(controller)
        let scrollView = try pagerScrollView(in: controller)
        var stateChanges: [SwiftPagerState] = []

        controller.apply(
            dataSource: dataSource(count: 3),
            page: box.binding,
            callbacks: PagerCallbacks(onPagerStateChange: { stateChanges.append($0) }),
            configuration: SwiftPagerConfiguration(),
            content: { Text("\($0)") }
        )

        controller.scrollViewWillBeginDragging(scrollView)
        scrollView.contentOffset = CGPoint(x: 60, y: 0)

        var targetOffset = CGPoint(x: 60, y: 0)
        controller.scrollViewWillEndDragging(
            scrollView,
            withVelocity: .zero,
            targetContentOffset: &targetOffset
        )
        controller.scrollViewDidEndDragging(scrollView, willDecelerate: false)

        #expect(stateChanges.last?.currentPage == 1)
        #expect(stateChanges.last?.targetPage == 1)
        #expect(stateChanges.last?.scrollPhase == .animating)

        scrollView.contentOffset = CGPoint(x: 100, y: 0)
        controller.scrollViewDidEndScrollingAnimation(scrollView)

        #expect(stateChanges.last?.targetPage == nil)
        #expect(stateChanges.last?.scrollPhase == .idle)
        _ = window
    }

    @Test
    func scrollingToVisiblePageDoesNotEnterAnimatingPhase() throws {
        let box = PageBox(1)
        let pagerController = SwiftPagerController(initialPage: 1)
        let controller = makeController()
        let window = attachToWindow(controller)
        var stateChanges: [SwiftPagerState] = []

        controller.apply(
            dataSource: dataSource(count: 3),
            page: box.binding,
            controller: pagerController,
            callbacks: PagerCallbacks(onPagerStateChange: { stateChanges.append($0) }),
            configuration: SwiftPagerConfiguration(),
            content: { Text("\($0)") }
        )

        pagerController.scrollToPage(1, animated: true)

        #expect(stateChanges.last?.currentPage == 1)
        #expect(stateChanges.last?.targetPage == nil)
        #expect(stateChanges.last?.scrollPhase == .idle)
        _ = window
    }

    @Test
    func pendingControllerScrollAppliesAfterInitialAttach() async throws {
        let box = PageBox(0)
        let pagerController = SwiftPagerController()
        let controller = makeController()
        let scrollView = try pagerScrollView(in: controller)

        pagerController.scrollToPage(3, animated: false)

        controller.apply(
            dataSource: dataSource(count: 5),
            page: box.binding,
            controller: pagerController,
            configuration: SwiftPagerConfiguration(),
            content: { Text("\($0)") }
        )

        await waitUntil {
            box.value == 3 && pagerController.currentPage == 3
        }

        #expect(box.value == 3)
        #expect(pagerController.currentPage == 3)
        #expect(Int(scrollView.contentOffset.x.rounded()) == 300)
    }

    @Test
    func pendingControllerIDScrollAppliesAfterInitialAttach() async throws {
        let box = PageBox(0)
        let pagerController = SwiftPagerController()
        let controller = makeController()
        let scrollView = try pagerScrollView(in: controller)

        pagerController.scrollToPage(id: 13, animated: false)

        controller.apply(
            dataSource: dataSource(ids: [10, 11, 12, 13, 14]),
            page: box.binding,
            controller: pagerController,
            configuration: SwiftPagerConfiguration(),
            content: { Text("\($0)") }
        )

        await waitUntil {
            box.value == 3 && pagerController.currentPage == 3
        }

        #expect(box.value == 3)
        #expect(pagerController.currentPage == 3)
        #expect(Int(scrollView.contentOffset.x.rounded()) == 300)
    }

    @Test
    func pendingControllerScrollAppliesAfterDetachAndReattach() async throws {
        let firstBox = PageBox(0)
        let pagerController = SwiftPagerController()
        let firstController = makeController()

        firstController.apply(
            dataSource: dataSource(count: 5),
            page: firstBox.binding,
            controller: pagerController,
            configuration: SwiftPagerConfiguration(),
            content: { Text("\($0)") }
        )

        firstController.teardown()
        pagerController.scrollToPage(3, animated: false)

        let secondBox = PageBox(0)
        let secondController = makeController()
        let secondScrollView = try pagerScrollView(in: secondController)
        secondController.apply(
            dataSource: dataSource(count: 5),
            page: secondBox.binding,
            controller: pagerController,
            configuration: SwiftPagerConfiguration(),
            content: { Text("\($0)") }
        )

        await waitUntil {
            secondBox.value == 3 && pagerController.currentPage == 3
        }

        #expect(secondBox.value == 3)
        #expect(pagerController.currentPage == 3)
        #expect(Int(secondScrollView.contentOffset.x.rounded()) == 300)
    }

    @Test
    func pendingControllerIDScrollSurvivesEmptyDetachAndReattach() async throws {
        let firstBox = PageBox(0)
        let pagerController = SwiftPagerController()
        let firstController = makeController()

        firstController.apply(
            dataSource: dataSource(count: 0),
            page: firstBox.binding,
            controller: pagerController,
            configuration: SwiftPagerConfiguration(),
            content: { Text("\($0)") }
        )

        pagerController.scrollToPage(id: 13, animated: false)
        firstController.teardown()

        let secondBox = PageBox(0)
        let secondController = makeController()
        let secondScrollView = try pagerScrollView(in: secondController)

        secondController.apply(
            dataSource: dataSource(ids: [10, 11, 12, 13, 14]),
            page: secondBox.binding,
            controller: pagerController,
            configuration: SwiftPagerConfiguration(),
            content: { Text("\($0)") }
        )

        await waitUntil {
            secondBox.value == 3 && pagerController.currentPage == 3
        }

        #expect(secondBox.value == 3)
        #expect(pagerController.currentPage == 3)
        #expect(Int(secondScrollView.contentOffset.x.rounded()) == 300)
    }

    @Test
    func externalAnimatedApplyAtCurrentOffsetDoesNotEnterAnimatingPhase() throws {
        let box = PageBox(0)
        let controller = makeController()
        let window = attachToWindow(controller)
        let scrollView = try pagerScrollView(in: controller)
        var stateChanges: [SwiftPagerState] = []

        controller.apply(
            dataSource: dataSource(count: 3),
            page: box.binding,
            callbacks: PagerCallbacks(onPagerStateChange: { stateChanges.append($0) }),
            configuration: SwiftPagerConfiguration(),
            content: { Text("\($0)") }
        )

        scrollView.contentOffset = CGPoint(x: 100, y: 0)
        box.value = 1

        controller.apply(
            dataSource: dataSource(count: 3),
            page: box.binding,
            callbacks: PagerCallbacks(onPagerStateChange: { stateChanges.append($0) }),
            configuration: SwiftPagerConfiguration(),
            content: { Text("\($0)") },
            animated: true
        )

        #expect(stateChanges.last?.currentPage == 1)
        #expect(stateChanges.last?.targetPage == nil)
        #expect(stateChanges.last?.scrollPhase == .idle)
        _ = window
    }

    @Test
    func replacingPagerControllerDetachesOldController() throws {
        let box = PageBox(0)
        let firstPagerController = SwiftPagerController()
        let secondPagerController = SwiftPagerController()
        let controller = makeController()

        controller.apply(
            dataSource: dataSource(count: 5),
            page: box.binding,
            controller: firstPagerController,
            configuration: SwiftPagerConfiguration(),
            content: { Text("\($0)") }
        )

        controller.apply(
            dataSource: dataSource(count: 5),
            page: box.binding,
            controller: secondPagerController,
            configuration: SwiftPagerConfiguration(),
            content: { Text("\($0)") }
        )

        firstPagerController.scrollToPage(3, animated: false)

        #expect(box.value == 0)
        #expect(firstPagerController.currentPage == 0)

        controller.apply(
            dataSource: dataSource(count: 5),
            page: box.binding,
            controller: firstPagerController,
            configuration: SwiftPagerConfiguration(),
            content: { Text("\($0)") }
        )

        #expect(box.value == 0)
        #expect(firstPagerController.currentPage == 0)

        firstPagerController.scrollToPage(2, animated: false)

        #expect(box.value == 2)
        #expect(firstPagerController.currentPage == 2)

        secondPagerController.scrollToPage(3, animated: false)

        #expect(box.value == 2)
        #expect(secondPagerController.currentPage == 0)
    }

    @Test
    func dataMutationPreservesSettledPageByStableID() async throws {
        let box = PageBox(2)
        let pagerController = SwiftPagerController()
        let controller = makeController()
        let scrollView = try pagerScrollView(in: controller)

        controller.apply(
            dataSource: dataSource(ids: [10, 11, 12, 13]),
            page: box.binding,
            controller: pagerController,
            configuration: SwiftPagerConfiguration(),
            content: { Text("\($0)") }
        )

        #expect(box.value == 2)
        #expect(pagerController.currentPage == 2)

        controller.apply(
            dataSource: dataSource(ids: [10, 11, 99, 12, 13]),
            page: box.binding,
            controller: pagerController,
            configuration: SwiftPagerConfiguration(),
            content: { Text("\($0)") }
        )

        #expect(pagerController.currentPage == 3)
        #expect(Int(scrollView.contentOffset.x.rounded()) == 300)

        controller.apply(
            dataSource: dataSource(ids: [10, 11, 99, 12, 13]),
            page: box.binding,
            controller: pagerController,
            configuration: SwiftPagerConfiguration(),
            content: { Text("\($0)") }
        )

        #expect(pagerController.currentPage == 3)
        #expect(Int(scrollView.contentOffset.x.rounded()) == 300)

        await waitUntil {
            box.value == 3
        }

        #expect(box.value == 3)
    }

    @Test
    func dataMutationKeepsMovedStableIDOnSameHost() throws {
        let box = PageBox(2)
        let controller = makeController()
        let scrollView = try pagerScrollView(in: controller)

        controller.apply(
            dataSource: dataSource(ids: [10, 11, 12, 13]),
            page: box.binding,
            configuration: SwiftPagerConfiguration(),
            content: { Text("\($0)") }
        )

        let originalSettledView = try horizontalSubview(in: scrollView, at: 200)

        controller.apply(
            dataSource: dataSource(ids: [10, 11, 99, 12, 13]),
            page: box.binding,
            configuration: SwiftPagerConfiguration(),
            content: { Text("\($0)") }
        )

        let movedSettledView = try horizontalSubview(in: scrollView, at: 300)

        #expect(movedSettledView === originalSettledView)
    }

    @Test
    func loadedPageInfoUpdatesWhenIdentityReordersInsideLoadedWindow() throws {
        let box = PageBox(1)
        let controller = makeController()

        controller.apply(
            dataSource: dataSource(ids: [10, 11, 12]),
            page: box.binding,
            configuration: SwiftPagerConfiguration(preloadDistance: 1),
            content: { Text("\($0)") }
        )

        #expect(controller.pagerState.loadedPages.map(\.id) == [AnyHashable(10), AnyHashable(11), AnyHashable(12)])

        controller.apply(
            dataSource: dataSource(ids: [12, 11, 10]),
            page: box.binding,
            configuration: SwiftPagerConfiguration(preloadDistance: 1),
            content: { Text("\($0)") }
        )

        #expect(controller.pagerState.loadedPages.map(\.index) == [0, 1, 2])
        #expect(controller.pagerState.loadedPages.map(\.id) == [AnyHashable(12), AnyHashable(11), AnyHashable(10)])
    }

    @Test
    func duplicateStableIDsDoNotAliasOneHostAcrossMultipleIndexes() throws {
        let box = PageBox(1)
        let controller = makeController()
        let scrollView = try pagerScrollView(in: controller)

        controller.apply(
            dataSource: dataSource(ids: [10, 10, 11]),
            page: box.binding,
            configuration: SwiftPagerConfiguration(preloadDistance: 1),
            content: { Text("\($0)") }
        )

        let initialAttachedViews = Set(scrollView.subviews.map(ObjectIdentifier.init))
        #expect(initialAttachedViews.count == 3)

        controller.apply(
            dataSource: dataSource(ids: [10, 10, 11]),
            page: box.binding,
            configuration: SwiftPagerConfiguration(preloadDistance: 1),
            content: { Text("\($0)") }
        )

        let reattachedViews = Set(scrollView.subviews.map(ObjectIdentifier.init))
        #expect(reattachedViews.count == 3)
        #expect(scrollView.subviews.count == 3)
    }

    @Test
    func sameIndexStableIDDoesNotUseIndexLookupOnReapply() throws {
        let box = PageBox(2)
        let controller = makeController()
        var lookupCalls = 0
        let source = dataSource(ids: [10, 11, 12, 13]) { id in
            lookupCalls += 1
            return [10, 11, 12, 13].firstIndex { AnyHashable($0) == id }
        }

        controller.apply(
            dataSource: source,
            page: box.binding,
            configuration: SwiftPagerConfiguration(),
            content: { Text("\($0)") }
        )

        lookupCalls = 0

        controller.apply(
            dataSource: source,
            page: box.binding,
            configuration: SwiftPagerConfiguration(),
            content: { Text("\($0)") }
        )

        #expect(controller.pagerState.currentPage == 2)
        #expect(lookupCalls == 0)
    }

    @Test
    func externalPageChangeWinsOverIdentityPreservation() throws {
        let box = PageBox(2)
        let pagerController = SwiftPagerController()
        let controller = makeController()
        let scrollView = try pagerScrollView(in: controller)

        controller.apply(
            dataSource: dataSource(ids: [10, 11, 12, 13]),
            page: box.binding,
            controller: pagerController,
            configuration: SwiftPagerConfiguration(),
            content: { Text("\($0)") }
        )

        box.value = 1

        controller.apply(
            dataSource: dataSource(ids: [10, 11, 99, 12, 13]),
            page: box.binding,
            controller: pagerController,
            configuration: SwiftPagerConfiguration(),
            content: { Text("\($0)") }
        )

        #expect(box.value == 1)
        #expect(pagerController.currentPage == 1)
        #expect(Int(scrollView.contentOffset.x.rounded()) == 100)
    }

    @Test
    func windowRemovalDuringPreservedAnimationSettlesOnReapply() throws {
        let box = PageBox(0)
        let pagerController = SwiftPagerController()
        let controller = makeController()
        let window = attachToWindow(controller)
        let scrollView = try pagerScrollView(in: controller)
        var stateChanges: [SwiftPagerState] = []

        controller.apply(
            dataSource: dataSource(count: 4),
            page: box.binding,
            controller: pagerController,
            callbacks: PagerCallbacks(onPagerStateChange: { stateChanges.append($0) }),
            configuration: SwiftPagerConfiguration(),
            content: { Text("\($0)") }
        )

        // 1. Start an animated programmatic scroll while in a window.
        pagerController.scrollToPage(3, animated: true)
        // Partial progress, like the in-flight UIKit animation would produce.
        scrollView.contentOffset = CGPoint(x: 150, y: 0)
        controller.scrollViewDidScroll(scrollView)
        #expect(stateChanges.last?.scrollPhase == .animating)
        #expect(stateChanges.last?.targetPage == 3)

        // 2. The view leaves the window (e.g. nav push / SwiftUI moves it
        //    offscreen) WITHOUT teardown. UIKit cancels the running
        //    setContentOffset(animated:) and never fires
        //    scrollViewDidEndScrollingAnimation.
        window.rootViewController = nil
        controller.view.removeFromSuperview()
        #expect(controller.view.window == nil)

        // 3. SwiftUI re-runs apply(animated:false) with unchanged data/config
        //    while still .animating. Because the view is no longer in a window,
        //    UIKit cannot deliver the animation-end delegate, so the pager must
        //    finalize instead of preserving the dead animation.
        controller.apply(
            dataSource: dataSource(count: 4),
            page: box.binding,
            controller: pagerController,
            callbacks: PagerCallbacks(onPagerStateChange: { stateChanges.append($0) }),
            configuration: SwiftPagerConfiguration(),
            content: { Text("\($0)") }
        )

        #expect(stateChanges.last?.scrollPhase == .idle)
        #expect(stateChanges.last?.targetPage == nil)
        #expect(box.value == 3)
        #expect(pagerController.currentPage == 3)
        #expect(Int(scrollView.contentOffset.x.rounded()) == 300)
    }
}

private final class AccessibilityFormatterCapture {
    let token = "capture"
}

@MainActor
private final class PageBox: @unchecked Sendable {
    var value: Int

    init(_ value: Int) {
        self.value = value
    }

    var binding: Binding<Int> {
        Binding(
            get: { self.value },
            set: { self.value = $0 }
        )
    }
}

@MainActor
private final class FallbackPageBox {
    var value: Int?
    let controller: SwiftPagerController

    init(controller: SwiftPagerController) {
        self.controller = controller
    }

    var binding: Binding<Int> {
        Binding(
            get: { self.value ?? self.controller.currentPage },
            set: { self.value = $0 }
        )
    }
}

private final class CGFloatBox: @unchecked Sendable {
    var value: CGFloat

    init(_ value: CGFloat) {
        self.value = value
    }

    var binding: Binding<CGFloat> {
        Binding(
            get: { self.value },
            set: { self.value = $0 }
        )
    }
}

private final class StateToken {}

private final class LayoutPassRecorder {
    private var layoutCountsByValue: [Int: Int] = [:]

    func recordLayout(value: Int) {
        layoutCountsByValue[value, default: 0] += 1
    }

    func layoutCount(for value: Int) -> Int {
        layoutCountsByValue[value, default: 0]
    }
}

private struct LayoutProbePage: View {
    var value: Int
    let recorder: LayoutPassRecorder

    var body: some View {
        LayoutProbe(value: value, recorder: recorder)
            .frame(width: 10, height: 10)
    }
}

private struct LayoutProbe: UIViewRepresentable {
    var value: Int
    let recorder: LayoutPassRecorder

    func makeUIView(context: Context) -> LayoutProbeView {
        LayoutProbeView(value: value, recorder: recorder)
    }

    func updateUIView(_ uiView: LayoutProbeView, context: Context) {
        uiView.value = value
    }
}

private final class LayoutProbeView: UIView {
    var value: Int
    let recorder: LayoutPassRecorder

    init(value: Int, recorder: LayoutPassRecorder) {
        self.value = value
        self.recorder = recorder
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        recorder.recordLayout(value: value)
    }
}

private final class StateTokenRecorder {
    private var tokensByValue: [Int: ObjectIdentifier] = [:]

    func record(value: Int, token: StateToken) {
        tokensByValue[value] = ObjectIdentifier(token)
    }

    func token(for value: Int) -> ObjectIdentifier? {
        tokensByValue[value]
    }
}

private struct StatefulProbePage: View {
    var value: Int
    let recorder: StateTokenRecorder

    @State private var token = StateToken()

    var body: some View {
        StateTokenProbe(value: value, token: token, recorder: recorder)
            .frame(width: 1, height: 1)
    }
}

private struct StateTokenProbe: UIViewRepresentable {
    var value: Int
    let token: StateToken
    let recorder: StateTokenRecorder

    func makeUIView(context: Context) -> UIView {
        recorder.record(value: value, token: token)
        return UIView()
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        recorder.record(value: value, token: token)
    }
}

@MainActor
private func drainMainActorWork() async {
    await Task.yield()
    await Task.yield()
}

@MainActor
private func waitUntil(_ condition: () -> Bool) async {
    for _ in 0..<100 {
        if condition() {
            return
        }
        await drainMainActorWork()
        try? await Task.sleep(nanoseconds: 1_000_000)
    }
}

@MainActor
private func makeController() -> PagerViewController<Int, Text> {
    makeController(contentType: Text.self)
}

@MainActor
private func makeController<Content: View>(contentType: Content.Type) -> PagerViewController<Int, Content> {
    let controller = PagerViewController<Int, Content>()
    controller.loadViewIfNeeded()
    controller.view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    controller.view.setNeedsLayout()
    controller.view.layoutIfNeeded()
    return controller
}

@MainActor
private func attachToWindow(_ controller: UIViewController) -> UIWindow {
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    window.rootViewController = controller
    window.makeKeyAndVisible()
    controller.view.setNeedsLayout()
    controller.view.layoutIfNeeded()
    return window
}

private func dataSource(count: Int) -> PagerDataSource<Int> {
    PagerDataSource(count: count) { offset in
        guard offset >= 0, offset < count else { return nil }
        return PagerItem(
            index: offset,
            element: offset,
            id: AnyHashable(offset),
            reuseType: nil
        )
    }
}

private func dataSource(count: Int, reuseType: AnyHashable) -> PagerDataSource<Int> {
    PagerDataSource(count: count) { offset in
        guard offset >= 0, offset < count else { return nil }
        return PagerItem(
            index: offset,
            element: offset,
            id: AnyHashable(offset),
            reuseType: reuseType
        )
    }
}

private func dataSource(ids: [Int]) -> PagerDataSource<Int> {
    PagerDataSource(count: ids.count) { offset in
        guard offset >= 0, offset < ids.count else { return nil }
        return PagerItem(
            index: offset,
            element: ids[offset],
            id: AnyHashable(ids[offset]),
            reuseType: nil
        )
    }
}

private func dataSource(elements: [Int], ids: [Int]) -> PagerDataSource<Int> {
    PagerDataSource(count: elements.count) { offset in
        guard offset >= 0, offset < elements.count, offset < ids.count else { return nil }
        return PagerItem(
            index: offset,
            element: elements[offset],
            id: AnyHashable(ids[offset]),
            reuseType: nil
        )
    }
}

private func dataSource(
    ids: [Int],
    indexOfID: @escaping (AnyHashable) -> Int?
) -> PagerDataSource<Int> {
    PagerDataSource(
        count: ids.count,
        item: { offset in
            guard offset >= 0, offset < ids.count else { return nil }
            return PagerItem(
                index: offset,
                element: ids[offset],
                id: AnyHashable(ids[offset]),
                reuseType: nil
            )
        },
        indexOfID: indexOfID,
        isIDIndexAuthoritative: true
    )
}

@MainActor
private func pagerScrollView(in controller: UIViewController) throws -> UIScrollView {
    try #require(controller.view.subviews.compactMap { $0 as? UIScrollView }.first)
}

@MainActor
private func pagerAccessibilityControl(in controller: UIViewController) throws -> UIView {
    try #require(controller.view.subviews.first {
        $0.isAccessibilityElement && $0.accessibilityLabel == "Pager"
    })
}

@MainActor
private func tapRecognizer(in view: UIView, taps: Int) throws -> UITapGestureRecognizer {
    try #require(view.gestureRecognizers?.compactMap { $0 as? UITapGestureRecognizer }.first {
        $0.numberOfTapsRequired == taps
    })
}

@MainActor
private func horizontalFrameOrigins(in scrollView: UIScrollView) -> [Int] {
    scrollView.subviews
        .map { Int($0.frame.minX.rounded()) }
        .sorted()
}

@MainActor
private func verticalFrameOrigins(in scrollView: UIScrollView) -> [Int] {
    scrollView.subviews
        .map { Int($0.frame.minY.rounded()) }
        .sorted()
}

@MainActor
private func horizontalSubview(in scrollView: UIScrollView, at origin: Int) throws -> UIView {
    try #require(scrollView.subviews.first { Int($0.frame.minX.rounded()) == origin })
}
#endif
