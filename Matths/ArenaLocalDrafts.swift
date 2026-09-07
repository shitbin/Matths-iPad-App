import CryptoKit
import Foundation

enum ArenaDraftValidation {
    static func identifier(_ value: String) -> Bool {
        !value.isEmpty && value.utf8.count <= 128
            && value.utf8.allSatisfy { (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) || $0 == 45 || $0 == 95 }
    }
}

struct GoatArenaSolutionBoardDraft: Codable, Sendable {
    var revision: Int
    var drawingData: Data
    var drawingSHA256: String?
    init(revision: Int, drawingData: Data) {
        self.revision = revision; self.drawingData = drawingData
        drawingSHA256 = SHA256.hash(data: drawingData).map { String(format: "%02x", $0) }.joined()
    }
    func validate() throws {
        guard (0..<9_007_199_254_740_991).contains(revision), !drawingData.isEmpty,
              drawingData.count <= 16 * 1_024 * 1_024 else { throw ArenaDraftStorageError.invalid }
        if let drawingSHA256 {
            guard drawingSHA256 == SHA256.hash(data: drawingData).map({ String(format: "%02x", $0) }).joined() else { throw ArenaDraftStorageError.damaged }
        }
    }
}

struct GoatArenaDraft: Codable, Sendable {
    let matchId: String
    let attemptId: String
    let questionPackId: String
    let currentQuestionIndex: Int
    let answers: [Int: String]
    let dirtySlots: [Int]?
    let answerCommandIds: [Int: String]?
    func validate() throws {
        guard [matchId, attemptId, questionPackId].allSatisfy(ArenaDraftValidation.identifier),
              (0...4).contains(currentQuestionIndex), answers.count <= 5,
              answers.allSatisfy({ (1...5).contains($0.key) && $0.value.utf8.count <= 256 }),
              dirtySlots?.allSatisfy({ (1...5).contains($0) }) ?? true,
              answerCommandIds?.allSatisfy({ (1...5).contains($0.key) && ArenaDraftValidation.identifier($0.value) }) ?? true else {
            throw ArenaDraftStorageError.invalid
        }
    }
}

struct EvidenceFile: Identifiable, Hashable, Sendable {
    let url: URL
    var id: String { url.path }
}

struct GoatArenaEvidenceDraft: Codable, Sendable {
    let matchId: String
    let attemptId: String
    let submissionId: String
    let deadlineAt: Date?
    let filePaths: [String]
    func validate() throws {
        guard [matchId, attemptId, submissionId].allSatisfy(ArenaDraftValidation.identifier),
              filePaths.count <= 5, Set(filePaths).count == filePaths.count else { throw ArenaDraftStorageError.invalid }
    }
    @MainActor func existingFiles(accountSlot: String) throws -> [EvidenceFile] {
        try filePaths.compactMap { path in
            let url = URL(fileURLWithPath: path)
            try GoatArenaEvidenceDraftStore.validateAttachment(url, attemptId: attemptId, accountSlot: accountSlot)
            guard FileManager.default.fileExists(atPath: url.path) else { return nil }
            return EvidenceFile(url: url)
        }
    }
}

@MainActor enum GoatArenaSolutionBoardDraftStore {
    static func url(matchId: String, slot: Int, accountSlot: String) throws -> URL {
        guard ArenaDraftValidation.identifier(matchId), (1...5).contains(slot) else { throw ArenaDraftStorageError.invalid }
        return try ArenaDraftPersistence.resourceURL("goat-arena-board-\(matchId)-\(slot).json", slot: accountSlot)
    }
    static func load(matchId: String, slot: Int, accountSlot: String) throws -> GoatArenaSolutionBoardDraft? {
        try ArenaDraftPersistence.load(GoatArenaSolutionBoardDraft.self,
            at: url(matchId: matchId, slot: slot, accountSlot: accountSlot), slot: accountSlot, validate: { try $0.validate() })
    }
    static func save(_ draft: GoatArenaSolutionBoardDraft, matchId: String, slot: Int, accountSlot: String) throws {
        try draft.validate()
        try ArenaDraftPersistence.schedule(ArenaDraftSnapshot(draft, validate: { try $0.validate() }),
            at: url(matchId: matchId, slot: slot, accountSlot: accountSlot), slot: accountSlot)
    }
    static func saveSnapshot(matchId: String, slot: Int, accountSlot: String,
                             build: @escaping @Sendable () throws -> GoatArenaSolutionBoardDraft) throws {
        try ArenaDraftPersistence.schedule(ArenaDraftSnapshot(build: build, validate: { try $0.validate() }),
            at: url(matchId: matchId, slot: slot, accountSlot: accountSlot), slot: accountSlot)
    }
    static func recover(_ draft: GoatArenaSolutionBoardDraft, matchId: String, slot: Int, accountSlot: String) async -> Bool {
        guard let target = try? url(matchId: matchId, slot: slot, accountSlot: accountSlot) else { return false }
        return await ArenaDraftPersistence.recover(ArenaDraftSnapshot(draft, validate: { try $0.validate() }), at: target, slot: accountSlot)
    }
    static func clear(matchId: String, accountSlot: String) async -> Bool {
        var success = true
        for slot in 1...5 {
            guard let target = try? url(matchId: matchId, slot: slot, accountSlot: accountSlot) else { return false }
            if !(await ArenaDraftPersistence.remove(at: target, slot: accountSlot)) { success = false }
        }
        return success
    }
}

@MainActor enum GoatArenaDraftStore {
    static func url(accountSlot: String) throws -> URL {
        try ArenaDraftPersistence.resourceURL("goat-arena-match-drafts.json", slot: accountSlot)
    }
    nonisolated private static func validate(_ values: [GoatArenaDraft]) throws {
        guard values.count <= 1_000 else { throw ArenaDraftStorageError.invalid }
        for value in values { try value.validate() }
    }
    private static func readAll(accountSlot: String) throws -> [GoatArenaDraft] {
        try ArenaDraftPersistence.load([GoatArenaDraft].self, at: url(accountSlot: accountSlot), slot: accountSlot,
                                      validate: { try validate($0) }) ?? []
    }
    static func load(matchId: String, attemptId: String, questionPackId: String, accountSlot: String) throws -> GoatArenaDraft? {
        try readAll(accountSlot: accountSlot).first { $0.matchId == matchId && $0.attemptId == attemptId && $0.questionPackId == questionPackId }
    }
    static func save(_ draft: GoatArenaDraft, accountSlot: String) throws {
        try draft.validate()
        var values = try readAll(accountSlot: accountSlot).filter { !($0.matchId == draft.matchId && $0.attemptId == draft.attemptId) }
        values.append(draft)
        try ArenaDraftPersistence.schedule(ArenaDraftSnapshot(values, validate: { try validate($0) }),
                                          at: url(accountSlot: accountSlot), slot: accountSlot)
    }
    static func clear(matchId: String, attemptId: String, accountSlot: String) throws {
        let values = try readAll(accountSlot: accountSlot).filter { !($0.matchId == matchId && $0.attemptId == attemptId) }
        try ArenaDraftPersistence.schedule(ArenaDraftSnapshot(values, validate: { try validate($0) }),
                                          at: url(accountSlot: accountSlot), slot: accountSlot)
    }
    static func recover(accountSlot: String) async -> Bool {
        guard let target = try? url(accountSlot: accountSlot) else { return false }
        return await ArenaDraftPersistence.recover(ArenaDraftSnapshot([GoatArenaDraft](), validate: { try validate($0) }),
                                                  at: target, slot: accountSlot)
    }
}

@MainActor enum GoatArenaEvidenceDraftStore {
    static func url(accountSlot: String) throws -> URL {
        try ArenaDraftPersistence.resourceURL("goat-arena-evidence-drafts.json", slot: accountSlot)
    }
    nonisolated private static func validate(_ values: [GoatArenaEvidenceDraft]) throws {
        guard values.count <= 1_000 else { throw ArenaDraftStorageError.invalid }
        for value in values { try value.validate() }
    }
    private static func readAll(accountSlot: String) throws -> [GoatArenaEvidenceDraft] {
        try ArenaDraftPersistence.load([GoatArenaEvidenceDraft].self, at: url(accountSlot: accountSlot), slot: accountSlot,
                                      validate: { try validate($0) }) ?? []
    }
    static func validateAttachment(_ url: URL, attemptId: String, accountSlot: String) throws {
        guard ArenaDraftValidation.identifier(attemptId), ArenaDraftPersistence.owns(url, slot: accountSlot),
              url.lastPathComponent.hasPrefix("arena-evidence-\(attemptId.prefix(8))-"), url.pathExtension.lowercased() == "jpg" else {
            throw ArenaDraftStorageError.outsideAccount
        }
        if FileManager.default.fileExists(atPath: url.path) {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            guard attributes[.type] as? FileAttributeType == .typeRegular else { throw ArenaDraftStorageError.outsideAccount }
        }
    }
    static func load(matchId: String, attemptId: String, accountSlot: String) throws -> GoatArenaEvidenceDraft? {
        try readAll(accountSlot: accountSlot).first { $0.matchId == matchId && $0.attemptId == attemptId }
    }
    static func save(_ draft: GoatArenaEvidenceDraft, accountSlot: String) throws {
        try draft.validate()
        for path in draft.filePaths { try validateAttachment(URL(fileURLWithPath: path), attemptId: draft.attemptId, accountSlot: accountSlot) }
        var values = try readAll(accountSlot: accountSlot).filter { !($0.matchId == draft.matchId && $0.attemptId == draft.attemptId) }
        values.append(draft)
        try ArenaDraftPersistence.schedule(ArenaDraftSnapshot(values, validate: { try validate($0) }),
                                          at: url(accountSlot: accountSlot), slot: accountSlot)
    }
    static func clear(matchId: String, attemptId: String, deleting files: [EvidenceFile], accountSlot: String) async -> Bool {
        do {
            for file in files { try validateAttachment(file.url, attemptId: attemptId, accountSlot: accountSlot) }
            let values = try readAll(accountSlot: accountSlot).filter { !($0.matchId == matchId && $0.attemptId == attemptId) }
            try ArenaDraftPersistence.schedule(ArenaDraftSnapshot(values, validate: { try validate($0) }),
                                              at: url(accountSlot: accountSlot), slot: accountSlot)
            guard await ArenaDraftPersistence.flush(slot: accountSlot), DataScope.slot == accountSlot else { return false }
            for file in files where FileManager.default.fileExists(atPath: file.url.path) {
                try validateAttachment(file.url, attemptId: attemptId, accountSlot: accountSlot)
                try FileManager.default.removeItem(at: file.url)
            }
            return true
        } catch { return false }
    }
    static func recover(accountSlot: String) async -> Bool {
        guard let target = try? url(accountSlot: accountSlot) else { return false }
        return await ArenaDraftPersistence.recover(ArenaDraftSnapshot([GoatArenaEvidenceDraft](), validate: { try validate($0) }),
                                                  at: target, slot: accountSlot)
    }
}
