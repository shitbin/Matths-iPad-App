import AVFoundation
import SwiftUI
import UIKit

/// 웹에서 승인·버전 고정한 9개 승급 MP4의 iPad 번들 레지스트리다.
/// 티어 판정은 만들지 않고 이미 결정된 서버 코드를 영상 파일로만 매핑한다.
enum RankPromotionVideoAssets {
    private static let filenames: [RankTier: String] = [
        .bronze: "bronze-rank-up.v6",
        .silver: "silver-rank-up.v6",
        .gold: "gold-rank-up.v6",
        .platinum: "platinum-rank-up.v7",
        .emerald: "emerald-rank-up.v6",
        .diamond: "diamond-rank-up.v6",
        .master: "master-rank-up.v6",
        .grandmaster: "grandmaster-rank-up.v6",
        .challenger: "challenger-rank-up.v12",
    ]

    static func url(for tier: RankTier) -> URL? {
        guard let name = filenames[tier] else { return nil }
        return Bundle.main.url(forResource: name, withExtension: "mp4", subdirectory: "RankMotion")
            ?? Bundle.main.url(forResource: name, withExtension: "mp4")
    }
}

/// AVPlayerLayer의 hardware decode 경로를 사용하고 resizeAspect로 9:16 원본을
/// landscape iPad에서도 자르지 않는다. 영상 안 AAC가 승인 음향이므로 별도 SFX는 없다.
struct RankPromotionVideoPlayer: UIViewRepresentable {
    let url: URL
    let playbackID: UUID
    let motionActive: Bool
    let onComplete: () -> Void
    let onFailure: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete, onFailure: onFailure)
    }

    func makeUIView(context: Context) -> PlayerSurface {
        let view = PlayerSurface()
        context.coordinator.attach(to: view)
        context.coordinator.configure(url: url, playbackID: playbackID, motionActive: motionActive)
        return view
    }

    func updateUIView(_ view: PlayerSurface, context: Context) {
        context.coordinator.onComplete = onComplete
        context.coordinator.onFailure = onFailure
        context.coordinator.attach(to: view)
        context.coordinator.configure(url: url, playbackID: playbackID, motionActive: motionActive)
    }

    static func dismantleUIView(_ view: PlayerSurface, coordinator: Coordinator) {
        coordinator.stop()
        view.playerLayer.player = nil
    }

    final class PlayerSurface: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

        override init(frame: CGRect) {
            super.init(frame: frame)
            backgroundColor = .clear
            isUserInteractionEnabled = false
            playerLayer.videoGravity = .resizeAspect
        }

        required init?(coder: NSCoder) { nil }
    }

    @MainActor
    final class Coordinator: NSObject {
        var onComplete: () -> Void
        var onFailure: () -> Void
        private weak var surface: PlayerSurface?
        private var player: AVPlayer?
        private var item: AVPlayerItem?
        private var playbackID: UUID?
        private var url: URL?
        private var endObserver: NSObjectProtocol?
        private var failureObserver: NSObjectProtocol?
        private var foregroundObserver: NSObjectProtocol?
        private var statusObservation: NSKeyValueObservation?
        /// 이번 재생이 끝까지 가야 하는 재생인지. 동작 줄이기에서는 정지 화면만 두므로 false.
        private var expectsPlayback = false
        /// 끝났다는 말은 한 번만 한다. 끝 통지와 실패 통지가 겹쳐도 두 번 닫지 않는다.
        private var didReportEnd = false

        init(onComplete: @escaping () -> Void, onFailure: @escaping () -> Void) {
            self.onComplete = onComplete
            self.onFailure = onFailure
        }

        deinit {
            if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
            if let failureObserver { NotificationCenter.default.removeObserver(failureObserver) }
            if let foregroundObserver { NotificationCenter.default.removeObserver(foregroundObserver) }
            statusObservation?.invalidate()
        }

        func attach(to surface: PlayerSurface) {
            self.surface = surface
            surface.playerLayer.player = player
        }

        func configure(url: URL, playbackID: UUID, motionActive: Bool) {
            guard self.playbackID != playbackID || self.url != url else { return }
            stop()
            self.playbackID = playbackID
            self.url = url

            let item = AVPlayerItem(url: url)
            item.preferredForwardBufferDuration = 1
            let player = AVPlayer(playerItem: item)
            player.actionAtItemEnd = .pause
            player.automaticallyWaitsToMinimizeStalling = true
            player.isMuted = !motionActive
            self.item = item
            self.player = player
            self.didReportEnd = false
            self.expectsPlayback = motionActive
            surface?.playerLayer.player = player

            endObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: item,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in self?.reportEnd() }
            }
            failureObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemFailedToPlayToEndTime,
                object: item,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in self?.reportFailure() }
            }
            // 파일이 아예 열리지 않으면 위의 두 통지가 오지 않는다. 그대로 두면 배경만
            // 남은 화면에서 아무 일도 일어나지 않으므로, 읽기에 실패한 순간 그림으로
            // 그리는 휘장으로 넘긴다.
            statusObservation = item.observe(\.status, options: [.new]) { [weak self] observed, _ in
                guard observed.status == .failed else { return }
                Task { @MainActor [weak self] in self?.reportFailure() }
            }
            // 홈으로 나갔다 돌아오면 재생이 멈춘 자리에 그대로 선다. 끝 통지도 오지
            // 않아 휘장이 중간 프레임에서 멎는다. 돌아온 시점에 이어서 재생한다.
            foregroundObserver = NotificationCenter.default.addObserver(
                forName: UIApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in self?.resumeAfterInterruption() }
            }

            if motionActive {
                player.playImmediately(atRate: 1)
            } else {
                // Reduce Motion에서는 소리와 시간 진행 없이 완성 휘장 정지 프레임만 보인다.
                player.seek(
                    to: CMTime(seconds: 5.7, preferredTimescale: 600),
                    toleranceBefore: .zero,
                    toleranceAfter: .zero)
                player.pause()
            }
        }

        /// 재생이 끝났다. 승급 결과와 기록은 이미 정해져 있고 여기서는 화면만 넘긴다.
        private func reportEnd() {
            guard !didReportEnd else { return }
            didReportEnd = true
            onComplete()
        }

        /// 영상을 틀 수 없다. 같은 이유로 화면만 넘기고 승급 자체는 건드리지 않는다.
        private func reportFailure() {
            guard !didReportEnd else { return }
            didReportEnd = true
            onFailure()
        }

        /// 앱이 다시 앞으로 나왔을 때 멈춰 있던 재생을 이어 붙인다. 아직 틀 준비가
        /// 안 됐거나 이미 끝까지 간 재생은 그대로 둔다.
        private func resumeAfterInterruption() {
            guard expectsPlayback, !didReportEnd else { return }
            guard let player, let item, item.status == .readyToPlay else { return }
            guard player.timeControlStatus == .paused else { return }
            let duration = item.duration
            guard duration.isNumeric, player.currentTime() < duration else { return }
            player.playImmediately(atRate: 1)
        }

        func stop() {
            player?.pause()
            if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
            if let failureObserver { NotificationCenter.default.removeObserver(failureObserver) }
            if let foregroundObserver { NotificationCenter.default.removeObserver(foregroundObserver) }
            statusObservation?.invalidate()
            endObserver = nil
            failureObserver = nil
            foregroundObserver = nil
            statusObservation = nil
            expectsPlayback = false
            item = nil
            player = nil
            surface?.playerLayer.player = nil
        }
    }
}
