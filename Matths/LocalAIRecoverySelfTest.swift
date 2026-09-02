import CryptoKit
import Foundation

#if DEBUG
/// 두 번의 실제 앱 실행 사이에 원본 사진과 단계 메타데이터가 남고, 복구 후 민감 원본을
/// 지우는지 검증한다. 전용 Documents 하위 폴더만 사용해 사용자 분석 작업과 섞이지 않는다.
enum LocalAIRecoverySelfTest {
    private struct Report: Codable {
        let schemaVersion: String
        let recordedAt: Date
        let phase: String
        let payloadSHA256: String?
        let stageLabel: String?
        let restoredAfterRelaunch: Bool
        let clearedAfterRecovery: Bool
        let status: String
    }

    static func runIfRequested() {
        let arguments = ProcessInfo.processInfo.arguments
        guard let flag = arguments.firstIndex(of: "-localAIRecoverySelfTest"),
              flag + 1 < arguments.count else { return }
        let phase = arguments[flag + 1]
        if phase == "prepare" { prepare() }
        else if phase == "verify" { verify() }
    }

    private static var documents: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private static var root: URL {
        documents.appendingPathComponent("LocalAIRecoverySelfTest", isDirectory: true)
    }

    private static var recovery: URL {
        root.appendingPathComponent("recovery", isDirectory: true)
    }

    private static var reportURL: URL {
        documents.appendingPathComponent("local-ai-recovery-device-qa.json")
    }

    private static func prepare() {
        let fm = FileManager.default
        try? fm.removeItem(at: root)
        do {
            try fm.createDirectory(at: root, withIntermediateDirectories: true)
            let source = root.appendingPathComponent("picked.jpg")
            let bytes = payload()
            try bytes.write(to: source, options: [.atomic, .completeFileProtection])
            _ = try LocalAIJobRecovery.begin(
                sourcePath: source.path,
                stageLabel: "손글씨 풀이 전사",
                in: recovery)
            write(Report(
                schemaVersion: "MATTHS_LOCAL_AI_RECOVERY_DEVICE_QA_V1",
                recordedAt: Date(),
                phase: "PREPARED",
                payloadSHA256: sha256(bytes),
                stageLabel: "손글씨 풀이 전사",
                restoredAfterRelaunch: false,
                clearedAfterRecovery: false,
                status: "PREPARED"))
        } catch {
            writeFailure(phase: "PREPARE", error: error)
        }
    }

    private static func verify() {
        let expectedHash = sha256(payload())
        guard let restored = LocalAIJobRecovery.restore(in: recovery),
              let bytes = try? Data(contentsOf: URL(fileURLWithPath: restored.imagePath)) else {
            writeFailure(phase: "VERIFY", error: CocoaError(.fileNoSuchFile))
            return
        }
        let restoredAfterRelaunch = sha256(bytes) == expectedHash &&
            restored.job.stageLabel == "손글씨 풀이 전사" &&
            LocalAIJobRecovery.owns(path: restored.imagePath, in: recovery)
        LocalAIJobRecovery.clear(in: recovery)
        let cleared = !FileManager.default.fileExists(atPath: recovery.path)
        write(Report(
            schemaVersion: "MATTHS_LOCAL_AI_RECOVERY_DEVICE_QA_V1",
            recordedAt: Date(),
            phase: "VERIFIED",
            payloadSHA256: expectedHash,
            stageLabel: restored.job.stageLabel,
            restoredAfterRelaunch: restoredAfterRelaunch,
            clearedAfterRecovery: cleared,
            status: restoredAfterRelaunch && cleared ? "PASS" : "FAIL"))
        try? FileManager.default.removeItem(at: root)
    }

    private static func writeFailure(phase: String, error: Error) {
        NSLog("LocalAIRecoverySelfTest %@ failed: %@", phase, String(describing: error))
        write(Report(
            schemaVersion: "MATTHS_LOCAL_AI_RECOVERY_DEVICE_QA_V1",
            recordedAt: Date(),
            phase: phase,
            payloadSHA256: nil,
            stageLabel: nil,
            restoredAfterRelaunch: false,
            clearedAfterRecovery: false,
            status: "FAIL"))
    }

    private static func write(_ report: Report) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(report) { try? data.write(to: reportURL, options: .atomic) }
    }

    private static func payload() -> Data {
        var data = Data([0xff, 0xd8, 0xff, 0xdb])
        data.append(Data(repeating: 0x42, count: 512 * 1_024))
        return data
    }

    private static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
#endif
