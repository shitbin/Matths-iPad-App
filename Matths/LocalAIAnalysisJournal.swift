import CryptoKit
import Foundation

/// Successful, parsed stage objects only. No native KV state, partial token
/// stream or unvalidated model draft is persisted. Each record is tied to the
/// original bytes, model, prompt and policy version and must pass the caller's
/// output validator again after loading. It never changes official grades.
struct LocalAIAnalysisJournal: Sendable {
    static let policyVersion = "sheet-json-checkpoints-2026-09-07-v1"
    static let maximumPayloadBytes = 128 * 1_024
    static let maximumEntries = 128
    let directory: URL
    private let image: URL
    private let sourceSHA256: String
    private let identity: ModelIntegrityReceipt.Identity

    private struct Record: Codable {
        let version: String
        let sourceSHA256: String
        let requestKey: String
        let payloadSHA256: String
        let payload: Data
    }

    init?(image: URL) {
        guard image.lastPathComponent == "source.jpg",
              image.deletingLastPathComponent().lastPathComponent == "local-ai-pending-sheet",
              let identity = try? ModelIntegrityReceipt.Identity.read(at: image),
              (1...50_000_000).contains(identity.bytes),
              let data = try? Data(contentsOf: image, options: .mappedIfSafe) else { return nil }
        self.image = image
        self.identity = identity
        self.sourceSHA256 = Self.digest(data)
        self.directory = image.deletingLastPathComponent().appendingPathComponent("checkpoints-v1", isDirectory: true)
    }

    func key(model: String, prompt: String, maxTokens: Int, imageInput: Bool, imageDigest: String? = nil) -> String {
        // JSON encoding avoids delimiter collisions in untrusted problem text.
        let fields = [Self.policyVersion, sourceSHA256, model, String(maxTokens), imageInput ? "vision" : "text", imageDigest ?? "", prompt]
        return Self.digest((try? JSONEncoder().encode(fields)) ?? Data())
    }

    static func imageDigest(at path: String) -> String? {
        let url = URL(fileURLWithPath: path)
        guard let identity = try? ModelIntegrityReceipt.Identity.read(at: url),
              (1...50_000_000).contains(identity.bytes),
              let data = try? Data(contentsOf: url, options: .mappedIfSafe) else { return nil }
        return digest(data)
    }

    func load(key: String) -> Data? {
        guard sourceUnchanged,
              let attributes = try? FileManager.default.attributesOfItem(atPath: recordURL(key).path),
              let size = attributes[.size] as? NSNumber,
              size.intValue <= Self.maximumPayloadBytes * 2,
              let data = try? Data(contentsOf: recordURL(key)),
              let record = try? JSONDecoder().decode(Record.self, from: data),
              record.version == Self.policyVersion, record.sourceSHA256 == sourceSHA256,
              record.requestKey == key, record.payload.count <= Self.maximumPayloadBytes,
              Self.digest(record.payload) == record.payloadSHA256 else { return nil }
        return record.payload
    }

    func save(_ payload: Data, key: String) throws {
        guard sourceUnchanged, payload.count <= Self.maximumPayloadBytes,
              (try? JSONSerialization.jsonObject(with: payload)) is [String: Any] else { return }
        let fm = FileManager.default
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        let files = (try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        guard files.count < Self.maximumEntries || fm.fileExists(atPath: recordURL(key).path) else { return }
        let record = Record(version: Self.policyVersion, sourceSHA256: sourceSHA256,
                            requestKey: key, payloadSHA256: Self.digest(payload), payload: payload)
        try ProtectedFileWriter.write(JSONEncoder().encode(record), to: recordURL(key))
        var protectedDirectory = directory
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? protectedDirectory.setResourceValues(values)
    }

    private var sourceUnchanged: Bool {
        guard let current = try? ModelIntegrityReceipt.Identity.read(at: image) else { return false }
        return current == identity
    }

    private func recordURL(_ key: String) -> URL {
        // Public methods remain confined even if called with a malformed key.
        directory.appendingPathComponent(Self.digest(Data(key.utf8))).appendingPathExtension("json")
    }

    private static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
