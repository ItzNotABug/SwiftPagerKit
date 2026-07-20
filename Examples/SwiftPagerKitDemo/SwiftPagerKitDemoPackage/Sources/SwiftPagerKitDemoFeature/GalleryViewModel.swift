import Combine
import Foundation

@MainActor
final class GalleryViewModel: ObservableObject {
    @Published private(set) var items: [DemoItem]
    @Published private(set) var status: String
    @Published private(set) var isLoading = false
    @Published private(set) var hasLoadedInitialResults = true

    private let initialItemCount = 18
    private let loadMoreItemCount = 9

    init() {
        self.items = DemoItem.gallerySamples(count: initialItemCount)
        self.status = "Bundled"
    }

    func loadInitialIfNeeded() async -> String? {
        hasLoadedInitialResults = true
        status = "Bundled"
        return nil
    }

    func loadMore(reason: String) async -> String? {
        guard !isLoading else { return nil }

        isLoading = true
        defer { isLoading = false }

        let startIndex = (items.map(\.index).max() ?? -1) + 1
        items.append(contentsOf: DemoItem.gallerySamples(startIndex: startIndex, count: loadMoreItemCount))
        return "\(reason) count=\(items.count)"
    }

    func remove(at index: Int) -> String? {
        guard !items.isEmpty else { return nil }
        let removeIndex = min(index, items.count - 1)
        items.remove(at: removeIndex)
        return "remove image=\(removeIndex)"
    }

    func shuffle() -> String {
        items.shuffle()
        return "shuffle count=\(items.count)"
    }

    func reset() {
        items = DemoItem.gallerySamples(count: initialItemCount)
        hasLoadedInitialResults = true
        isLoading = false
        status = "Bundled"
    }

    func itemID(at index: Int) -> String? {
        guard items.indices.contains(index) else { return nil }
        return items[index].id
    }

    func item(at index: Int) -> DemoItem? {
        guard items.indices.contains(index) else { return nil }
        return items[index]
    }

}
