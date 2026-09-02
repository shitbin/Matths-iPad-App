//  LocalAIBackgroundExecution.swift
//  Matths
//
//  iPadOS가 허용하는 짧은 background-task 유예를 로컬 AI 작업이 함께 쓴다.
//  무제한 실행을 약속하지 않는다. 유예가 끝나면 앱은 suspend되고, 프로세스가
//  살아 있으면 같은 Task/llama 호출이 foreground 복귀 뒤 이어진다.

import Foundation
import UIKit

@MainActor
final class LocalAIBackgroundExecution {
    static let shared = LocalAIBackgroundExecution()

    struct Token: Hashable {
        fileprivate let id: UUID
    }

    private var active: [Token: String] = [:]
    private var sceneIsBackground = false
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid

    private init() {}

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

    func beginWork(_ label: String) -> Token {
        let token = Token(id: UUID())
        active[token] = label
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
        endBackgroundTask()
    }

    private func startBackgroundTaskIfNeeded() {
        guard sceneIsBackground, !active.isEmpty, backgroundTask == .invalid else { return }
        backgroundTask = UIApplication.shared.beginBackgroundTask(
            withName: "Matths local AI") { [weak self] in
                // 만료 시 새 연산을 시작하지 않는다. 현재 native 호출은 iPadOS가
                // suspend하고, 앱이 살아 있으면 foreground에서 그대로 복귀한다.
                Task { @MainActor in self?.endBackgroundTask() }
            }
    }

    private func endBackgroundTask() {
        guard backgroundTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
    }
}
