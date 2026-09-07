import Foundation
import CryptoKit

/// Small user-authored drafts and stable submission identities. No passwords,
/// tokens or server entitlement decisions are stored here.
struct NativeServiceDraft: Codable, Equatable {
    var version = 1
    let slot: String
    let resource: String
    var fields: [String: String] = [:]
    var attachments: [String] = []
    var submissionID: String?
    var submittedFingerprint: String?

    mutating func ticket(for fields: [String: String]) -> String {
        let fingerprint = Self.fingerprint(fields)
        if fingerprint != submittedFingerprint || submissionID == nil {
            submissionID = UUID().uuidString
            submittedFingerprint = fingerprint
        }
        return submissionID ?? ""
    }
    static func fingerprint(_ fields: [String: String]) -> String {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let data = (try? encoder.encode(fields)) ?? Data()
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
    var isValid: Bool {
        version == 1 && !slot.isEmpty && !resource.isEmpty && fields.count <= 1000
            && fields.values.reduce(0, { $0 + $1.utf8.count }) <= 256_000
            && attachments.count <= 5
            && attachments.allSatisfy { !$0.isEmpty && !$0.contains("/") && !$0.contains("\\") && $0 != "." && $0 != ".." }
    }
}

enum NativeServiceDraftDisk {
    static func backup(slot: String, resource: String) throws {
        let source = try url(slot: slot, resource: resource)
        guard FileManager.default.fileExists(atPath: source.path) else { return }
        try FileManager.default.copyItem(at: source, to: source.deletingPathExtension().appendingPathExtension("backup-\(UUID().uuidString).json"))
    }
    static func url(slot: String, resource: String) throws -> URL {
        let folder = DataScope.url("native-service-drafts", for: slot)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let id = NativeServiceDraft.fingerprint(["resource": resource])
        return folder.appendingPathComponent(id + ".json")
    }
    static func load(slot: String, resource: String) throws -> NativeServiceDraft {
        let path = try url(slot: slot, resource: resource)
        return try load(from: path, slot: slot, resource: resource)
    }
    static func load(from path: URL, slot: String, resource: String) throws -> NativeServiceDraft {
        guard FileManager.default.fileExists(atPath: path.path) else { return .init(slot: slot, resource: resource) }
        let metadata = try path.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
        guard metadata.isRegularFile == true, (metadata.fileSize ?? Int.max) <= 512_000 else { throw CocoaError(.fileReadCorruptFile) }
        let value = try JSONDecoder().decode(NativeServiceDraft.self, from: Data(contentsOf: path))
        guard value.isValid, value.slot == slot, value.resource == resource else { throw CocoaError(.fileReadCorruptFile) }
        return value
    }
    static func save(_ value: NativeServiceDraft) throws {
        try save(value, to: url(slot: value.slot, resource: value.resource))
    }
    static func save(_ value: NativeServiceDraft, to path: URL) throws {
        guard value.isValid else { throw CocoaError(.coderInvalidValue) }
        let encoded = try JSONEncoder().encode(value)
        #if os(iOS)
        try encoded.write(to: path, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        #else
        try encoded.write(to: path, options: [.atomic])
        #endif
    }
}

/// Latest query wins independently of its completion order.
struct NativeServiceRequestRevision {
    private(set) var current = UUID()
    mutating func begin() -> UUID { current = UUID(); return current }
    func accepts(_ value: UUID) -> Bool { current == value }
}

enum NativeServiceInputPolicy {
    static let attachmentExtensions: Set<String> = ["pdf", "doc", "docx", "hwp", "hwpx", "xls", "xlsx", "ppt", "pptx", "zip", "png", "jpg", "jpeg", "webp", "heic"]
    static let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "webp", "heic"]
    static func allowsAttachment(extension ext: String, bytes: Int, totalBytes: Int) -> Bool {
        let ext = ext.lowercased()
        let limit = (imageExtensions.contains(ext) ? 10 : 25) * 1024 * 1024
        return attachmentExtensions.contains(ext) && bytes >= 0 && bytes <= limit && totalBytes >= bytes && totalBytes <= 50 * 1024 * 1024
    }
    static func isCommunityAttachmentPath(_ path: String, attachmentID: String) -> Bool {
        let parts = path.split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count == 8, parts[0].isEmpty, parts[1] == "api", parts[2] == "v1",
              parts[3] == "community", parts[4] == "posts", parts[6] == "attachments",
              String(parts[7]) == attachmentID else { return false }
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_")
        return [parts[5], parts[7]].allSatisfy { !$0.isEmpty && $0.unicodeScalars.allSatisfy(allowed.contains) }
    }
}
