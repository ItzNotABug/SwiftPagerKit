import Foundation
import SwiftPagerKit
import SwiftUI

struct GalleryPagerDemoView: View {
    @StateObject private var pagerController = SwiftPagerController()
    @ObservedObject var galleryViewModel: GalleryViewModel
    @State private var page: Int
    @State private var contentRefreshToken = 0
    @State private var continuousIndex: CGFloat
    @State private var lastZoomScale: CGFloat = 1
    @State private var backdropOpacity: CGFloat = 1
    @State private var lastPhase = SwiftPagerScrollPhase.idle
    @State private var eventCount = 0
    @State private var lastEvent = "Ready"
    @State private var showsOpeningPreview: Bool
    @State private var showsDiagnostics: Bool
    private let openingPreviewImage: UIImage?
    var onActiveItemChange: (String) -> Void
    var close: () -> Void

    init(
        galleryViewModel: GalleryViewModel,
        initialPage: Int,
        openingPreviewImage: UIImage?,
        showsDiagnostics: Bool,
        onActiveItemChange: @escaping (String) -> Void,
        close: @escaping () -> Void
    ) {
        self.galleryViewModel = galleryViewModel
        self.openingPreviewImage = openingPreviewImage
        self.onActiveItemChange = onActiveItemChange
        self.close = close
        let boundedPage = min(max(initialPage, 0), max(galleryViewModel.items.count - 1, 0))
        _page = State(initialValue: boundedPage)
        _continuousIndex = State(initialValue: CGFloat(boundedPage))
        _showsOpeningPreview = State(initialValue: openingPreviewImage != nil)
        _showsDiagnostics = State(initialValue: showsDiagnostics)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.ignoresSafeArea()

                pager
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .ignoresSafeArea()

                GalleryVignette()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                if showsOpeningPreview, let openingPreviewImage {
                    Image(uiImage: openingPreviewImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }

                VStack(spacing: 0) {
                    GalleryTopBar(
                        showsDiagnostics: showsDiagnostics,
                        toggleDiagnostics: { showsDiagnostics.toggle() },
                        shuffle: shuffleItems,
                        reset: resetItems,
                        close: close
                    )

                    Spacer(minLength: 0)

                    if showsDiagnostics {
                        GalleryDiagnosticsPanel(
                            loadedRangeText: loadedRangeText,
                            phaseText: lastPhase.title,
                            zoomText: zoomText,
                            itemCountText: "\(galleryViewModel.items.count)",
                            positionText: String(format: "%.2f", Double(continuousIndex)),
                            sourceText: galleryViewModel.status,
                            eventCountText: "\(eventCount)",
                            lastEvent: lastEvent,
                            jumpAhead: jumpAhead,
                            loadMore: { loadMoreGallery(reason: "append") },
                            removeItem: removeItem
                        )
                        .padding(.bottom, 14)
                    }

                    GalleryCaptionOverlay(
                        currentPage: livePageIndex,
                        pageCount: galleryViewModel.items.count,
                        continuousIndex: continuousIndex
                    )
                }
                .padding(.leading, 20)
                .padding(.trailing, max(proxy.safeAreaInsets.trailing + 18, 18))
                .padding(.top, max(proxy.safeAreaInsets.top + 12, 52))
                .padding(.bottom, max(proxy.safeAreaInsets.bottom + 14, 24))
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .ignoresSafeArea()
        .statusBar(hidden: true)
        .onChange(of: page) { _, newValue in
            handlePageChange(newValue)
        }
        .onChange(of: continuousIndex) { _, _ in
            updateActiveTransitionSource()
        }
        .onChange(of: galleryViewModel.items.map(\.id)) { _, _ in
            updateActiveTransitionSource()
        }
        .onAppear {
            updateActiveTransitionSource()
            hideOpeningPreview()
        }
        .task {
            await loadInitialGalleryIfNeeded()
        }
    }

    private var pager: some View {
        SwiftPager(galleryViewModel.items, id: \.id, reuseType: \.reuseType, page: $page, direction: .horizontal) { item in
            GalleryPage(item: item)
        }
        .pageSpacing(0)
        .cachePolicy(.performance)
        .contentRefreshToken(contentRefreshToken)
        .controller(pagerController)
        .continuousPageIndex($continuousIndex)
        .zoomable { _ in
            .enabled(minimumScale: 1, maximumScale: 5)
        }
        .onZoomChange { _, scale in
            if abs(scale - lastZoomScale) >= 0.05 {
                lastZoomScale = scale
            }
        }
        .onScrollPhaseChange { phase in
            lastPhase = phase
        }
        .onDragStart {
            record("drag page=\(page)")
        }
        .onTap {
            record("tap page=\(page)")
        }
        .onOverscroll { boundary in
            record("overscroll=\(boundary.title)")
        }
        .onLoadMore(when: .nearEnd(offsetFromEnd: 4)) {
            loadMoreGallery(reason: "loadMore")
        }
        .onPullToDismiss(backgroundOpacity: $backdropOpacity) {
            record("dismiss page=\(page)")
            close()
        }
        .pagerAccessibilityLabel("Gallery pager")
        .pagerAccessibilityValue { state in
            guard state.pageCount > 0 else { return "No photos" }
            return "Photo \(state.currentPage + 1) of \(state.pageCount)"
        }
        .background(Color.black.opacity(max(0.08, backdropOpacity)))
        .accessibilityIdentifier("demoPager")
    }

    private var currentItem: DemoItem? {
        guard !galleryViewModel.items.isEmpty else { return nil }
        return galleryViewModel.items[livePageIndex]
    }

    private var livePageIndex: Int {
        guard !galleryViewModel.items.isEmpty else { return 0 }
        let livePage = continuousIndex.isFinite ? Int(continuousIndex.rounded()) : page
        return min(max(livePage, 0), galleryViewModel.items.count - 1)
    }

    private var loadedRangeText: String {
        guard let loadedRange = pagerController.loadedRange else { return "-" }
        return "\(loadedRange.lowerBound)-\(loadedRange.upperBound)"
    }

    private var zoomText: String {
        String(format: "%.2fx", Double(max(lastZoomScale, 1)))
    }

    private func jumpAhead() {
        guard !galleryViewModel.items.isEmpty else { return }

        let target = min(page + 7, galleryViewModel.items.count - 1)
        let item = galleryViewModel.items[target]
        pagerController.scrollToPage(id: item.id, animated: true)
        record("jump target=\(target)")
    }

    private func removeItem() {
        guard let event = galleryViewModel.remove(at: page) else { return }

        page = min(page, max(galleryViewModel.items.count - 1, 0))
        contentRefreshToken += 1
        record(event)
    }

    private func shuffleItems() {
        record(galleryViewModel.shuffle())
        page = 0
        contentRefreshToken += 1
    }

    private func resetItems() {
        galleryViewModel.reset()
        page = 0
        continuousIndex = 0
        lastZoomScale = 1
        backdropOpacity = 1
        contentRefreshToken += 1
        record("reset")

        Task {
            await loadInitialGalleryIfNeeded()
        }
    }

    private func handlePageChange(_ newValue: Int) {
        lastZoomScale = 1
        updateActiveTransitionSource()
        record("page=\(newValue)")
    }

    private func loadInitialGalleryIfNeeded() async {
        guard let event = await galleryViewModel.loadInitialIfNeeded() else { return }
        contentRefreshToken += 1
        updateActiveTransitionSource()
        record(event)
    }

    private func loadMoreGallery(reason: String) {
        Task {
            guard let event = await galleryViewModel.loadMore(reason: reason) else { return }
            contentRefreshToken += 1
            record(event)
        }
    }

    private func record(_ event: String) {
        eventCount += 1
        lastEvent = event
    }

    private func updateActiveTransitionSource() {
        guard let itemID = currentItem?.id else { return }
        onActiveItemChange(itemID)
    }

    private func hideOpeningPreview() {
        guard showsOpeningPreview else { return }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(280))
            withAnimation(.easeInOut(duration: 0.18)) {
                showsOpeningPreview = false
            }
        }
    }
}
