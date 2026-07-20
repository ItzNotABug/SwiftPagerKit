import AVFoundation
import SwiftUI
import UIKit

struct ReelVideoPage: View {
    let item: ReelItem
    @ObservedObject var playback: ReelPlaybackCoordinator

    @StateObject private var playerModel = ReelPlayerModel()
    @State private var overlayIcon: PlaybackOverlayIcon = .play
    @State private var isOverlayVisible = false
    @State private var overlayHideTask: Task<Void, Never>?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if let posterURL = item.posterURL {
                    DemoResourceImage(urls: [posterURL], title: item.title)
                } else {
                    ReelPlaceholder()
                }

                PlayerSurface(player: playerModel.player)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .opacity(playerModel.player == nil ? 0 : 1)

                ReelVignette()

                PlaybackStatusOverlay(icon: overlayIcon)
                    .scaleEffect(isOverlayVisible ? 1 : 0.82)
                    .opacity(isOverlayVisible ? 1 : 0)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .contentShape(Rectangle())
        .ignoresSafeArea()
        .task(id: item.videoURL) {
            playerModel.configure(url: item.videoURL)
            playerModel.setActive(isActive)
        }
        .onChange(of: playback.activeItemID) { _, _ in
            playerModel.setActive(isActive)
        }
        .onTapGesture {
            handlePlaybackTap()
        }
        .onDisappear {
            overlayHideTask?.cancel()
            isOverlayVisible = false
            playerModel.release()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Reel \(item.index + 1), \(item.title), by \(item.creator)")
        .accessibilityValue(playbackAccessibilityValue)
        .accessibilityHint("Tap to play or pause")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction {
            handlePlaybackTap()
        }
        .accessibilityIdentifier("reelPage-\(item.index)")
    }

    private var isActive: Bool {
        playback.activeItemID == item.id
    }

    private var playbackAccessibilityValue: String {
        isActive && !playerModel.isUserPaused ? "Playing" : "Paused"
    }

    private func handlePlaybackTap() {
        let icon = playerModel.togglePlayback()
        showTransientOverlay(icon)
    }

    private func showTransientOverlay(_ icon: PlaybackOverlayIcon) {
        overlayHideTask?.cancel()

        overlayHideTask = Task { @MainActor in
            let hadVisibleIcon = isOverlayVisible
            if hadVisibleIcon {
                withAnimation(.easeInOut(duration: 0.22)) {
                    isOverlayVisible = false
                }
                try? await Task.sleep(for: .milliseconds(230))
                guard !Task.isCancelled else { return }
            }

            overlayIcon = icon
            withAnimation(.snappy(duration: 0.18)) {
                isOverlayVisible = true
            }

            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.28)) {
                isOverlayVisible = false
            }
        }
    }
}

@MainActor
private final class ReelPlayerModel: ObservableObject {
    @Published private(set) var player: AVPlayer?
    @Published private(set) var isUserPaused = false

    private var currentURL: URL?
    private var isActive = false
    private var timeControlObservation: NSKeyValueObservation?
    private let endObserver = NotificationObserverBox()

    func configure(url: URL?) {
        guard currentURL != url else { return }
        currentURL = url
        timeControlObservation = nil
        endObserver.remove()

        guard let url else {
            player = nil
            return
        }

        let playerItem = AVPlayerItem(url: url)
        playerItem.preferredForwardBufferDuration = 2
        let nextPlayer = AVPlayer(playerItem: playerItem)
        nextPlayer.isMuted = true
        nextPlayer.volume = 0
        nextPlayer.automaticallyWaitsToMinimizeStalling = true
        observePlayback(on: nextPlayer)
        observeLoop(on: nextPlayer, item: playerItem)
        player = nextPlayer
        applyPlaybackState()
    }

    func release() {
        isActive = false
        isUserPaused = false
        currentURL = nil
        timeControlObservation = nil
        endObserver.remove()
        player?.pause()
        player = nil
    }

    func setActive(_ nextActiveState: Bool) {
        isActive = nextActiveState
        if !nextActiveState {
            isUserPaused = false
        }
        applyPlaybackState()
    }

    func togglePlayback() -> PlaybackOverlayIcon {
        guard player != nil else { return .play }

        if isActive {
            isUserPaused.toggle()
            applyPlaybackState()
            return isUserPaused ? .pause : .play
        } else {
            isUserPaused = false
            applyPlaybackState()
            return .play
        }
    }

    private func applyPlaybackState() {
        guard let player else { return }

        if isActive && !isUserPaused {
            player.isMuted = true
            player.volume = 0
            player.playImmediately(atRate: 1)
        } else {
            player.pause()
        }
    }

    private func observePlayback(on player: AVPlayer) {
        timeControlObservation = player.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if self.isActive && !self.isUserPaused && player.timeControlStatus == .paused {
                    player.playImmediately(atRate: 1)
                }
            }
        }
    }

    private func observeLoop(on player: AVPlayer, item: AVPlayerItem) {
        endObserver.replace(
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: item,
                queue: .main
            ) { [weak self, weak player] _ in
                Task { @MainActor [weak self, weak player] in
                    guard let self, let player, self.isActive, !self.isUserPaused else { return }
                    player.seek(to: .zero)
                    player.playImmediately(atRate: 1)
                }
            }
        )
    }

    deinit {
        timeControlObservation?.invalidate()
    }
}

private final class NotificationObserverBox: @unchecked Sendable {
    private var observer: NSObjectProtocol?

    func replace(_ nextObserver: NSObjectProtocol) {
        remove()
        observer = nextObserver
    }

    func remove() {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
            self.observer = nil
        }
    }

    deinit {
        remove()
    }
}

private enum PlaybackOverlayIcon {
    case play
    case pause

    var systemImage: String {
        switch self {
        case .play:
            "play.fill"
        case .pause:
            "pause.fill"
        }
    }
}

private struct PlaybackStatusOverlay: View {
    var icon: PlaybackOverlayIcon

    var body: some View {
        Image(systemName: icon.systemImage)
            .font(.system(size: 34, weight: .heavy))
            .frame(width: 86, height: 86)
            .glassEffect(
                .regular.tint(.black.opacity(0.18)),
                in: Circle()
            )
            .shadow(color: .black.opacity(0.42), radius: 18, y: 8)
            .foregroundStyle(.white)
            .allowsHitTesting(false)
    }
}

private struct PlayerSurface: UIViewRepresentable {
    var player: AVPlayer?

    func makeUIView(context: Context) -> PlayerSurfaceView {
        let view = PlayerSurfaceView()
        view.playerLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PlayerSurfaceView, context: Context) {
        uiView.playerLayer.player = player
    }
}

private final class PlayerSurfaceView: UIView {
    override static var layerClass: AnyClass {
        AVPlayerLayer.self
    }

    var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }
}

private struct ReelVignette: View {
    var body: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [.black.opacity(0.36), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 180)

            Spacer(minLength: 0)

            LinearGradient(
                colors: [.clear, .black.opacity(0.84)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 320)
        }
        .allowsHitTesting(false)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ReelPlaceholder: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.03, green: 0.04, blue: 0.05),
                Color(red: 0.13, green: 0.16, blue: 0.16),
                Color.black,
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay {
            Image(systemName: "play.rectangle.fill")
                .font(.system(size: 54, weight: .semibold))
                .foregroundStyle(.white.opacity(0.26))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
