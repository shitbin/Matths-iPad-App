import Foundation

@main enum GoatArenaCommandKeyJournalCases {
    @MainActor static func main() async throws {
        func check(_ value: Bool) { precondition(value) }
        precondition(!GoatArenaCommandKeyStore.canDiscard(attemptStatus: "EVIDENCE_REQUIRED", evidenceRequired: true))
        precondition(!GoatArenaCommandKeyStore.canDiscard(attemptStatus: "IN_PROGRESS", evidenceRequired: nil))
        precondition(GoatArenaCommandKeyStore.canDiscard(attemptStatus: "SUBMITTED", evidenceRequired: nil))
        precondition(GoatArenaCommandKeyStore.canDiscard(attemptStatus: "IN_PROGRESS", evidenceRequired: false))
        let manager = FileManager.default
        let root = manager.temporaryDirectory.appendingPathComponent("matths-command-journal-\(UUID().uuidString)")
        try manager.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? manager.removeItem(at: root) }
        let directory = root.appendingPathComponent("account-a")
        let first = try GoatArenaCommandKeyStore.loadOrCreate(matchId: "match-1", directory: directory, buildVersion: "1.0 (17)")
        let file = directory.appendingPathComponent(GoatArenaCommandKeyStore.fileName)
        let initialBytes = try Data(contentsOf: file)
        let replay = try GoatArenaCommandKeyStore.loadOrCreate(matchId: "match-1", directory: directory, buildVersion: "1.0 (18)")
        precondition(first == replay && replay.clientBuildVersion == "1.0 (17)")
        check(try Data(contentsOf: file) == initialBytes)
        let batch = try await withThrowingTaskGroup(of: GoatArenaCommandKeys.self) { group in
            for _ in 0..<20 { group.addTask { try await MainActor.run {
                try GoatArenaCommandKeyStore.loadOrCreate(matchId: "match-2", directory: directory, buildVersion: "1.0 (18)")
            } } }
            var results: [GoatArenaCommandKeys] = []
            for try await result in group { results.append(result) }
            return results
        }
        precondition(Set(batch.map(\.startCommandId)).count == 1)
        let b = try GoatArenaCommandKeyStore.loadOrCreate(matchId: "match-1", directory: root.appendingPathComponent("account-b"), buildVersion: "1.0 (18)")
        precondition(b.startCommandId != first.startCommandId)
        try GoatArenaCommandKeyStore.clear(matchId: "match-2", directory: directory)
        check(try GoatArenaCommandKeyStore.existing(matchId: "match-1", directory: directory) == first)
        let corrupted = Data("broken original command history".utf8)
        try corrupted.write(to: file)
        do { _ = try GoatArenaCommandKeyStore.loadOrCreate(matchId: "match-new", directory: directory, buildVersion: "1.0 (18)"); preconditionFailure("corruption must block new keys") } catch {}
        do { try GoatArenaCommandKeyStore.clear(matchId: "match-1", directory: directory); preconditionFailure("clear must not erase corrupted history") } catch {}
        check(try Data(contentsOf: file) == corrupted)
        try GoatArenaCommandKeyStore.backUpOriginal(directory: directory)
        let backup = try manager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil).first { $0.lastPathComponent.contains(".backup-") }!
        check(try Data(contentsOf: backup) == corrupted)
        check(try Data(contentsOf: file) == corrupted)
        let duplicates = try JSONEncoder().encode([first, first])
        try duplicates.write(to: file)
        do { _ = try GoatArenaCommandKeyStore.loadOrCreate(matchId: "match-new", directory: directory, buildVersion: "18"); preconditionFailure("duplicate IDs must not overwrite") } catch {}
        try manager.removeItem(at: file)
        try manager.createSymbolicLink(at: file, withDestinationURL: root.appendingPathComponent("missing-target"))
        do { _ = try GoatArenaCommandKeyStore.loadOrCreate(matchId: "match-new", directory: directory, buildVersion: "18"); preconditionFailure("dangling symlink must not become missing file") } catch {}
        try manager.removeItem(at: file)
        let legacy = Data(#"[{"matchId":"legacy","startCommandId":"original-start","submissionId":"original-submit"}]"#.utf8)
        try legacy.write(to: file)
        let migrated = try GoatArenaCommandKeyStore.loadOrCreate(matchId: "legacy", directory: directory, buildVersion: "18")
        precondition(migrated.startCommandId == "original-start" && migrated.submissionId == "original-submit")
        check(try GoatArenaCommandKeyStore.loadOrCreate(matchId: "legacy", directory: directory, buildVersion: "19").clientBuildVersion == "18")
        let blockedDirectory = root.appendingPathComponent("not-a-directory")
        try Data("keep".utf8).write(to: blockedDirectory)
        do { _ = try GoatArenaCommandKeyStore.loadOrCreate(matchId: "new", directory: blockedDirectory, buildVersion: "18"); preconditionFailure("IO failure must not return a nondurable key") } catch {}
        check(try Data(contentsOf: blockedDirectory) == Data("keep".utf8))
        let limit = (0..<10_000).map { GoatArenaCommandKeys(matchId: "limit-\($0)", startCommandId: "start-\($0)", submissionId: "submit-\($0)", clientBuildVersion: "18") }
        let limitBytes = try JSONEncoder().encode(limit)
        try limitBytes.write(to: file)
        do { _ = try GoatArenaCommandKeyStore.loadOrCreate(matchId: "beyond-limit", directory: directory, buildVersion: "18"); preconditionFailure("write must not create a journal that its own reader rejects") } catch {}
        check(try Data(contentsOf: file) == limitBytes)
        check(try GoatArenaCommandKeyStore.existing(matchId: "limit-9999", directory: directory) == limit.last)
        print("Arena command journal: durable 20-way single identity, build migration, corrupt/duplicate/symlink refusal and original backup passed")
    }
}
