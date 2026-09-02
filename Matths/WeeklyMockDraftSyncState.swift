//  WeeklyMockDraftSyncState.swift
//  Matths
//
//  주간 모의고사 답안의 네트워크 요청 세대를 추적한다. 서버 응답에는 답안
//  revision이 없으므로, 요청 시작 뒤 생긴 로컬 편집을 오래된 응답이 덮지 않게
//  클라이언트 세대를 정본으로 사용한다.

import Foundation

struct WeeklyMockPersistedDraft: Codable, Equatable {
    let answers: [String]
    let dirty: Bool

    static func decode(_ data: Data?, legacyDirty: Bool = false) -> Self? {
        guard let data else { return nil }
        if let value = try? JSONDecoder().decode(Self.self, from: data) {
            return value
        }
        // 기존 앱은 같은 키에 답안 배열만 저장했다.
        if let answers = try? JSONDecoder().decode([String].self, from: data) {
            return Self(answers: answers, dirty: legacyDirty)
        }
        return nil
    }
}

struct WeeklyMockDraftSyncState: Codable, Equatable {
    struct SaveRequest: Equatable {
        fileprivate let editRevision: Int
    }

    struct LoadRequest: Equatable {
        fileprivate let generation: Int
        fileprivate let editRevision: Int
        fileprivate let hadUnsavedChanges: Bool
    }

    private(set) var editRevision = 0
    private(set) var savedRevision = 0
    private(set) var latestLoadGeneration = 0

    init(editRevision: Int = 0, savedRevision: Int = 0) {
        self.editRevision = max(0, editRevision)
        self.savedRevision = max(0, min(savedRevision, editRevision))
    }

    init(persistedDirty: Bool) {
        self.init(editRevision: persistedDirty ? 1 : 0, savedRevision: 0)
    }

    var hasUnsavedChanges: Bool {
        savedRevision != editRevision
    }

    mutating func recordEdit() {
        editRevision &+= 1
    }

    func beginSave() -> SaveRequest {
        SaveRequest(editRevision: editRevision)
    }

    mutating func markSaveSucceeded(_ request: SaveRequest) {
        // 저장 도중 추가 편집이 있었다면 최신 revision은 dirty로 남는다.
        savedRevision = request.editRevision
    }

    mutating func markServerSnapshotApplied() {
        savedRevision = editRevision
    }

    mutating func markTerminal() {
        editRevision = 0
        savedRevision = 0
    }

    func hasEdits(after request: SaveRequest) -> Bool {
        editRevision != request.editRevision
    }

    func canApplySaveResponse(_ request: SaveRequest) -> Bool {
        !hasEdits(after: request)
    }

    mutating func beginLoad() -> LoadRequest {
        latestLoadGeneration &+= 1
        return LoadRequest(
            generation: latestLoadGeneration,
            editRevision: editRevision,
            hadUnsavedChanges: hasUnsavedChanges)
    }

    func shouldApplyMetadata(_ request: LoadRequest) -> Bool {
        isLatest(request)
    }

    func shouldPreserveLocalDraft(_ request: LoadRequest) -> Bool {
        isLatest(request) && (
            request.hadUnsavedChanges ||
            request.editRevision != editRevision ||
            hasUnsavedChanges
        )
    }

    func isLatest(_ request: LoadRequest) -> Bool {
        request.generation == latestLoadGeneration
    }
}

enum WeeklyMockDraftRecovery {
    static func answers(
        server: [String],
        local: [String]?,
        current: [String],
        count: Int,
        preserveLocal: Bool
    ) -> [String] {
        var resolved = Array(server.prefix(count))
        if resolved.count < count {
            resolved += Array(repeating: "", count: count - resolved.count)
        }

        guard preserveLocal else {
            if let local, local.count == count {
                for index in 0..<count where resolved[index].isEmpty && !local[index].isEmpty {
                    resolved[index] = local[index]
                }
            }
            return resolved
        }

        if let local, local.count == count { return local }
        if current.count == count { return current }
        return resolved
    }
}
