import Combine
import Foundation

@MainActor
final class ReelsViewModel: ObservableObject {
    @Published private(set) var items: [ReelItem]
    @Published private(set) var status: String
    @Published private(set) var isLoading = false
    @Published private(set) var hasLoadedInitialResults = true

    init() {
        self.items = ReelItem.sampleVideos(count: 8)
        self.status = "Bundled"
    }

    func loadInitialIfNeeded() async {
        hasLoadedInitialResults = true
        status = "Bundled"
    }

    func loadMore(reason _: String) async {
        guard hasLoadedInitialResults else { return }

        appendSamples()
    }

    func reset() {
        items = ReelItem.sampleVideos(count: 8)
        hasLoadedInitialResults = true
        isLoading = false
        status = "Bundled"
    }

    private func appendSamples() {
        let startIndex = (items.map(\.index).max() ?? -1) + 1
        items.append(contentsOf: ReelItem.sampleVideos(startIndex: startIndex, count: 8))
        status = "Bundled"
    }
}
