import Foundation
import UIKit

#if DEBUG
/// 실제 다른 앱으로 전환됐을 때 활성 로컬 AI 작업이 iPadOS background task를 획득하는지
/// 기록한다. 무거운 모델은 열지 않고 제품 coordinator 상태 전이만 사용한다.
@MainActor
enum LocalAIBackgroundSelfTest {
    private struct Report: Codable {
        let schemaVersion: String
        let recordedAt: Date
        let activeWorkCount: Int
        let sceneIsBackground: Bool
        let backgroundTaskActive: Bool
        let backgroundTimeRemaining: TimeInterval
        let sampleDelayMilliseconds: Int
        let status: String
    }

    private static var token: LocalAIBackgroundExecution.Token?

    static func startIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains("-localAIBackgroundSelfTest") else { return }
        token = LocalAIBackgroundExecution.shared.beginWork("Local AI background device QA")
    }

    static func recordBackgroundIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains("-localAIBackgroundSelfTest") else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1))
            writeBackgroundSnapshot()
        }
    }

    private static func writeBackgroundSnapshot() {
        let snapshot = LocalAIBackgroundExecution.shared.deviceQASnapshot()
        let passed = snapshot.activeWorkCount == 1 && snapshot.sceneIsBackground &&
            snapshot.backgroundTaskActive && snapshot.backgroundTimeRemaining > 0
        let report = Report(
            schemaVersion: "MATTHS_LOCAL_AI_BACKGROUND_DEVICE_QA_V1",
            recordedAt: Date(),
            activeWorkCount: snapshot.activeWorkCount,
            sceneIsBackground: snapshot.sceneIsBackground,
            backgroundTaskActive: snapshot.backgroundTaskActive,
            backgroundTimeRemaining: snapshot.backgroundTimeRemaining,
            sampleDelayMilliseconds: 1_000,
            status: passed ? "PASS" : "FAIL")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        if let data = try? encoder.encode(report) {
            try? data.write(
                to: documents.appendingPathComponent("local-ai-background-device-qa.json"),
                options: .atomic)
        }
    }
}
#endif
