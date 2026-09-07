import Foundation

enum AppStore { static func slotKey(_ key: String) -> String { "isolated-kice-test-" + key } }
@MainActor enum DataScope {
    static var root = FileManager.default.temporaryDirectory.appendingPathComponent("matths-kice-test-\(UUID())")
    static func url(_ name: String, for slot: String) -> URL { root.appendingPathComponent(slot).appendingPathComponent(name) }
}

@main enum KiceStudyArchiveCases {
    @MainActor static func main() async throws {
        let fm = FileManager.default
        defer { try? fm.removeItem(at: DataScope.root) }
        let fixture = KiceStudyDefinition(examID: "exam-A", title: "격리 기출", shortTitle: "기출", displayForm: nil,
            common: [.init(section: "공통", number: 1, answer: "3", points: 50, isChoice: true)],
            electives: ["미적분": [.init(section: "미적분", number: 23, answer: "23", points: 50, isChoice: false)]])
        var archive = KiceStudyArchive(slot: "account-A")
        let first = try archive.prepare(fixture, now: Date(timeIntervalSince1970: 100))
        try archive.answer(examID: "exam-A", key: "공통-1", value: "3")
        try archive.answer(examID: "exam-A", key: "미적분-23", value: "023")
        try archive.checkpoint(examID: "exam-A", elapsedMs: 65000, page: 2)
        let handle = KiceStudyRepository.handle(slot: "account-A")!
        if case .missing = await KiceStudyRepository.load(handle) {} else { preconditionFailure("not missing") }
        precondition(KiceStudyRepository.schedule(archive, for: handle))
        let saved = await KiceStudyRepository.flush(slot: "account-A")
        precondition(saved)
        guard case .archive(var relaunched) = KiceStudyDisk.load(at: handle.url, slot: "account-A") else { preconditionFailure("lost relaunch") }
        let reopened = try relaunched.prepare(fixture)
        precondition(reopened.id == first.id && reopened.answers["공통-1"] == "3" && reopened.subject == "미적분")
        precondition(reopened.elapsedMs == 65000 && reopened.pdfPageIndex == 2, "relaunch must not reset elapsed or answers")
        try relaunched.checkpoint(examID: "exam-A", elapsedMs: 1000)
        precondition(relaunched.attempts["exam-A"]!.elapsedMs == 65000)
        let receipt = try relaunched.grade(fixture, elapsedMs: 65500)
        precondition(receipt.result.score == 100 && receipt.result.correctCount == 2)
        let replay = try relaunched.grade(fixture, elapsedMs: 99999)
        precondition(replay == receipt && relaunched.receipts.count == 1)
        precondition(relaunched.statistics == .init(solved: 2, correct: 2), "grading retry derives one receipt contribution, never increments twice")
        let committed = await KiceStudyRepository.save(relaunched, for: handle)
        precondition(committed)
        guard case .archive(var postCrash) = KiceStudyDisk.load(at: handle.url, slot: "account-A") else { preconditionFailure("lost result") }
        precondition(postCrash.receipts[receipt.id]?.result == receipt.result)
        precondition(postCrash.pendingEffects.map(\.id) == [receipt.id], "post-result crash leaves effects recoverable")
        postCrash.markEffectsApplied(receipt.id)
        try postCrash.beginAgain(fixture)
        precondition(postCrash.attempts["exam-A"]!.id != receipt.id && postCrash.receipts.count == 1)
        try postCrash.answer(examID: "exam-A", key: "공통-1", value: "1")
        _ = try postCrash.grade(fixture, elapsedMs: 1000)
        precondition(postCrash.statistics == .init(solved: 4, correct: 2))
        postCrash.resetStatistics()
        precondition(postCrash.statistics == .zero && postCrash.receipts.count == 2, "reset does not erase results or revive their statistics")

        // A different account and malformed content are never loaded as empty.
        if case .unreadable = KiceStudyDisk.load(at: handle.url, slot: "account-B") {} else { preconditionFailure("cross account") }
        var other = KiceStudyRepository.handle(slot: "account-B")!
        if case .missing = await KiceStudyRepository.load(other) {} else { preconditionFailure("account leak") }
        let badBytes = Data("{bad-original".utf8)
        try fm.createDirectory(at: other.url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try ProtectedFileWriter.write(badBytes, to: other.url)
        if case .unreadable = await KiceStudyRepository.load(other) {} else { preconditionFailure("corrupt accepted") }
        precondition(!KiceStudyRepository.schedule(.init(slot: "account-B"), for: other), "corrupt file blocks automatic overwrite")
        let unchangedCorrupt = try Data(contentsOf: other.url)
        precondition(unchangedCorrupt == badBytes)
        let reset = await KiceStudyRepository.resetPreservingOriginal(other)
        precondition(reset != nil)
        precondition(!KiceStudyRepository.accepts(other), "recovery invalidates old readers and input handles")
        other = KiceStudyRepository.handle(slot: "account-B")!
        let backups = try fm.contentsOfDirectory(at: other.url.deletingLastPathComponent().appendingPathComponent("preserved-originals"), includingPropertiesForKeys: nil)
        precondition(backups.count == 1)
        let originalBackup = try Data(contentsOf: backups[0])
        precondition(KiceStudyArchive.digest(originalBackup) == KiceStudyArchive.digest(badBytes), "explicit recovery verifies the retained original bytes")

        var pendingArchive = reset!
        _ = try pendingArchive.prepare(fixture)
        let diskBeforeFailure = try Data(contentsOf: other.url)
        try fm.setAttributes([.posixPermissions: 0o555], ofItemAtPath: other.url.deletingLastPathComponent().path)
        let failed = await KiceStudyRepository.save(pendingArchive, for: other)
        try fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: other.url.deletingLastPathComponent().path)
        precondition(!failed)
        let diskAfterFailure = try Data(contentsOf: other.url)
        precondition(diskBeforeFailure == diskAfterFailure, "failed atomic replacement preserves prior record")
        for index in 0..<20 {
            try pendingArchive.answer(examID: "exam-A", key: "공통-1", value: "\(index)")
            precondition(KiceStudyRepository.schedule(pendingArchive, for: other))
        }
        KiceStudyRepository.activate(slot: "account-B")
        precondition(!KiceStudyRepository.accepts(other))
        let reauthenticated = KiceStudyRepository.handle(slot: "account-B")!
        let finalFlush = await KiceStudyRepository.flush(slot: "account-B")
        precondition(finalFlush)
        guard case .archive(let newest) = await KiceStudyRepository.load(reauthenticated) else { preconditionFailure("lost newest") }
        precondition(newest.attempts["exam-A"]?.answers["공통-1"] == "19", "latest state survives reauthentication and schedule order")
        await KiceStudyRepository.invalidate(slot: "account-B")
        try fm.removeItem(at: other.url.deletingLastPathComponent())
        precondition(!KiceStudyRepository.schedule(pendingArchive, for: reauthenticated))
        try await Task.sleep(for: .milliseconds(200))
        precondition(!fm.fileExists(atPath: other.url.path), "invalidated account cannot be resurrected by delayed writes")

        if CommandLine.arguments.count > 1 {
            let index = try JSONDecoder().decode(KiceIndex.self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))
            var checked = 0
            for exam in index.exams {
                let definition = KiceStudyDefinition(exam: exam)
                for subject in definition.electives.keys {
                    var actual = KiceStudyArchive(slot: "catalog-test")
                    _ = try actual.prepare(definition)
                    try actual.selectSubject(examID: exam.id, subject: subject, definition: definition)
                    for question in definition.questions(subject: subject) { try actual.answer(examID: exam.id, key: question.key, value: question.answer) }
                    let graded = try actual.grade(definition, elapsedMs: 1000)
                    precondition(graded.result.score == 100 && graded.result.correctCount == 30 && graded.result.total == 30)
                    checked += 1
                }
            }
            print("Actual bundled KICE answer-bank full-score projections passed: \(checked) exam/subject combinations.")
        }
        print("KICE archive PASS: relaunch answers/subject/elapsed/page, frozen result, idempotent receipt statistics, effects recovery, reset epochs, corruption backup, failed-write original, account isolation and invalidate.")
    }
}
