#if canImport(UIKit)
import Testing
import UIKit
@testable import SwiftPagerKitCore

@MainActor
@Suite
struct PagerClearBackgroundTests {
    @Test
    func clearsAncestorChainWithoutAssumingFixedDepth() {
        let ancestors = (0..<10).map { _ in UIView() }
        let marker = UIView()

        for ancestor in ancestors {
            ancestor.backgroundColor = .red
        }

        for (parent, child) in zip(ancestors, ancestors.dropFirst()) {
            parent.addSubview(child)
        }
        ancestors.last?.addSubview(marker)

        let result = PagerBackgroundClearing.clearAncestors(of: marker)

        #expect(result.didClearAncestor)
        #expect(!result.reachedWindow)
        #expect(ancestors.allSatisfy { $0.backgroundColor == .clear })
    }

    @Test
    func doesNotClearWindowBackground() {
        let window = UIWindow()
        let root = UIView()
        let marker = UIView()

        window.backgroundColor = .red
        root.backgroundColor = .green
        window.addSubview(root)
        root.addSubview(marker)

        let result = PagerBackgroundClearing.clearAncestors(of: marker)

        #expect(result.didClearAncestor)
        #expect(result.reachedWindow)
        #expect(root.backgroundColor == .clear)
        #expect(window.backgroundColor == .red)
    }

    @Test
    func retriesUntilViewIsAttached() async {
        let root = UIView()
        let marker = UIView()

        root.backgroundColor = .red
        PagerBackgroundClearing.clearAncestorsWhenAttached(to: marker)
        root.addSubview(marker)

        await waitUntil {
            root.backgroundColor == .clear
        }

        #expect(root.backgroundColor == .clear)
    }

    @Test
    func retriesAfterPartialAttachmentUntilWindowIsReached() async {
        let window = UIWindow()
        let root = UIView()
        let wrapper = UIView()
        let marker = UIView()

        root.backgroundColor = .red
        wrapper.backgroundColor = .green
        wrapper.addSubview(marker)

        PagerBackgroundClearing.clearAncestorsWhenAttached(to: marker)
        await waitUntil {
            wrapper.backgroundColor == .clear
        }

        window.addSubview(root)
        root.addSubview(wrapper)
        await waitUntil {
            root.backgroundColor == .clear
        }

        #expect(wrapper.backgroundColor == .clear)
        #expect(root.backgroundColor == .clear)
        #expect(window.backgroundColor != .clear)
    }
}

@MainActor
private func waitUntil(_ condition: () -> Bool) async {
    for _ in 0..<20 {
        if condition() {
            return
        }
        try? await Task.sleep(nanoseconds: 10_000_000)
    }
}
#endif
