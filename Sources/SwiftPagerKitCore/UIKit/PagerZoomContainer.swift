#if canImport(UIKit)
import SwiftUI
import UIKit

@MainActor
final class PagerZoomContainer<Element>: UIScrollView, UIScrollViewDelegate, UIGestureRecognizerDelegate {
    private var hostedView: UIView?
    private var settings = SwiftPagerSettings<Element>()
    private var element: Element?
    private var direction: SwiftPagerDirection = .horizontal
    private var singleTapRecognizer: UITapGestureRecognizer?
    private var doubleTapRecognizer: UITapGestureRecognizer?
    private var isUserZooming = false
    private var isDismissAnimationRunning = false
    private var dismissAnimationGeneration = 0
    private var lastBoundsSize: CGSize = .zero
    private var needsMinimumZoomReset = false
    private var configuredGestureShape: GestureShape?
    private var configuredZoomConfiguration: SwiftPagerZoomConfiguration = .disabled
    private var dismissBindingPageID: AnyHashable?

    private struct GestureShape: Equatable {
        var needsSingleTap: Bool
        var needsDoubleTap: Bool
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        bounces = true
        bouncesZoom = true
        contentInsetAdjustmentBehavior = .never
        decelerationRate = .fast
        delegate = self
        panGestureRecognizer.delegate = self
        showsHorizontalScrollIndicator = false
        showsVerticalScrollIndicator = false
        clipsToBounds = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(
        pageID: AnyHashable? = nil,
        element: Element,
        settings: SwiftPagerSettings<Element>,
        direction: SwiftPagerDirection
    ) {
        let normalizedSettings = settings.normalized()
        restorePreviousDismissBackgroundBindingIfNeeded(replacingWith: normalizedSettings, pageID: pageID)
        self.element = element
        self.settings = normalizedSettings
        self.direction = direction
        self.dismissBindingPageID = pageID
        let zoomConfiguration = self.settings.zoomConfiguration(element)
        configuredZoomConfiguration = zoomConfiguration
        configureZoom(zoomConfiguration)
        configureGestureRecognizers(zoomConfiguration: zoomConfiguration)
        configureBounceBehavior()
    }

    func setHostedView(_ view: UIView) {
        guard hostedView !== view else {
            setNeedsLayout()
            return
        }

        hostedView?.removeFromSuperview()
        hostedView = view
        view.backgroundColor = .clear
        addSubview(view)
        setNeedsLayout()
    }

    func removeHostedView() -> UIView? {
        prepareForRemoval()
        let view = hostedView
        hostedView?.removeFromSuperview()
        hostedView = nil
        return view
    }

    func resetZoom(animated: Bool = false) {
        guard zoomScale != minimumZoomScale else { return }
        setZoomScale(minimumZoomScale, animated: animated)
        contentInset = .zero
    }

    func prepareForReuse() {
        prepareForRemoval()
        isUserZooming = false
        lastBoundsSize = .zero
        needsMinimumZoomReset = true
        resetZoom(animated: false)
        contentInset = .zero
    }

    func prepareForRetention() {
        prepareForRemoval()
        isUserZooming = false
        resetZoom(animated: false)
        contentInset = .zero
    }

    func prepareForRemoval() {
        dismissAnimationGeneration += 1
        isDismissAnimationRunning = false
        isUserInteractionEnabled = true
        transform = .identity
        setContentOffset(.zero, animated: false)
        setDismissBackgroundOpacity(1, deferred: true)
        dismissBindingPageID = nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard let hostedView else { return }

        let sizeChanged = lastBoundsSize != bounds.size
        if sizeChanged {
            lastBoundsSize = bounds.size
        }

        if hostedView.frame == .zero || sizeChanged || zoomScale <= minimumZoomScale {
            hostedView.frame = CGRect(origin: .zero, size: bounds.size)
        }

        let contentWidth = canDismiss && direction == .vertical ? bounds.width + 1 : bounds.width
        let contentHeight = canDismiss && direction == .horizontal ? bounds.height + 1 : bounds.height
        let targetSize = CGSize(width: contentWidth, height: contentHeight)
        if zoomScale <= minimumZoomScale, contentSize != targetSize {
            contentSize = targetSize
        }

        updateZoomInsets()
    }

    private var canDismiss: Bool {
        settings.onDismiss != nil
    }

    private var dismissPullOffset: CGFloat {
        switch direction {
        case .horizontal:
            contentOffset.y
        case .vertical:
            contentOffset.x
        }
    }

    private var dismissExtent: CGFloat {
        switch direction {
        case .horizontal:
            bounds.height
        case .vertical:
            bounds.width
        }
    }

    private func dismissVelocity(from velocity: CGPoint) -> CGFloat {
        switch direction {
        case .horizontal:
            velocity.y
        case .vertical:
            velocity.x
        }
    }

    private var dismissTransform: CGAffineTransform {
        switch direction {
        case .horizontal:
            CGAffineTransform(translationX: 0, y: bounds.height)
        case .vertical:
            CGAffineTransform(translationX: bounds.width, y: 0)
        }
    }

    private func configureZoom(_ zoomConfiguration: SwiftPagerZoomConfiguration) {
        switch zoomConfiguration {
        case .disabled:
            minimumZoomScale = 1
            maximumZoomScale = 1
            if needsMinimumZoomReset || zoomScale != 1 {
                setZoomScale(1, animated: false)
            }
            needsMinimumZoomReset = false
            setPinchGestureEnabled(false)
        case let .enabled(minimum, maximum, _):
            let clampedMinimum = max(0.01, minimum)
            let clampedMaximum = max(clampedMinimum, maximum)
            let shouldResetZoom = needsMinimumZoomReset ||
                zoomScale < clampedMinimum ||
                zoomScale > clampedMaximum
            minimumZoomScale = clampedMinimum
            maximumZoomScale = clampedMaximum
            if shouldResetZoom {
                setZoomScale(clampedMinimum, animated: false)
            }
            needsMinimumZoomReset = false
            setPinchGestureEnabled(clampedMaximum > clampedMinimum)
        }
    }

    private func configureBounceBehavior() {
        alwaysBounceVertical = canDismiss && direction == .horizontal
        alwaysBounceHorizontal = canDismiss && direction == .vertical
    }

    private func configureGestureRecognizers(zoomConfiguration: SwiftPagerZoomConfiguration) {
        let shape = GestureShape(
            needsSingleTap: settings.onTap != nil,
            needsDoubleTap: settings.onDoubleTap != nil || zoomDoubleTapAction(from: zoomConfiguration) != nil
        )
        guard configuredGestureShape != shape else { return }

        if let singleTapRecognizer {
            removeGestureRecognizer(singleTapRecognizer)
            self.singleTapRecognizer = nil
        }
        if let doubleTapRecognizer {
            removeGestureRecognizer(doubleTapRecognizer)
            self.doubleTapRecognizer = nil
        }

        var singleTap: UITapGestureRecognizer?
        if shape.needsSingleTap {
            let recognizer = UITapGestureRecognizer(target: self, action: #selector(handleSingleTap(_:)))
            recognizer.numberOfTapsRequired = 1
            recognizer.numberOfTouchesRequired = 1
            addGestureRecognizer(recognizer)
            singleTap = recognizer
            singleTapRecognizer = recognizer
        }

        if shape.needsDoubleTap {
            let recognizer = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
            recognizer.numberOfTapsRequired = 2
            recognizer.numberOfTouchesRequired = 1
            addGestureRecognizer(recognizer)
            singleTap?.require(toFail: recognizer)
            doubleTapRecognizer = recognizer
        }
        configuredGestureShape = shape
    }

    private var zoomDoubleTap: SwiftPagerDoubleTapAction? {
        zoomDoubleTapAction(from: configuredZoomConfiguration)
    }

    private func zoomDoubleTapAction(from zoomConfiguration: SwiftPagerZoomConfiguration) -> SwiftPagerDoubleTapAction? {
        guard case let .enabled(_, _, doubleTap) = zoomConfiguration else { return nil }
        guard doubleTap != .disabled else { return nil }
        return doubleTap
    }

    private func setPinchGestureEnabled(_ isEnabled: Bool) {
        guard pinchGestureRecognizer?.isEnabled != isEnabled else { return }
        pinchGestureRecognizer?.isEnabled = isEnabled
    }

    @objc private func handleSingleTap(_ recognizer: UITapGestureRecognizer) {
        settings.onTap?()
    }

    @objc private func handleDoubleTap(_ recognizer: UITapGestureRecognizer) {
        settings.onDoubleTap?()

        guard case let .zoom(toFraction: scale) = zoomDoubleTap,
              maximumZoomScale > minimumZoomScale,
              let hostedView
        else {
            return
        }

        let normalizedScale = min(max(scale, 0), 1)
        let targetScale = zoomScale <= minimumZoomScale
            ? minimumZoomScale + (maximumZoomScale - minimumZoomScale) * normalizedScale
            : minimumZoomScale
        let point = recognizer.location(in: hostedView)
        zoom(to: zoomRect(centeredAt: point, scale: targetScale), animated: true)
    }

    private func zoomRect(centeredAt point: CGPoint, scale: CGFloat) -> CGRect {
        let width = bounds.width / scale
        let height = bounds.height / scale
        return CGRect(
            x: point.x - width / 2,
            y: point.y - height / 2,
            width: width,
            height: height
        )
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        settings.onDragStart?()
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateDismissProgress()
        updatePinchAvailability()
    }

    func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?) {
        isUserZooming = true
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        updateZoomInsets()
        if let element {
            settings.onZoomChange?(element, zoomScale)
        }
    }

    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        isUserZooming = false
        updateZoomInsets()
    }

    func scrollViewWillEndDragging(
        _ scrollView: UIScrollView,
        withVelocity velocity: CGPoint,
        targetContentOffset: UnsafeMutablePointer<CGPoint>
    ) {
        performDismissIfNeeded(velocity: velocity)
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        hostedView
    }

    private func updateZoomInsets() {
        guard let hostedView else { return }

        let horizontalInset = max(0, (bounds.width - hostedView.frame.width) / 2)
        let verticalInset = max(0, (bounds.height - hostedView.frame.height) / 2)
        let targetInset = UIEdgeInsets(
            top: verticalInset,
            left: horizontalInset,
            bottom: verticalInset,
            right: horizontalInset
        )
        if contentInset != targetInset {
            contentInset = targetInset
        }
    }

    private func updateDismissProgress() {
        guard canDismiss, zoomScale <= minimumZoomScale, !isDismissAnimationRunning else { return }

        let pullDistance = max(0, -dismissPullOffset)
        if pullDistance > 0 {
            let fadeDistance = dismissExtent * settings.dismissFadeDistanceRatio
            let progress = fadeDistance > 0 ? min(pullDistance / fadeDistance, 1) : 1
            setDismissBackgroundOpacity(1 - progress)
        } else {
            setDismissBackgroundOpacity(1)
        }
    }

    private func updatePinchAvailability() {
        guard maximumZoomScale > minimumZoomScale else {
            setPinchGestureEnabled(false)
            return
        }

        if canDismiss,
           zoomScale <= minimumZoomScale,
           -dismissPullOffset > settings.pinchGestureActivationOffset {
            setPinchGestureEnabled(false)
        } else {
            setPinchGestureEnabled(true)
        }
    }

    private func performDismissIfNeeded(velocity: CGPoint) {
        guard canDismiss,
              !isDismissAnimationRunning,
              !isUserZooming,
              zoomScale <= minimumZoomScale,
              let onDismiss = settings.onDismiss
        else {
            restoreDismissProgressIfNeeded()
            return
        }

        let pullDistance = max(0, -dismissPullOffset)
        let triggerDistance = dismissExtent * settings.dismissTriggerOffset
        let hasEnoughDistance = pullDistance >= triggerDistance
        let hasEnoughVelocity = dismissVelocity(from: velocity) < -settings.dismissVelocity

        guard hasEnoughDistance && hasEnoughVelocity else {
            restoreDismissProgressIfNeeded()
            return
        }

        isDismissAnimationRunning = true
        dismissAnimationGeneration += 1
        let dismissGeneration = dismissAnimationGeneration
        isUserInteractionEnabled = false
        setDismissBackgroundOpacity(0)

        UIView.animate(
            withDuration: settings.dismissAnimationDuration,
            delay: 0,
            options: [.curveEaseOut, .beginFromCurrentState],
            animations: {
                self.transform = self.dismissTransform
            },
            completion: { _ in
                guard self.dismissAnimationGeneration == dismissGeneration,
                      self.isDismissAnimationRunning
                else {
                    return
                }

                let finishDismiss = {
                    onDismiss()
                    self.restoreAfterDismissCallback()
                }

                if self.settings.disablesSwiftUIAnimationsOnDismiss {
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        finishDismiss()
                    }
                } else {
                    finishDismiss()
                }
            }
        )
    }

    private func restoreAfterDismissCallback() {
        guard isDismissAnimationRunning else { return }
        isDismissAnimationRunning = false
        isUserInteractionEnabled = true
        transform = .identity
        setContentOffset(.zero, animated: false)
        setDismissBackgroundOpacity(1)
    }

    private func restoreDismissProgressIfNeeded() {
        guard canDismiss, !isDismissAnimationRunning else { return }
        setDismissBackgroundOpacity(1)
    }

    private func restorePreviousDismissBackgroundBindingIfNeeded(
        replacingWith newSettings: SwiftPagerSettings<Element>,
        pageID: AnyHashable?
    ) {
        guard let previousBinding = settings.dismissBackgroundOpacity else { return }

        let shouldRestore: Bool
        if newSettings.onDismiss == nil || newSettings.dismissBackgroundOpacity == nil {
            shouldRestore = true
        } else if let previousPageID = dismissBindingPageID, let pageID, previousPageID != pageID {
            shouldRestore = true
        } else if let nextBinding = newSettings.dismissBackgroundOpacity {
            shouldRestore = abs(previousBinding.wrappedValue - nextBinding.wrappedValue) > 0.001
        } else {
            shouldRestore = false
        }

        guard shouldRestore else { return }
        setDismissBackgroundOpacity(previousBinding, to: 1, deferred: true)
    }

    private func setDismissBackgroundOpacity(_ opacity: CGFloat, deferred: Bool = false) {
        guard let binding = settings.dismissBackgroundOpacity else { return }
        setDismissBackgroundOpacity(binding, to: opacity, deferred: deferred)
    }

    private func setDismissBackgroundOpacity(_ binding: Binding<CGFloat>, to opacity: CGFloat, deferred: Bool) {
        guard abs(binding.wrappedValue - opacity) > 0.001 else { return }
        if deferred {
            DispatchQueue.main.async {
                guard abs(binding.wrappedValue - opacity) > 0.001 else { return }
                binding.wrappedValue = opacity
            }
        } else {
            binding.wrappedValue = opacity
        }
    }

    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer === panGestureRecognizer else { return true }

        return shouldBeginPanGesture(with: panGestureRecognizer.velocity(in: self))
    }

    func shouldBeginPanGesture(with velocity: CGPoint) -> Bool {
        switch direction {
        case .horizontal:
            if canDismiss, abs(velocity.y) > abs(velocity.x), zoomScale <= minimumZoomScale {
                return true
            }

            if zoomScale <= minimumZoomScale {
                return false
            }

            let maximumOffsetX = max(-contentInset.left, contentSize.width - bounds.width + contentInset.right)
            let minimumOffsetX = -contentInset.left
            let isAtRightEdge = contentOffset.x >= maximumOffsetX - 1
            let isAtLeftEdge = contentOffset.x <= minimumOffsetX + 1
            let hasHorizontalIntent = abs(velocity.x) >= abs(velocity.y)

            if hasHorizontalIntent && isAtRightEdge && velocity.x < 0 {
                return false
            }
            if hasHorizontalIntent && isAtLeftEdge && velocity.x > 0 {
                return false
            }
            return true
        case .vertical:
            if abs(velocity.x) > abs(velocity.y) {
                return canDismiss || zoomScale > minimumZoomScale
            }

            if zoomScale <= minimumZoomScale {
                return false
            }

            let maximumOffsetY = max(-contentInset.top, contentSize.height - bounds.height + contentInset.bottom)
            let minimumOffsetY = -contentInset.top
            let isAtBottomEdge = contentOffset.y >= maximumOffsetY - 1
            let isAtTopEdge = contentOffset.y <= minimumOffsetY + 1
            let hasVerticalIntent = abs(velocity.y) >= abs(velocity.x)

            if hasVerticalIntent && isAtBottomEdge && velocity.y < 0 {
                return false
            }
            if hasVerticalIntent && isAtTopEdge && velocity.y > 0 {
                return false
            }
            return true
        }
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        false
    }
}
#endif
