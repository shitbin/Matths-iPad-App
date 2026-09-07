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
        if ProcessInfo.processInfo.arguments.contains("-localAIResourceSelfTest") {
            Task { @MainActor in await runResourceInterruptionTest() }
        }
        guard ProcessInfo.processInfo.arguments.contains("-localAIBackgroundSelfTest") else { return }
        token = LocalAIBackgroundExecution.shared.beginWork("Local AI background device QA")
    }

    private static func runResourceInterruptionTest() async {
        let execution = LocalAIBackgroundExecution.shared
        var scenarios: [[String: Any]] = []
        var allPassed = true
        for reason in [LocalAIBackgroundExecution.Interruption.memoryPressure, .thermalPressure, .backgroundExpired] {
            do {
                let owner = try await LocalAIWorkCoordinator.shared.acquire(.sheetGrading)
                var interrupted = 0
                let tokens = (0..<20).map { _ in
                    execution.beginWork("Resource safety fixture") { received in
                        if received == reason { interrupted += 1 }
                    }
                }
                execution.injectInterruptionForSelfTest(reason)
                // Yield actor turns until resource release has queued behind the
                // active lease. No wall-time guess and no real model is loaded.
                var deferred = false
                for _ in 0..<1_000 {
                    let state = await LocalAIWorkCoordinator.shared.snapshot()
                    if state.waiting.contains(.resourceRecovery) {
                        deferred = state.active == .sheetGrading
                        break
                    }
                    await Task.yield()
                }
                await LocalAIWorkCoordinator.shared.release(owner)
                await execution.awaitResourceReleaseForSelfTest()
                tokens.forEach { execution.endWork($0) }
                let ended = execution.deviceQASnapshot().activeWorkCount == 0
                let passed = interrupted == 20 && deferred && ended
                allPassed = allPassed && passed
                scenarios.append(["reason": reason.rawValue, "interruptedWaiters": interrupted,
                                  "unloadDeferredUntilLeaseReturn": deferred, "workCleared": ended,
                                  "passed": passed])
            } catch {
                allPassed = false
                scenarios.append(["reason": reason.rawValue, "passed": false])
            }
        }
        let report: [String: Any] = [
            "schemaVersion": "MATTHS_LOCAL_AI_RESOURCE_QA_V1", "syntheticInjection": true,
            "actualMemoryPressureOrThermalMeasurement": false, "modelInferenceExecuted": false,
            "scenarios": scenarios, "status": allPassed ? "PASS" : "FAIL"]
        if let data = try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]) {
            let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            try? data.write(to: documents.appendingPathComponent("local-ai-resource-qa.json"), options: .atomic)
        }
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
