import Foundation
import SwiftPagerKit
import SwiftUI
import UIKit

public struct ContentView: View {
    @StateObject private var galleryViewModel: GalleryViewModel
    @StateObject private var reelsViewModel: ReelsViewModel
    @State private var selectedGallery: GallerySelection?
    @State private var activeGalleryTransitionSourceID: String?
    @State private var galleryGridScrollTargetID: String?
    @State private var galleryGridScrollGeneration = 0
    @State private var selectedTabIndex = DemoTab.gallery.pageIndex
    @State private var continuousTabIndex: CGFloat = CGFloat(DemoTab.gallery.pageIndex)
    @StateObject private var tabCoordinator = DemoTabCoordinator()
    @Namespace private var galleryTransition
    private let showsDiagnostics: Bool

    public init(
        showsDiagnostics: Bool = ProcessInfo.processInfo.environment["SWIFTPAGERKIT_DEMO_SHOW_DIAGNOSTICS"] == "1"
    ) {
        _galleryViewModel = StateObject(
            wrappedValue: GalleryViewModel()
        )
        _reelsViewModel = StateObject(
            wrappedValue: ReelsViewModel()
        )
        self.showsDiagnostics = showsDiagnostics
    }

    public var body: some View {
        GeometryReader { proxy in
            ZStack {
                tabPager
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .ignoresSafeArea()

                DemoBottomTabBar(
                    selection: selectedTabBinding,
                    continuousIndex: continuousTabIndex,
                    bottomInset: proxy.safeAreaInsets.bottom
                )
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .ignoresSafeArea(.container, edges: [.top, .bottom])
        .preferredColorScheme(.dark)
        .onAppear {
            tabCoordinator.activate(liveSelectedTab)
        }
        .onChange(of: continuousTabIndex) { _, _ in
            tabCoordinator.activate(liveSelectedTab)
        }
        .onChange(of: selectedTabIndex) { _, _ in
            tabCoordinator.activate(liveSelectedTab)
        }
        .fullScreenCover(item: $selectedGallery) { selection in
            GalleryPagerDemoView(
                galleryViewModel: galleryViewModel,
                initialPage: selection.index,
                openingPreviewImage: selection.previewImage,
                showsDiagnostics: showsDiagnostics,
                onActiveItemChange: { itemID in
                    activeGalleryTransitionSourceID = itemID
                    scheduleGalleryGridRecenter(to: itemID)
                }
            ) {
                selectedGallery = nil
            }
            .navigationTransition(
                .zoom(
                    sourceID: activeGalleryTransitionSourceID ?? selection.initialItemID,
                    in: galleryTransition
                )
            )
            .presentationBackground(.clear)
        }
    }

    private var tabPager: some View {
        SwiftPager(DemoTab.allCases, page: $selectedTabIndex, direction: .horizontal) { tab in
            tabContent(for: tab)
        }
        .pageSpacing(0)
        .cachePolicy(.performance)
        .continuousPageIndex($continuousTabIndex)
        .pagerAccessibilityLabel("Demo sections")
        .pagerAccessibilityValue { state in
            DemoTab(pageIndex: state.currentPage)?.title ?? "Gallery"
        }
        .accessibilityIdentifier("demoTabPager")
    }

    @ViewBuilder
    private func tabContent(for tab: DemoTab) -> some View {
        switch tab {
        case .gallery:
            GalleryGridView(
                viewModel: galleryViewModel,
                transitionFocusID: $galleryGridScrollTargetID,
                transitionNamespace: galleryTransition,
                openIndex: openGallery
            )
            .accessibilityHidden(liveSelectedTab != .gallery)
        case .reels:
            ReelsView(
                viewModel: reelsViewModel,
                tabCoordinator: tabCoordinator
            )
            .accessibilityHidden(liveSelectedTab != .reels)
        }
    }

    private var selectedTab: DemoTab {
        DemoTab(pageIndex: selectedTabIndex) ?? .gallery
    }

    private var liveSelectedTab: DemoTab {
        let liveIndex = continuousTabIndex.isFinite ? Int(continuousTabIndex.rounded()) : selectedTabIndex
        return DemoTab(pageIndex: liveIndex) ?? selectedTab
    }

    private var selectedTabBinding: Binding<DemoTab> {
        Binding(
            get: { liveSelectedTab },
            set: { tab in
                selectedTabIndex = tab.pageIndex
                continuousTabIndex = CGFloat(tab.pageIndex)
            }
        )
    }

    private func openGallery(at index: Int) {
        guard let item = galleryViewModel.item(at: index) else { return }
        let itemID = item.id
        activeGalleryTransitionSourceID = itemID
        selectedGallery = GallerySelection(
            index: index,
            initialItemID: itemID,
            previewImage: DemoImageMemoryCache.previewImage(for: item.photo.thumbnailURLs + item.photo.imageURLs)
        )
    }

    private func scheduleGalleryGridRecenter(to itemID: String) {
        galleryGridScrollGeneration += 1
        let generation = galleryGridScrollGeneration

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(420))
            guard selectedGallery != nil, galleryGridScrollGeneration == generation else { return }
            galleryGridScrollTargetID = itemID
        }
    }
}

enum DemoTab: Hashable, CaseIterable {
    case gallery
    case reels

    init?(pageIndex: Int) {
        guard DemoTab.allCases.indices.contains(pageIndex) else { return nil }
        self = DemoTab.allCases[pageIndex]
    }

    var pageIndex: Int {
        switch self {
        case .gallery:
            0
        case .reels:
            1
        }
    }
}

@MainActor
final class DemoTabCoordinator: ObservableObject {
    @Published private(set) var liveTab = DemoTab.gallery

    func activate(_ tab: DemoTab) {
        guard liveTab != tab else { return }
        liveTab = tab
    }
}

private struct GallerySelection: Identifiable, Equatable {
    let presentationID = UUID()
    let index: Int
    let initialItemID: String
    let previewImage: UIImage?

    var id: UUID { presentationID }

    static func == (lhs: GallerySelection, rhs: GallerySelection) -> Bool {
        lhs.presentationID == rhs.presentationID
    }
}
