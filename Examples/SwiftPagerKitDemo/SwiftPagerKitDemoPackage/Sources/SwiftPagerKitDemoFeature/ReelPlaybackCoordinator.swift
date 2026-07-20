import Combine
import Foundation

@MainActor
final class ReelPlaybackCoordinator: ObservableObject {
    @Published private(set) var activeItemID: String?

    func activate(itemID: String?) {
        guard activeItemID != itemID else { return }
        activeItemID = itemID
    }
}
