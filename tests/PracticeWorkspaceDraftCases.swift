import Foundation

@MainActor enum DataScope {
    static var root = FileManager.default.temporaryDirectory.appendingPathComponent("practice-draft-tests-\(UUID())")
    static func url(_ name: String, for slot: String) -> URL {
        root.appendingPathComponent(slot).appendingPathComponent(name)
    }
}

@main enum PracticeWorkspaceDraftCases {
    final class Counter: @unchecked Sendable {
        private let lock = NSLock()
        private var count = 0
        var value: Int { lock.withLock { count } }
        func increment() { lock.withLock { count += 1 } }
    }
    @MainActor static func main() async throws {
        let fm = FileManager.default
        defer { try? fm.removeItem(at: DataScope.root) }
        let key = PracticeWorkspaceDraft.questionFingerprint(id: "problem-1", typeKey: "quadratic",
                    statement: "x² = 3", choices: ["sqrt(3)", "3"], revisionHint: "answer-a|diagram-v1")
        let changed = PracticeWorkspaceDraft.questionFingerprint(id: "problem-1", typeKey: "quadratic",
                    statement: "x² = 5", choices: ["sqrt(5)", "5"], revisionHint: "answer-a|diagram-v1")
        precondition(key != changed)
        precondition(PracticeWorkspaceDraftRepository.handle(fingerprint: "../../escape", slot: "a") == nil)
        PracticeWorkspaceDraftRepository.activate(slot: "a")
        let a = PracticeWorkspaceDraftRepository.handle(fingerprint: key, slot: "a")!
        let b = PracticeWorkspaceDraftRepository.handle(fingerprint: key, slot: "b")!
        let drawingBytes = Data("opaque-drawing-fixture".utf8)
        let first = try PracticeWorkspaceDraft(fingerprint: key, answer: "sqrt(3)", pickedKey: "a",
                                               drawingData: drawingBytes, zoom: 1.75)
        precondition(PracticeWorkspaceDraftRepository.schedule(first, for: a))
        let saved = await PracticeWorkspaceDraftRepository.flush(slot: "a")
        precondition(saved)
        if case .loaded(let restored) = PracticeWorkspaceDraftDisk.load(at: a.url, fingerprint: key) {
            precondition(restored == first, "real file roundtrip preserves answer, choice, bytes and zoom")
        } else { preconditionFailure("missing disk draft") }
        if case .missing = await PracticeWorkspaceDraftRepository.load(b) { }
        else { preconditionFailure("account b saw account a input") }

        for index in 0..<20 {
            let next = try PracticeWorkspaceDraft(fingerprint: key, answer: "revision-\(index)", pickedKey: "a",
                                                 drawingData: drawingBytes, zoom: 2)
            precondition(PracticeWorkspaceDraftRepository.schedule(next, for: a))
        }
        let finalSaved = await PracticeWorkspaceDraftRepository.flush(slot: "a")
        precondition(finalSaved)
        if case .loaded(let restored) = PracticeWorkspaceDraftDisk.load(at: a.url, fingerprint: key) {
            precondition(restored.answer == "revision-19", "lifecycle flush cannot lose just-scheduled values")
        } else { preconditionFailure("latest disk value") }

        // A malformed JSON or mismatching fingerprint is never silently replaced.
        let original = try Data(contentsOf: a.url)
        if case .unreadable = PracticeWorkspaceDraftDisk.load(at: a.url, fingerprint: changed) { }
        else { preconditionFailure("same id with changed content accepted") }
        try Data("broken-json".utf8).write(to: a.url, options: .atomic)
        if case .unreadable = PracticeWorkspaceDraftDisk.load(at: a.url, fingerprint: key) { }
        else { preconditionFailure("corrupt draft accepted") }
        let preserved = try Data(contentsOf: a.url)
        precondition(preserved == Data("broken-json".utf8), "failed read must preserve source")
        let recovered = await PracticeWorkspaceDraftRepository.resetPreservingOriginal(a)
        precondition(recovered)
        let backupDirectory = a.url.deletingLastPathComponent().appendingPathComponent("preserved-originals")
        let backups = try fm.contentsOfDirectory(at: backupDirectory, includingPropertiesForKeys: nil)
        precondition(backups.count == 1)
        let backupBytes = try Data(contentsOf: backups[0])
        precondition(backupBytes == preserved, "explicit reset must retain verified original bytes")
        if case .loaded(let blank) = PracticeWorkspaceDraftDisk.load(at: a.url, fingerprint: key) {
            precondition(blank.answer.isEmpty && blank.pickedKey == nil && blank.drawingData.isEmpty && blank.zoom == 1)
        } else { preconditionFailure("recovery did not create readable empty draft") }

        let counter = Counter()
        let deferredSource = PracticeWorkspaceDraftSource { counter.increment(); return first }
        precondition(PracticeWorkspaceDraftRepository.schedule(deferredSource, for: a))
        precondition(counter.value == 0, "drawing serialization must not occur synchronously in a UI edit callback")
        let sourceSaved = await PracticeWorkspaceDraftRepository.flush(slot: "a")
        precondition(sourceSaved && counter.value == 1)
        precondition(PracticeWorkspaceDraftRepository.schedule(first, for: a))
        let concurrentFlushes = (0..<20).map { _ in Task { await PracticeWorkspaceDraftRepository.flush(slot: "a") } }
        for flush in concurrentFlushes {
            let completed = await flush.value
            precondition(completed, "concurrent lifecycle flushes must coalesce without a revision livelock")
        }

        let blocked = PracticeWorkspaceDraftRepository.handle(fingerprint: key, slot: "blocked-backup")!
        try fm.createDirectory(at: blocked.url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try preserved.write(to: blocked.url)
        try Data([1]).write(to: blocked.url.deletingLastPathComponent().appendingPathComponent("preserved-originals"))
        let failedRecovery = await PracticeWorkspaceDraftRepository.resetPreservingOriginal(blocked)
        precondition(!failedRecovery)
        let stillOriginal = try Data(contentsOf: blocked.url)
        precondition(stillOriginal == preserved, "backup failure must never replace original")
        try original.write(to: a.url, options: .atomic)
        var object = try JSONSerialization.jsonObject(with: original) as! [String: Any]
        object["drawingSHA256"] = String(repeating: "0", count: 64)
        try JSONSerialization.data(withJSONObject: object).write(to: a.url, options: .atomic)
        if case .unreadable = PracticeWorkspaceDraftDisk.load(at: a.url, fingerprint: key) { }
        else { preconditionFailure("damaged drawing digest accepted") }

        do {
            _ = try PracticeWorkspaceDraft(fingerprint: key, answer: "", pickedKey: nil,
                drawingData: Data(repeating: 0, count: PracticeWorkspaceDraft.maximumDrawingBytes + 1), zoom: 1)
            preconditionFailure("oversized drawing accepted")
        } catch PracticeWorkspaceDraft.ValidationError.tooLarge { }
        do {
            _ = try PracticeWorkspaceDraft(fingerprint: key, answer: "", pickedKey: nil, drawingData: Data(), zoom: .nan)
            preconditionFailure("nonfinite zoom accepted")
        } catch PracticeWorkspaceDraft.ValidationError.invalid { }

        // Cancel-and-drain comes before the owner's directory is removed.
        precondition(PracticeWorkspaceDraftRepository.schedule(first, for: a))
        await PracticeWorkspaceDraftRepository.invalidate(slot: "a")
        try fm.removeItem(at: a.url.deletingLastPathComponent().deletingLastPathComponent())
        precondition(!PracticeWorkspaceDraftRepository.schedule(first, for: a))
        let obsoleteSave = await PracticeWorkspaceDraftRepository.save(first, for: a)
        precondition(!obsoleteSave)
        try await Task.sleep(nanoseconds: 200_000_000)
        precondition(!fm.fileExists(atPath: a.url.path), "late snapshot resurrected deleted owner")
        precondition(PracticeWorkspaceDraftRepository.handle(fingerprint: key, slot: "a") == nil)
        PracticeWorkspaceDraftRepository.activate(slot: "a")
        let newA = PracticeWorkspaceDraftRepository.handle(fingerprint: key, slot: "a")!
        precondition(newA.epoch != a.epoch)
        precondition(!PracticeWorkspaceDraftRepository.schedule(first, for: a))
        let newSaved = await PracticeWorkspaceDraftRepository.save(first, for: newA)
        precondition(newSaved, "explicit new session can write without reviving old handles")
        print("Practice workspace draft: real disk roundtrip/latest flush, fingerprint/account isolation, corruption/size/zoom limits, invalidate and reactivation passed (PencilKit decode is simulator-only)")
    }
}
