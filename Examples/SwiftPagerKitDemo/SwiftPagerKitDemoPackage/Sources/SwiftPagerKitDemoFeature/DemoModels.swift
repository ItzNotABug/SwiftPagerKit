import Foundation

struct DemoItem: Identifiable, Equatable {
    let id: String
    var index: Int
    var title: String
    var detail: String
    var photo: DemoPhoto

    var reuseType: String { "photo" }

    init(photo: DemoPhoto, index: Int) {
        self.id = "gallery-\(index)-\(photo.id)"
        self.index = index
        self.title = photo.title
        self.detail = photo.detail
        self.photo = photo
    }

    static func galleryPlaceholders(startIndex: Int = 0, count: Int) -> [DemoItem] {
        (0..<count).map { offset in
            let index = startIndex + offset
            return DemoItem(photo: DemoPhoto.placeholder(index: index), index: index)
        }
    }

    static func gallerySamples(startIndex: Int = 0, count: Int = 9) -> [DemoItem] {
        DemoPhoto.bundledSamples(startIndex: startIndex, count: count).map { photo in
            DemoItem(photo: photo, index: photo.index)
        }
    }
}

struct DemoPhoto: Equatable, Hashable {
    var id: String
    var index: Int
    var title: String
    var photographer: String
    var width: Int
    var height: Int
    var thumbnailURLs: [URL]
    var imageURLs: [URL]
    var pageURL: URL?

    var imageURL: URL? { imageURLs.first }

    var detail: String {
        guard width > 0, height > 0 else { return "Offline sample" }
        return "\(photographer) - \(width) x \(height)"
    }

    static func placeholder(index: Int) -> DemoPhoto {
        let titles = [
            "Coastline",
            "Alpine Light",
            "City Glass",
            "Desert Road",
            "Forest Rain",
            "Harbor Night",
            "Canyon Edge",
            "Studio Bloom",
            "Morning Ridge",
            "Concrete Lines",
        ]

        return DemoPhoto(
            id: "placeholder-\(index)",
            index: index,
            title: titles[index % titles.count],
            photographer: "Bundled sample",
            width: 0,
            height: 0,
            thumbnailURLs: [],
            imageURLs: [],
            pageURL: nil
        )
    }

    static func bundledSamples(startIndex: Int = 0, count: Int) -> [DemoPhoto] {
        guard !BundledGalleryAsset.all.isEmpty else {
            return (0..<count).map { placeholder(index: startIndex + $0) }
        }

        return (0..<count).map { offset in
            let index = startIndex + offset
            let sample = BundledGalleryAsset.all[index % BundledGalleryAsset.all.count]
            return DemoPhoto(
                id: "\(sample.id)-\(index)",
                index: index,
                title: sample.title,
                photographer: sample.photographer,
                width: 1080,
                height: 1920,
                thumbnailURLs: sample.fileURL.map { [$0] } ?? [],
                imageURLs: sample.fileURL.map { [$0] } ?? [],
                pageURL: sample.pageURL
            )
        }
    }
}

private struct BundledGalleryAsset {
    var id: String
    var title: String
    var photographer: String
    var resourceName: String
    var pageURL: URL?

    var fileURL: URL? {
        Bundle.module.url(forResource: resourceName, withExtension: "jpg", subdirectory: "Gallery")
            ?? Bundle.module.url(forResource: resourceName, withExtension: "jpg")
    }

    static let all: [BundledGalleryAsset] = [
        BundledGalleryAsset(
            id: "palm-silhouette",
            title: "Palm Silhouette",
            photographer: "Mixkit",
            resourceName: "gallery-01",
            pageURL: URL(string: "https://mixkit.co/free-stock-video/palm-tree-in-front-of-the-sun-1191/")
        ),
        BundledGalleryAsset(
            id: "turquoise-break",
            title: "Turquoise Break",
            photographer: "Mixkit",
            resourceName: "gallery-02",
            pageURL: URL(string: "https://mixkit.co/free-stock-video/aerial-view-of-the-beautiful-turquoise-waves-crashing-on-the-51500/")
        ),
        BundledGalleryAsset(
            id: "stone-cascade",
            title: "Stone Cascade",
            photographer: "Mixkit",
            resourceName: "gallery-03",
            pageURL: URL(string: "https://mixkit.co/free-stock-video/water-falling-over-stones-2186/")
        ),
        BundledGalleryAsset(
            id: "sea-sunset",
            title: "Sea Sunset",
            photographer: "Mixkit",
            resourceName: "gallery-04",
            pageURL: URL(string: "https://mixkit.co/free-stock-video/stunning-sunset-seen-from-the-sea-4119/")
        ),
        BundledGalleryAsset(
            id: "meadow-light",
            title: "Meadow Light",
            photographer: "Mixkit",
            resourceName: "gallery-05",
            pageURL: URL(string: "https://mixkit.co/free-stock-video/countryside-meadow-4075/")
        ),
        BundledGalleryAsset(
            id: "beach-dusk",
            title: "Beach Dusk",
            photographer: "Mixkit",
            resourceName: "gallery-06",
            pageURL: URL(string: "https://mixkit.co/free-stock-video/sunset-from-a-peaceful-beach-44496/")
        ),
        BundledGalleryAsset(
            id: "open-horizon",
            title: "Open Horizon",
            photographer: "Mixkit",
            resourceName: "gallery-07",
            pageURL: URL(string: "https://mixkit.co/free-stock-video/view-of-the-horizon-in-the-sea-while-a-sailboat-4477/")
        ),
        BundledGalleryAsset(
            id: "forest-falls",
            title: "Forest Falls",
            photographer: "Mixkit",
            resourceName: "gallery-08",
            pageURL: URL(string: "https://mixkit.co/free-stock-video/waterfall-in-forest-2213/")
        ),
        BundledGalleryAsset(
            id: "shoreline-detail",
            title: "Shoreline Detail",
            photographer: "Mixkit",
            resourceName: "gallery-09",
            pageURL: URL(string: "https://mixkit.co/free-stock-video/aerial-view-of-the-beautiful-turquoise-waves-crashing-on-the-51500/")
        ),
    ]
}
