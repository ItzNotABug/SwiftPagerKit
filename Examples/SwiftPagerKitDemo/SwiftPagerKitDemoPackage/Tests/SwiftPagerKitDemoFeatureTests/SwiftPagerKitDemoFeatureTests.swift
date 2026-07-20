import Foundation
import Testing
@testable import SwiftPagerKitDemoFeature

@Test
func demoItemsHaveStableUniqueIDs() {
    let items = DemoItem.galleryPlaceholders(count: 100)
    let ids = Set(items.map(\.id))

    #expect(ids.count == items.count)
}

@Test
func galleryItemsUsePhotoReuseType() {
    let items = DemoItem.galleryPlaceholders(count: 9)
    let reuseTypes = Set(items.map(\.reuseType))

    #expect(reuseTypes == ["photo"])
}

@Test
func galleryPlaceholdersUseStablePhotoPages() {
    let items = DemoItem.galleryPlaceholders(count: 8)

    #expect(items.allSatisfy { $0.photo.imageURL == nil })
    #expect(Set(items.map(\.index)).count == items.count)
}

@Test
func gallerySamplesUseNineStaticPortraitPhotos() {
    let items = DemoItem.gallerySamples()
    let ids = Set(items.map(\.id))

    #expect(items.count == 9)
    #expect(ids.count == items.count)
    #expect(items.allSatisfy { $0.photo.width == 1080 })
    #expect(items.allSatisfy { $0.photo.height == 1920 })
    #expect(items.allSatisfy { $0.photo.imageURL?.isFileURL == true })
    #expect(items.allSatisfy { $0.photo.thumbnailURLs.allSatisfy(\.isFileURL) })
}

@Test
func gallerySamplesCycleBundledAssetsWithUniqueIDs() {
    let items = DemoItem.gallerySamples(count: 18)
    let ids = Set(items.map(\.id))
    let resourcePaths = Set(items.compactMap { $0.photo.imageURL?.lastPathComponent })

    #expect(items.count == 18)
    #expect(ids.count == items.count)
    #expect(resourcePaths.count == 9)
}

@Test
@MainActor
func galleryViewModelStartsFullAndAppendsBundledPages() async {
    let viewModel = GalleryViewModel()

    #expect(viewModel.status == "Bundled")
    #expect(viewModel.items.count == 18)

    let event = await viewModel.loadMore(reason: "grid")
    #expect(event == "grid count=27")
    #expect(viewModel.items.count == 27)
    #expect(Set(viewModel.items.map(\.id)).count == viewModel.items.count)
    #expect(viewModel.items.allSatisfy { $0.photo.imageURL?.isFileURL == true })
}

@Test
@MainActor
func reelsViewModelStartsWithPlayableSamples() {
    let viewModel = ReelsViewModel()

    #expect(viewModel.status == "Bundled")
    #expect(viewModel.items.allSatisfy { $0.videoURL != nil })
    #expect(viewModel.items.allSatisfy { $0.posterURL != nil })
    #expect(viewModel.items.allSatisfy { $0.videoURL?.isFileURL == true })
    #expect(viewModel.items.allSatisfy { $0.posterURL?.isFileURL == true })
    #expect(viewModel.hasLoadedInitialResults)
}

@Test
@MainActor
func reelsViewModelAppendsBundledSamples() async {
    let viewModel = ReelsViewModel()

    #expect(viewModel.items.count == 8)

    await viewModel.loadMore(reason: "loadMore")
    #expect(viewModel.status == "Bundled")
    #expect(viewModel.items.count == 16)
    #expect(Set(viewModel.items.map(\.id)).count == viewModel.items.count)
    #expect(viewModel.items.allSatisfy { $0.videoURL?.isFileURL == true })
}

@Test
func sampleReelsHaveStablePlayableURLs() {
    let reels = ReelItem.sampleVideos(count: 12)
    let ids = Set(reels.map(\.id))

    #expect(ids.count == reels.count)
    #expect(reels.allSatisfy { $0.videoURL?.isFileURL == true })
    #expect(reels.allSatisfy { $0.posterURL?.isFileURL == true })
    #expect(reels.allSatisfy { $0.sourceURL?.host == "mixkit.co" })
}

@Test
@MainActor
func reelPlaybackCoordinatorTracksActiveItemID() {
    let coordinator = ReelPlaybackCoordinator()

    #expect(coordinator.activeItemID == nil)

    coordinator.activate(itemID: "reel-a")
    #expect(coordinator.activeItemID == "reel-a")

    coordinator.activate(itemID: "reel-b")
    #expect(coordinator.activeItemID == "reel-b")

    coordinator.activate(itemID: nil)
    #expect(coordinator.activeItemID == nil)
}
