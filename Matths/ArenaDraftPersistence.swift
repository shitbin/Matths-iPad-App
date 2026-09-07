import CryptoKit
import Foundation

enum ArenaDraftStorageError: Error { case damaged, outsideAccount, invalid, closed }

enum ArenaDraftDisk {
    static let maximumBytes = 32 * 1_024 * 1_024
    static func read(_ url: URL) throws -> Data? {
        let attributes: [FileAttributeKey: Any]
        do { attributes = try FileManager.default.attributesOfItem(atPath: url.path) }
        catch let error as CocoaError where error.code == .fileReadNoSuchFile || error.code == .fileNoSuchFile { return nil }
        guard attributes[.type] as? FileAttributeType == .typeRegular,
              let size = attributes[.size] as? NSNumber, size.int64Value > 0,
              size.int64Value <= Int64(maximumBytes) else { throw ArenaDraftStorageError.damaged }
        return try Data(contentsOf: url, options: .mappedIfSafe)
    }
    static func preserveOriginal(_ url: URL) throws {
        let attributes: [FileAttributeKey: Any]
        do { attributes = try FileManager.default.attributesOfItem(atPath: url.path) }
        catch let error as CocoaError where error.code == .fileReadNoSuchFile || error.code == .fileNoSuchFile { return }
        guard attributes[.type] as? FileAttributeType == .typeRegular,
              let size = attributes[.size] as? NSNumber, size.int64Value >= 0,
              size.int64Value <= Int64(maximumBytes) else { throw ArenaDraftStorageError.damaged }
        let original = try Data(contentsOf: url, options: .mappedIfSafe)
        let folder = url.deletingLastPathComponent().appendingPathComponent("arena-draft-preserved-originals", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let backup = folder.appendingPathComponent(url.lastPathComponent + "." + UUID().uuidString + ".original")
        try ProtectedFileWriter.write(original, to: backup)
        let verified = try Data(contentsOf: backup, options: .mappedIfSafe)
        let unchanged = try Data(contentsOf: url, options: .mappedIfSafe)
        guard SHA256.hash(data: verified) == SHA256.hash(data: original),
              SHA256.hash(data: unchanged) == SHA256.hash(data: original) else {
            throw ArenaDraftStorageError.damaged
        }
    }
    static func preserveWorkingCopy(_ data: Data, beside url: URL) throws {
        guard data.count <= maximumBytes else { throw ArenaDraftStorageError.invalid }
        let folder = url.deletingLastPathComponent().appendingPathComponent("arena-draft-preserved-originals", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let backup = folder.appendingPathComponent(url.lastPathComponent + ".working-" + UUID().uuidString + ".original")
        try ProtectedFileWriter.write(data, to: backup)
        let verified = try Data(contentsOf: backup, options: .mappedIfSafe)
        guard SHA256.hash(data: verified) == SHA256.hash(data: data) else { throw ArenaDraftStorageError.damaged }
    }
}

/// The captured immutable Codable value / drawing producer is encoded only by
/// the serial disk sink. The lock also protects an occasional read of a pending
/// lazy drawing when the same board is reopened before its debounce fires.
final class ArenaDraftSnapshot: @unchecked Sendable {
    let value: Any?
    private let lock = NSLock()
    private let encoder: @Sendable () throws -> Data
    let validateExisting: @Sendable (Data) throws -> Void
    private var cached: Result<Data, Error>?
    init<Value: Codable & Sendable>(_ value: Value, validate: @escaping @Sendable (Value) throws -> Void) {
        self.value = value
        encoder = { try validate(value); return try JSONEncoder().encode(value) }
        validateExisting = { try validate(JSONDecoder().decode(Value.self, from: $0)) }
    }
    init<Value: Codable & Sendable>(build: @escaping @Sendable () throws -> Value,
                                    validate: @escaping @Sendable (Value) throws -> Void) {
        value = nil
        encoder = { let value = try build(); try validate(value); return try JSONEncoder().encode(value) }
        validateExisting = { try validate(JSONDecoder().decode(Value.self, from: $0)) }
    }
    init(raw data: Data, validate: @escaping @Sendable (Data) throws -> Void) {
        value = data
        encoder = { try validate(data); return data }
        validateExisting = validate
    }
    func encoded() throws -> Data {
        try lock.withLock {
            if let cached { return try cached.get() }
            let result = Result { try encoder() }
            cached = result
            return try result.get()
        }
    }
}

@MainActor enum ArenaDraftPersistence {
    static let failureNotification = Notification.Name("kr.matths.arenaDraftPersistenceFailed")
    private struct Pending: Sendable {
        let slot: String
        let revision: UInt64
        let snapshot: ArenaDraftSnapshot?
        let recovery: Bool
        var workingCopy: ArenaDraftSnapshot? = nil
    }
    private static var revision: UInt64 = 0
    private static var epochs: [String: UUID] = [:]
    private static var closedSlots = Set<String>()
    private static var keysBySlot: [String: Set<URL>] = [:]
    private static var pending: [URL: Pending] = [:]
    private static var blocked = Set<URL>()
    private static var recovering: [URL: UUID] = [:]
    private static let writer = DebouncedSnapshotWriter<URL, Pending>(debounceNanoseconds: 180_000_000) { url, item in
        do {
            if let snapshot = item.snapshot {
                let data = try snapshot.encoded()
                guard data.count <= ArenaDraftDisk.maximumBytes else { throw ArenaDraftStorageError.invalid }
                if item.recovery {
                    try ArenaDraftDisk.preserveOriginal(url)
                    if let workingCopy = item.workingCopy { try ArenaDraftDisk.preserveWorkingCopy(workingCopy.encoded(), beside: url) }
                }
                else if let existing = try ArenaDraftDisk.read(url) {
                    do { try snapshot.validateExisting(existing) }
                    catch { throw ArenaDraftStorageError.damaged }
                }
                try ProtectedFileWriter.write(data, to: url)
            } else if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
            Task { @MainActor in
                if pending[url]?.revision == item.revision { pending[url] = nil }
            }
            return true
        } catch {
            let damaged = (error as? ArenaDraftStorageError).map { if case .damaged = $0 { return true }; return false } ?? false
            Task { @MainActor in
                guard pending[url]?.revision == item.revision else { return }
                if damaged { blocked.insert(url) }
                NotificationCenter.default.post(name: failureNotification, object: url,
                    userInfo: ["accountSlot": item.slot])
            }
            return false
        }
    }

    static func activate(slot: String) { closedSlots.remove(slot); epochs[slot] = UUID() }
    static func resourceURL(_ name: String, slot: String) throws -> URL {
        guard !closedSlots.contains(slot) else { throw ArenaDraftStorageError.closed }
        guard !name.isEmpty, !name.contains("/"), !name.contains("\\"), name != ".", name != ".." else {
            throw ArenaDraftStorageError.outsideAccount
        }
        return DataScope.url(name, for: slot)
    }
    private static func epoch(for slot: String) -> UUID {
        if let value = epochs[slot] { return value }
        let value = UUID(); epochs[slot] = value; return value
    }
    static func needsRecovery(_ url: URL) -> Bool { blocked.contains(url) }
    static func markDamaged(_ url: URL, slot: String) {
        guard owns(url, slot: slot) else { return }
        blocked.insert(url)
        revision &+= 1; let cutoff = revision
        Task { await writer.invalidate([url], through: cutoff) }
    }
    static func owns(_ url: URL, slot: String) -> Bool {
        guard !closedSlots.contains(slot) else { return false }
        let directory = DataScope.directory(for: slot).standardizedFileURL.resolvingSymlinksInPath()
        let parent = url.deletingLastPathComponent().standardizedFileURL.resolvingSymlinksInPath()
        return url.isFileURL && parent == directory
    }
    static func load<Value: Codable & Sendable>(_ type: Value.Type, at url: URL, slot: String,
                                               validate: (Value) throws -> Void) throws -> Value? {
        guard owns(url, slot: slot) else { throw ArenaDraftStorageError.outsideAccount }
        guard !closedSlots.contains(slot), recovering[url] == nil else { throw ArenaDraftStorageError.closed }
        guard !blocked.contains(url) else { throw ArenaDraftStorageError.damaged }
        keysBySlot[slot, default: []].insert(url)
        do {
            if let item = pending[url], let snapshot = item.snapshot {
                let value = try (snapshot.value as? Value) ?? JSONDecoder().decode(Value.self, from: snapshot.encoded())
                try validate(value); return value
            }
            guard let data = try ArenaDraftDisk.read(url) else { return nil }
            let value = try JSONDecoder().decode(type, from: data)
            try validate(value)
            return value
        } catch {
            markDamaged(url, slot: slot)
            throw error
        }
    }
    static func schedule(_ snapshot: ArenaDraftSnapshot, at url: URL, slot: String) throws {
        guard owns(url, slot: slot) else { throw ArenaDraftStorageError.outsideAccount }
        guard !closedSlots.contains(slot), recovering[url] == nil else { throw ArenaDraftStorageError.closed }
        guard !blocked.contains(url) else { throw ArenaDraftStorageError.damaged }
        revision &+= 1
        let item = Pending(slot: slot, revision: revision, snapshot: snapshot, recovery: false)
        keysBySlot[slot, default: []].insert(url); pending[url] = item
        Task { await writer.schedule(item, for: url, revision: item.revision) }
    }
    static func flush(slot: String) async -> Bool {
        guard !closedSlots.contains(slot) else { return false }
        let owner = epoch(for: slot)
        while true {
            guard epochs[slot] == owner, !closedSlots.contains(slot) else { return false }
            let values = pending.filter { $0.value.slot == slot }
            if values.isEmpty { return true }
            var writes: [(key: URL, payload: Pending, revision: UInt64)] = []
            for (url, old) in values {
                guard !blocked.contains(url), recovering[url] == nil else { return false }
                revision &+= 1
                let item = Pending(slot: slot, revision: revision, snapshot: old.snapshot, recovery: old.recovery, workingCopy: old.workingCopy)
                pending[url] = item; writes.append((url, item, revision))
            }
            let results = await writer.writeImmediately(writes)
            guard epochs[slot] == owner, !closedSlots.contains(slot) else { return false }
            for write in writes where results[write.key] == .written && pending[write.key]?.revision == write.revision {
                pending[write.key] = nil
            }
            if results.values.contains(.ioFailed) || Task.isCancelled { return false }
        }
    }
    static func invalidate(slot: String) async {
        closedSlots.insert(slot)
        epochs[slot] = UUID()
        revision &+= 1
        let keys = keysBySlot[slot] ?? []
        for key in keys { pending[key] = nil; blocked.remove(key); recovering[key] = nil }
        await writer.invalidate(keys, through: revision)
    }
    static func recover(_ snapshot: ArenaDraftSnapshot, at url: URL, slot: String) async -> Bool {
        guard owns(url, slot: slot), !closedSlots.contains(slot), recovering[url] == nil else { return false }
        let owner = epoch(for: slot)
        keysBySlot[slot, default: []].insert(url)
        let recoveryID = UUID()
        recovering[url] = recoveryID
        defer { if recovering[url] == recoveryID { recovering[url] = nil } }
        let workingCopy = pending[url]?.snapshot
        revision &+= 1; pending[url] = nil
        await writer.invalidate([url], through: revision)
        guard epochs[slot] == owner, !closedSlots.contains(slot) else { return false }
        revision &+= 1
        let item = Pending(slot: slot, revision: revision, snapshot: snapshot, recovery: true, workingCopy: workingCopy)
        pending[url] = item
        let result = await writer.writeImmediately(item, for: url, revision: item.revision)
        if result == .written, epochs[slot] == owner, !closedSlots.contains(slot) {
            if pending[url]?.revision == item.revision { pending[url] = nil }
            blocked.remove(url)
        }
        return result == .written && epochs[slot] == owner && !closedSlots.contains(slot)
    }
    static func remove(at url: URL, slot: String) async -> Bool {
        guard owns(url, slot: slot), !closedSlots.contains(slot), recovering[url] == nil else { return false }
        let owner = epoch(for: slot)
        revision &+= 1
        let item = Pending(slot: slot, revision: revision, snapshot: nil, recovery: false)
        pending[url] = item; keysBySlot[slot, default: []].insert(url)
        let result = await writer.writeImmediately(item, for: url, revision: item.revision)
        if result == .written, epochs[slot] == owner, !closedSlots.contains(slot) {
            if pending[url]?.revision == item.revision { pending[url] = nil }
            blocked.remove(url)
        }
        return result == .written && epochs[slot] == owner && !closedSlots.contains(slot)
    }
}
