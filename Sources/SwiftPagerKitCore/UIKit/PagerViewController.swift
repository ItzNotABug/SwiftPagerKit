#if canImport(UIKit)
import SwiftUI
import UIKit

@MainActor
final class PagerViewController<Element, Content: View>: UIViewController, UIScrollViewDelegate {
    private let scrollView = PagerScrollView()
    private let accessibilityControl = PagerAccessibilityControl()
    private var dataSource = PagerDataSource<Element>.empty
    private var page: Binding<Int>?
    private var configuration = SwiftPagerConfiguration()
    private var content: ((Element) -> Content)?
    private var controller: SwiftPagerController?
    private var sharedReusePool: SwiftPagerReusePool?
    private var callbacks = PagerCallbacks()
    private var settings = SwiftPagerSettings<Element>()
    private var lastNotifiedState: SwiftPagerState?
    private var lastNotifiedSignature: PagerStateSignature?
    private var attachedHostsByIndex: [Int: PagerHost<Element, Content>] = [:]
    private var cachedLoadedRange: ClosedRange<Int>?
    private var cachedLoadedPageInfo: [SwiftPagerPageInfo] = []
    private var isLoadedStateCacheValid = false
    private var loadedStateGeneration = 0
    private var lastAccessibilityValuePage: Int?
    private var lastAccessibilityValuePageCount: Int?
    private var retainedHostsByID: [AnyHashable: PagerHost<Element, Content>] = [:]
    private var retainedHostOrder: [AnyHashable] = []
    private let localReusePool = PagerReusePool<Element, Content>()
    private var isAnimatingProgrammaticOffset = false
    private var shouldFinishProgrammaticAnimationOnDirectWrite = false
    private var didSetInitialOffset = false
    private var pageCorrectionGeneration = 0
    private var pendingContinuousPagePosition: CGFloat?
    private var pendingContinuousPagePositionForcesPublish = false
    private var isContinuousPagePositionUpdateScheduled = false
    private var lastContinuousPagePositionPublished: CGFloat?
    private var continuousPagePositionGeneration = 0
    private var isApplyingUpdate = false
    private var shouldDeferExternalUpdatesDuringApply = false
    private var isControllerNotificationScheduled = false
    private var controllerNotificationGeneration = 0
    private var pendingPageCorrection: PendingPageCorrection?
    private var windowCenter: Int?
    private var windowDirectionBias: Int?
    private var settledIndex: Int?
    private var settledID: AnyHashable?
    private var hasResolvedInitialRestoration = false
    private var pendingInitialRestorationIndex: Int?
    private var emptyStateCurrentPage: Int?
    private var dragStartIndex: Int?
    private var targetIndex: Int?
    private var scrollPhase: SwiftPagerScrollPhase = .idle
    private var lastLayoutSize: CGSize = .zero
    private let pageAdvanceVelocityThreshold: CGFloat = 0.25
    private let continuousPagePositionMinimumDelta: CGFloat = 0.01
    private let directionalPrewarmThreshold: CGFloat = 0.05
    private var lastLoadMoreTriggerCount: Int?
    private var loadMoreGeneration = 0
    private var activeScrollPagePosition: CGFloat?
    private var hasNotifiedOverscroll = false

    private var reusePool: PagerReusePool<Element, Content> {
        sharedReusePool?.pool() ?? localReusePool
    }

    private struct PendingPageCorrection {
        var requestedIndex: Int
        var correctedIndex: Int
        var generation: Int
    }

    private struct PagerStateSignature: Equatable {
        var currentPage: Int
        var pageCount: Int
        var loadedStateGeneration: Int
        var targetPage: Int?
        var direction: SwiftPagerDirection
        var scrollPhase: SwiftPagerScrollPhase
        var pageSize: CGSize
    }

    private var currentIndex: Int {
        get { min(max(page?.wrappedValue ?? 0, 0), max(dataSource.count - 1, 0)) }
        set {
            let clamped = min(max(newValue, 0), max(dataSource.count - 1, 0))
            if page?.wrappedValue != clamped {
                page?.wrappedValue = clamped
            }
        }
    }

    private var rawPagePosition: CGFloat {
        guard pageExtent > 0, !dataSource.isEmpty else { return 0 }

        switch configuration.direction {
        case .horizontal:
            return scrollView.contentOffset.x / pageExtent
        case .vertical:
            return scrollView.contentOffset.y / pageExtent
        }
    }

    private var visibleIndex: Int {
        if let settledIndex {
            return clampedPageIndex(settledIndex)
        }
        return currentIndex
    }

    private var pageExtent: CGFloat {
        switch configuration.direction {
        case .horizontal:
            return scrollView.bounds.width + configuration.pageSpacing
        case .vertical:
            return scrollView.bounds.height + configuration.pageSpacing
        }
    }

    private var pageContentSemanticContentAttribute: UISemanticContentAttribute {
        switch view.effectiveUserInterfaceLayoutDirection {
        case .rightToLeft:
            return .forceRightToLeft
        case .leftToRight:
            return .forceLeftToRight
        @unknown default:
            return .forceLeftToRight
        }
    }

    private var isActivelyScrolling: Bool {
        scrollView.isTracking ||
            scrollView.isDragging ||
            scrollView.isDecelerating ||
            isAnimatingProgrammaticOffset ||
            dragStartIndex != nil ||
            scrollPhase == .dragging ||
            scrollPhase == .decelerating ||
            scrollPhase == .animating
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        scrollView.backgroundColor = .clear
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.decelerationRate = .fast
        scrollView.isDirectionalLockEnabled = true
        scrollView.semanticContentAttribute = .forceLeftToRight
        scrollView.isAccessibilityElement = false
        scrollView.delegate = self
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        accessibilityControl.backgroundColor = .clear
        accessibilityControl.isUserInteractionEnabled = false
        accessibilityControl.isAccessibilityElement = true
        accessibilityControl.accessibilityLabel = settings.accessibilityLabel
        accessibilityControl.accessibilityTraits.insert(.adjustable)
        accessibilityControl.accessibilityIncrementAction = { [weak self] in
            self?.performAccessibilityIncrement()
        }
        accessibilityControl.accessibilityDecrementAction = { [weak self] in
            self?.performAccessibilityDecrement()
        }
        accessibilityControl.accessibilityScrollAction = { [weak self] direction in
            self?.performAccessibilityScroll(direction) ?? false
        }
        accessibilityControl.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(scrollView)
        view.addSubview(accessibilityControl)
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            accessibilityControl.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            accessibilityControl.topAnchor.constraint(equalTo: view.topAnchor),
            accessibilityControl.widthAnchor.constraint(equalToConstant: 1),
            accessibilityControl.heightAnchor.constraint(equalToConstant: 1)
        ])
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let activePagePosition: CGFloat? = if isActivelyScrolling {
            clampedPagePosition(activeScrollPagePosition ?? rawPagePosition)
        } else {
            nil
        }
        let sizeChanged = !scrollView.bounds.size.isApproximatelyEqual(to: lastLayoutSize)
        let shouldFinishAnimationAfterLayout = shouldFinishAnimationAfterLayout(sizeChanged: sizeChanged)
        updateAttachedHostSemantics()
        updateContentSize()
        if let activePagePosition, sizeChanged {
            setDirectContentOffset(
                contentOffset(forPagePosition: activePagePosition),
                finishingProgrammaticAnimationAt: shouldFinishAnimationAfterLayout ? targetIndex : nil
            )
        }
        layoutAttachedHosts()

        let shouldPublishLayoutState = !didSetInitialOffset || sizeChanged
        let shouldRestorePageOffset = shouldPublishLayoutState && !isActivelyScrolling
        lastLayoutSize = scrollView.bounds.size

        if shouldPublishLayoutState && !isActivelyScrolling {
            prewarmAttachedHostLayouts()
        }

        if shouldRestorePageOffset {
            setPageOffset(visibleIndex, animated: false)
            didSetInitialOffset = true
        } else if !didSetInitialOffset {
            didSetInitialOffset = true
        }

        if shouldPublishLayoutState {
            notifyController()
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        trimCachesForMemoryPressure()
    }

    func apply(
        dataSource: PagerDataSource<Element>,
        page: Binding<Int>,
        controller: SwiftPagerController? = nil,
        sharedReusePool: SwiftPagerReusePool? = nil,
        callbacks: PagerCallbacks = PagerCallbacks(),
        settings: SwiftPagerSettings<Element> = SwiftPagerSettings<Element>(),
        configuration: SwiftPagerConfiguration,
        content: @escaping (Element) -> Content,
        animated: Bool = false,
        deferExternalUpdates: Bool = false
    ) {
        var normalizedSettings = settings.normalized()
        normalizedSettings.direction = configuration.direction
        normalizedSettings.pageSpacing = configuration.pageSpacing
        normalizedSettings.preloadDistance = configuration.preloadDistance

        let previousSettledIndex = settledIndex
        let previousSettledID = settledID ?? previousSettledIndex.flatMap { self.dataSource.item($0)?.id }
        let previousDataCount = self.dataSource.count
        let previousConfiguration = self.configuration
        let requestedIndex = page.wrappedValue
        let isPendingCorrection = pendingPageCorrection.map {
            $0.requestedIndex == requestedIndex && $0.correctedIndex == previousSettledIndex
        } ?? false
        let pageChangedExternally = previousSettledIndex.map {
            requestedIndex != $0 && !isPendingCorrection
        } ?? false

        let shouldClearLocalReusePool = self.sharedReusePool == nil && sharedReusePool != nil

        invalidatePendingContinuousPagePositionUpdates(resetLastPublished: false)
        let previousShouldDeferExternalUpdates = shouldDeferExternalUpdatesDuringApply
        shouldDeferExternalUpdatesDuringApply = deferExternalUpdates
        isApplyingUpdate = true
        defer {
            isApplyingUpdate = false
            shouldDeferExternalUpdatesDuringApply = previousShouldDeferExternalUpdates
            scheduleAbsoluteContentPositionUpdate()
        }

        self.dataSource = dataSource
        self.page = page
        self.configuration = configuration
        self.content = content
        self.sharedReusePool = sharedReusePool
        self.settings = normalizedSettings
        accessibilityControl.accessibilityLabel = normalizedSettings.accessibilityLabel
        invalidateAccessibilityValueCache()
        if shouldClearLocalReusePool {
            localReusePool.removeAll()
        }
        self.callbacks = callbacks
        updateScrollDirectionBehavior()

        if let existingController = self.controller {
            if let controller {
                if existingController !== controller {
                    existingController.detach(from: self)
                }
            } else {
                existingController.detach(from: self)
            }
        }

        self.controller = controller
        if sharedReusePool == nil {
            localReusePool.limit = configuration.reusePoolLimit
        }
        pageCorrectionGeneration += 1

        if dataSource.isEmpty {
            updateEmptyRestorationState(requestedIndex: requestedIndex)
            removeAllHosts()
            scrollView.contentSize = .zero
            controller?.attach(to: self)
            notifyController()
            return
        }

        let requestedTargetIndex: Int
        if !hasResolvedInitialRestoration, let pendingInitialRestorationIndex {
            requestedTargetIndex = clampedPageIndex(pendingInitialRestorationIndex)
        } else if configuration.stateRestorationPolicy == .reset && !hasResolvedInitialRestoration {
            requestedTargetIndex = 0
        } else {
            requestedTargetIndex = clampedPageIndex(requestedIndex)
        }
        let preservedTargetIndex: Int? = if !pageChangedExternally, let previousSettledID {
            if let previousSettledIndex,
               dataSource.item(previousSettledIndex)?.id == previousSettledID {
                previousSettledIndex
            } else {
                indexOfPage(id: previousSettledID, in: dataSource)
            }
        } else {
            nil
        }
        let targetIndex = preservedTargetIndex ?? requestedTargetIndex
        normalizeScrollStateForCurrentData()
        emptyStateCurrentPage = nil
        schedulePageCorrectionIfNeeded(
            binding: page,
            requestedIndex: requestedIndex,
            correctedIndex: targetIndex,
            generation: pageCorrectionGeneration
        )
        if !hasResolvedInitialRestoration {
            hasResolvedInitialRestoration = true
            pendingInitialRestorationIndex = nil
        }

        if settledIndex == nil {
            updateSettledAnchor(index: targetIndex)
        }

        let targetChanged = previousSettledIndex != targetIndex
        let identityMoved = preservedTargetIndex != nil && targetChanged
        let shouldForceTargetOffset = pageChangedExternally || identityMoved
        let offsetIndex = nearestPageIndex(for: scrollView.contentOffset)
        let targetOffset = pageOffset(for: targetIndex)
        let needsTargetOffsetUpdate = targetOffset.map { !scrollView.contentOffset.isApproximatelyEqual(to: $0) } ?? false
        let shouldApplyOffset = !isActivelyScrolling || shouldForceTargetOffset
        let willAnimateTargetJump = animated && targetChanged && needsTargetOffsetUpdate && offsetIndex != targetIndex && view.window != nil
        let activePagePositionAfterDataUpdate: CGFloat? = if isActivelyScrolling && !shouldApplyOffset {
            clampedPagePosition(activeScrollPagePosition ?? rawPagePosition)
        } else {
            nil
        }
        let windowTarget = if willAnimateTargetJump {
            offsetIndex
        } else if shouldApplyOffset {
            targetIndex
        } else {
            windowCenter ?? targetIndex
        }

        updateContentSize()
        let shouldPreserveProgrammaticAnimation = shouldPreserveProgrammaticAnimationThroughApply(
            targetIndex: targetIndex,
            previousDataCount: previousDataCount,
            previousConfiguration: previousConfiguration,
            pageChangedExternally: pageChangedExternally
        )
        let didFinishAnimationWithDirectWrite: Bool
        if let activePagePositionAfterDataUpdate {
            activeScrollPagePosition = activePagePositionAfterDataUpdate
            if shouldPreserveProgrammaticAnimation {
                didFinishAnimationWithDirectWrite = false
            } else {
                didFinishAnimationWithDirectWrite = setDirectContentOffset(
                    contentOffset(forPagePosition: activePagePositionAfterDataUpdate),
                    finishingProgrammaticAnimationAt: targetIndex
                )
            }
        } else {
            didFinishAnimationWithDirectWrite = false
        }
        updateWindow(
            center: didFinishAnimationWithDirectWrite ? targetIndex : windowTarget,
            reconcileIdentity: true,
            directionBias: didFinishAnimationWithDirectWrite
                ? nil
                : willAnimateTargetJump ? directionSign(from: offsetIndex, to: targetIndex) : nil
        )
        layoutAttachedHosts()
        if !isActivelyScrolling {
            prewarmAttachedHostLayouts()
        }

        if shouldApplyOffset {
            let shouldAnimate = animated && targetChanged && needsTargetOffsetUpdate && view.window != nil
            if shouldForceTargetOffset {
                resetDragTrackingForForcedTarget()
            }
            self.targetIndex = shouldAnimate ? targetIndex : nil
            if shouldAnimate {
                scrollPhase = .animating
            } else {
                scrollPhase = .idle
            }
            updateSettledAnchor(index: targetIndex)
            let startedAnimation = setPageOffset(
                targetIndex,
                animated: shouldAnimate,
                finishAnimationOnDirectWrite: true
            )
            if !startedAnimation {
                self.targetIndex = nil
            }
        }
        controller?.attach(to: self)
        notifyController()
    }

    private func shouldPreserveProgrammaticAnimationThroughApply(
        targetIndex: Int,
        previousDataCount: Int,
        previousConfiguration: SwiftPagerConfiguration,
        pageChangedExternally: Bool
    ) -> Bool {
        isAnimatingProgrammaticOffset &&
            shouldFinishProgrammaticAnimationOnDirectWrite &&
            scrollPhase == .animating &&
            view.window != nil &&
            self.targetIndex == targetIndex &&
            previousDataCount == dataSource.count &&
            previousConfiguration == configuration &&
            !pageChangedExternally
    }

    private func updateContentSize() {
        guard !dataSource.isEmpty else {
            scrollView.contentSize = .zero
            return
        }

        let count = CGFloat(dataSource.count)
        switch configuration.direction {
        case .horizontal:
            let width = count * scrollView.bounds.width + max(0, count - 1) * configuration.pageSpacing
            scrollView.contentSize = CGSize(width: max(scrollView.bounds.width, width), height: scrollView.bounds.height)
        case .vertical:
            let height = count * scrollView.bounds.height + max(0, count - 1) * configuration.pageSpacing
            scrollView.contentSize = CGSize(width: scrollView.bounds.width, height: max(scrollView.bounds.height, height))
        }
    }

    private func updateScrollDirectionBehavior() {
        switch configuration.direction {
        case .horizontal:
            scrollView.alwaysBounceHorizontal = dataSource.count > 1
            scrollView.alwaysBounceVertical = false
        case .vertical:
            scrollView.alwaysBounceHorizontal = false
            scrollView.alwaysBounceVertical = dataSource.count > 1
        }
    }

    private func updateWindow(center: Int, reconcileIdentity: Bool = false, directionBias: Int? = nil) {
        guard let content else { return }

        let resolvedCenter = clampedPageIndex(center)
        let effectiveDirectionBias = directionBias ?? prefetchDirectionBias(for: resolvedCenter)
        let liveDistance = max(1, configuration.preloadDistance)
        let liveRange = PagerWindow.range(
            center: resolvedCenter,
            count: dataSource.count,
            radius: liveDistance,
            directionBias: effectiveDirectionBias
        )
        let retentionRange = PagerWindow.range(center: resolvedCenter, count: dataSource.count, radius: configuration.retentionDistance)
        if reconcileIdentity {
            reconcileAttachedHostIdentity(in: liveRange)
        }
        let diff = PagerWindow.diff(attached: attachedHostsByIndex.keys, desired: liveRange)
        let hadWindowChanges = !diff.toDetach.isEmpty || !diff.toAttach.isEmpty

        for index in diff.toDetach {
            guard let host = attachedHostsByIndex.removeValue(forKey: index) else { continue }
            host.detach()

            if retentionRange?.contains(index) == true {
                host.prepareForRetention()
                retainHost(host)
            } else {
                reusePool.enqueue(host)
            }
        }

        pruneRetainedHosts(outside: retentionRange)

        var attachedNow = Set<Int>()
        for index in diff.toAttach {
            guard let item = dataSource.item(index) else { continue }
            let host = takeHost(for: item, content: content)
            host.index = index
            host.attach(
                to: self,
                in: scrollView,
                settings: settings,
                direction: configuration.direction
            )
            host.updateSemanticContentAttribute(pageContentSemanticContentAttribute)
            attachedHostsByIndex[index] = host
            attachedNow.insert(index)
        }

        var didUpdateAttachedMetadata = false
        for (index, host) in attachedHostsByIndex where dataSource.contains(index) {
            guard !attachedNow.contains(index) else { continue }
            guard let item = dataSource.item(index) else { continue }
            let previousID = host.id
            let previousReuseType = host.reuseType
            host.bind(
                item: item,
                updatePolicy: configuration.contentUpdatePolicy,
                contentRefreshToken: configuration.contentRefreshToken,
                settings: settings,
                direction: configuration.direction,
                content: content
            )
            host.attach(
                to: self,
                in: scrollView,
                settings: settings,
                direction: configuration.direction
            )
            host.updateSemanticContentAttribute(pageContentSemanticContentAttribute)
            if host.id != previousID || host.reuseType != previousReuseType {
                didUpdateAttachedMetadata = true
            }
        }

        if hadWindowChanges || didUpdateAttachedMetadata {
            invalidateLoadedStateCache()
        }
        windowCenter = resolvedCenter
        windowDirectionBias = effectiveDirectionBias
    }

    private func invalidateLoadedStateCache() {
        isLoadedStateCacheValid = false
        loadedStateGeneration += 1
    }

    private func updateLoadedStateCacheIfNeeded() {
        guard !isLoadedStateCacheValid else { return }

        let sortedIndices = attachedHostsByIndex.keys.sorted()
        if let lowerBound = sortedIndices.first, let upperBound = sortedIndices.last {
            cachedLoadedRange = lowerBound...upperBound
        } else {
            cachedLoadedRange = nil
        }
        cachedLoadedPageInfo = sortedIndices.compactMap { index in
            guard let host = attachedHostsByIndex[index] else { return nil }
            return SwiftPagerPageInfo(
                index: index,
                id: host.id,
                reuseType: host.reuseType
            )
        }
        isLoadedStateCacheValid = true
    }

    private func updateAttachedHostSemantics() {
        let attribute = pageContentSemanticContentAttribute
        for host in attachedHostsByIndex.values {
            host.updateSemanticContentAttribute(attribute)
        }
        for host in retainedHostsByID.values {
            host.updateSemanticContentAttribute(attribute)
        }
    }

    private func reconcileAttachedHostIdentity(in liveRange: ClosedRange<Int>?) {
        guard let liveRange, !attachedHostsByIndex.isEmpty else { return }

        var hostsByID: [AnyHashable: PagerHost<Element, Content>] = [:]
        for index in attachedHostsByIndex.keys.sorted() {
            guard let host = attachedHostsByIndex[index], hostsByID[host.id] == nil else {
                continue
            }
            hostsByID[host.id] = host
        }

        var remappedHostsByIndex: [Int: PagerHost<Element, Content>] = [:]
        var preservedHosts = Set<ObjectIdentifier>()

        for index in liveRange {
            guard let item = dataSource.item(index),
                  let host = hostsByID[item.id]
            else {
                continue
            }

            let hostIdentifier = ObjectIdentifier(host)
            guard !preservedHosts.contains(hostIdentifier) else {
                continue
            }

            remappedHostsByIndex[index] = host
            preservedHosts.insert(hostIdentifier)
        }

        guard !remappedHostsByIndex.isEmpty else { return }

        let didRemapHostIdentity = remappedHostsByIndex.count != attachedHostsByIndex.count ||
            remappedHostsByIndex.contains { entry in
                attachedHostsByIndex[entry.key] !== entry.value
            }

        for host in attachedHostsByIndex.values where !preservedHosts.contains(ObjectIdentifier(host)) {
            host.detach()
            reusePool.enqueue(host)
        }

        attachedHostsByIndex = remappedHostsByIndex
        for (index, host) in attachedHostsByIndex {
            host.index = index
        }
        if didRemapHostIdentity {
            invalidateLoadedStateCache()
        }
    }

    private func takeHost(
        for item: PagerItem<Element>,
        content: @escaping (Element) -> Content
    ) -> PagerHost<Element, Content> {
        if let host = retainedHostsByID.removeValue(forKey: item.id) {
            retainedHostOrder.removeAll { $0 == item.id }
            host.bind(
                item: item,
                updatePolicy: configuration.contentUpdatePolicy,
                contentRefreshToken: configuration.contentRefreshToken,
                settings: settings,
                direction: configuration.direction,
                content: content
            )
            return host
        }

        if let host = reusePool.dequeue(reuseType: item.reuseType) {
            host.bind(
                item: item,
                updatePolicy: configuration.contentUpdatePolicy,
                contentRefreshToken: configuration.contentRefreshToken,
                settings: settings,
                direction: configuration.direction,
                content: content,
                force: true
            )
            return host
        }

        return PagerHost(
            item: item,
            contentRefreshToken: configuration.contentRefreshToken,
            settings: settings,
            direction: configuration.direction,
            content: content
        )
    }

    private func retainHost(_ host: PagerHost<Element, Content>) {
        retainedHostOrder.removeAll { $0 == host.id }
        retainedHostOrder.append(host.id)
        if let replaced = retainedHostsByID.updateValue(host, forKey: host.id), replaced !== host {
            reusePool.enqueue(replaced)
        }

        let maxRetainedHosts = max(0, configuration.retentionDistance * 2 + 1)
        while retainedHostOrder.count > maxRetainedHosts {
            let id = retainedHostOrder.removeFirst()
            if let removed = retainedHostsByID.removeValue(forKey: id) {
                reusePool.enqueue(removed)
            }
        }
    }

    private func pruneRetainedHosts(outside range: ClosedRange<Int>?) {
        guard let range else {
            for host in retainedHostsByID.values {
                reusePool.enqueue(host)
            }
            retainedHostsByID.removeAll()
            retainedHostOrder.removeAll()
            return
        }

        for id in retainedHostOrder {
            guard let host = retainedHostsByID[id], !range.contains(host.index) else { continue }
            retainedHostsByID[id] = nil
            reusePool.enqueue(host)
        }
        retainedHostOrder.removeAll { retainedHostsByID[$0] == nil }
    }

    private func layoutAttachedHosts() {
        for (index, host) in attachedHostsByIndex {
            switch configuration.direction {
            case .horizontal:
                host.view.frame = CGRect(
                    x: CGFloat(index) * pageExtent,
                    y: 0,
                    width: scrollView.bounds.width,
                    height: scrollView.bounds.height
                )
            case .vertical:
                host.view.frame = CGRect(
                    x: 0,
                    y: CGFloat(index) * pageExtent,
                    width: scrollView.bounds.width,
                    height: scrollView.bounds.height
                )
            }
        }
    }

    private func prewarmAttachedHostLayouts() {
        guard view.window != nil else { return }
        for host in attachedHostsByIndex.values {
            host.prewarmLayout()
        }
    }

    @discardableResult
    private func setPageOffset(
        _ index: Int,
        animated: Bool,
        activePosition: CGFloat? = nil,
        finishAnimationOnDirectWrite: Bool = false
    ) -> Bool {
        guard let target = pageOffset(for: index) else { return false }

        let shouldAnimate = animated && view.window != nil

        let needsOffsetWrite = !scrollView.contentOffset.isApproximatelyEqual(to: target)

        guard needsOffsetWrite else {
            let wasAnimatingProgrammaticOffset = isAnimatingProgrammaticOffset
            cancelProgrammaticAnimationAtResolvedOffsetIfNeeded(target, index: index)
            if wasAnimatingProgrammaticOffset, scrollView.contentOffset != target {
                scrollView.setContentOffset(target, animated: false)
            }
            return false
        }

        if !shouldAnimate {
            cancelProgrammaticAnimationBeforeResolvedOffsetWriteIfNeeded(index: index)
        }

        isAnimatingProgrammaticOffset = shouldAnimate
        shouldFinishProgrammaticAnimationOnDirectWrite = shouldAnimate && finishAnimationOnDirectWrite
        scrollView.setContentOffset(target, animated: shouldAnimate)
        if shouldAnimate {
            activeScrollPagePosition = clampedPagePosition(activePosition ?? CGFloat(clampedPageIndex(index)))
        }
        return shouldAnimate
    }

    private func cancelProgrammaticAnimationAtResolvedOffsetIfNeeded(_ target: CGPoint, index: Int) {
        guard isAnimatingProgrammaticOffset else { return }

        let clampedIndex = clampedPageIndex(index)
        isAnimatingProgrammaticOffset = false
        shouldFinishProgrammaticAnimationOnDirectWrite = false
        activeScrollPagePosition = nil
        updateSettledAnchor(index: clampedIndex)
        targetIndex = nil
        if scrollPhase == .animating {
            scrollPhase = .idle
        }
        hasNotifiedOverscroll = false
        scrollView.setContentOffset(target, animated: false)
    }

    private func cancelProgrammaticAnimationBeforeResolvedOffsetWriteIfNeeded(index: Int) {
        guard isAnimatingProgrammaticOffset || scrollPhase == .animating else { return }

        let clampedIndex = clampedPageIndex(index)
        isAnimatingProgrammaticOffset = false
        shouldFinishProgrammaticAnimationOnDirectWrite = false
        activeScrollPagePosition = nil
        updateSettledAnchor(index: clampedIndex)
        targetIndex = nil
        if scrollPhase == .animating {
            scrollPhase = .idle
        }
        hasNotifiedOverscroll = false
    }

    private func resetDragTrackingForForcedTarget() {
        dragStartIndex = nil
        activeScrollPagePosition = nil
        hasNotifiedOverscroll = false
    }

    @discardableResult
    private func setDirectContentOffset(
        _ offset: CGPoint,
        finishingProgrammaticAnimationAt index: Int?
    ) -> Bool {
        let shouldFinish = shouldFinishProgrammaticAnimationAfterDirectContentOffsetWrite(at: index)
        let resolvedOffset: CGPoint
        if shouldFinish,
           let index,
           let targetOffset = pageOffset(for: index) {
            resolvedOffset = targetOffset
        } else {
            resolvedOffset = offset
        }

        if shouldFinish, let index {
            prepareInterruptedScrollAnimationForDirectContentOffsetWrite(at: index)
        }
        scrollView.contentOffset = resolvedOffset
        if shouldFinish {
            notifyController()
        }
        return shouldFinish
    }

    private func pageOffset(for index: Int) -> CGPoint? {
        guard pageExtent > 0 else { return nil }

        switch configuration.direction {
        case .horizontal:
            return CGPoint(x: CGFloat(index) * pageExtent, y: 0)
        case .vertical:
            return CGPoint(x: 0, y: CGFloat(index) * pageExtent)
        }
    }

    private func contentOffset(forPagePosition pagePosition: CGFloat) -> CGPoint {
        let pagePosition = clampedPagePosition(pagePosition)
        switch configuration.direction {
        case .horizontal:
            return CGPoint(x: pagePosition * pageExtent, y: 0)
        case .vertical:
            return CGPoint(x: 0, y: pagePosition * pageExtent)
        }
    }

    private func clampedPagePosition(_ pagePosition: CGFloat) -> CGFloat {
        guard !dataSource.isEmpty else { return 0 }
        let maxPagePosition = CGFloat(max(dataSource.count - 1, 0))
        return min(max(pagePosition, 0), maxPagePosition)
    }

    private func shouldFinishAnimationAfterLayout(sizeChanged: Bool) -> Bool {
        guard sizeChanged,
              isAnimatingProgrammaticOffset,
              shouldFinishProgrammaticAnimationOnDirectWrite,
              scrollPhase == .animating,
              targetIndex != nil
        else {
            return false
        }

        return true
    }

    private func shouldFinishProgrammaticAnimationAfterDirectContentOffsetWrite(at index: Int?) -> Bool {
        isAnimatingProgrammaticOffset &&
            shouldFinishProgrammaticAnimationOnDirectWrite &&
            scrollPhase == .animating &&
            index != nil
    }

    private func prepareInterruptedScrollAnimationForDirectContentOffsetWrite(at index: Int) {
        let clampedIndex = clampedPageIndex(index)
        isAnimatingProgrammaticOffset = false
        shouldFinishProgrammaticAnimationOnDirectWrite = false
        activeScrollPagePosition = nil
        updateSettledAnchor(index: clampedIndex)
        updateWindow(center: clampedIndex)
        layoutAttachedHosts()
        targetIndex = nil
        scrollPhase = .idle
        hasNotifiedOverscroll = false
    }

    private func finishInterruptedScrollAnimation(at index: Int) {
        prepareInterruptedScrollAnimationForDirectContentOffsetWrite(at: index)
        notifyController()
    }

    private func normalizeScrollStateForCurrentData() {
        guard !dataSource.isEmpty else {
            targetIndex = nil
            activeScrollPagePosition = nil
            return
        }

        if let targetIndex {
            self.targetIndex = clampedPageIndex(targetIndex)
        }

        if let settledIndex {
            let clampedSettledIndex = clampedPageIndex(settledIndex)
            if clampedSettledIndex != settledIndex {
                self.settledIndex = clampedSettledIndex
                settledID = dataSource.item(clampedSettledIndex)?.id
            }
        }

        if let activeScrollPagePosition {
            self.activeScrollPagePosition = clampedPagePosition(activeScrollPagePosition)
        }
    }

    private func nearestPageIndex(for offset: CGPoint) -> Int {
        guard pageExtent > 0, !dataSource.isEmpty else { return 0 }
        let rawPage: CGFloat
        switch configuration.direction {
        case .horizontal:
            rawPage = offset.x / pageExtent
        case .vertical:
            rawPage = offset.y / pageExtent
        }
        return min(max(Int(round(rawPage)), 0), dataSource.count - 1)
    }

    private var visibleFraction: CGFloat {
        guard pageExtent > 0, !dataSource.isEmpty else { return 1 }
        let rawPage: CGFloat

        switch configuration.direction {
        case .horizontal:
            rawPage = scrollView.contentOffset.x / pageExtent
        case .vertical:
            rawPage = scrollView.contentOffset.y / pageExtent
        }

        let distanceFromNearestPage = abs(rawPage - CGFloat(nearestPageIndex(for: scrollView.contentOffset)))
        return min(max(1 - distanceFromNearestPage, 0), 1)
    }

    private var pageSize: CGSize {
        scrollView.bounds.size
    }

    private func targetPageIndex(for proposedOffset: CGPoint, velocity: CGPoint) -> Int {
        let proposedIndex = nearestPageIndex(for: proposedOffset)
        let currentPage = dragStartIndex ?? nearestPageIndex(for: scrollView.contentOffset)
        let directionalVelocity: CGFloat

        switch configuration.direction {
        case .horizontal:
            directionalVelocity = velocity.x
        case .vertical:
            directionalVelocity = velocity.y
        }

        guard abs(directionalVelocity) >= pageAdvanceVelocityThreshold else {
            return proposedIndex
        }

        let direction = directionalVelocity > 0 ? 1 : -1
        return clampedPageIndex(currentPage + direction)
    }

    private func prefetchDirectionBias(for center: Int) -> Int {
        if let targetIndex {
            return directionSign(from: center, to: targetIndex)
        }

        if let dragStartIndex {
            return directionSign(from: dragStartIndex, to: center)
        }

        return 0
    }

    private func directionalPrewarmBias(rawPagePosition: CGFloat, center: Int) -> Int {
        if let targetIndex {
            return directionSign(from: center, to: targetIndex)
        }

        guard let dragStartIndex else {
            return prefetchDirectionBias(for: center)
        }

        let distanceFromDragStart = rawPagePosition - CGFloat(dragStartIndex)
        guard abs(distanceFromDragStart) >= directionalPrewarmThreshold else { return 0 }
        return distanceFromDragStart > 0 ? 1 : -1
    }

    private func directionSign(from source: Int, to target: Int) -> Int {
        if target > source { return 1 }
        if target < source { return -1 }
        return 0
    }

    private func clampedPageIndex(_ index: Int) -> Int {
        min(max(index, 0), max(dataSource.count - 1, 0))
    }

    private func schedulePageCorrectionIfNeeded(
        binding: Binding<Int>,
        requestedIndex: Int,
        correctedIndex: Int,
        generation: Int
    ) {
        guard requestedIndex != correctedIndex else {
            pendingPageCorrection = nil
            return
        }

        pendingPageCorrection = PendingPageCorrection(
            requestedIndex: requestedIndex,
            correctedIndex: correctedIndex,
            generation: generation
        )

        DispatchQueue.main.async { [weak self] in
            guard let self, !self.dataSource.isEmpty, self.pageCorrectionGeneration == generation else { return }
            let liveCorrection = self.clampedPageIndex(correctedIndex)
            if binding.wrappedValue != liveCorrection {
                binding.wrappedValue = liveCorrection
            }
            if self.pendingPageCorrection?.generation == generation {
                self.pendingPageCorrection = nil
            }
        }
    }

    private func updateEmptyRestorationState(requestedIndex: Int) {
        if hasResolvedInitialRestoration {
            emptyStateCurrentPage = max(0, requestedIndex)
            return
        }

        switch configuration.stateRestorationPolicy {
        case .preserve:
            pendingInitialRestorationIndex = nil
            emptyStateCurrentPage = max(0, requestedIndex)
        case .reset:
            pendingInitialRestorationIndex = 0
            emptyStateCurrentPage = 0
        }
    }

    private func updateAbsoluteContentPosition() {
        guard !isApplyingUpdate else { return }
        scheduleContinuousPagePositionUpdate(rawPagePosition)
    }

    private func scheduleAbsoluteContentPositionUpdate() {
        scheduleContinuousPagePositionUpdate(rawPagePosition, force: true)
    }

    private var hasContinuousPageObservers: Bool {
        settings.continuousPageIndex != nil || settings.onContinuousPageChange != nil
    }

    private func scheduleContinuousPagePositionUpdate(_ pagePosition: CGFloat, force: Bool = false) {
        guard hasContinuousPageObservers else { return }
        guard force || shouldPublishContinuousPagePosition(pagePosition) else { return }

        pendingContinuousPagePosition = pagePosition
        pendingContinuousPagePositionForcesPublish = pendingContinuousPagePositionForcesPublish || force
        guard !isContinuousPagePositionUpdateScheduled else { return }

        isContinuousPagePositionUpdateScheduled = true
        let generation = continuousPagePositionGeneration
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.isContinuousPagePositionUpdateScheduled = false
            guard self.continuousPagePositionGeneration == generation else { return }
            let pagePosition = self.pendingContinuousPagePosition ?? self.rawPagePosition
            let force = self.pendingContinuousPagePositionForcesPublish
            self.pendingContinuousPagePosition = nil
            self.pendingContinuousPagePositionForcesPublish = false
            self.publishContinuousPagePosition(pagePosition, force: force)
        }
    }

    private func shouldPublishContinuousPagePosition(_ pagePosition: CGFloat) -> Bool {
        guard let lastContinuousPagePositionPublished else { return true }
        if abs(lastContinuousPagePositionPublished - pagePosition) >= continuousPagePositionMinimumDelta {
            return true
        }

        let nearestIntegerPosition = pagePosition.rounded()
        return abs(pagePosition - nearestIntegerPosition) <= 0.0001 &&
            abs(lastContinuousPagePositionPublished - pagePosition) > 0.0001
    }

    private func publishContinuousPagePosition(_ pagePosition: CGFloat, force: Bool) {
        guard force || shouldPublishContinuousPagePosition(pagePosition) else { return }

        settings.onContinuousPageChange?(pagePosition)
        if let position = settings.continuousPageIndex,
           abs(position.wrappedValue - pagePosition) > 0.0001 {
            position.wrappedValue = pagePosition
        }
        lastContinuousPagePositionPublished = pagePosition
    }

    private func invalidatePendingContinuousPagePositionUpdates(resetLastPublished: Bool) {
        continuousPagePositionGeneration += 1
        pendingContinuousPagePosition = nil
        pendingContinuousPagePositionForcesPublish = false
        isContinuousPagePositionUpdateScheduled = false
        if resetLastPublished {
            lastContinuousPagePositionPublished = nil
        }
    }

    private func notifyOverscrollIfNeeded() {
        guard !hasNotifiedOverscroll,
              !dataSource.isEmpty,
              settings.onOverscroll != nil
        else {
            return
        }

        let threshold = CGFloat(settings.overscrollThreshold)
        let rawPosition = rawPagePosition
        let lastPage = CGFloat(max(dataSource.count - 1, 0))

        if rawPosition < -threshold {
            settings.onOverscroll?(.beginning)
            hasNotifiedOverscroll = true
        } else if rawPosition > lastPage + threshold {
            settings.onOverscroll?(.end)
            hasNotifiedOverscroll = true
        }
    }

    private func triggerLoadMoreIfNeeded(currentIndex: Int) {
        guard let onLoadMore = settings.onLoadMore, !dataSource.isEmpty else { return }

        let triggerIndex: Int
        switch settings.loadMoreTrigger {
        case let .nearEnd(offsetFromEnd):
            triggerIndex = max(0, dataSource.count - 1 - max(0, offsetFromEnd))
        }

        guard currentIndex >= triggerIndex else { return }

        guard lastLoadMoreTriggerCount != dataSource.count else {
            return
        }

        lastLoadMoreTriggerCount = dataSource.count
        let generation = loadMoreGeneration
        DispatchQueue.main.async { [weak self] in
            guard let self, self.loadMoreGeneration == generation else { return }
            onLoadMore()
        }
    }

    private func updateSettledAnchor(index: Int) {
        settledIndex = clampedPageIndex(index)
        settledID = dataSource.item(settledIndex ?? 0)?.id
        if let settledIndex {
            triggerLoadMoreIfNeeded(currentIndex: settledIndex)
        }
    }

    private func resetZoomOutsideCurrentPage(_ currentIndex: Int) {
        for (index, host) in attachedHostsByIndex where index != currentIndex {
            host.resetZoom(animated: false)
        }
    }

    @discardableResult
    private func settlePage(animated: Bool) -> Bool {
        let index = nearestPageIndex(for: scrollView.contentOffset)
        currentIndex = index
        updateSettledAnchor(index: index)
        updateWindow(center: index)
        layoutAttachedHosts()
        prewarmAttachedHostLayouts()
        resetZoomOutsideCurrentPage(index)
        updateAbsoluteContentPosition()
        return setPageOffset(
            index,
            animated: animated,
            activePosition: rawPagePosition,
            finishAnimationOnDirectWrite: true
        )
    }

    private func removeAllHosts() {
        isAnimatingProgrammaticOffset = false
        shouldFinishProgrammaticAnimationOnDirectWrite = false
        pageCorrectionGeneration += 1
        loadMoreGeneration += 1
        for host in attachedHostsByIndex.values {
            host.discard()
        }
        for host in retainedHostsByID.values {
            host.discard()
        }
        if sharedReusePool == nil {
            localReusePool.removeAll()
        }
        attachedHostsByIndex.removeAll()
        invalidateLoadedStateCache()
        retainedHostsByID.removeAll()
        retainedHostOrder.removeAll()
        lastNotifiedSignature = nil
        windowCenter = nil
        windowDirectionBias = nil
        settledIndex = nil
        settledID = nil
        dragStartIndex = nil
        activeScrollPagePosition = nil
        targetIndex = nil
        scrollPhase = .idle
        pendingPageCorrection = nil
        invalidatePendingContinuousPagePositionUpdates(resetLastPublished: true)
        lastLoadMoreTriggerCount = nil
        hasNotifiedOverscroll = false
    }

    private func trimCachesForMemoryPressure() {
        for host in retainedHostsByID.values {
            host.discard()
        }
        retainedHostsByID.removeAll()
        retainedHostOrder.removeAll()
        localReusePool.removeAll()
        sharedReusePool?.removeAll()
    }

    func teardown() {
        controller?.detach(from: self)
        controller = nil
        scrollView.delegate = nil
        controllerNotificationGeneration += 1
        isControllerNotificationScheduled = false
        accessibilityControl.accessibilityIncrementAction = nil
        accessibilityControl.accessibilityDecrementAction = nil
        accessibilityControl.accessibilityScrollAction = nil
        removeAllHosts()
        localReusePool.removeAll()
        dataSource = .empty
        page = nil
        content = nil
        sharedReusePool = nil
        configuration = SwiftPagerConfiguration()
        callbacks = PagerCallbacks()
        settings = SwiftPagerSettings<Element>()
        scrollView.contentSize = .zero
        accessibilityControl.accessibilityLabel = settings.accessibilityLabel
        accessibilityControl.accessibilityValue = nil
        lastNotifiedState = nil
        lastNotifiedSignature = nil
        invalidateAccessibilityValueCache()
    }

    private func notifyController() {
        guard !shouldDeferExternalUpdatesDuringApply else {
            scheduleDeferredControllerNotification()
            return
        }

        publishControllerNotification()
    }

    private func scheduleDeferredControllerNotification() {
        guard !isControllerNotificationScheduled else { return }
        isControllerNotificationScheduled = true
        controllerNotificationGeneration += 1
        let generation = controllerNotificationGeneration
        DispatchQueue.main.async { [weak self] in
            guard let self, self.controllerNotificationGeneration == generation else { return }
            self.isControllerNotificationScheduled = false
            self.publishControllerNotification()
        }
    }

    private func publishControllerNotification() {
        let signature = makePagerStateSignature()
        let shouldRefreshAccessibility = shouldRefreshAccessibilityValue(
            currentPage: signature.currentPage,
            pageCount: signature.pageCount
        )
        guard lastNotifiedState == nil ||
            lastNotifiedSignature != signature ||
            shouldRefreshAccessibility
        else {
            return
        }

        let state = pagerState
        let previousState = lastNotifiedState
        updateAccessibilityState(state)
        controller?.updateState(state)
        lastNotifiedSignature = signature

        guard previousState != state else { return }

        lastNotifiedState = state
        if let previousState {
            if previousState.currentPage != state.currentPage {
                callbacks.onPageChange?(state.currentPage)
                postAccessibilityPageChange(state)
            }
            if previousState.scrollPhase != state.scrollPhase {
                callbacks.onScrollPhaseChange?(state.scrollPhase)
            }
        }
        callbacks.onPagerStateChange?(state)
    }

    private func updateAccessibilityState(_ state: SwiftPagerState) {
        let shouldRefreshValue = shouldRefreshAccessibilityValue(
            currentPage: state.currentPage,
            pageCount: state.pageCount
        )

        guard shouldRefreshValue else { return }

        accessibilityControl.accessibilityValue = accessibilityPageValue(for: state)
        lastAccessibilityValuePage = state.currentPage
        lastAccessibilityValuePageCount = state.pageCount
    }

    private func shouldRefreshAccessibilityValue(currentPage: Int, pageCount: Int) -> Bool {
        lastAccessibilityValuePage != currentPage ||
            lastAccessibilityValuePageCount != pageCount
    }

    private func invalidateAccessibilityValueCache() {
        lastAccessibilityValuePage = nil
        lastAccessibilityValuePageCount = nil
    }

    private func postAccessibilityPageChange(_ state: SwiftPagerState) {
        guard UIAccessibility.isVoiceOverRunning else { return }
        UIAccessibility.post(notification: .pageScrolled, argument: accessibilityPageValue(for: state))
    }

    private func accessibilityPageValue(for state: SwiftPagerState) -> String {
        settings.accessibilityValue(state)
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let rawPagePosition = rawPagePosition
        updateAbsoluteContentPosition()
        notifyOverscrollIfNeeded()
        if isActivelyScrolling {
            activeScrollPagePosition = rawPagePosition
        }
        let index = nearestPageIndex(for: scrollView.contentOffset)
        let directionBias = directionalPrewarmBias(rawPagePosition: rawPagePosition, center: index)
        if windowCenter != index || windowDirectionBias != directionBias {
            updateWindow(center: index, directionBias: directionBias)
            layoutAttachedHosts()
        }
        notifyController()
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        isAnimatingProgrammaticOffset = false
        shouldFinishProgrammaticAnimationOnDirectWrite = false
        settings.onDragStart?()
        hasNotifiedOverscroll = false
        let dragStartIndex = nearestPageIndex(for: scrollView.contentOffset)
        self.dragStartIndex = dragStartIndex
        activeScrollPagePosition = rawPagePosition
        currentIndex = dragStartIndex
        updateSettledAnchor(index: dragStartIndex)
        scrollPhase = .dragging
        targetIndex = nil
        updateWindow(center: dragStartIndex, directionBias: 0)
        layoutAttachedHosts()
        prewarmAttachedHostLayouts()
        notifyController()
    }

    func scrollViewWillEndDragging(
        _ scrollView: UIScrollView,
        withVelocity velocity: CGPoint,
        targetContentOffset: UnsafeMutablePointer<CGPoint>
    ) {
        let index = targetPageIndex(for: targetContentOffset.pointee, velocity: velocity)
        targetIndex = index
        switch configuration.direction {
        case .horizontal:
            targetContentOffset.pointee.x = CGFloat(index) * pageExtent
        case .vertical:
            targetContentOffset.pointee.y = CGFloat(index) * pageExtent
        }
        updateWindow(center: nearestPageIndex(for: scrollView.contentOffset))
        layoutAttachedHosts()
        prewarmAttachedHostLayouts()
        notifyController()
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if decelerate {
            scrollPhase = .decelerating
            notifyController()
        } else {
            let settledTarget = nearestPageIndex(for: scrollView.contentOffset)
            targetIndex = settledTarget
            scrollPhase = .animating
            let startedAnimation = settlePage(animated: true)
            dragStartIndex = nil
            if !startedAnimation {
                activeScrollPagePosition = nil
            }
            targetIndex = startedAnimation ? settledTarget : nil
            scrollPhase = startedAnimation ? .animating : .idle
            hasNotifiedOverscroll = false
            notifyController()
        }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        let settledTarget = nearestPageIndex(for: scrollView.contentOffset)
        targetIndex = settledTarget
        scrollPhase = .animating
        let startedAnimation = settlePage(animated: true)
        dragStartIndex = nil
        if !startedAnimation {
            activeScrollPagePosition = nil
        }
        targetIndex = startedAnimation ? settledTarget : nil
        scrollPhase = startedAnimation ? .animating : .idle
        hasNotifiedOverscroll = false
        notifyController()
    }

    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        isAnimatingProgrammaticOffset = false
        shouldFinishProgrammaticAnimationOnDirectWrite = false
        activeScrollPagePosition = nil
        updateWindow(center: visibleIndex)
        layoutAttachedHosts()
        prewarmAttachedHostLayouts()
        targetIndex = nil
        scrollPhase = .idle
        hasNotifiedOverscroll = false
        notifyController()
    }

    private func performAccessibilityIncrement() {
        guard visibleIndex < dataSource.count - 1 else { return }
        _ = scrollToPage(visibleIndex + 1, animated: true)
    }

    private func performAccessibilityDecrement() {
        guard visibleIndex > 0 else { return }
        _ = scrollToPage(visibleIndex - 1, animated: true)
    }

    private func performAccessibilityScroll(_ direction: UIAccessibilityScrollDirection) -> Bool {
        switch (configuration.direction, direction) {
        case (.horizontal, .left), (.vertical, .up):
            guard visibleIndex < dataSource.count - 1 else { return false }
            return scrollToPage(visibleIndex + 1, animated: true)
        case (.horizontal, .right), (.vertical, .down):
            guard visibleIndex > 0 else { return false }
            return scrollToPage(visibleIndex - 1, animated: true)
        default:
            return false
        }
    }
}

private final class PagerScrollView: UIScrollView {
}

private final class PagerAccessibilityControl: UIView {
    var accessibilityIncrementAction: (() -> Void)?
    var accessibilityDecrementAction: (() -> Void)?
    var accessibilityScrollAction: ((UIAccessibilityScrollDirection) -> Bool)?

    override func accessibilityIncrement() {
        accessibilityIncrementAction?()
    }

    override func accessibilityDecrement() {
        accessibilityDecrementAction?()
    }

    override func accessibilityScroll(_ direction: UIAccessibilityScrollDirection) -> Bool {
        accessibilityScrollAction?(direction) ?? super.accessibilityScroll(direction)
    }
}

extension PagerViewController: SwiftPagerControlling {
    var pagerState: SwiftPagerState {
        updateLoadedStateCacheIfNeeded()
        return SwiftPagerState(
            currentPage: currentPageForState,
            pageCount: dataSource.count,
            loadedRange: cachedLoadedRange,
            loadedPages: cachedLoadedPageInfo,
            targetPage: targetPageForState,
            direction: configuration.direction,
            scrollPhase: scrollPhase,
            visibleFraction: visibleFraction,
            pageSize: pageSize
        )
    }

    private var currentPageForState: Int {
        dataSource.isEmpty ? (emptyStateCurrentPage ?? 0) : visibleIndex
    }

    private var targetPageForState: Int? {
        dataSource.isEmpty ? nil : targetIndex.map(clampedPageIndex)
    }

    private func makePagerStateSignature() -> PagerStateSignature {
        PagerStateSignature(
            currentPage: currentPageForState,
            pageCount: dataSource.count,
            loadedStateGeneration: loadedStateGeneration,
            targetPage: targetPageForState,
            direction: configuration.direction,
            scrollPhase: scrollPhase,
            pageSize: pageSize
        )
    }

    func performScroll(toPage index: Int, animated: Bool) -> Bool {
        scrollToPage(index, animated: animated)
    }

    func performScroll(toPageID id: AnyHashable, animated: Bool) -> Bool {
        guard let index = indexOfPage(id: id, in: dataSource) else { return false }
        return scrollToPage(index, animated: animated)
    }

    func resolvePageIndex(forID id: AnyHashable) -> Int? {
        indexOfPage(id: id, in: dataSource)
    }

    private func indexOfPage(id: AnyHashable, in dataSource: PagerDataSource<Element>) -> Int? {
        dataSource.indexOfPage(id: id)
    }

    private func scrollToPage(_ index: Int, animated: Bool) -> Bool {
        guard !dataSource.isEmpty else { return false }

        pageCorrectionGeneration += 1
        pendingPageCorrection = nil

        let targetIndex = clampedPageIndex(index)
        let offsetIndex = nearestPageIndex(for: scrollView.contentOffset)
        let targetOffset = pageOffset(for: targetIndex)
        let needsOffsetUpdate = targetOffset.map { !scrollView.contentOffset.isApproximatelyEqual(to: $0) } ?? false
        let shouldAnimate = animated && view.window != nil && needsOffsetUpdate

        self.targetIndex = shouldAnimate ? targetIndex : nil

        if shouldAnimate && offsetIndex != targetIndex {
            updateWindow(center: offsetIndex, directionBias: directionSign(from: offsetIndex, to: targetIndex))
        } else {
            updateWindow(center: targetIndex)
        }

        layoutAttachedHosts()
        prewarmAttachedHostLayouts()
        resetZoomOutsideCurrentPage(targetIndex)
        currentIndex = targetIndex
        updateSettledAnchor(index: targetIndex)
        scrollPhase = shouldAnimate ? .animating : .idle
        setPageOffset(targetIndex, animated: shouldAnimate, finishAnimationOnDirectWrite: true)
        notifyController()
        return true
    }
}
#endif
