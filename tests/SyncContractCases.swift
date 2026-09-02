import Foundation

// WrongNoteStore.swift가 앱 내부에서 참조하는 최소 타입. 테스트 대상은 실제
// WrongNoteEntry Codable/병합 구현이며, 이 타입들은 동작하지 않는 컴파일 스텁이다.
struct GeneratedProblem {
    init(id: String, typeKey: String, typeName: String, unit: String,
         statement: String, answer: String, steps: [String], minutes: Int,
         choices: [String]?, isTex: Bool, hintText: String?, visualizationJSON: String?) {}
}

enum DataScope {
    static func url(_ name: String) -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(name)
    }

    // 비동기 writer가 enqueue 때 캡처한 계정 슬롯으로 쓰는 실제 DataScope API.
    static func url(_ name: String, for slot: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(slot, isDirectory: true)
            .appendingPathComponent(name)
    }
}

final class AppStore {
    static func slotKey(_ key: String) -> String { key }
    var wrongNoteStorageAlert: String?
}

@MainActor
enum AppStoreLocator {
    static var shared: AppStore?
}

enum EventLog {
    static func append(_ name: String) {}
}

@main
struct SyncContractCases {
    static func decode(_ object: [String: Any]) throws -> WrongNoteEntry {
        let data = try JSONSerialization.data(withJSONObject: object)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(WrongNoteEntry.self, from: data)
    }

    static func require(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else {
            fputs("FAIL: \(message)\n", stderr)
            exit(1)
        }
    }

    static func fixture(nextReviewAt: Any?, serverUpdatedAt: String? = nil) -> [String: Any] {
        var value: [String: Any] = [
            "id": "client-attempt-1",
            "problemID": "problem-1",
            "typeKey": "linear",
            "typeName": "일차방정식",
            "unit": "방정식",
            "statement": "로컬 필기와 함께 보존할 문장",
            "answer": "1",
            "steps": ["양변에서 1을 뺀다."],
            "seed": 1,
            "drawingPNGBase64": "local-drawing",
            "srsStage": 0,
            "wrongCount": 1,
            "createdAt": "2026-08-04T00:00:00Z",
            "choices": ["0", "1"],
            "isTex": true,
            "myAnswer": "0",
            "serverAttemptId": "66a000000000000000000001",
        ]
        value["nextReviewAt"] = nextReviewAt ?? NSNull()
        if let serverUpdatedAt { value["serverUpdatedAt"] = serverUpdatedAt }
        return value
    }

    static func main() throws {
        // serverUpdatedAt 필드가 없던 실제 구 저장 파일도 계속 열린다.
        var local = try decode(
            fixture(nextReviewAt: "2026-08-05T00:00:00Z")
        )
        require(local.serverUpdatedAt == nil, "legacy JSON must decode without revision")
        require(
            WrongNoteReviewSyncAddress.attemptIdentifier(for: local) ==
                "66a000000000000000000001",
            "server id must be preferred after bulk acknowledgement"
        )

        var beforeBulk = local
        beforeBulk.serverAttemptId = nil
        require(
            WrongNoteReviewSyncAddress.attemptIdentifier(for: beforeBulk) ==
                "client-attempt-1",
            "client attempt id must keep pre-ack review result uploadable"
        )

        var remoteObject = fixture(
            nextReviewAt: nil,
            serverUpdatedAt: "2026-08-04T01:00:00Z"
        )
        remoteObject["statement"] = "서버가 보낸 축약 문장"
        remoteObject["drawingPNGBase64"] = NSNull()
        remoteObject["wrongCount"] = 2
        remoteObject["srsStage"] = 1
        let remote = try decode(remoteObject)

        require(
            WrongNoteSyncMerge.apply(remote: remote, to: &local),
            "new server revision must apply"
        )
        require(local.nextReviewAt == nil, "completed review must propagate")
        require(local.wrongCount == 2, "wrong count must advance")
        require(local.srsStage == 1, "review stage must advance")
        require(
            local.statement == "로컬 필기와 함께 보존할 문장",
            "local problem snapshot must win"
        )
        require(local.drawingPNGBase64 == "local-drawing", "local drawing must survive")

        require(
            !WrongNoteSyncMerge.apply(remote: remote, to: &local),
            "same revision must be idempotent"
        )

        print("Sync contract Swift cases passed")
        print("- legacy wrong-note JSON remains decodable")
        print("- review result has an address before and after bulk acknowledgement")
        print("- newer server review state merges once without replacing local snapshot")
    }
}
