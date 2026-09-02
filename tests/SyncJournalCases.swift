import Foundation

enum DataScope {
    static let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("matths-sync-journal-\(UUID().uuidString)", isDirectory: true)

    static func url(_ name: String, for slot: String) -> URL {
        let directory = directory(for: slot)
        try? FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent(name)
    }

    static func directory(for slot: String) -> URL {
        root.appendingPathComponent(slot, isDirectory: true)
    }
}

@main
struct SyncJournalCases {
    private static let journal = SyncQueueJournal.shared

    static func main() async throws {
        defer { try? FileManager.default.removeItem(at: DataScope.root) }

        try await checkOrderedAppendAndIDMerge()
        try await checkFailedAppendRecovery()
        try await checkInvalidationAndActivation()

        print("Sync journal actor behavior passed")
        print("- ordered append and ID merge")
        print("- failed append recovery by atomic rewrite")
        print("- invalidate blocks resurrection; activate starts fresh")
    }

    private static func checkOrderedAppendAndIDMerge() async throws {
        let slot = "ordered"
        await journal.activate(slot: slot)

        require(await journal.append([op("a", slot), op("b", slot)], for: slot),
                "첫 ordered batch 저장 실패")
        require(await journal.append([op("a", slot), op("c", slot)], for: slot),
                "두 번째 ordered batch 저장 실패")

        let snapshot = await journal.snapshot(for: slot)
        require(snapshot?.operations.map(\.id) == ["a", "b", "c"],
                "durable FIFO 뒤에 새 ID만 순서대로 병합해야 함")

        let persisted = try decodeQueue(at: DataScope.url("sync-queue.jsonl", for: slot))
        require(persisted.map(\.id) == ["a", "b", "c"],
                "실제 JSONL도 중복 ID 없이 actor 호출 순서를 보존해야 함")
    }

    private static func checkFailedAppendRecovery() async throws {
        let slot = "retry"
        await journal.activate(slot: slot)
        let queueURL = DataScope.url("sync-queue.jsonl", for: slot)

        // queue 파일 자리에 디렉터리를 만들어 append와 신규 파일 쓰기를 모두
        // 실패시킨다. 실패 원인을 치운 뒤 actor가 보관한 논리 FIFO를 복구해야 한다.
        try FileManager.default.createDirectory(at: queueURL, withIntermediateDirectories: true)
        require(!(await journal.append([op("retry-me", slot)], for: slot)),
                "쓰기 불가능한 URL의 append가 성공으로 보고되면 안 됨")
        let beforeRecovery = await journal.snapshot(for: slot)
        require(beforeRecovery?.operations.isEmpty == true,
                "disk ack 전 payload를 durable snapshot으로 공개하면 안 됨")

        try FileManager.default.removeItem(at: queueURL)
        require(await journal.flushPending(for: slot),
                "실패 payload의 atomic rewrite 재시도 실패")
        let afterRecovery = await journal.snapshot(for: slot)
        require(afterRecovery?.operations.map(\.id) == ["retry-me"],
                "재시도 뒤 실패 payload가 durable snapshot에 복원돼야 함: \(afterRecovery?.operations.map(\.id) ?? [])")
    }

    private static func checkInvalidationAndActivation() async throws {
        let slot = "withdrawn"
        await journal.activate(slot: slot)
        require(await journal.append([op("old", slot)], for: slot), "invalidate 준비 저장 실패")

        let directory = DataScope.directory(for: slot)
        await journal.invalidate(slot: slot)
        try FileManager.default.removeItem(at: directory)

        require(!(await journal.append([op("late", slot)], for: slot)),
                "invalidate 뒤 늦은 append를 거부해야 함")
        let invalidatedSnapshot = await journal.snapshot(for: slot)
        require(invalidatedSnapshot == nil,
                "invalidate된 slot의 snapshot은 열리면 안 됨")
        require(!FileManager.default.fileExists(atPath: directory.path),
                "거부한 append가 삭제한 slot 디렉터리를 되살리면 안 됨")

        await journal.activate(slot: slot)
        require(await journal.append([op("fresh", slot)], for: slot),
                "activate 뒤 새 journal append 실패")
        let reactivatedSnapshot = await journal.snapshot(for: slot)
        require(reactivatedSnapshot?.operations.map(\.id) == ["fresh"],
                "activate가 탈퇴 전 actor state를 새 journal에 섞으면 안 됨")
    }

    private static func op(_ id: String, _ slot: String) -> SyncOp {
        SyncOp(
            id: id,
            kind: .event,
            payload: ["clientEventId": .s(id)],
            createdAt: Date(timeIntervalSince1970: 1_800_000_000),
            slot: slot,
            attemptCount: nil
        )
    }

    private static func decodeQueue(at url: URL) throws -> [SyncOp] {
        let text = try String(contentsOf: url, encoding: .utf8)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try text.split(separator: "\n").map {
            try decoder.decode(SyncOp.self, from: Data($0.utf8))
        }
    }

    private static func require(_ condition: Bool, _ message: String) {
        guard condition else {
            fputs("FAIL: \(message)\n", stderr)
            exit(1)
        }
    }
}
