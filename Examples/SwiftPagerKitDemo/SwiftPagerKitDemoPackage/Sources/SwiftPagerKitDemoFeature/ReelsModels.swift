import Foundation

struct ReelItem: Identifiable, Equatable {
    let id: String
    var index: Int
    var title: String
    var creator: String
    var duration: Int
    var posterURL: URL?
    var videoURL: URL?
    var sourceURL: URL?

    var reuseType: String { "reel" }

    var detail: String {
        let seconds = max(duration, 0)
        return seconds > 0 ? "\(creator) - \(seconds)s" : creator
    }

    static func placeholders(startIndex: Int = 0, count: Int) -> [ReelItem] {
        (0..<count).map { offset in
            let index = startIndex + offset
            return ReelItem(
                id: "reel-placeholder-\(index)",
                index: index,
                title: ["Forest Light", "Ocean Light", "Sea Drift", "Sunset Tree"][index % 4],
                creator: "Offline Demo",
                duration: 0,
                posterURL: nil,
                videoURL: nil,
                sourceURL: nil
            )
        }
    }

    static func sampleVideos(startIndex: Int = 0, count: Int = 8) -> [ReelItem] {
        guard !SampleReelVideo.all.isEmpty else { return placeholders(startIndex: startIndex, count: count) }

        return (0..<count).map { offset in
            let index = startIndex + offset
            let sample = SampleReelVideo.all[index % SampleReelVideo.all.count]
            return ReelItem(
                id: "sample-reel-\(index)-\(sample.id)",
                index: index,
                title: sample.title,
                creator: sample.creator,
                duration: sample.duration,
                posterURL: sample.posterURL,
                videoURL: sample.url,
                sourceURL: sample.sourceURL
            )
        }
    }
}

private struct SampleReelVideo {
    var id: String
    var title: String
    var creator: String
    var duration: Int
    var resourceName: String
    var sourceURL: URL

    var url: URL? {
        Bundle.module.url(forResource: resourceName, withExtension: "mp4", subdirectory: "Reels")
            ?? Bundle.module.url(forResource: resourceName, withExtension: "mp4")
    }

    var posterURL: URL? {
        Bundle.module.url(forResource: resourceName, withExtension: "jpg", subdirectory: "Reels")
            ?? Bundle.module.url(forResource: resourceName, withExtension: "jpg")
    }

    static let all: [SampleReelVideo] = [
        SampleReelVideo(
            id: "mixkit-reel-01",
            title: "Palm tree in front of the sun",
            creator: "Mixkit",
            duration: 8,
            resourceName: "reel-01",
            sourceURL: URL(string: "https://mixkit.co/free-stock-video/palm-tree-in-front-of-the-sun-1191/")!
        ),
        SampleReelVideo(
            id: "mixkit-reel-02",
            title: "Aerial turquoise beach",
            creator: "Mixkit",
            duration: 8,
            resourceName: "reel-02",
            sourceURL: URL(string: "https://mixkit.co/free-stock-video/aerial-view-of-the-beautiful-turquoise-waves-crashing-on-the-51500/")!
        ),
        SampleReelVideo(
            id: "mixkit-reel-03",
            title: "Water falling over stones",
            creator: "Mixkit",
            duration: 8,
            resourceName: "reel-03",
            sourceURL: URL(string: "https://mixkit.co/free-stock-video/water-falling-over-stones-2186/")!
        ),
        SampleReelVideo(
            id: "mixkit-reel-04",
            title: "Sunset from the sea",
            creator: "Mixkit",
            duration: 8,
            resourceName: "reel-04",
            sourceURL: URL(string: "https://mixkit.co/free-stock-video/stunning-sunset-seen-from-the-sea-4119/")!
        ),
        SampleReelVideo(
            id: "mixkit-reel-05",
            title: "Countryside meadow",
            creator: "Mixkit",
            duration: 8,
            resourceName: "reel-05",
            sourceURL: URL(string: "https://mixkit.co/free-stock-video/countryside-meadow-4075/")!
        ),
        SampleReelVideo(
            id: "mixkit-reel-06",
            title: "Peaceful beach sunset",
            creator: "Mixkit",
            duration: 7,
            resourceName: "reel-06",
            sourceURL: URL(string: "https://mixkit.co/free-stock-video/sunset-from-a-peaceful-beach-44496/")!
        ),
        SampleReelVideo(
            id: "mixkit-reel-07",
            title: "Sailboat at sunset",
            creator: "Mixkit",
            duration: 8,
            resourceName: "reel-07",
            sourceURL: URL(string: "https://mixkit.co/free-stock-video/view-of-the-horizon-in-the-sea-while-a-sailboat-4477/")!
        ),
        SampleReelVideo(
            id: "mixkit-reel-08",
            title: "Waterfall in forest",
            creator: "Mixkit",
            duration: 8,
            resourceName: "reel-08",
            sourceURL: URL(string: "https://mixkit.co/free-stock-video/waterfall-in-forest-2213/")!
        ),
    ]
}
