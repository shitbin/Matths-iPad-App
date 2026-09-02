import Foundation

@main
enum LocalAIJobRecoveryCases {
    static func main() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent("matths-local-ai-recovery-tests-\(UUID().uuidString)", isDirectory: true)
        defer { try? fm.removeItem(at: root) }
        try fm.createDirectory(at: root, withIntermediateDirectories: true)

        let source = root.appendingPathComponent("picked.jpg")
        let recovery = root.appendingPathComponent("recovery", isDirectory: true)
        let payload = Data([0xff, 0xd8, 0xff, 0xdb, 0x01, 0x02, 0x03])
        try payload.write(to: source)

        let durablePath = try LocalAIJobRecovery.begin(
            sourcePath: source.path,
            stageLabel: "모델 준비",
            in: recovery)
        require(FileManager.default.fileExists(atPath: durablePath), "복구 사진이 만들어져야 한다")
        let restoredPayload = try Data(contentsOf: URL(fileURLWithPath: durablePath))
        require(restoredPayload == payload, "사진 바이트를 보존해야 한다")
        require(LocalAIJobRecovery.owns(path: durablePath, in: recovery), "복구 저장소가 자기 사진을 식별해야 한다")

        LocalAIJobRecovery.update(stageLabel: "손글씨 풀이 전사", in: recovery)
        let restored = LocalAIJobRecovery.restore(in: recovery)
        require(restored?.job.stageLabel == "손글씨 풀이 전사", "마지막 단계를 복원해야 한다")
        require(restored?.imagePath == durablePath, "동일 사진 경로를 복원해야 한다")

        let staleNow = Date().addingTimeInterval(LocalAIJobRecovery.maximumAge + 1)
        require(LocalAIJobRecovery.restore(in: recovery, now: staleNow) == nil, "오래된 민감 사진은 복원하지 않아야 한다")
        require(!fm.fileExists(atPath: recovery.path), "오래된 복구 묶음은 지워야 한다")

        _ = try LocalAIJobRecovery.begin(sourcePath: source.path, stageLabel: "분석 준비", in: recovery)
        try Data("not-json".utf8).write(
            to: recovery.appendingPathComponent(LocalAIJobRecovery.metadataFileName),
            options: .atomic)
        require(LocalAIJobRecovery.restore(in: recovery) == nil, "깨진 메타데이터를 복원하면 안 된다")
        require(!fm.fileExists(atPath: recovery.path), "깨진 묶음은 지워야 한다")

        _ = try LocalAIJobRecovery.begin(sourcePath: source.path, stageLabel: "분석 준비", in: recovery)
        LocalAIJobRecovery.clear(in: recovery)
        require(!fm.fileExists(atPath: recovery.path), "명시 중단 시 복구 묶음을 지워야 한다")

        print("Local AI job recovery cases passed")
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else {
            fputs("FAIL: \(message)\n", stderr)
            exit(1)
        }
    }
}
