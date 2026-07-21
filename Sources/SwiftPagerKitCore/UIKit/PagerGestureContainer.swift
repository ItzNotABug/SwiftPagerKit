#if canImport(UIKit)
import UIKit

@MainActor
final class PagerGestureContainer<Element>: UIView {
    private var hostedView: UIView?
    private var settings = SwiftPagerSettings<Element>()
    private var singleTapRecognizer: UITapGestureRecognizer?
    private var doubleTapRecognizer: UITapGestureRecognizer?
    private var configuredGestureShape: GestureShape?

    private struct GestureShape: Equatable {
        var needsSingleTap: Bool
        var needsDoubleTap: Bool
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        clipsToBounds = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(settings: SwiftPagerSettings<Element>) {
        self.settings = settings.normalized()
        configureGestureRecognizers()
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
        let view = hostedView
        hostedView?.removeFromSuperview()
        hostedView = nil
        return view
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard let hostedView, hostedView.frame != bounds else { return }
        hostedView.frame = bounds
    }

    private func configureGestureRecognizers() {
        let shape = GestureShape(
            needsSingleTap: settings.onTap != nil,
            needsDoubleTap: settings.onDoubleTap != nil
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

    @objc func handleSingleTap(_ recognizer: UITapGestureRecognizer) {
        settings.onTap?()
    }

    @objc func handleDoubleTap(_ recognizer: UITapGestureRecognizer) {
        settings.onDoubleTap?()
    }
}
#endif
