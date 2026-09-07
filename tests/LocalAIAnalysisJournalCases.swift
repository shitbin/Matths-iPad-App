import Foundation

@main
enum LocalAIAnalysisJournalCases {
    static func main() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("ai-journal-tests-\(UUID())")
        let pending = root.appendingPathComponent("local-ai-pending-sheet")
        try fm.createDirectory(at: pending, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }
        let source = pending.appendingPathComponent("source.jpg")
        let imageBytes = Data([0xff, 0xd8, 0xff, 0xdb, 1, 2, 3])
        try imageBytes.write(to: source, options: .atomic)
        guard let journal = LocalAIAnalysisJournal(image: source) else { fatalError("fixture journal") }

        var keys: [String] = []
        for stage in 0..<20 {
            let key = journal.key(model: "vision-or-reasoning-v1", prompt: "stage-\(stage)", maxTokens: 600, imageInput: stage < 2)
            let payload = try JSONSerialization.data(withJSONObject: ["stage": stage, "status": "validated"])
            try journal.save(payload, key: key)
            keys.append(key)
            // Simulated process restart after each independently committed stage.
            guard let restored = LocalAIAnalysisJournal(image: source) else { fatalError("relaunch") }
            for completed in keys { precondition(restored.load(key: completed) != nil) }
        }

        let records = try fm.contentsOfDirectory(at: journal.directory, includingPropertiesForKeys: nil)
        precondition(records.count == 20)
        try Data("{\"partial-write\":".utf8).write(to: records[0], options: .atomic)
        let reusable = keys.filter { journal.load(key: $0) != nil }.count
        precondition(reusable == 19, "one corrupt stage must not discard other completed stages")
        let preservedSource = try Data(contentsOf: source)
        precondition(preservedSource == imageBytes, "checkpoint corruption preserves source")
        let changedModel = journal.key(model: "new-model-v2", prompt: "stage-1", maxTokens: 600, imageInput: true)
        let changedPrompt = journal.key(model: "vision-or-reasoning-v1", prompt: "changed-stage-1", maxTokens: 600, imageInput: true)
        let changedCrop = journal.key(model: "vision-or-reasoning-v1", prompt: "stage-1", maxTokens: 600, imageInput: true, imageDigest: "other-crop")
        precondition(journal.load(key: changedModel) == nil)
        precondition(journal.load(key: changedPrompt) == nil)
        precondition(journal.load(key: changedCrop) == nil)

        let otherAccount = root.appendingPathComponent("other-account/local-ai-pending-sheet")
        try fm.createDirectory(at: otherAccount, withIntermediateDirectories: true)
        let otherSource = otherAccount.appendingPathComponent("source.jpg")
        try imageBytes.write(to: otherSource, options: .atomic)
        let otherJournal = LocalAIAnalysisJournal(image: otherSource)!
        precondition(otherJournal.load(key: keys[1]) == nil, "identical photo in another account cannot read prior account's journal")

        var modified = imageBytes; modified[modified.count - 1] = 4
        try modified.write(to: source, options: .atomic)
        precondition(journal.load(key: keys[1]) == nil, "a changed original cannot reuse stale analysis")
        let newJournal = LocalAIAnalysisJournal(image: source)!
        let newKey = newJournal.key(model: "vision-or-reasoning-v1", prompt: "stage-1", maxTokens: 600, imageInput: true)
        precondition(newJournal.load(key: newKey) == nil)

        try fm.removeItem(at: pending)
        try journal.save(Data("{\"late\":true}".utf8), key: keys[1])
        precondition(!fm.fileExists(atPath: pending.path), "late callback after explicit discard must not resurrect private data")
        print("AI stage journal: 20 interrupted/relaunched stages, corruption isolation, model/prompt/crop invalidation, account isolation, and late-write discard passed")
    }
}
