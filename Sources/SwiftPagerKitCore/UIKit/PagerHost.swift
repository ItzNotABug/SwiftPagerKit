#if canImport(UIKit)
import SwiftUI
import UIKit

@MainActor
final class PagerHost<Element, Content: View> {
    let controller: UIHostingController<PagerHostedRoot<Content>>
    var index: Int
    var id: AnyHashable
    var reuseType: AnyHashable?
    private(set) var contentRefreshToken: SwiftPagerContentRefreshToken?
    private var element: Element
    private var zoomContainer: PagerZoomContainer<Element>?

    var view: UIView {
        zoomContainer ?? controller.view
    }

    init(
        item: PagerItem<Element>,
        contentRefreshToken: SwiftPagerContentRefreshToken?,
        settings: SwiftPagerSettings<Element>,
        direction: SwiftPagerDirection,
        content: (Element) -> Content
    ) {
        self.controller = UIHostingController(
            rootView: PagerHostedRoot(id: item.id, content: content(item.element))
        )
        self.index = item.index
        self.id = item.id
        self.reuseType = item.reuseType
        self.contentRefreshToken = contentRefreshToken
        self.element = item.element
        controller.view.backgroundColor = .clear
        updateContainerRequirement(item: item, settings: settings)
    }

    func bind(
        item: PagerItem<Element>,
        updatePolicy: SwiftPagerContentUpdatePolicy,
        contentRefreshToken: SwiftPagerContentRefreshToken?,
        settings: SwiftPagerSettings<Element>,
        direction: SwiftPagerDirection,
        content: (Element) -> Content,
        force: Bool = false
    ) {
        let isNewPageIdentity = force || id != item.id
        if shouldUpdateRootView(for: item, updatePolicy: updatePolicy, contentRefreshToken: contentRefreshToken, force: force) {
            controller.rootView = PagerHostedRoot(id: item.id, content: content(item.element))
            self.contentRefreshToken = contentRefreshToken
        }
        index = item.index
        id = item.id
        reuseType = item.reuseType
        element = item.element
        updateContainerRequirement(item: item, settings: settings)
        if isNewPageIdentity {
            zoomContainer?.prepareForReuse()
        }
    }

    private func shouldUpdateRootView(
        for item: PagerItem<Element>,
        updatePolicy: SwiftPagerContentUpdatePolicy,
        contentRefreshToken: SwiftPagerContentRefreshToken?,
        force: Bool
    ) -> Bool {
        if force || id != item.id {
            return true
        }

        switch updatePolicy {
        case .always:
            return true
        case .identity:
            return false
        case .refreshToken:
            guard let contentRefreshToken else { return true }
            return self.contentRefreshToken != contentRefreshToken
        }
    }

    func attach(
        to parent: UIViewController,
        in scrollView: UIScrollView,
        settings: SwiftPagerSettings<Element>,
        direction: SwiftPagerDirection
    ) {
        if let zoomContainer {
            zoomContainer.setHostedView(controller.view)
            zoomContainer.configure(
                pageID: id,
                element: element,
                settings: settings,
                direction: direction
            )
        }

        let parentChanged = controller.parent !== parent
        if controller.parent !== parent {
            if controller.parent != nil {
                controller.willMove(toParent: nil)
                view.removeFromSuperview()
                controller.removeFromParent()
            }
            parent.addChild(controller)
        }

        if view.superview !== scrollView {
            scrollView.addSubview(view)
        }

        if parentChanged {
            controller.didMove(toParent: parent)
        }
    }

    func updateSemanticContentAttribute(_ attribute: UISemanticContentAttribute) {
        controller.view.semanticContentAttribute = attribute
        if let zoomContainer {
            zoomContainer.semanticContentAttribute = .forceLeftToRight
        } else {
            view.semanticContentAttribute = attribute
        }
    }

    func detach() {
        view.removeFromSuperview()
    }

    func prepareForRetention() {
        removeFromParentIfNeeded()
        zoomContainer?.prepareForRetention()
    }

    func prewarmLayout() {
        if let zoomContainer {
            zoomContainer.setNeedsLayout()
            zoomContainer.layoutIfNeeded()
        }
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
    }

    func prepareForReuse() {
        if controller.parent != nil {
            controller.willMove(toParent: nil)
            view.removeFromSuperview()
            controller.removeFromParent()
        } else {
            view.removeFromSuperview()
        }
        view.frame = .zero
        zoomContainer?.prepareForReuse()
    }

    func discard() {
        zoomContainer?.prepareForRemoval()
        if controller.parent != nil {
            controller.willMove(toParent: nil)
            view.removeFromSuperview()
            controller.removeFromParent()
        } else {
            view.removeFromSuperview()
        }
    }

    func resetZoom(animated: Bool = false) {
        zoomContainer?.resetZoom(animated: animated)
    }

    private func updateContainerRequirement(
        item: PagerItem<Element>,
        settings: SwiftPagerSettings<Element>
    ) {
        if settings.requiresPageContainer(for: item.element) {
            if zoomContainer == nil {
                zoomContainer = PagerZoomContainer<Element>()
                zoomContainer?.setHostedView(controller.view)
            }
        } else if let existingContainer = zoomContainer {
            _ = existingContainer.removeHostedView()
            existingContainer.removeFromSuperview()
            zoomContainer = nil
        }
    }

    private func removeFromParentIfNeeded() {
        guard controller.parent != nil else { return }
        controller.willMove(toParent: nil)
        view.removeFromSuperview()
        controller.removeFromParent()
    }
}

struct PagerHostedRoot<Content: View>: View {
    var id: AnyHashable
    var content: Content

    var body: some View {
        content.id(id)
    }
}
#endif
