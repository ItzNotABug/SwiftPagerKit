import ImageIO
import SwiftUI
import UIKit

struct DemoResourceImage: View {
    let urls: [URL]
    var previewURLs: [URL] = []
    let title: String

    @Environment(\.displayScale) private var displayScale
    @StateObject private var loader = DemoResourceImageLoader()

    var body: some View {
        GeometryReader { proxy in
            let loadID = DemoResourceImageLoadID(
                urls: urls,
                previewURLs: previewURLs,
                pixelWidth: Int(max(proxy.size.width * displayScale, 1).rounded(.up)),
                pixelHeight: Int(max(proxy.size.height * displayScale, 1).rounded(.up))
            )
            let immediatePreview = DemoImageMemoryCache.previewImage(for: previewURLs + urls)

            ZStack {
                switch loader.phase {
                case .empty, .loading:
                    if let immediatePreview {
                        renderedImage(immediatePreview)
                    } else {
                        GalleryPlaceholder()
                    }
                case .success(let image):
                    renderedImage(image)
                        .transition(.opacity.animation(.easeInOut(duration: 0.22)))
                case .failure:
                    if let immediatePreview {
                        renderedImage(immediatePreview)
                    } else {
                        GalleryFailure()
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
            .task(id: loadID) {
                await loader.load(
                    urls: urls,
                    previewURLs: previewURLs,
                    title: title,
                    targetSize: proxy.size,
                    scale: displayScale
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    private func renderedImage(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
    }
}

private struct DemoResourceImageLoadID: Hashable {
    var urls: [URL]
    var previewURLs: [URL]
    var pixelWidth: Int
    var pixelHeight: Int
}

@MainActor
enum DemoImageMemoryCache {
    static let imageCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 90
        cache.totalCostLimit = 120 * 1024 * 1024
        return cache
    }()

    static let previewCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 160
        cache.totalCostLimit = 80 * 1024 * 1024
        return cache
    }()

    static func previewImage(for urls: [URL]) -> UIImage? {
        for url in urls {
            if let image = previewCache.object(forKey: url.absoluteString as NSString) {
                return image
            }
        }

        return nil
    }
}

@MainActor
private final class DemoResourceImageLoader: ObservableObject {
    enum Phase {
        case empty
        case loading
        case success(UIImage)
        case failure
    }

    @Published private(set) var phase = Phase.empty

    private var activeRequestID: String?

    func load(urls: [URL], previewURLs: [URL], title: String, targetSize: CGSize, scale: CGFloat) async {
        let targetPixelSize = Self.targetPixelSize(for: targetSize, scale: scale)
        let requestID = Self.requestID(for: urls + previewURLs, targetPixelSize: targetPixelSize)

        if activeRequestID == requestID, case .success = phase {
            return
        }

        activeRequestID = requestID
        let previewImage = DemoImageMemoryCache.previewImage(for: previewURLs)
        if let previewImage {
            phase = .success(previewImage)
        } else {
            phase = .loading
        }

        for url in urls {
            guard !Task.isCancelled else {
                if activeRequestID == requestID {
                    phase = .empty
                }
                return
            }

            do {
                let image = try await Self.fetchImage(
                    from: url,
                    targetPixelSize: targetPixelSize
                )
                guard !Task.isCancelled, activeRequestID == requestID else { return }
                phase = .success(image)
                return
            } catch {
                guard !Task.isCancelled else {
                    if activeRequestID == requestID {
                        phase = .empty
                    }
                    return
                }
                guard activeRequestID == requestID else { return }
                continue
            }
        }

        guard !Task.isCancelled else { return }
        if previewImage == nil {
            phase = .failure
        }
    }

    private static func fetchImage(from url: URL, targetPixelSize: CGSize) async throws -> UIImage {
        let cacheKey = cacheKey(for: url, targetPixelSize: targetPixelSize)
        if let cachedImage = DemoImageMemoryCache.imageCache.object(forKey: cacheKey) {
            return cachedImage
        }

        guard url.isFileURL else {
            throw URLError(.unsupportedURL)
        }

        let image = try await decodedImage(from: url, targetPixelSize: targetPixelSize)
        DemoImageMemoryCache.imageCache.setObject(image, forKey: cacheKey, cost: image.memoryCost)
        DemoImageMemoryCache.previewCache.setObject(image, forKey: url.absoluteString as NSString, cost: image.memoryCost)
        return image
    }

    private nonisolated static func decodedImage(from url: URL, targetPixelSize: CGSize) async throws -> UIImage {
        try await Task.detached(priority: .userInitiated) {
            let data = try Data(contentsOf: url)
            guard let image = downsampledImage(from: data, targetPixelSize: targetPixelSize) else {
                throw URLError(.cannotDecodeContentData)
            }
            return image
        }.value
    }

    private static func targetPixelSize(for size: CGSize, scale: CGFloat) -> CGSize {
        CGSize(
            width: max(size.width * scale, 1),
            height: max(size.height * scale, 1)
        )
    }

    private static func cacheKey(for url: URL, targetPixelSize: CGSize) -> NSString {
        let width = Int(targetPixelSize.width.rounded(.up))
        let height = Int(targetPixelSize.height.rounded(.up))
        return "\(url.absoluteString)#\(width)x\(height)" as NSString
    }

    private static func requestID(for urls: [URL], targetPixelSize: CGSize) -> String {
        let width = Int(targetPixelSize.width.rounded(.up))
        let height = Int(targetPixelSize.height.rounded(.up))
        return urls.map(\.absoluteString).joined(separator: "|") + "#\(width)x\(height)"
    }

    private nonisolated static func downsampledImage(from data: Data, targetPixelSize: CGSize) -> UIImage? {
        let sourceOptions = [
            kCGImageSourceShouldCache: false,
        ] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else {
            return UIImage(data: data)
        }

        let maxPixelSize = max(
            1,
            Int(max(targetPixelSize.width, targetPixelSize.height).rounded(.up))
        )
        let thumbnailOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ] as CFDictionary

        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions) else {
            return UIImage(data: data)
        }

        return UIImage(cgImage: image)
    }
}

private extension UIImage {
    var memoryCost: Int {
        guard let cgImage else { return 1 }
        return max(cgImage.bytesPerRow * cgImage.height, 1)
    }
}
