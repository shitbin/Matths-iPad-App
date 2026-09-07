import CryptoKit
import Foundation

/// A value snapshot can carry a PencilKit drawing without serializing its bytes
/// on the main actor. The builder owns an immutable drawing copy; the revisioned
/// disk actor resolves it once after debounce (or immediately for a flush).
final class PracticeWorkspaceDraftSource: @unchecked Sendable {
    let id = UUID()
    private let lock = NSLock()
    private let build: @Sendable () throws -> PracticeWorkspaceDraft
    private var cached: Result<PracticeWorkspaceDraft, Error>?
    init(build: @escaping @Sendable () throws -> PracticeWorkspaceDraft) { self.build = build }
    func resolve() throws -> PracticeWorkspaceDraft {
        try lock.withLock {
            if let cached { return try cached.get() }
            let result = Result { try build() }
            cached = result
            return try result.get()
        }
    }
}

/// Local workspace only. It contains no score, submitted/passed marker, unlock,
/// official attempt ID or sync event and can never become an assessment receipt.
struct PracticeWorkspaceDraft: Codable, Equatable, Sendable {
    static let namespace = "practice-workspace-drafts-v1"
    static let maximumDrawingBytes = 4 * 1_024 * 1_024
    static let maximumEncodedBytes = 6 * 1_024 * 1_024
    static let maximumAnswerBytes = 8_192

    let schemaVersion: Int
    let fingerprint: String
    let answer: String
    let pickedKey: String?
    let drawingData: Data
    let drawingSHA256: String
    let zoom: Double
    let updatedAt: Date

    init(fingerprint: String, answer: String, pickedKey: String?, drawingData: Data,
         zoom: Double, updatedAt: Date = Date()) throws {
        self.schemaVersion = 1
        self.fingerprint = fingerprint
        self.answer = answer
        self.pickedKey = pickedKey
        self.drawingData = drawingData
        self.drawingSHA256 = Self.digest(drawingData)
        self.zoom = zoom
        self.updatedAt = updatedAt
        try validate(expectedFingerprint: fingerprint)
    }

    enum ValidationError: Error { case invalid, tooLarge }

    func validate(expectedFingerprint: String) throws {
        guard schemaVersion == 1, fingerprint == expectedFingerprint,
              Self.isFingerprint(fingerprint), zoom.isFinite, (0.25...8).contains(zoom),
              pickedKey.map({ !$0.isEmpty && $0.utf8.count <= 128 }) ?? true else {
            throw ValidationError.invalid
        }
        guard answer.utf8.count <= Self.maximumAnswerBytes,
              drawingData.count <= Self.maximumDrawingBytes else { throw ValidationError.tooLarge }
        guard drawingSHA256 == Self.digest(drawingData) else { throw ValidationError.invalid }
    }

    /// Stable across rotation and relaunch, but changes with source content even
    /// when the server/generator reuses an ID. Include diagram/answer revision in
    /// revisionHint; the original correct answer is never stored in the draft.
    static func questionFingerprint(id: String, typeKey: String, statement: String,
                                    choices: [String]?, revisionHint: String = "") -> String {
        let parts = ["practice-workspace-v1", id, typeKey, statement,
                     choices == nil ? "free-response" : "multiple-choice"]
            + (choices ?? []) + [revisionHint]
        return digest((try? JSONEncoder().encode(parts)) ?? Data())
    }

    static func isFingerprint(_ value: String) -> Bool {
        value.count == 64 && value.allSatisfy { $0.isHexDigit && !$0.isUppercase }
    }

    private static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

enum PracticeWorkspaceDraftDisk {
    enum LoadResult: Sendable { case missing, loaded(PracticeWorkspaceDraft), unreadable }

    static func load(at url: URL, fingerprint: String) -> LoadResult {
        let fm = FileManager.default
        let attrs: [FileAttributeKey: Any]
        do { attrs = try fm.attributesOfItem(atPath: url.path) }
        catch { return isMissingFile(error) ? .missing : .unreadable }
        guard attrs[.type] as? FileAttributeType == .typeRegular,
              let size = attrs[.size] as? NSNumber,
              size.int64Value > 0, size.int64Value <= Int64(PracticeWorkspaceDraft.maximumEncodedBytes),
              let data = try? Data(contentsOf: url, options: .mappedIfSafe),
              let draft = try? JSONDecoder().decode(PracticeWorkspaceDraft.self, from: data),
              (try? draft.validate(expectedFingerprint: fingerprint)) != nil else { return .unreadable }
        return .loaded(draft)
    }

    static func save(_ draft: PracticeWorkspaceDraft, at url: URL) -> Bool {
        do {
            try draft.validate(expectedFingerprint: draft.fingerprint)
            let data = try JSONEncoder().encode(draft)
            guard data.count <= PracticeWorkspaceDraft.maximumEncodedBytes else { return false }
            let directory = url.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try ProtectedFileWriter.write(data, to: url)
            var protected = directory
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try? protected.setResourceValues(values)
            return true
        } catch { return false }
    }

    /// Called only by the repository's serialized writer after explicit user
    /// recovery. The original is never replaced until a byte-verified backup is
    /// present. Any copy/hash/storage failure leaves the original untouched.
    static func preserveOriginal(at url: URL) throws {
        let fm = FileManager.default
        let originalAttributes: [FileAttributeKey: Any]
        do { originalAttributes = try fm.attributesOfItem(atPath: url.path) }
        catch {
            if isMissingFile(error) { return }
            throw error
        }
        guard originalAttributes[.type] as? FileAttributeType == .typeRegular else {
            throw PracticeWorkspaceDraft.ValidationError.invalid
        }
        let backupDirectory = url.deletingLastPathComponent().appendingPathComponent("preserved-originals", isDirectory: true)
        try fm.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
        let token = UUID().uuidString
        let staging = backupDirectory.appendingPathComponent("\(token).part")
        let destination = backupDirectory.appendingPathComponent("\(url.deletingPathExtension().lastPathComponent)-\(token).json")
        defer { try? fm.removeItem(at: staging) }
        try fm.copyItem(at: url, to: staging)
        let sourceHash = try digestFile(url)
        guard try digestFile(staging) == sourceHash else { throw PracticeWorkspaceDraft.ValidationError.invalid }
        let currentAttributes = try fm.attributesOfItem(atPath: url.path)
        guard (originalAttributes[.size] as? NSNumber) == (currentAttributes[.size] as? NSNumber),
              (originalAttributes[.modificationDate] as? Date) == (currentAttributes[.modificationDate] as? Date),
              (originalAttributes[.systemFileNumber] as? NSNumber) == (currentAttributes[.systemFileNumber] as? NSNumber) else {
            throw PracticeWorkspaceDraft.ValidationError.invalid
        }
        try fm.moveItem(at: staging, to: destination)
        try? fm.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: destination.path)
    }

    private static func digestFile(_ url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hash = SHA256()
        while let chunk = try handle.read(upToCount: 1_048_576), !chunk.isEmpty {
            try Task.checkCancellation()
            hash.update(data: chunk)
        }
        return hash.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private static func isMissingFile(_ error: Error) -> Bool {
        let value = error as NSError
        return value.domain == NSCocoaErrorDomain
            && [CocoaError.fileNoSuchFile.rawValue, CocoaError.fileReadNoSuchFile.rawValue].contains(value.code)
    }
}
