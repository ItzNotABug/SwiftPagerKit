import SwiftUI

struct GalleryGridView: View {
    @ObservedObject var viewModel: GalleryViewModel
    @Binding var transitionFocusID: String?
    var transitionNamespace: Namespace.ID
    var openIndex: (Int) -> Void

    private let gridSpacing: CGFloat = 0.5
    private let thumbnailAspectRatio: CGFloat = 0.76

    private let columns = [
        GridItem(.flexible(), spacing: 0.5),
        GridItem(.flexible(), spacing: 0.5),
        GridItem(.flexible(), spacing: 0.5),
    ]

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ScrollViewReader { scrollProxy in
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: gridSpacing) {
                            ForEach(viewModel.items) { item in
                                Button {
                                    openItem(item)
                                } label: {
                                    GalleryGridCell(
                                        item: item,
                                        aspectRatio: thumbnailAspectRatio
                                    )
                                }
                                .frame(maxWidth: .infinity)
                                .aspectRatio(thumbnailAspectRatio, contentMode: .fit)
                                .buttonStyle(.plain)
                                .matchedTransitionSource(id: item.id, in: transitionNamespace)
                            }

                            GalleryGridLoadMoreSentinel(
                                isEnabled: isGridAutoLoadEnabled && viewModel.hasLoadedInitialResults,
                                isLoading: viewModel.isLoading
                            ) {
                                loadMoreFromGrid()
                            }
                            .gridCellColumns(columns.count)
                        }
                        .accessibilityIdentifier("galleryGrid")
                        .padding(.horizontal, gridSpacing)
                        .padding(.top, gridSpacing)
                        .padding(
                            .bottom,
                            max(
                                proxy.safeAreaInsets.bottom + DemoTabBarMetrics.gridBottomClearance,
                                DemoTabBarMetrics.gridBottomClearance
                            )
                        )
                    }
                    .background(GalleryGridBackground())
                    .onAppear {
                        scrollToTransitionSource(with: scrollProxy)
                    }
                    .onChange(of: transitionFocusID) { _, _ in
                        scrollToTransitionSource(with: scrollProxy)
                    }
                }

                GalleryGridVignette()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                VStack(spacing: 0) {
                    galleryTopChrome(proxy: proxy)
                    Spacer(minLength: 0)
                }
                .allowsHitTesting(true)
            }
        }
        .ignoresSafeArea(.container, edges: [.top, .bottom])
        .statusBar(hidden: true)
        .task {
            _ = await viewModel.loadInitialIfNeeded()
        }
    }

    private func galleryTopChrome(proxy: GeometryProxy) -> some View {
        HStack(alignment: .center) {
            HStack(alignment: .center, spacing: 8) {
                Text("Gallery")
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
                Task {
                    _ = await viewModel.loadInitialIfNeeded()
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
            .accessibilityLabel("Refresh gallery")
        }
        .foregroundStyle(.white)
        .padding(.leading, max(proxy.safeAreaInsets.leading + 20, 20))
        .padding(.trailing, max(proxy.safeAreaInsets.trailing + 18, 18))
        .padding(.top, max(proxy.safeAreaInsets.top + 12, 52))
        .accessibilityElement(children: .contain)
    }

    private func scrollToTransitionSource(with scrollProxy: ScrollViewProxy) {
        guard let transitionFocusID else { return }

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            scrollProxy.scrollTo(transitionFocusID, anchor: .center)
        }
    }

    private func loadMoreFromGrid() {
        guard isGridAutoLoadEnabled, viewModel.hasLoadedInitialResults, !viewModel.isLoading else { return }

        Task {
            _ = await viewModel.loadMore(reason: "grid")
        }
    }

    private var isGridAutoLoadEnabled: Bool {
        ProcessInfo.processInfo.environment["SWIFTPAGERKIT_DEMO_DISABLE_GRID_AUTOPREFETCH"] != "1"
    }

    private func openItem(_ item: DemoItem) {
        guard let index = viewModel.items.firstIndex(where: { $0.id == item.id }) else { return }
        openIndex(index)
    }
}

struct GalleryGridCell: View {
    let item: DemoItem
    let aspectRatio: CGFloat

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if !item.photo.thumbnailURLs.isEmpty {
                    DemoResourceImage(urls: item.photo.thumbnailURLs, title: item.title)
                } else if !item.photo.imageURLs.isEmpty {
                    DemoResourceImage(urls: item.photo.imageURLs, title: item.title)
                } else {
                    GalleryPlaceholder()
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
        .clipped()
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Open \(item.title)")
        .accessibilityIdentifier("galleryGridCell-\(item.index)")
    }
}

private struct GalleryGridBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.04, green: 0.05, blue: 0.07),
                Color(red: 0.09, green: 0.10, blue: 0.12),
                Color.black,
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

private struct GalleryGridVignette: View {
    var body: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [
                    Color.black.opacity(0.46),
                    Color.black.opacity(0.22),
                    Color.black.opacity(0.0),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 190)

            Spacer(minLength: 0)

            LinearGradient(
                colors: [
                    Color.black.opacity(0.0),
                    Color.black.opacity(0.34),
                    Color.black.opacity(0.82),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 220)
        }
    }
}

private struct GalleryGridLoadMoreSentinel: View {
    var isEnabled: Bool
    var isLoading: Bool
    var loadMore: () -> Void

    var body: some View {
        ZStack {
            if isEnabled && isLoading {
                ProgressView()
                    .controlSize(.regular)
                    .tint(.white)
                    .padding(.vertical, 22)
                    .accessibilityLabel("Loading more photos")
            } else {
                Color.clear
                    .frame(height: 1)
            }
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            guard isEnabled else { return }
            loadMore()
        }
    }
}
