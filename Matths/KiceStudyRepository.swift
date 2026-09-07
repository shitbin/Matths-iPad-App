import Foundation

@MainActor enum KiceStudyRepository {
    static let failedNotification = Notification.Name("kr.matths.kiceStudySaveFailed")
    struct Handle: Hashable, Sendable { let slot: String; let epoch: UUID; let url: URL }
    private struct Pending: Sendable { let handle: Handle; let archive: KiceStudyArchive; let revision: UInt64; var preserveOriginal = false }
    private static var revision: UInt64 = 0
    private static var epochs: [String: UUID] = [:]
    private static var closed = Set<String>()
    private static var handles: [String: Handle] = [:]
    private static var readable = Set<URL>()
    private static var recovering = Set<URL>()
    private static var pending: [URL: Pending] = [:]
    private static var latestSnapshots: [URL: KiceStudyArchive] = [:]
    private static var durableSnapshots: [URL: KiceStudyArchive] = [:]
    private static var durableWriteRevisions: [URL: UInt64] = [:]
    private static let writer = DebouncedSnapshotWriter<URL, Pending>(debounceNanoseconds: 150_000_000) { url, value in
        let success: Bool
        do {
            if value.preserveOriginal { try PracticeWorkspaceDraftDisk.preserveOriginal(at: url) }
            success = KiceStudyDisk.write(value.archive, at: url)
        } catch { success = false }
        Task { @MainActor in
            guard !closed.contains(value.handle.slot), epochs[value.handle.slot] == value.handle.epoch else { return }
            if success {
                acknowledge(value)
                if pending[url]?.revision == value.revision { pending[url] = nil }
            }
            else if !success, pending[url]?.revision == value.revision {
                NotificationCenter.default.post(name: failedNotification, object: value.handle)
            }
        }
        return success
    }
    private static func acknowledge(_ value: Pending) {
        let url = value.handle.url
        guard !closed.contains(value.handle.slot), epochs[value.handle.slot] == value.handle.epoch,
              value.revision >= (durableWriteRevisions[url] ?? 0) else { return }
        if !value.preserveOriginal, let durable = durableSnapshots[url], durable.revision > value.archive.revision { return }
        durableWriteRevisions[url] = value.revision
        durableSnapshots[url] = value.archive
    }
    private static func register(_ archive: KiceStudyArchive, for handle: Handle) -> Bool {
        guard accepts(handle), readable.contains(handle.url), archive.slot == handle.slot else { return false }
        if let previous = latestSnapshots[handle.url] {
            guard archive.revision >= previous.revision else { return false }
            guard archive.revision != previous.revision || archive == previous else { return false }
        }
        latestSnapshots[handle.url] = archive
        return true
    }
    static func activate(slot: String) {
        closed.remove(slot)
        let epoch = UUID(); epochs[slot] = epoch
        if let old = handles[slot] {
            let handle = Handle(slot: slot, epoch: epoch, url: old.url)
            handles[slot] = handle
            // Same-account re-auth can activate without a changed-slot flush.
            // Transfer the newest pending value, while invalidating old handles.
            if let previous = pending[old.url] {
                revision &+= 1
                let value = Pending(handle: handle, archive: previous.archive, revision: revision)
                pending[old.url] = value
                Task { await writer.schedule(value, for: handle.url, revision: value.revision) }
            }
        }
    }
    static func handle(slot: String) -> Handle? {
        guard !closed.contains(slot), !slot.isEmpty, slot.utf8.count <= 120,
              slot.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }) else { return nil }
        if let handle = handles[slot] { return handle }
        let epoch = epochs[slot] ?? UUID(); epochs[slot] = epoch
        let handle = Handle(slot: slot, epoch: epoch, url: DataScope.url(KiceStudyArchive.filename, for: slot))
        handles[slot] = handle
        return handle
    }
    static func accepts(_ handle: Handle) -> Bool { !closed.contains(handle.slot) && epochs[handle.slot] == handle.epoch && !recovering.contains(handle.url) }
    static func load(_ handle: Handle) async -> KiceStudyDisk.Loaded {
        guard accepts(handle) else { return .unreadable }
        if let value = pending[handle.url], value.handle == handle {
            guard await flush(slot: handle.slot) else { return .unreadable }
        }
        var value = await Task.detached(priority: .utility) { KiceStudyDisk.load(at: handle.url, slot: handle.slot) }.value
        guard accepts(handle), !Task.isCancelled else { return .unreadable }
        if let newest = pending[handle.url], newest.handle == handle {
            guard await flush(slot: handle.slot) else { return .unreadable }
            return await load(handle)
        }
        // A newer write may have completed and removed `pending` while this
        // detached read held an older file image. Keep the newer durable value;
        // otherwise a late read -> UI checkpoint could rewind the disk again.
        if case .archive(let disk) = value {
            if let latest = latestSnapshots[handle.url], latest.revision > disk.revision {
                guard let durable = durableSnapshots[handle.url], durable.revision >= latest.revision else { return .unreadable }
                value = .archive(durable)
            } else if let latest = latestSnapshots[handle.url], latest.revision == disk.revision, latest != disk {
                readable.remove(handle.url)
                return .unreadable
            }
        } else if case .missing = value, latestSnapshots[handle.url] != nil {
            readable.remove(handle.url)
            return .unreadable
        }
        switch value {
        case .unreadable: readable.remove(handle.url)
        case .missing: readable.insert(handle.url)
        case .archive(let archive):
            readable.insert(handle.url)
            latestSnapshots[handle.url] = archive
            durableSnapshots[handle.url] = archive
        }
        return value
    }
    @discardableResult static func schedule(_ archive: KiceStudyArchive, for handle: Handle) -> Bool {
        guard register(archive, for: handle) else { return false }
        revision &+= 1
        let value = Pending(handle: handle, archive: archive, revision: revision)
        pending[handle.url] = value
        Task { await writer.schedule(value, for: handle.url, revision: value.revision) }
        return true
    }
    static func save(_ archive: KiceStudyArchive, for handle: Handle) async -> Bool {
        guard register(archive, for: handle) else { return false }
        revision &+= 1
        let value = Pending(handle: handle, archive: archive, revision: revision)
        pending[handle.url] = value
        let outcome = await writer.writeImmediately(value, for: handle.url, revision: value.revision)
        if outcome == .written {
            acknowledge(value)
            if pending[handle.url]?.revision == value.revision { pending[handle.url] = nil }
        }
        if outcome == .superseded, accepts(handle) {
            // A lifecycle flush can commit this exact snapshot with a higher
            // writer revision before this waiter arrives. Confirm bytes on disk
            // rather than incorrectly report a healthy save as a storage error.
            let loaded = await Task.detached(priority: .utility) { KiceStudyDisk.load(at: handle.url, slot: handle.slot) }.value
            if case .archive(let stored) = loaded { return stored == archive && accepts(handle) }
        }
        return outcome == .written && accepts(handle)
    }
    static func flush(slot: String) async -> Bool {
        guard !closed.contains(slot) else { return false }
        while let handle = handles[slot], let value = pending[handle.url] {
            guard accepts(handle), value.handle == handle else { return false }
            guard await save(value.archive, for: handle) else { return false }
        }
        return !closed.contains(slot)
    }
    static func invalidate(slot: String) async {
        closed.insert(slot); epochs[slot] = UUID(); revision &+= 1
        guard let handle = handles[slot] else { return }
        pending[handle.url] = nil; readable.remove(handle.url)
        latestSnapshots[handle.url] = nil; durableSnapshots[handle.url] = nil; durableWriteRevisions[handle.url] = nil
        await writer.invalidate([handle.url], through: revision)
    }
    static func resetPreservingOriginal(_ handle: Handle) async -> KiceStudyArchive? {
        guard accepts(handle) else { return nil }
        recovering.insert(handle.url)
        defer { recovering.remove(handle.url) }
        revision &+= 1; pending[handle.url] = nil
        await writer.invalidate([handle.url], through: revision)
        guard !closed.contains(handle.slot), epochs[handle.slot] == handle.epoch else { return nil }
        let archive = KiceStudyArchive(slot: handle.slot)
        revision &+= 1
        let value = Pending(handle: handle, archive: archive, revision: revision, preserveOriginal: true)
        let outcome = await writer.writeImmediately(value, for: handle.url, revision: value.revision)
        guard outcome == .written, !closed.contains(handle.slot), epochs[handle.slot] == handle.epoch else { return nil }
        acknowledge(value)
        latestSnapshots[handle.url] = archive
        readable.insert(handle.url)
        // Recovery starts a new lifetime. A file read captured before reset is
        // not allowed to return the preserved old archive after replacement.
        let epoch = UUID()
        epochs[handle.slot] = epoch
        handles[handle.slot] = Handle(slot: handle.slot, epoch: epoch, url: handle.url)
        return archive
    }
}
