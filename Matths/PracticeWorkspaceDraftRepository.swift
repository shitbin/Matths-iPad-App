import Foundation

/// Reuses the revisioned writer, not the official assessment namespace. Values
/// reach this main-actor boundary synchronously before any actor/Task hop, so a
/// lifecycle flush cannot miss a just-edited answer or delayed drawing snapshot.
@MainActor
enum PracticeWorkspaceDraftRepository {
    static let saveFailedNotification = Notification.Name("kr.matths.practiceWorkspaceSaveFailed")
    struct Handle: Hashable, Sendable {
        let slot: String
        let epoch: UUID
        let fingerprint: String
        let url: URL
    }
    private struct Pending: Sendable {
        let handle: Handle
        let source: PracticeWorkspaceDraftSource
        let revision: UInt64
    }
    private static var revision: UInt64 = 0
    private static var epochs: [String: UUID] = [:]
    private static var closedSlots = Set<String>()
    private static var keysBySlot: [String: Set<URL>] = [:]
    private static var latest: [URL: Pending] = [:]
    private static var recoveryIDs: [URL: UUID] = [:]
    private static var flushTasks: [String: (id: UUID, epoch: UUID?, task: Task<Bool, Never>)] = [:]
    private static let writer = DebouncedSnapshotWriter<URL, Pending>(debounceNanoseconds: 150_000_000) { url, pending in
        let success: Bool
        if let draft = try? pending.source.resolve(),
           (try? draft.validate(expectedFingerprint: pending.handle.fingerprint)) != nil {
            success = PracticeWorkspaceDraftDisk.save(draft, at: url)
        } else { success = false }
        Task { @MainActor in
            if success {
                if latest[url]?.revision == pending.revision {
                    latest[url] = nil
                }
            } else if latest[url]?.revision == pending.revision {
                NotificationCenter.default.post(name: saveFailedNotification, object: pending.handle,
                                                userInfo: ["sourceID": pending.source.id.uuidString])
            }
        }
        return success
    }

    static func activate(slot: String) {
        closedSlots.remove(slot)
        epochs[slot] = UUID()
    }

    static func handle(fingerprint: String, slot: String) -> Handle? {
        guard !closedSlots.contains(slot), PracticeWorkspaceDraft.isFingerprint(fingerprint) else { return nil }
        let epoch = epochs[slot] ?? UUID()
        epochs[slot] = epoch
        let url = DataScope.url(PracticeWorkspaceDraft.namespace, for: slot)
            .appendingPathComponent(fingerprint).appendingPathExtension("json")
        keysBySlot[slot, default: []].insert(url)
        return Handle(slot: slot, epoch: epoch, fingerprint: fingerprint, url: url)
    }

    static func accepts(_ handle: Handle) -> Bool {
        !closedSlots.contains(handle.slot) && epochs[handle.slot] == handle.epoch && recoveryIDs[handle.url] == nil
    }

    static func load(_ handle: Handle) async -> PracticeWorkspaceDraftDisk.LoadResult {
        guard accepts(handle) else { return .unreadable }
        if let pending = latest[handle.url], pending.handle == handle { return await resolve(pending) }
        let loaded = await Task.detached(priority: .utility) {
            PracticeWorkspaceDraftDisk.load(at: handle.url, fingerprint: handle.fingerprint)
        }.value
        guard accepts(handle), !Task.isCancelled else { return .unreadable }
        // Input changed while the file read was in flight: newest memory wins.
        if let pending = latest[handle.url], pending.handle == handle { return await resolve(pending) }
        return loaded
    }

    private static func resolve(_ pending: Pending) async -> PracticeWorkspaceDraftDisk.LoadResult {
        let draft = try? await Task.detached(priority: .utility) { try pending.source.resolve() }.value
        guard accepts(pending.handle), !Task.isCancelled, let draft,
              (try? draft.validate(expectedFingerprint: pending.handle.fingerprint)) != nil else { return .unreadable }
        return .loaded(draft)
    }

    @discardableResult
    static func schedule(_ draft: PracticeWorkspaceDraft, for handle: Handle) -> Bool {
        guard accepts(handle), (try? draft.validate(expectedFingerprint: handle.fingerprint)) != nil else { return false }
        return schedule(PracticeWorkspaceDraftSource { draft }, for: handle)
    }

    @discardableResult
    static func schedule(_ source: PracticeWorkspaceDraftSource, for handle: Handle) -> Bool {
        guard accepts(handle) else { return false }
        revision &+= 1
        let pending = Pending(handle: handle, source: source, revision: revision)
        latest[handle.url] = pending
        Task { await writer.schedule(pending, for: handle.url, revision: pending.revision) }
        return true
    }

    static func save(_ draft: PracticeWorkspaceDraft, for handle: Handle) async -> Bool {
        guard accepts(handle), (try? draft.validate(expectedFingerprint: handle.fingerprint)) != nil else { return false }
        return await save(PracticeWorkspaceDraftSource { draft }, for: handle)
    }

    static func save(_ source: PracticeWorkspaceDraftSource, for handle: Handle) async -> Bool {
        guard accepts(handle) else { return false }
        revision &+= 1
        let pending = Pending(handle: handle, source: source, revision: revision)
        latest[handle.url] = pending
        let result = await writer.writeImmediately(pending, for: handle.url, revision: pending.revision)
        if result == .written, latest[handle.url]?.revision == pending.revision { latest[handle.url] = nil }
        return result == .written
    }

    static func flush(slot: String) async -> Bool {
        guard !closedSlots.contains(slot) else { return false }
        if let running = flushTasks[slot], running.epoch == epochs[slot] { return await running.task.value }
        let id = UUID()
        let epoch = epochs[slot]
        let task = Task { @MainActor in await performFlush(slot: slot, capturedEpoch: epoch) }
        flushTasks[slot] = (id, epoch, task)
        let result = await task.value
        if flushTasks[slot]?.id == id { flushTasks[slot] = nil }
        return result
    }

    private static func performFlush(slot: String, capturedEpoch: UUID?) async -> Bool {
        while true {
            guard !closedSlots.contains(slot), epochs[slot] == capturedEpoch else { return false }
            let pending = latest.values.filter { $0.handle.slot == slot }
            guard !pending.isEmpty else { return true }
            var writes: [(key: URL, payload: Pending, revision: UInt64)] = []
            for old in pending {
                revision &+= 1
                let current = Pending(handle: old.handle, source: old.source, revision: revision)
                latest[old.handle.url] = current
                writes.append((old.handle.url, current, revision))
            }
            let outcomes = await writer.writeImmediately(writes)
            for write in writes where outcomes[write.key] == .written && latest[write.key]?.revision == write.revision {
                latest[write.key] = nil
            }
            if outcomes.values.contains(.ioFailed) { return false }
            if Task.isCancelled { return false }
        }
    }

    static func invalidate(slot: String) async {
        closedSlots.insert(slot) // before await: no new higher-revision writes
        epochs[slot] = UUID()
        revision &+= 1
        let keys = keysBySlot[slot] ?? []
        for key in keys { latest[key] = nil }
        await writer.invalidate(keys, through: revision)
    }

    static func resetPreservingOriginal(_ handle: Handle) async -> Bool {
        guard accepts(handle) else { return false }
        let recoveryID = UUID()
        recoveryIDs[handle.url] = recoveryID
        defer { if recoveryIDs[handle.url] == recoveryID { recoveryIDs[handle.url] = nil } }
        revision &+= 1
        latest[handle.url] = nil
        await writer.invalidate([handle.url], through: revision)
        guard !closedSlots.contains(handle.slot), epochs[handle.slot] == handle.epoch else { return false }
        let source = PracticeWorkspaceDraftSource {
            try PracticeWorkspaceDraftDisk.preserveOriginal(at: handle.url)
            return try PracticeWorkspaceDraft(fingerprint: handle.fingerprint, answer: "", pickedKey: nil,
                                               drawingData: Data(), zoom: 1)
        }
        revision &+= 1
        let pending = Pending(handle: handle, source: source, revision: revision)
        latest[handle.url] = pending
        // Backup and replacement both execute in this same sink; account
        // invalidate cannot finish and purge the directory between these steps.
        let result = await writer.writeImmediately(pending, for: handle.url, revision: revision)
        if result == .written, latest[handle.url]?.revision == pending.revision { latest[handle.url] = nil }
        return result == .written && !closedSlots.contains(handle.slot) && epochs[handle.slot] == handle.epoch
    }
}
