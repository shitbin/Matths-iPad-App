//  CurriculumSpeechPlayer.swift
//  Matths
//
//  개념 narration 재생기. UI는 provider 종류를 모르고 문장 chunk와 checkpoint만
//  관리한다. 현재는 기기 AVSpeechSynthesizer, 향후에는 같은 protocol을 구현한
//  first-party signed audio provider를 주입한다. ElevenLabs 키는 앱에 넣지 않는다.

import AVFoundation
import Foundation
import SwiftUI

struct CurriculumSpeechRequest: Identifiable, Equatable {
    let id: UUID
    let conceptID: String
    let chunkID: String
    let text: String
    let locale: String

    init(
        id: UUID = UUID(),
        conceptID: String,
        chunkID: String,
        text: String,
        locale: String
    ) {
        self.id = id
        self.conceptID = conceptID
        self.chunkID = chunkID
        self.text = text
        self.locale = locale
    }
}

@MainActor
protocol CurriculumSpeechProviderDelegate: AnyObject {
    func curriculumSpeechProviderDidFinish(
        _ provider: any CurriculumSpeechProviding,
        request: CurriculumSpeechRequest
    )
    func curriculumSpeechProviderDidCancel(
        _ provider: any CurriculumSpeechProviding,
        request: CurriculumSpeechRequest
    )
    func curriculumSpeechProviderDidInterrupt(
        _ provider: any CurriculumSpeechProviding,
        request: CurriculumSpeechRequest
    )
    func curriculumSpeechProvider(
        _ provider: any CurriculumSpeechProviding,
        request: CurriculumSpeechRequest,
        didFail error: Error
    )
}

/// System/향후 server-backed ElevenLabs adapter가 공유하는 실제 주입 경계.
@MainActor
protocol CurriculumSpeechProviding: AnyObject {
    var delegate: (any CurriculumSpeechProviderDelegate)? { get set }
    var isAvailable: Bool { get }
    var isSpeaking: Bool { get }
    var isPaused: Bool { get }
    func speak(_ request: CurriculumSpeechRequest)
    @discardableResult func pause() -> Bool
    @discardableResult func resume() -> Bool
    func stop()
}

@MainActor
final class SystemCurriculumSpeechProvider: NSObject, CurriculumSpeechProviding {
    weak var delegate: (any CurriculumSpeechProviderDelegate)?

    private let synthesizer: AVSpeechSynthesizer
    private var interruptionObserver: NSObjectProtocol?
    private var activeRequest: CurriculumSpeechRequest?
    private var activeUtterance: AVSpeechUtterance?

    override init() {
        synthesizer = AVSpeechSynthesizer()
        super.init()
        synthesizer.delegate = self
        #if os(iOS) || os(tvOS) || os(watchOS)
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            let typeValue = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            guard typeValue == AVAudioSession.InterruptionType.began.rawValue else { return }
            Task { @MainActor [weak self] in self?.handleInterruption() }
        }
        #endif
    }

    deinit {
        if let interruptionObserver {
            NotificationCenter.default.removeObserver(interruptionObserver)
        }
    }

    var isAvailable: Bool { !AVSpeechSynthesisVoice.speechVoices().isEmpty }
    var isSpeaking: Bool { synthesizer.isSpeaking }
    var isPaused: Bool { synthesizer.isPaused }

    func speak(_ request: CurriculumSpeechRequest) {
        stop()
        activeRequest = request
        do {
            try activateAudioSession()
        } catch {
            activeRequest = nil
            activeUtterance = nil
            deactivateAudioSession()
            delegate?.curriculumSpeechProvider(self, request: request, didFail: error)
            return
        }

        let utterance = AVSpeechUtterance(string: request.text)
        utterance.voice = Self.preferredFemaleVoice(locale: request.locale)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
            * CurriculumNarrationTimingPolicy.systemSpeechRateFactor
        utterance.pitchMultiplier = 1
        utterance.preUtteranceDelay = 0.04
        activeUtterance = utterance
        synthesizer.speak(utterance)
    }

    @discardableResult
    func pause() -> Bool {
        guard synthesizer.isSpeaking, !synthesizer.isPaused else { return false }
        return synthesizer.pauseSpeaking(at: .word)
    }

    @discardableResult
    func resume() -> Bool {
        guard synthesizer.isPaused else { return false }
        do {
            try activateAudioSession()
        } catch {
            if let activeRequest {
                delegate?.curriculumSpeechProvider(self, request: activeRequest, didFail: error)
            }
            return false
        }
        return synthesizer.continueSpeaking()
    }

    func stop() {
        activeRequest = nil
        activeUtterance = nil
        if synthesizer.isSpeaking || synthesizer.isPaused {
            synthesizer.stopSpeaking(at: .immediate)
        }
        deactivateAudioSession()
    }

    static func preferredFemaleVoice(locale: String = "ko-KR") -> AVSpeechSynthesisVoice? {
        let language = locale.lowercased()
        let korean = AVSpeechSynthesisVoice.speechVoices().filter {
            $0.language.lowercased().hasPrefix(language.split(separator: "-").first.map(String.init) ?? "ko")
        }
        return korean.first(where: { $0.gender == .female })
            ?? korean.first(where: { $0.language.caseInsensitiveCompare(locale) == .orderedSame })
            ?? korean.first
            ?? AVSpeechSynthesisVoice(language: locale)
    }

    private func handleInterruption() {
        guard let activeRequest, activeUtterance != nil,
              synthesizer.isSpeaking || synthesizer.isPaused else { return }
        _ = synthesizer.pauseSpeaking(at: .word)
        delegate?.curriculumSpeechProviderDidInterrupt(self, request: activeRequest)
    }

    /// 자동 재생 경로에서만 켠다. 프로토콜에는 넣지 않는다 — 테스트 대역
    /// (DelayedCurriculumSpeechProvider)이 프로토콜을 직접 구현하고 있어서다.
    var prefersAmbientSession = false

    private func activateAudioSession() throws {
        #if os(iOS) || os(tvOS) || os(watchOS)
        let session = AVAudioSession.sharedInstance()
        // 사용자가 직접 누른 재생은 .playback 이라 무음 스위치를 무시하고 들려준다.
        // 반면 화면에 들어왔다고 저절로 시작하는 소리까지 무음 스위치를 무시하면
        // 수업 중에 사고가 난다. 자동 시작은 .ambient 로 낮춰 무음 스위치를 따르고
        // 다른 앱 소리도 누르지 않는다.
        if prefersAmbientSession {
            try session.setCategory(.ambient, mode: .spokenAudio, options: [])
        } else {
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        }
        try session.setActive(true, options: [])
        #endif
    }

    private func deactivateAudioSession() {
        #if os(iOS) || os(tvOS) || os(watchOS)
        do {
            try AVAudioSession.sharedInstance().setActive(
                false,
                options: [.notifyOthersOnDeactivation]
            )
        } catch {
            NSLog("[Matths] curriculum narration audio session deactivation failed: %@", error.localizedDescription)
        }
        #endif
    }
}

extension SystemCurriculumSpeechProvider: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        Task { @MainActor [weak self] in
            guard let self, let request = self.activeRequest,
                  self.activeUtterance === utterance else { return }
            self.activeRequest = nil
            self.activeUtterance = nil
            self.deactivateAudioSession()
            self.delegate?.curriculumSpeechProviderDidFinish(self, request: request)
        }
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        Task { @MainActor [weak self] in
            guard let self, let request = self.activeRequest,
                  self.activeUtterance === utterance else { return }
            self.activeRequest = nil
            self.activeUtterance = nil
            self.deactivateAudioSession()
            self.delegate?.curriculumSpeechProviderDidCancel(self, request: request)
        }
    }
}

protocol CurriculumNarrationCheckpointStoring {
    func load(conceptID: String, maximum: Int, accountSlot: String) -> Int
    func save(_ index: Int, conceptID: String, accountSlot: String)
    func clear(conceptID: String, accountSlot: String)
}

struct UserDefaultsCurriculumNarrationCheckpointStore: CurriculumNarrationCheckpointStoring {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load(conceptID: String, maximum: Int, accountSlot: String) -> Int {
        let index = defaults.integer(forKey: key(conceptID, accountSlot: accountSlot))
        return index >= 0 && index < maximum ? index : 0
    }

    func save(_ index: Int, conceptID: String, accountSlot: String) {
        defaults.set(index, forKey: key(conceptID, accountSlot: accountSlot))
    }

    func clear(conceptID: String, accountSlot: String) {
        defaults.removeObject(forKey: key(conceptID, accountSlot: accountSlot))
    }

    private func key(_ conceptID: String, accountSlot: String) -> String {
        DataScope.defaultsKey(
            "matths.curriculumNarration.\(conceptID)",
            for: accountSlot
        )
    }
}

enum CurriculumNarrationPlaybackState: String, Equatable {
    case idle
    case playing
    case paused
    case completed
    case failed
}

@MainActor
final class CurriculumNarrationPlayer: NSObject, ObservableObject {
    @Published private(set) var state: CurriculumNarrationPlaybackState = .idle
    @Published private(set) var currentChunkIndex = 0
    @Published private(set) var currentSceneID: String?
    /// 문제가 생겼을 때만 채운다. 평소에는 빈 문자열이다 — silentNotice 가
/// 이 값을 화면에 올리므로, 정상 상태에서 뭔가 적어 두면 무음 안내로 새어 나온다.
    @Published private(set) var message = ""

    private let provider: any CurriculumSpeechProviding
    private let checkpoints: any CurriculumNarrationCheckpointStoring
    private let accountSlotProvider: () -> String
    private var story: CurriculumStudentStory?
    private var chunks: [CurriculumNarrationChunk] = []
    private var watchdog: Task<Void, Never>?
    private var activeRequestID: UUID?
    private var capturedAccountSlot: String?

    init(
        provider: (any CurriculumSpeechProviding)? = nil,
        checkpoints: any CurriculumNarrationCheckpointStoring =
            UserDefaultsCurriculumNarrationCheckpointStore(),
        accountSlotProvider: @escaping () -> String = { DataScope.slot }
    ) {
        let resolvedProvider = provider ?? SystemCurriculumSpeechProvider()
        self.provider = resolvedProvider
        self.checkpoints = checkpoints
        self.accountSlotProvider = accountSlotProvider
        super.init()
        resolvedProvider.delegate = self
    }

    var currentChunk: CurriculumNarrationChunk? {
        chunks.indices.contains(currentChunkIndex) ? chunks[currentChunkIndex] : nil
    }

    var hasProgress: Bool { currentChunkIndex > 0 || state == .completed }

    /// 소리가 나지 않을 때만 화면에 남길 한 줄. 평소에는 nil 이다.
    ///
    /// 재생 버튼을 없애면서 `message` 를 그리던 자리도 같이 사라졌는데, 그대로 두면
    /// 음성을 못 쓰는 기기나 다른 앱이 소리를 내는 상황에서 학생이 **이유 없는 무음**을
    /// 보게 된다. 조작 버튼은 되살리지 않되, 사실을 알리는 한 줄은 남긴다.
    /// 재생 중·멈춤·완료처럼 정상 상태에서는 아무것도 내보내지 않는다.
    var silentNotice: String? {
        switch state {
        case .failed: return message
        case .idle: return message.isEmpty ? nil : message
        case .playing, .paused, .completed: return nil
        }
    }

    // 2026-08-16: 재생 버튼의 글자와 아이콘을 만들던 계산 속성 두 개를 지웠다.
    // 해설 음성이 영상의 일부가 되면서 버튼이 화면에서 사라졌고, 부르는 곳도 없어졌다.
    // 쓰지 않는 UI 문자열을 남겨 두면 다음 사람이 "버튼이 어딘가 있나" 하고 찾는다.
    // 되살아나지 않도록 tests/run-curriculum-narration-integrated-contract.sh 가 감시한다.

    func load(_ story: CurriculumStudentStory) {
        let nextAccountSlot = accountSlotProvider()
        guard self.story?.narrationCheckpointID != story.narrationCheckpointID
                || capturedAccountSlot != nextAccountSlot else { return }
        stopAndPreserve()
        self.story = story
        capturedAccountSlot = nextAccountSlot
        chunks = CurriculumNarrationChunker.chunks(for: story)
        currentChunkIndex = checkpoints.load(
            conceptID: story.narrationCheckpointID,
            maximum: chunks.count,
            accountSlot: nextAccountSlot
        )
        currentSceneID = currentChunk?.sceneID
        state = currentChunkIndex > 0 ? .paused : .idle
        // 불러온 직후에는 할 말이 없다. 예전에는 이어듣기 안내와 음성 선택 안내를
        // 넣었는데, 둘 다 재생 버튼 옆 상태줄을 채우려고 쓰던 문구다.
        // 버튼이 없어진 지금은 학생이 굳이 알 필요 없는 내부 사정이고,
        // silentNotice 가 이 값을 그대로 화면에 올린다. 문제가 생겼을 때만 말한다.
        message = ""
    }

    func toggle() {
        // 사용자가 직접 누른 재생이다. 무음 스위치를 무시하는 .playback 으로 되돌린다.
        (provider as? SystemCurriculumSpeechProvider)?.prefersAmbientSession = false
        state == .playing ? pause() : play()
    }

    /// 설명 화면에 들어오면 해설이 영상과 함께 시작한다.
    ///
    /// 재생 버튼은 없다 — 해설 음성은 영상의 일부이지 따로 조작하는 물건이 아니다.
    /// 그래서 `.idle` 뿐 아니라 **멈춰 둔 상태와 다 들은 상태에서도 이어서 켠다.**
    /// 예전에는 `.idle` 에서만 켰는데, 버튼이 있을 때는 그래도 됐지만 버튼을 없앤
    /// 지금은 지난 세션의 체크포인트가 `.paused` 로 남아 있으면 영영 무음이 된다.
    ///
    /// 저절로 나는 소리라 아래 두 가지는 지킨다.
    /// - 다른 앱이 소리를 내는 중이면 켜지 않는다(남의 재생을 덮지 않는다)
    /// - 동작 줄이기(Reduce Motion)를 켠 사용자 — 호출부가 판단해 넘긴다
    func autoStart(allowed: Bool) {
        guard allowed, story != nil, !chunks.isEmpty else { return }
        guard state == .idle || state == .paused || state == .completed else { return }
        #if os(iOS) || os(tvOS) || os(watchOS)
        if AVAudioSession.sharedInstance().isOtherAudioPlaying {
            // 버튼이 없으므로 "직접 눌러 주세요" 라고 할 수 없다. 사실만 남긴다.
            message = "다른 앱에서 소리가 나고 있어 해설을 켜지 않았습니다."
            return
        }
        #endif
        (provider as? SystemCurriculumSpeechProvider)?.prefersAmbientSession = true
        play()
    }

    func play() {
        guard story != nil, provider.isAvailable, !chunks.isEmpty else {
            state = .failed
            message = "이 기기에서는 음성 읽기를 사용할 수 없습니다. 해설 원문으로 학습해 주세요."
            return
        }
        if state == .completed {
            currentChunkIndex = 0
            clearCheckpoint()
        }
        if state == .paused, provider.isPaused {
            if provider.resume() {
                state = .playing
                currentSceneID = currentChunk?.sceneID
                message = progressMessage
                startWatchdog()
                return
            }
            if state == .failed { return }
            activeRequestID = nil
        }
        speakCurrent()
    }

    func pause() {
        guard state == .playing, story != nil else { return }
        let pausedAtWord = provider.pause()
        if !pausedAtWord {
            activeRequestID = nil
            provider.stop()
        }
        saveCheckpoint(currentChunkIndex)
        cancelWatchdog()
        state = .paused
        message = "현재 문장을 보존했습니다. 문장 경계부터 이어집니다."
    }

    func pauseForInterruption() {
        guard state == .playing, story != nil else { return }
        activeRequestID = nil
        provider.stop()
        saveCheckpoint(currentChunkIndex)
        cancelWatchdog()
        state = .paused
        message = "앱이 비활성화되어 멈췄습니다. 현재 문장부터 이어 들을 수 있습니다."
    }

    func restart() {
        guard story != nil else { return }
        activeRequestID = nil
        provider.stop()
        cancelWatchdog()
        clearCheckpoint()
        currentChunkIndex = 0
        currentSceneID = chunks.first?.sceneID
        state = .idle
        message = "처음부터 다시 재생합니다."
        play()
    }

    func stopAndPreserve() {
        if story != nil, state == .playing || state == .paused {
            saveCheckpoint(currentChunkIndex)
        }
        activeRequestID = nil
        provider.stop()
        cancelWatchdog()
    }

    func unload() {
        stopAndPreserve()
        story = nil
        chunks = []
        capturedAccountSlot = nil
        currentChunkIndex = 0
        currentSceneID = nil
        state = .idle
        message = ""
    }

    private var progressMessage: String {
        guard let chunk = currentChunk else { return "5분 해설을 준비하고 있습니다." }
        return "\(chunk.sceneTitle) · 문장 \(currentChunkIndex + 1) / \(chunks.count)"
    }

    private func speakCurrent() {
        guard let story else { return }
        guard let chunk = currentChunk else {
            state = .completed
            currentSceneID = nil
            activeRequestID = nil
            clearCheckpoint()
            message = "5분 해설을 모두 들었습니다."
            return
        }
        state = .playing
        currentSceneID = chunk.sceneID
        message = progressMessage
        saveCheckpoint(currentChunkIndex)
        let request = CurriculumSpeechRequest(
            conceptID: story.conceptID,
            chunkID: chunk.id,
            text: chunk.text,
            locale: "ko-KR"
        )
        activeRequestID = request.id
        startWatchdog()
        provider.speak(request)
    }

    private func startWatchdog() {
        cancelWatchdog()
        guard let chunk = currentChunk else { return }
        let seconds = max(20, Double(chunk.text.count) * 0.30)
        watchdog = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled, let self, self.state == .playing,
                  self.story != nil else { return }
            self.activeRequestID = nil
            self.provider.stop()
            self.saveCheckpoint(self.currentChunkIndex)
            self.state = .paused
            self.message = "음성이 오래 멈춰 현재 문장을 보존했습니다. 이어 듣기를 눌러 다시 시작해 주세요."
        }
    }

    private func cancelWatchdog() {
        watchdog?.cancel()
        watchdog = nil
    }

    private func saveCheckpoint(_ index: Int) {
        guard let story, let capturedAccountSlot else { return }
        checkpoints.save(
            index,
            conceptID: story.narrationCheckpointID,
            accountSlot: capturedAccountSlot
        )
    }

    private func clearCheckpoint() {
        guard let story, let capturedAccountSlot else { return }
        checkpoints.clear(
            conceptID: story.narrationCheckpointID,
            accountSlot: capturedAccountSlot
        )
    }
}

extension CurriculumNarrationPlayer: CurriculumSpeechProviderDelegate {
    func curriculumSpeechProviderDidFinish(
        _ provider: any CurriculumSpeechProviding,
        request: CurriculumSpeechRequest
    ) {
        guard activeRequestID == request.id, state == .playing, story != nil else { return }
        activeRequestID = nil
        cancelWatchdog()
        currentChunkIndex += 1
        saveCheckpoint(currentChunkIndex)
        speakCurrent()
    }

    func curriculumSpeechProviderDidCancel(
        _ provider: any CurriculumSpeechProviding,
        request: CurriculumSpeechRequest
    ) {
        guard activeRequestID == request.id, state == .playing, story != nil else { return }
        activeRequestID = nil
        cancelWatchdog()
        saveCheckpoint(currentChunkIndex)
        state = .paused
        message = "음성이 중단되어 현재 문장을 보존했습니다."
    }

    func curriculumSpeechProviderDidInterrupt(
        _ provider: any CurriculumSpeechProviding,
        request: CurriculumSpeechRequest
    ) {
        guard activeRequestID == request.id, state == .playing, story != nil else { return }
        activeRequestID = nil
        provider.stop()
        cancelWatchdog()
        saveCheckpoint(currentChunkIndex)
        state = .paused
        message = "다른 음성이나 통화로 멈췄습니다. 현재 문장부터 이어 들을 수 있습니다."
    }

    func curriculumSpeechProvider(
        _ provider: any CurriculumSpeechProviding,
        request: CurriculumSpeechRequest,
        didFail error: Error
    ) {
        guard activeRequestID == request.id else { return }
        activeRequestID = nil
        cancelWatchdog()
        state = .failed
        message = "음성을 재생하지 못했습니다. 해설 원문으로 계속 학습해 주세요."
    }
}
