import SwiftUI

enum DemoTabBarMetrics {
    static let barHeight: CGFloat = 54
    static let gridBottomClearance: CGFloat = 112
}

struct DemoBottomTabBar: View {
    @Binding var selection: DemoTab
    var continuousIndex: CGFloat
    var bottomInset: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            ZStack {
                LinearGradient(
                    colors: [
                        Color.black.opacity(0),
                        Color.black.opacity(0.46),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 118)
                .allowsHitTesting(false)

                ZStack(alignment: .leading) {
                    GeometryReader { proxy in
                        Capsule()
                            .fill(Color.white.opacity(0.14))
                            .frame(
                                width: segmentWidth(in: proxy.size.width),
                                height: 44
                            )
                            .offset(x: segmentWidth(in: proxy.size.width) * clampedContinuousIndex)
                    }
                    .frame(height: 44)
                    .allowsHitTesting(false)

                    HStack(spacing: 0) {
                        ForEach(DemoTab.allCases, id: \.self) { tab in
                            tabButton(tab)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding(5)
                .frame(width: 244)
                .frame(height: DemoTabBarMetrics.barHeight)
                .glassEffect(
                    .regular.tint(.black.opacity(0.22)).interactive(),
                    in: Capsule()
                )
                .shadow(color: .black.opacity(0.36), radius: 18, y: 8)
                .padding(.bottom, max(bottomInset + 10, 18))
            }
            .frame(maxWidth: .infinity)
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("demoTabBar")
    }

    private func tabButton(_ tab: DemoTab) -> some View {
        let isSelected = tab == selection
        let activeAmount = activeAmount(for: tab)

        return Button {
            selection = tab
        } label: {
            HStack(spacing: 8) {
                Image(systemName: tab.systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .frame(width: 20, height: 20)

                Text(tab.title)
                    .font(.footnote.weight(.semibold))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.white.opacity(0.62 + (0.38 * activeAmount)))
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("demoTab-\(tab.title)")
    }

    private var clampedContinuousIndex: CGFloat {
        let maxIndex = CGFloat(max(DemoTab.allCases.count - 1, 0))
        guard continuousIndex.isFinite else { return 0 }
        return min(max(continuousIndex, 0), maxIndex)
    }

    private func segmentWidth(in width: CGFloat) -> CGFloat {
        width / CGFloat(max(DemoTab.allCases.count, 1))
    }

    private func activeAmount(for tab: DemoTab) -> Double {
        let distance = abs(clampedContinuousIndex - CGFloat(tab.pageIndex))
        return Double(max(0, 1 - min(distance, 1)))
    }
}

extension DemoTab {
    var title: String {
        switch self {
        case .gallery:
            "Gallery"
        case .reels:
            "Reels"
        }
    }

    var systemImage: String {
        switch self {
        case .gallery:
            "photo"
        case .reels:
            "movieclapper"
        }
    }
}
