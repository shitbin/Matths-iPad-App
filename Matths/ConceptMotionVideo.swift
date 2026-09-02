//  ConceptMotionVideo.swift
//  Matths
//
//  개념 설명 영상 재생. **나레이션이 구워진 단일 mp4** 를 그대로 튼다.
//
//  왜 이 파일이 생겼나:
//    종전 구조는 WKWebView 가 애니메이션을 그리고 AVSpeechSynthesizer 가 따로 TTS 를
//    읽었다. 시계가 둘이라 그림과 말이 맞을 수가 없었다 — 웹 애니메이션은 수십 초,
//    TTS 는 수백 초로 흘러 서로 다른 데를 가리켰다. 사용자 보고가 정확했다:
//    "영상이랑 목소리가 다 따로 나온다."
//
//    영상 안에 소리가 들어 있으면 어긋날 여지가 원천적으로 없다. 시계가 하나다.
//    그래서 재생 버튼도 없다 — 영상에 재생 버튼을 따로 달지 않는 것과 같다.
//
//  자산 해석:
//    번들에 넣지 않는다. 개념 220개면 1GB 를 넘어 앱 크기가 감당이 안 된다.
//    Application Support 에 내려받은 파일을 읽고, 없으면 이 뷰가 아예 서지 않아
//    호출부가 기존 벡터 무대로 폴백한다. Caches 를 쓰지 않는 이유는 iOS 가
//    임의로 비우기 때문이다.
//
//  같은 뿌리를 쓰는 형제:
//    ConceptMotionWebStage.swift 는 굽지 않은 원본(HTML 컴포지션)을 같은 자산
//    트리에서 읽어 재생한다. mp4 가 있으면 mp4 가 먼저다 — 소리가 그림 안에
//    물리적으로 들어 있는 쪽이 어긋날 여지가 더 적다.

import AVFoundation
import SwiftUI

enum ConceptMotionAsset {
    /// 내려받은 개념 영상이 사는 곳. 번들이 아니다.
    static var directory: URL? {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                                  in: .userDomainMask).first else { return nil }
        return base.appendingPathComponent("ConceptMotion", isDirectory: true)
    }

    /// 이 개념의 영상이 준비돼 있으면 그 URL. 없으면 nil.
    ///
    /// 파일명에 버전을 박는다 — 같은 개념의 영상을 고쳐 다시 내보낼 때
    /// 캐시가 옛 파일을 붙들지 않게 하려는 것이고, 이미 랭크 모션 자산이
    /// 쓰는 관례(`platinum-rank-up.v7.mp4`)와 같다.
    static func url(conceptID: String, version: Int) -> URL? {
        guard let directory else { return nil }
        let file = directory
            .appendingPathComponent(conceptID, isDirectory: true)
            .appendingPathComponent("\(conceptID).v\(version).mp4")
        return FileManager.default.fileExists(atPath: file.path) ? file : nil
    }

    /// 지금 고른 성우의 해설 음성. 음성을 껐으면 nil 이며 별도 효과음은 없다.
    ///
    /// ⚠️ 지금은 호출부가 없다(코드 애니메이션 경로가 대신 쓰인다). 되살릴 때 주의:
    /// 이 함수는 **밀어넣은 자리만** 본다. 자산은 2026-08 부터 앱 번들에도 동봉되므로
    /// 설치본에서는 여기가 nil 을 돌려준다. 두 자리를 함께 보려면
    /// ConceptMotionWebAsset.roots 처럼 개념 단위로 폴백해야 한다.
    ///
    /// `assets/` 한 칸을 반드시 거친다. 제작 저장소의 트리가 그 모양이고,
    /// 코드 애니메이션 HTML 의 `<base href="../">` 도 같은 모양을 전제로 음성을 찾는다.
    /// 같은 파일을 두 경로가 다르게 가리키면 한쪽은 반드시 빈손으로 돌아온다.
    static func narrationURL(conceptID: String,
                             voice: ConceptNarrationVoice = ConceptNarrationPreference.current) -> URL? {
        guard let folder = voice.assetFolder, let directory else { return nil }
        let file = directory
            .appendingPathComponent("assets", isDirectory: true)
            .appendingPathComponent(folder, isDirectory: true)
            .appendingPathComponent(conceptID, isDirectory: true)
            .appendingPathComponent("full.mp3")
        return FileManager.default.fileExists(atPath: file.path) ? file : nil
    }

    /// 개념 영상을 쓸 수 있는가. 호출부가 이걸 보고 무대를 고른다.
    static func isReady(conceptID: String, version: Int) -> Bool {
        url(conceptID: conceptID, version: version) != nil
    }
}

/// 개념 설명 영상 무대.
///
/// 재생 컨트롤을 두지 않는다. 화면에 들어오면 시작하고 나가면 멈춘다.
/// 소리는 영상 안에 있으므로 TTS 를 함께 돌리지 않는다 — 호출부가 그 규칙을 지킨다.
struct ConceptMotionVideoView: UIViewRepresentable {
    let url: URL
    /// 동작 줄이기를 켠 사용자에게는 첫 프레임만 세워 둔다.
    let motionActive: Bool
    let onFinished: () -> Void
    let onFailure: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinished: onFinished, onFailure: onFailure)
    }

    func makeUIView(context: Context) -> Surface {
        let view = Surface()
        context.coordinator.attach(to: view)
        context.coordinator.start(url: url, motionActive: motionActive)
        return view
    }

    func updateUIView(_ view: Surface, context: Context) {
        context.coordinator.onFinished = onFinished
        context.coordinator.onFailure = onFailure
        context.coordinator.attach(to: view)
        context.coordinator.start(url: url, motionActive: motionActive)
    }

    static func dismantleUIView(_ view: Surface, coordinator: Coordinator) {
        coordinator.stop()
        view.playerLayer.player = nil
    }

    final class Surface: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

        override init(frame: CGRect) {
            super.init(frame: frame)
            backgroundColor = .clear
            // 9:16 원본을 가로 iPad 에서도 자르지 않는다.
            playerLayer.videoGravity = .resizeAspect
        }

        required init?(coder: NSCoder) { nil }
    }

    @MainActor
    final class Coordinator: NSObject {
        var onFinished: () -> Void
        var onFailure: () -> Void

        private weak var surface: Surface?
        private var player: AVPlayer?
        private var currentURL: URL?
        private var endObserver: NSObjectProtocol?
        private var failObserver: NSObjectProtocol?
        /// 끝났다는 말은 한 번만 한다.
        private var didReportEnd = false

        init(onFinished: @escaping () -> Void, onFailure: @escaping () -> Void) {
            self.onFinished = onFinished
            self.onFailure = onFailure
        }

        deinit {
            if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
            if let failObserver { NotificationCenter.default.removeObserver(failObserver) }
        }

        func attach(to surface: Surface) {
            self.surface = surface
            surface.playerLayer.player = player
        }

        func start(url: URL, motionActive: Bool) {
            guard currentURL != url else {
                // 같은 영상이면 다시 만들지 않는다. 뷰가 갱신될 때마다 처음으로
                // 되감기면 학생이 보던 자리를 잃는다.
                return
            }
            stop()
            currentURL = url
            didReportEnd = false

            configureAudioSession()

            let item = AVPlayerItem(url: url)
            let player = AVPlayer(playerItem: item)
            // 소리는 영상의 일부다. 음소거하지 않는다 —
            // 음소거하면 이 파일이 존재하는 이유가 사라진다.
            player.isMuted = false
            player.actionAtItemEnd = .pause
            self.player = player
            surface?.playerLayer.player = player

            endObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: item, queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in self?.reportEnd() }
            }
            failObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemFailedToPlayToEndTime,
                object: item, queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in self?.reportFailure() }
            }

            if motionActive {
                player.play()
            } else {
                // 동작 줄이기 — 첫 프레임만 세워 두고 소리도 내지 않는다.
                player.seek(to: .zero)
            }
        }

        func stop() {
            player?.pause()
            if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
            if let failObserver { NotificationCenter.default.removeObserver(failObserver) }
            endObserver = nil
            failObserver = nil
            player = nil
            currentURL = nil
        }

        func pause() { player?.pause() }
        func resume() { player?.play() }

        private func reportEnd() {
            guard !didReportEnd else { return }
            didReportEnd = true
            onFinished()
        }

        private func reportFailure() {
            guard !didReportEnd else { return }
            didReportEnd = true
            onFailure()
        }

        /// 저절로 시작하는 소리라 무음 스위치를 따른다(.ambient).
        /// 수업 중에 화면만 열었는데 소리가 터지면 사고다.
        /// 이 판단은 종전 TTS 경로가 쓰던 규칙과 같다.
        private func configureAudioSession() {
            #if os(iOS)
            do {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.ambient, mode: .moviePlayback, options: [])
                try session.setActive(true, options: [])
            } catch {
                NSLog("[Matths] concept motion audio session failed: %@", error.localizedDescription)
            }
            #endif
        }
    }
}
