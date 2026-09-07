import Foundation
import CryptoKit

@MainActor enum DataScope {
    static let root = FileManager.default.temporaryDirectory.appendingPathComponent("arena-draft-tests-\(UUID())", isDirectory: true)
    static var slot = "a"
    static func directory(for slot: String) -> URL {
        let path = root.appendingPathComponent(slot, isDirectory: true)
        try? FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)
        return path
    }
    static func url(_ name: String, for slot: String) -> URL { directory(for: slot).appendingPathComponent(name) }
}

@main enum ArenaDraftPersistenceCases {
    @MainActor static func main() async throws {
        let fm = FileManager.default
        defer { try? fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: DataScope.root.appendingPathComponent("a").path); try? fm.removeItem(at: DataScope.root) }
        ArenaDraftPersistence.activate(slot: "a"); ArenaDraftPersistence.activate(slot: "b")
        func answer(_ value: String, attempt: String = "attempt-a") -> GoatArenaDraft {
            .init(matchId: "match-a", attemptId: attempt, questionPackId: "pack-a", currentQuestionIndex: 0,
                  answers: [1: value], dirtySlots: [1], answerCommandIds: [1: "command-a"])
        }
        try GoatArenaDraftStore.save(answer("1"), accountSlot: "a")
        try GoatArenaDraftStore.save(answer("2", attempt: "attempt-b"), accountSlot: "a")
        for value in 0..<20 { try GoatArenaDraftStore.save(answer(String(value)), accountSlot: "a") }
        let firstFlush = await ArenaDraftPersistence.flush(slot: "a")
        precondition(firstFlush)
        let latest = try GoatArenaDraftStore.load(matchId: "match-a", attemptId: "attempt-a", questionPackId: "pack-a", accountSlot: "a")
        precondition(latest?.answers[1] == "19")
        let untouched = try GoatArenaDraftStore.load(matchId: "match-a", attemptId: "attempt-b", questionPackId: "pack-a", accountSlot: "a")
        precondition(untouched?.answers[1] == "2", "Full-index updates lost another attempt")
        let other = try GoatArenaDraftStore.load(matchId: "match-a", attemptId: "attempt-a", questionPackId: "pack-a", accountSlot: "b")
        precondition(other == nil)
        let answerURL = try GoatArenaDraftStore.url(accountSlot: "a")
        let beforeFailure = try Data(contentsOf: answerURL)
        try fm.setAttributes([.posixPermissions: 0o500], ofItemAtPath: DataScope.directory(for: "a").path)
        try GoatArenaDraftStore.save(answer("20"), accountSlot: "a")
        let failedFlush = await ArenaDraftPersistence.flush(slot: "a")
        precondition(!failedFlush, "Write failure was acknowledged as success")
        let afterFailure = try Data(contentsOf: answerURL)
        precondition(afterFailure == beforeFailure)
        try fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: DataScope.directory(for: "a").path)
        let retry = await ArenaDraftPersistence.flush(slot: "a")
        precondition(retry)
        let retried = try GoatArenaDraftStore.load(matchId: "match-a", attemptId: "attempt-a", questionPackId: "pack-a", accountSlot: "a")
        precondition(retried?.answers[1] == "20")

        let broken = Data("{broken draft index".utf8)
        try broken.write(to: answerURL, options: .atomic)
        do {
            _ = try GoatArenaDraftStore.load(matchId: "match-a", attemptId: "attempt-a", questionPackId: "pack-a", accountSlot: "a")
            preconditionFailure("Corrupt JSON was treated as an empty index")
        } catch {}
        do { try GoatArenaDraftStore.save(answer("unsafe"), accountSlot: "a"); preconditionFailure("Damaged index was overwritten") }
        catch {}
        let stillBroken = try Data(contentsOf: answerURL)
        precondition(stillBroken == broken)
        let recovered = await GoatArenaDraftStore.recover(accountSlot: "a")
        precondition(recovered)
        let backupDirectory = DataScope.directory(for: "a").appendingPathComponent("arena-draft-preserved-originals")
        let backups = try fm.contentsOfDirectory(at: backupDirectory, includingPropertiesForKeys: nil)
        let backupBytes = try backups.map { try Data(contentsOf: $0) }
        precondition(backupBytes.contains(broken), "Explicit recovery did not preserve the raw corrupt original")
        try GoatArenaDraftStore.save(answer("new"), accountSlot: "a")
        let afterRecovery = await ArenaDraftPersistence.flush(slot: "a")
        precondition(afterRecovery)

        try GoatArenaDraftStore.save(answer("working-copy"), accountSlot: "a")
        let secondBroken = Data("{second damaged on-disk source".utf8)
        try secondBroken.write(to: answerURL, options: .atomic)
        let conflictFlush = await ArenaDraftPersistence.flush(slot: "a")
        precondition(!conflictFlush)
        let workingRecovery = await GoatArenaDraftStore.recover(accountSlot: "a")
        precondition(workingRecovery)
        let allBackups = try fm.contentsOfDirectory(at: backupDirectory, includingPropertiesForKeys: nil)
        let allBackupBytes = try allBackups.map { try Data(contentsOf: $0) }
        precondition(allBackupBytes.contains(secondBroken))
        precondition(allBackupBytes.contains { bytes in
            (try? JSONDecoder().decode([GoatArenaDraft].self, from: bytes))?.contains(where: { $0.answers[1] == "working-copy" }) == true
        }, "Recovery preserved disk corruption but lost the latest in-memory working copy")

        let board = GoatArenaSolutionBoardDraft(revision: 3, drawingData: Data("opaque-PencilKit-fixture".utf8))
        try GoatArenaSolutionBoardDraftStore.save(board, matchId: "match-a", slot: 1, accountSlot: "a")
        let boardSaved = await ArenaDraftPersistence.flush(slot: "a")
        precondition(boardSaved)
        let boardURL = try GoatArenaSolutionBoardDraftStore.url(matchId: "match-a", slot: 1, accountSlot: "a")
        var corruptBoard = board; corruptBoard.drawingData = Data("changed-with-old-hash".utf8)
        let corruptBytes = try JSONEncoder().encode(corruptBoard)
        try corruptBytes.write(to: boardURL, options: .atomic)
        do { _ = try GoatArenaSolutionBoardDraftStore.load(matchId: "match-a", slot: 1, accountSlot: "a"); preconditionFailure("Checksum corruption was accepted") }
        catch {}
        let oldBoardBytes = try Data(contentsOf: boardURL)
        precondition(oldBoardBytes == corruptBytes)
        let recoveredBoard = await GoatArenaSolutionBoardDraftStore.recover(board, matchId: "match-a", slot: 1, accountSlot: "a")
        precondition(recoveredBoard)

        // No keys or file paths are silently regenerated when an attachment is missing.
        let missingURL = DataScope.url("arena-evidence-attempt--missing.jpg", for: "a")
        let evidence = GoatArenaEvidenceDraft(matchId: "match-a", attemptId: "attempt-a", submissionId: "stable-evidence-key", deadlineAt: nil, filePaths: [missingURL.path])
        try GoatArenaEvidenceDraftStore.save(evidence, accountSlot: "a")
        let evidenceSaved = await ArenaDraftPersistence.flush(slot: "a")
        precondition(evidenceSaved)
        let reloaded = try GoatArenaEvidenceDraftStore.load(matchId: "match-a", attemptId: "attempt-a", accountSlot: "a")
        precondition(reloaded?.filePaths == [missingURL.path] && reloaded?.submissionId == "stable-evidence-key")
        let resolved = try reloaded?.existingFiles(accountSlot: "a")
        precondition(resolved?.isEmpty == true && reloaded?.filePaths.count == 1)
        let outside = DataScope.url("arena-evidence-attempt--outside.jpg", for: "b")
        let photo = Data([0xff, 0xd8, 0x01, 0x02])
        try photo.write(to: outside)
        do { try GoatArenaEvidenceDraftStore.validateAttachment(outside, attemptId: "attempt-a", accountSlot: "a"); preconditionFailure("Cross-account attachment accepted") }
        catch {}
        let refusedDelete = await GoatArenaEvidenceDraftStore.clear(matchId: "match-a", attemptId: "attempt-a", deleting: [EvidenceFile(url: outside)], accountSlot: "a")
        precondition(!refusedDelete && fm.fileExists(atPath: outside.path))
        let symlink = DataScope.url("arena-evidence-attempt--link.jpg", for: "a")
        try fm.createSymbolicLink(at: symlink, withDestinationURL: outside)
        do { try GoatArenaEvidenceDraftStore.validateAttachment(symlink, attemptId: "attempt-a", accountSlot: "a"); preconditionFailure("Symlink attachment accepted") }
        catch {}

        let localPhoto = DataScope.url("arena-evidence-attempt--local.jpg", for: "a")
        try photo.write(to: localPhoto)
        let evidenceURL = try GoatArenaEvidenceDraftStore.url(accountSlot: "a")
        try broken.write(to: evidenceURL, options: .atomic)
        let failedClear = await GoatArenaEvidenceDraftStore.clear(matchId: "match-a", attemptId: "attempt-a", deleting: [EvidenceFile(url: localPhoto)], accountSlot: "a")
        precondition(!failedClear && fm.fileExists(atPath: localPhoto.path), "Attachment was deleted before its index committed")

        try GoatArenaDraftStore.save(answer("must-not-resurrect"), accountSlot: "a")
        await ArenaDraftPersistence.invalidate(slot: "a")
        let accountDirectory = DataScope.root.appendingPathComponent("a")
        try fm.removeItem(at: accountDirectory)
        do { try GoatArenaDraftStore.save(answer("late"), accountSlot: "a"); preconditionFailure("Closed account accepted a late write") }
        catch {}
        try await Task.sleep(for: .milliseconds(250))
        precondition(!fm.fileExists(atPath: accountDirectory.path), "A delayed writer recreated a deleted account directory")
        ArenaDraftPersistence.activate(slot: "a")
        try GoatArenaDraftStore.save(answer("new-session"), accountSlot: "a")
        let reactivated = await ArenaDraftPersistence.flush(slot: "a")
        precondition(reactivated)
        let newSession = try GoatArenaDraftStore.load(matchId: "match-a", attemptId: "attempt-a", questionPackId: "pack-a", accountSlot: "a")
        precondition(newSession?.answers[1] == "new-session")
        let freshEvidence = try GoatArenaEvidenceDraftStore.load(matchId: "match-a", attemptId: "attempt-a", accountSlot: "a")
        precondition(freshEvidence == nil, "A deleted account's damaged-file gate leaked into a new account session")
        print("Arena draft persistence: real atomic/latest writes, IO failure retry, corrupt-source backup/reset, checksum, slot isolation, path/symlink confinement, index-before-delete and invalidate/reactivate: PASS. Opaque drawing bytes only; no PKDrawing validity claim.")
    }
}
