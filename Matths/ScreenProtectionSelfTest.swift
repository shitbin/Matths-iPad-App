#if DEBUG
import Foundation
import UIKit

@MainActor
enum ScreenProtectionSelfTest {
    private struct RecordedEvent: Codable {
        let type: String
        let surface: String
    }

    private struct Report: Codable {
        let schemaVersion: String
        let result: String
        let observedAt: String
        let deviceModel: String
        let osVersion: String
        let appVersion: String
        let appBuild: String
        let serverSyncSuppressed: Bool
        let baseProtectionEnabled: Bool
        let screenshotModalSuppressed: Bool
        let repeatedScreenshotRecorded: Bool
        let accountWatermarkPseudonymous: Bool
        let captureCoverShown: Bool
        let captureCoverCleared: Bool
        let backgroundCoverShown: Bool
        let foregroundCoverCleared: Bool
        let queuePersisted: Bool
        let queueReloaded: Bool
        let queuePayloadPreserved: Bool
        let queueClearedAfterSuccess: Bool
        let eventTypes: [String]
        let events: [RecordedEvent]
    }

    static func runIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains("-screenProtectionSelfTest") else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(700))
            run()
        }
    }

    private static func run() {
        var events: [RecordedEvent] = []
        let guardModel = ScreenshotGuard { type, _, surface in
            events.append(RecordedEvent(type: type, surface: surface))
        }

        guardModel.setBaseProtection(true)
        let baseProtectionEnabled = guardModel.protectionEnabled

        guardModel.simulateScreenshotForDeviceQA()
        let screenshotModalSuppressed = !guardModel.isShowing
        // 학생 흐름을 막는 모달 없이도 두 번째 시스템 알림을 버리지 않는다.
        guardModel.simulateScreenshotForDeviceQA()
        let repeatedScreenshotRecorded = events.filter {
            $0.type == "protected-screen-screenshot"
        }.count == 2

        let accountCode = guardModel.accountWatermarkCode
        let accountWatermarkPseudonymous = accountCode == "GUEST"
            || (accountCode.count == 8 && !DataScope.slot.localizedCaseInsensitiveContains(accountCode))

        guardModel.simulateCaptureStateForDeviceQA(true)
        let captureCoverShown = guardModel.isCaptureActive
        guardModel.simulateCaptureStateForDeviceQA(false)
        let captureCoverCleared = !guardModel.isCaptureActive

        guardModel.setSceneActive(false)
        let backgroundCoverShown = guardModel.isPrivacyCoverActive
        guardModel.setSceneActive(true)
        let foregroundCoverCleared = !guardModel.isPrivacyCoverActive

        let expectedEvents = [
            "protected-screen-screenshot",
            "protected-screen-screenshot",
            "protected-screen-capture-started",
            "protected-screen-capture-ended",
        ]
        let eventTypes = events.map(\.type)
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let queueProbe = SyncEngine.runIntegrityQueueDeviceQA(
            at: documents.appendingPathComponent("screen-integrity-device-qa.jsonl")
        )
        let passed = baseProtectionEnabled
            && screenshotModalSuppressed
            && repeatedScreenshotRecorded
            && accountWatermarkPseudonymous
            && captureCoverShown
            && captureCoverCleared
            && backgroundCoverShown
            && foregroundCoverCleared
            && queueProbe.persisted
            && queueProbe.reloaded
            && queueProbe.payloadPreserved
            && queueProbe.cleared
            && eventTypes == expectedEvents

        let info = Bundle.main.infoDictionary ?? [:]
        let report = Report(
            schemaVersion: "MATTHS_SCREEN_PROTECTION_DEVICE_QA_V1",
            result: passed ? "PASS" : "FAIL",
            observedAt: ISO8601DateFormatter().string(from: Date()),
            deviceModel: UIDevice.current.model,
            osVersion: UIDevice.current.systemVersion,
            appVersion: String(info["CFBundleShortVersionString"] as? String ?? "unknown"),
            appBuild: String(info["CFBundleVersion"] as? String ?? "unknown"),
            serverSyncSuppressed: true,
            baseProtectionEnabled: baseProtectionEnabled,
            screenshotModalSuppressed: screenshotModalSuppressed,
            repeatedScreenshotRecorded: repeatedScreenshotRecorded,
            accountWatermarkPseudonymous: accountWatermarkPseudonymous,
            captureCoverShown: captureCoverShown,
            captureCoverCleared: captureCoverCleared,
            backgroundCoverShown: backgroundCoverShown,
            foregroundCoverCleared: foregroundCoverCleared,
            queuePersisted: queueProbe.persisted,
            queueReloaded: queueProbe.reloaded,
            queuePayloadPreserved: queueProbe.payloadPreserved,
            queueClearedAfterSuccess: queueProbe.cleared,
            eventTypes: eventTypes,
            events: events
        )

        do {
            let data = try JSONEncoder.pretty.encode(report)
            let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("screen-protection-device-qa.json")
            try data.write(to: url, options: .atomic)
        } catch {
            NSLog("ScreenProtectionSelfTest report write failed: %@", String(describing: error))
        }
    }
}

private extension JSONEncoder {
    static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
#endif
