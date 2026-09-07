import Foundation

@MainActor enum DataScope {
    static var root = FileManager.default.temporaryDirectory.appendingPathComponent("matths-kice-read-race-\(UUID())")
    static func url(_ name: String, for slot: String) -> URL { root.appendingPathComponent(slot).appendingPathComponent(name) }
}
enum KiceReadInterleaving {
    final class Gate: @unchecked Sendable {
        let lock = NSLock()
        let release = DispatchSemaphore(value: 0)
        var armed = false
        var reached = false
        func arm() { lock.withLock { armed = true; reached = false } }
        var didRead: Bool { lock.withLock { reached } }
        func shouldHold() -> Bool { lock.withLock { guard armed else { return false }; armed = false; reached = true; return true } }
    }
    static let gate = Gate()
    static func read(at url: URL, slot: String) -> KiceStudyDisk.Loaded {
        let actual = KiceStudyDisk.load(at: url, slot: slot)
        if gate.shouldHold() { gate.release.wait() }
        return actual
    }
}
@main enum KiceReadInterleavingCases {
    @MainActor static func main() async throws {
        defer { try? FileManager.default.removeItem(at: DataScope.root) }
        let definition = KiceStudyDefinition(examID: "race", title: "race", shortTitle: "race", displayForm: nil,
            common: [.init(section: "공통", number: 1, answer: "1", points: 100, isChoice: true)], electives: ["미적분": []])
        var old = KiceStudyArchive(slot: "owner-A"); _ = try old.prepare(definition)
        try old.answer(examID: "race", key: "공통-1", value: "old")
        let handle = KiceStudyRepository.handle(slot: "owner-A")!
        _ = await KiceStudyRepository.load(handle)
        let firstSaved = await KiceStudyRepository.save(old, for: handle)
        precondition(firstSaved)
        KiceReadInterleaving.gate.arm()
        let pendingRead = Task { @MainActor in await KiceStudyRepository.load(handle) }
        while !KiceReadInterleaving.gate.didRead { await Task.yield() }
        var newest = old
        try newest.answer(examID: "race", key: "공통-1", value: "newest")
        let newSaved = await KiceStudyRepository.save(newest, for: handle)
        precondition(newSaved)
        KiceReadInterleaving.gate.release.signal()
        guard case .archive(let observed) = await pendingRead.value else { preconditionFailure("read failed") }
        if CommandLine.arguments.contains("--expect-stale") {
            precondition(observed.attempts["race"]?.answers["공통-1"] == "old")
            precondition(KiceStudyRepository.schedule(observed, for: handle))
            let overwritten = await KiceStudyRepository.flush(slot: "owner-A")
            precondition(overwritten)
            guard case .archive(let disk) = KiceStudyDisk.load(at: handle.url, slot: "owner-A") else { preconditionFailure("disk") }
            precondition(disk.attempts["race"]?.answers["공통-1"] == "old")
            print("REPRODUCED: old async read returned after a newer save ACK, then an old UI snapshot overwrote the durable newer answer.")
        } else {
            precondition(observed.attempts["race"]?.answers["공통-1"] == "newest",
                         "read completion must use a newer durable in-memory generation after the disk ACK removes pending state")
            precondition(!KiceStudyRepository.schedule(old, for: handle), "older model snapshots cannot overwrite the latest accepted state")
            KiceReadInterleaving.gate.arm()
            let beforeResetRead = Task { @MainActor in await KiceStudyRepository.load(handle) }
            while !KiceReadInterleaving.gate.didRead { await Task.yield() }
            let recovered = await KiceStudyRepository.resetPreservingOriginal(handle)
            precondition(recovered != nil)
            KiceReadInterleaving.gate.release.signal()
            if case .unreadable = await beforeResetRead.value {} else {
                preconditionFailure("an old reader must not resurrect pre-reset answers")
            }
            let currentHandle = KiceStudyRepository.handle(slot: "owner-A")!
            guard case .archive(let current) = await KiceStudyRepository.load(currentHandle) else { preconditionFailure("reset missing") }
            precondition(current.attempts.isEmpty)
            print("KICE read/write interleaving PASS: newer acknowledged answer wins over a late read; stale model write is rejected.")
        }
    }
}
