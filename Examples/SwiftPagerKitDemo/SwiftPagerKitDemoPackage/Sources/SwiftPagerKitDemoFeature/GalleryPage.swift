import SwiftUI

struct GalleryPage: View {
    let item: DemoItem

    var body: some View {
        ZStack {
            Color.black

            if !item.photo.imageURLs.isEmpty {
                DemoResourceImage(
                    urls: item.photo.imageURLs,
                    previewURLs: item.photo.thumbnailURLs,
                    title: item.title
                )
            } else {
                GalleryPlaceholder()
            }
        }
        .contentShape(Rectangle())
        .ignoresSafeArea()
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isImage)
        .accessibilityLabel("Gallery image \(item.index + 1), \(item.title), \(item.detail)")
        .accessibilityIdentifier("demoPage-\(item.index)")
    }
}

struct GalleryPlaceholder: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.12, blue: 0.18),
                    Color(red: 0.15, green: 0.18, blue: 0.24),
                    Color(red: 0.05, green: 0.06, blue: 0.08),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

struct GalleryFailure: View {
    var body: some View {
        GalleryPlaceholder()
    }
}
