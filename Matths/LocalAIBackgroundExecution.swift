//  LocalAIBackgroundExecution.swift
//  Matths
//
//  iPadOS가 허용하는 짧은 background-task 유예를 로컬 AI 작업이 함께 쓴다.
//  무제한 실행을 약속하지 않는다. 유예가 끝나면 앱은 suspend되고, 프로세스가
//  만료·메모리 경고·발열 시 소유자 취소 플래그를 올리고 완료된 native 호출이
//  lease를 반납한 뒤 모델을 해제한다. KV cache 재개를 약속하지 않는다.

import Foundation
import UIKit

@MainActor
final class LocalAIBackgroundExecution {
    static let shared = LocalAIBackgroundExecution()

    struct Token: Hashable {
        fileprivate let id: UUID
    }

    enum Interruption: String, LocalizedError {
        case backgroundExpired, memoryPressure, thermalPressure
        var message: String {
            switch self {
            case .backgroundExpired:
                return "백그라운드 실행 시간이 끝나 분석을 멈췄습니다. 앱으로 돌아와 보존된 자료로 다시 시도해 주세요."
            case .memoryPressure:
                return "기기 메모리가 부족해 AI 작업을 멈췄습니다. 다른 앱을 닫고 보존된 자료로 다시 시도해 주세요."
            case .thermalPressure:
                return "기기 온도가 높아 AI 작업을 멈췄습니다. 기기가 식은 뒤 다시 시도해 주세요."
            }
        }
        var errorDescription: String? { message }
    }

    private struct Work {
        let label: String
        let interrupt: ((Interruption) -> Void)?
    }

    private var active: [Token: Work] = [:]
    private var sceneIsBackground = false
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var backgroundExpired = false
    private var observers: [NSObjectProtocol] = []
    private var resourceReleaseTask: Task<Void, Never>?
    private var pendingResourceReason: Interruption?

    private init() {
        observers.append(NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.interruptWork(.memoryPressure) }
        })
        observers.append(NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                if ProcessInfo.processInfo.thermalState == .serious || ProcessInfo.processInfo.thermalState == .critical {
                    self?.interruptWork(.thermalPressure)
                }
            }
        })
    }

    #if DEBUG
    struct DeviceQASnapshot {
        let activeWorkCount: Int
        let sceneIsBackground: Bool
        let backgroundTaskActive: Bool
        let backgroundTimeRemaining: TimeInterval
    }

    func deviceQASnapshot() -> DeviceQASnapshot {
        DeviceQASnapshot(
            activeWorkCount: active.count,
            sceneIsBackground: sceneIsBackground,
            backgroundTaskActive: backgroundTask != .invalid,
            backgroundTimeRemaining: UIApplication.shared.backgroundTimeRemaining)
    }

    func injectInterruptionForSelfTest(_ reason: Interruption) {
        interruptWork(reason)
    }

    func awaitResourceReleaseForSelfTest() async {
        await resourceReleaseTask?.value
    }
    #endif

    /// 화면이 사라진 채 iPadOS가 프로세스를 종료하면 화면의 정리 코드가 실행되지
    /// 않을 수 있다. 다음 실행에서 하루 넘은 임시 시험지·채팅 사진을 확실히 지운다.
    nonisolated static func cleanupStaleSourcePhotos(now: Date = Date()) {
        let directory = FileManager.default.temporaryDirectory
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]) else { return }
        for file in files where
            file.lastPathComponent.hasPrefix("matths-sheet-")
                || file.lastPathComponent.hasPrefix("matths-chat-") {
            let modified = (try? file.resourceValues(
                forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            if now.timeIntervalSince(modified) >= 24 * 60 * 60 {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }

    func beginWork(_ label: String, onInterruption: ((Interruption) -> Void)? = nil) -> Token {
        let token = Token(id: UUID())
        active[token] = Work(label: label, interrupt: onInterruption)
        // Deliver after the caller establishes its run ID/cancellation flag.
        if let interruption = currentInterruption {
            Task { @MainActor [weak self] in self?.interruptWork(interruption) }
        }
        startBackgroundTaskIfNeeded()
        return token
    }

    func endWork(_ token: Token) {
        active.removeValue(forKey: token)
        if active.isEmpty { endBackgroundTask() }
    }

    func didEnterBackground() {
        sceneIsBackground = true
        startBackgroundTaskIfNeeded()
    }

    func didBecomeActive() {
        sceneIsBackground = false
        backgroundExpired = false
        endBackgroundTask()
    }

    private func startBackgroundTaskIfNeeded() {
        guard sceneIsBackground, !backgroundExpired, !active.isEmpty, backgroundTask == .invalid else { return }
        backgroundTask = UIApplication.shared.beginBackgroundTask(
            withName: "Matths local AI") { [weak self] in
                Task { @MainActor in
                    self?.backgroundExpired = true
                    self?.interruptWork(.backgroundExpired)
                    self?.endBackgroundTask()
                }
            }
    }

    private var currentInterruption: Interruption? {
        if backgroundExpired { return .backgroundExpired }
        if let pendingResourceReason { return pendingResourceReason }
        let thermal = ProcessInfo.processInfo.thermalState
        return thermal == .serious || thermal == .critical ? .thermalPressure : nil
    }

    func checkAdmission() throws {
        if let reason = currentInterruption { throw reason }
    }

    var admissionFailureMessage: String? { currentInterruption?.message }

    private func interruptWork(_ reason: Interruption) {
        pendingResourceReason = reason
        LocalAIResourceStopSignal.shared.set(true)
        // Snapshot avoids mutation while a callback completes or switches jobs.
        let callbacks = active.values.compactMap(\.interrupt)
        callbacks.forEach { $0(reason) }
        guard resourceReleaseTask == nil else { return }
        resourceReleaseTask = Task { @MainActor in
            await AITutor.shared.releaseForMemory(waitForActiveWork: true)
            resourceReleaseTask = nil
            pendingResourceReason = nil
            LocalAIResourceStopSignal.shared.set(false)
        }
    }

    private func endBackgroundTask() {
        guard backgroundTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
    }
}
