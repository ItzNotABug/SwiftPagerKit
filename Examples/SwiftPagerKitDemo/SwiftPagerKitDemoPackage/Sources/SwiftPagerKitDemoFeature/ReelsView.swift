import SwiftPagerKit
import SwiftUI

struct ReelsView: View {
    @ObservedObject var viewModel: ReelsViewModel
    @ObservedObject var tabCoordinator: DemoTabCoordinator
    @StateObject private var controller = SwiftPagerController()
    @StateObject private var playback = ReelPlaybackCoordinator()
    @State private var page = 0
    @State private var continuousPage: CGFloat = 0
    @State private var contentRefreshToken = 0

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.ignoresSafeArea()

                pager
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .ignoresSafeArea()

                reelsTopChrome(proxy: proxy)
            }
        }
        .ignoresSafeArea(.container, edges: [.top, .bottom])
        .statusBar(hidden: true)
        .task {
            await viewModel.loadInitialIfNeeded()
            updateActiveReel()
        }
        .onAppear {
            updateActiveReel()
        }
        .onDisappear {
            playback.activate(itemID: nil)
        }
        .onChange(of: page) { _, _ in
            updateActiveReel()
        }
        .onChange(of: continuousPage) { _, _ in
            updateActiveReel()
        }
        .onChange(of: isActive) { _, nextIsActive in
            if nextIsActive {
                updateActiveReel()
            } else {
                playback.activate(itemID: nil)
            }
        }
        .onChange(of: viewModel.items.map(\.id)) { _, _ in
            page = min(page, max(viewModel.items.count - 1, 0))
            continuousPage = min(max(continuousPage, 0), CGFloat(max(viewModel.items.count - 1, 0)))
            contentRefreshToken += 1
            updateActiveReel()
        }
    }

    private var pager: some View {
        SwiftPager(viewModel.items, id: \.id, reuseType: \.reuseType, page: $page, direction: .vertical) { item in
            ReelVideoPage(item: item, playback: playback)
        }
        .pageSpacing(0)
        .cachePolicy(.minimal)
        .contentRefreshToken(contentRefreshToken)
        .continuousPageIndex($continuousPage)
        .controller(controller)
        .onLoadMore(when: .nearEnd(offsetFromEnd: 3)) {
            Task {
                await viewModel.loadMore(reason: "loadMore")
            }
        }
        .pagerAccessibilityLabel("Vertical reels pager")
        .pagerAccessibilityValue { state in
            guard state.pageCount > 0 else { return "No reels" }
            return "Reel \(state.currentPage + 1) of \(state.pageCount)"
        }
        .accessibilityIdentifier("reelsPager")
    }

    private var livePageIndex: Int {
        guard !viewModel.items.isEmpty else { return 0 }
        let roundedIndex = Int(continuousPage.rounded())
        return min(max(roundedIndex, 0), viewModel.items.count - 1)
    }

    private var isActive: Bool {
        tabCoordinator.liveTab == .reels
    }

    private func reelsTopChrome(proxy: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                HStack(alignment: .center, spacing: 8) {
                    Text("Reels")
                        .font(.title2.weight(.heavy))

                    Text(viewModel.status)
                        .font(.caption2.weight(.heavy))
                        .textCase(.uppercase)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .glassEffect(
                            .regular.tint(.black.opacity(0.14)),
                            in: Capsule()
                        )
                }
                .frame(height: 50, alignment: .center)
                .shadow(color: .black.opacity(0.58), radius: 10, y: 4)

                Spacer(minLength: 12)

                Button {
                    viewModel.reset()
                    page = 0
                    continuousPage = 0
                    contentRefreshToken += 1
                    updateActiveReel()
                    Task {
                        await viewModel.loadInitialIfNeeded()
                        updateActiveReel()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 16, weight: .heavy))
                        .frame(width: 50, height: 50)
                        .glassEffect(
                            .regular.tint(.black.opacity(0.18)).interactive(),
                            in: Circle()
                        )
                        .clipShape(Circle())
                        .contentShape(Circle())
                        .shadow(color: .black.opacity(0.55), radius: 8, y: 3)
                }
                .buttonStyle(.plain)
                .focusEffectDisabled()
                .accessibilityLabel("Refresh reels")
            }
            .foregroundStyle(.white)
            .padding(.leading, 20)
            .padding(.trailing, max(proxy.safeAreaInsets.trailing + 18, 18))
            .padding(.top, max(proxy.safeAreaInsets.top + 12, 52))

            Spacer(minLength: 0)
        }
        .allowsHitTesting(true)
    }

    private func updateActiveReel() {
        guard isActive else {
            playback.activate(itemID: nil)
            return
        }

        let index = livePageIndex
        guard viewModel.items.indices.contains(index) else {
            playback.activate(itemID: nil)
            return
        }

        let itemID = viewModel.items[index].id
        playback.activate(itemID: itemID)
    }
}
