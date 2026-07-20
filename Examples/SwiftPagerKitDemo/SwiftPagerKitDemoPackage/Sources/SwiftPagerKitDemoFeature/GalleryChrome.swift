import SwiftUI

struct GalleryVignette: View {
    var body: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [Color.black.opacity(0.28), Color.black.opacity(0.08), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 120)

            Spacer(minLength: 0)

            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.28), Color.black.opacity(0.9)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 360)
        }
    }
}

struct GalleryTopBar: View {
    var showsDiagnostics: Bool
    var toggleDiagnostics: () -> Void
    var shuffle: () -> Void
    var reset: () -> Void
    var close: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if let close {
                Button(action: close) {
                    Image(systemName: "xmark")
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
                .accessibilityLabel("Close gallery")
                .accessibilityIdentifier("closeGalleryPager")
            }

            Spacer(minLength: 12)

            Menu {
                Button(action: toggleDiagnostics) {
                    Label(showsDiagnostics ? "Hide Diagnostics" : "Show Diagnostics", systemImage: "waveform.path.ecg.rectangle")
                }
                .accessibilityIdentifier("diagnosticsToggle")

                Button(action: shuffle) {
                    Label("Shuffle Photos", systemImage: "shuffle")
                }
                .accessibilityIdentifier("shufflePages")

                Button(action: reset) {
                    Label("Reset Gallery", systemImage: "arrow.counterclockwise")
                }
                .accessibilityIdentifier("resetPages")
            } label: {
                ZStack {
                    Color.clear

                    Image(systemName: "ellipsis")
                        .font(.system(size: 19, weight: .heavy))
                        .symbolRenderingMode(.hierarchical)
                }
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
            .foregroundStyle(.white)
            .accessibilityIdentifier("galleryMenu")
        }
        .foregroundStyle(.white)
        .accessibilityElement(children: .contain)
    }
}

struct GalleryCaptionOverlay: View {
    var currentPage: Int
    var pageCount: Int
    var continuousIndex: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            GalleryWormIndicator(
                currentPage: currentPage,
                pageCount: pageCount,
                continuousIndex: continuousIndex
            )
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 38, alignment: .bottomLeading)
    }
}

struct GalleryWormIndicator: View {
    var currentPage: Int
    var pageCount: Int
    var continuousIndex: CGFloat

    private let visibleDotLimit = 5

    var body: some View {
        if pageCount > 1 {
            HStack(spacing: 7) {
                ForEach(visibleIndexes, id: \.self) { index in
                    Capsule()
                        .fill(index == activePage ? Color.white : Color.white.opacity(0.36))
                        .frame(width: index == activePage ? 30 : 7, height: 7)
                        .shadow(
                            color: index == activePage ? .black.opacity(0.34) : .clear,
                            radius: 8,
                            y: 2
                        )
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .glassEffect(
                .regular.tint(.black.opacity(0.18)),
                in: Capsule()
            )
            .animation(.snappy(duration: 0.22), value: activePage)
            .accessibilityElement()
            .accessibilityLabel("Gallery position")
            .accessibilityValue("Photo \(activePage + 1) of \(pageCount)")
            .accessibilityIdentifier("pageWormIndicator")
        }
    }

    private var activePage: Int {
        guard pageCount > 0 else { return 0 }

        let livePage = continuousIndex.isFinite ? Int(continuousIndex.rounded()) : currentPage
        return min(max(livePage, 0), pageCount - 1)
    }

    private var visibleIndexes: [Int] {
        guard pageCount > visibleDotLimit else {
            return Array(0..<pageCount)
        }

        let sideCount = visibleDotLimit / 2
        let lowerBound = min(max(activePage - sideCount, 0), pageCount - visibleDotLimit)
        return Array(lowerBound..<(lowerBound + visibleDotLimit))
    }
}

struct GalleryDiagnosticsPanel: View {
    var loadedRangeText: String
    var phaseText: String
    var zoomText: String
    var itemCountText: String
    var positionText: String
    var sourceText: String
    var eventCountText: String
    var lastEvent: String
    var jumpAhead: () -> Void
    var loadMore: () -> Void
    var removeItem: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                metric("Loaded", loadedRangeText, identifier: "loadedCounter")
                metric("Phase", phaseText, identifier: "phaseCounter")
                metric("Zoom", zoomText, identifier: "zoomCounter")
                metric("Items", itemCountText, identifier: "itemCounter")
                metric("Position", positionText, identifier: "positionCounter")
                metric("Source", sourceText, identifier: "sourceCounter")
                metric("Events", eventCountText, identifier: "eventCounter")
            }

            HStack(spacing: 12) {
                diagnosticsButton("Jump Ahead", systemImage: "scope", action: jumpAhead)
                    .accessibilityIdentifier("jumpAhead")
                diagnosticsButton("Load More", systemImage: "plus", action: loadMore)
                    .accessibilityIdentifier("insertPage")
                diagnosticsButton("Remove Photo", systemImage: "minus", action: removeItem)
                    .accessibilityIdentifier("removePage")
            }

            Text(lastEvent)
                .font(.footnote.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("lastEvent")
        }
        .padding(14)
        .glassEffect(
            .regular.tint(.black.opacity(0.2)),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func metric(_ title: String, _ value: String, identifier: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.monospacedDigit().weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .accessibilityIdentifier(identifier)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func diagnosticsButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .labelStyle(.iconOnly)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.glass)
        .accessibilityLabel(title)
    }
}
