#if canImport(UIKit)
import SwiftUI
import UIKit

/// A helper view that clears SwiftUI presentation wrapper backgrounds.
///
/// Place this in full-screen covers or overlays when SwiftUI inserts an opaque
/// hosting background around the pager.
public struct PagerClearBackground: UIViewRepresentable {
    /// Creates a background-clearing helper view.
    public init() {}

    /// Creates the marker view used to discover and clear ancestor backgrounds.
    public func makeUIView(context: Context) -> UIView {
        let view = UIView()
        PagerBackgroundClearing.clearAncestorsWhenAttached(to: view)
        return view
    }

    /// Re-runs background clearing after SwiftUI updates the hierarchy.
    public func updateUIView(_ uiView: UIView, context: Context) {
        PagerBackgroundClearing.clearAncestorsWhenAttached(to: uiView)
    }
}

@MainActor
enum PagerBackgroundClearing {
    static let maximumAttempts = 8
    static let retryDelayNanoseconds: UInt64 = 10_000_000

    static func clearAncestorsWhenAttached(to view: UIView, attemptsRemaining: Int = maximumAttempts) {
        if clearAncestors(of: view).reachedWindow {
            return
        }

        guard attemptsRemaining > 0 else { return }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: retryDelayNanoseconds)
            clearAncestorsWhenAttached(to: view, attemptsRemaining: attemptsRemaining - 1)
        }
    }

    @discardableResult
    static func clearAncestors(of view: UIView) -> AncestorClearResult {
        var didClearAncestor = false
        var currentView = view.superview

        while let ancestor = currentView {
            if ancestor is UIWindow {
                return AncestorClearResult(didClearAncestor: didClearAncestor, reachedWindow: true)
            }

            ancestor.backgroundColor = .clear
            didClearAncestor = true
            currentView = ancestor.superview
        }

        return AncestorClearResult(didClearAncestor: didClearAncestor, reachedWindow: false)
    }

    struct AncestorClearResult: Equatable {
        var didClearAncestor: Bool
        var reachedWindow: Bool
    }
}
#endif
