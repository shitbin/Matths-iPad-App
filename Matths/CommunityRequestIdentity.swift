import Foundation
import CryptoKit

enum CommunityRequestFingerprint {
    static func make(operation: String, fields: [String: String], attachments: [CommunityMultipartBody.Attachment],
                     validateOwner: () throws -> Void = {}) throws -> String {
        var material = fields
        material["operation"] = operation
        material["attachmentCount"] = String(attachments.count)
        var total = 0
        for (index, attachment) in attachments.enumerated() {
            try validateOwner(); try Task.checkCancellation()
            let metadata = try attachment.url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey])
            guard metadata.isRegularFile == true, let expected = metadata.fileSize, expected >= 0,
                  expected <= attachment.maximumBytes else { throw CommunityMultipartBody.PreparationError.sizeLimit }
            var digest = SHA256(); var bytes = 0
            let handle = try FileHandle(forReadingFrom: attachment.url)
            defer { try? handle.close() }
            while let chunk = try handle.read(upToCount: 256 * 1024), !chunk.isEmpty {
                try validateOwner(); try Task.checkCancellation()
                bytes += chunk.count; total += chunk.count
                guard bytes <= attachment.maximumBytes, total <= CommunityMultipartBody.maximumTotalFileBytes else {
                    throw CommunityMultipartBody.PreparationError.sizeLimit
                }
                digest.update(data: chunk)
            }
            let after = try attachment.url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
            guard bytes == expected, after.fileSize == expected, after.contentModificationDate == metadata.contentModificationDate else {
                throw CommunityMultipartBody.PreparationError.changedAttachment
            }
            material["attachment.\(index).name"] = attachment.filename
            material["attachment.\(index).mime"] = attachment.mimeType
            material["attachment.\(index).bytes"] = String(bytes)
            material["attachment.\(index).sha256"] = digest.finalize().map { String(format: "%02x", $0) }.joined()
        }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        return SHA256.hash(data: try encoder.encode(material)).map { String(format: "%02x", $0) }.joined()
    }
}

struct CommunityRequestLedger: Codable, Equatable {
    struct Entry: Codable, Equatable {
        enum Mode: String, Codable { case keyed, legacy }
        let mode: Mode
        let requestID: String?
        var operationScope: String? = nil
    }
    var version = 1
    let slot: String
    var entries: [String: Entry] = [:]
    var isValid: Bool {
        version == 1 && !slot.isEmpty && entries.count <= 1024 && entries.allSatisfy { key, entry in
            key.count == 64 && key.allSatisfy { "0123456789abcdef".contains($0) }
                && (entry.mode == .legacy ? entry.requestID == nil : entry.requestID.map(Self.validRequestID) == true)
                && (entry.operationScope.map { $0.count == 64 && $0.allSatisfy { "0123456789abcdef".contains($0) } } ?? true)
        }
    }
    static func validRequestID(_ value: String) -> Bool {
        (16...128).contains(value.utf8.count) && value.utf8.allSatisfy {
            (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) || $0 == 45 || $0 == 95
        }
    }
    static func key(origin: String, operationID: String, fingerprint: String) -> String {
        let fields = [origin, operationID, fingerprint]
        let encoded = (try? JSONEncoder().encode(fields)) ?? Data()
        return SHA256.hash(data: encoded).map { String(format: "%02x", $0) }.joined()
    }
    mutating func reserve(key: String, supported: Bool, operationScope: String? = nil) throws -> Entry {
        if var existing = entries[key] {
            if existing.operationScope == nil { existing.operationScope = operationScope; entries[key] = existing }
            return existing
        }
        // Never evict an uncertain operation just to make room for a new one.
        guard entries.count < 1024 else { throw CocoaError(.fileWriteOutOfSpace) }
        let entry = Entry(mode: supported ? .keyed : .legacy, requestID: supported ? UUID().uuidString : nil, operationScope: operationScope)
        entries[key] = entry
        return entry
    }
}

actor CommunityRequestIdentity {
    static let shared = CommunityRequestIdentity()
    static let fileName = "community-request-ledger-v1.json"

    /// The mode is also durable: a legacy request whose response was lost cannot
    /// become a "new" keyed operation merely because a deployment was upgraded.
    func requestID(owner: MobileRequestOwner, operationID: String, fingerprint: String,
                   capability: MobileFeatureCapabilities) throws -> String? {
        try owner.validate()
        guard CommunityRequestLedger.validRequestID(operationID) else { throw ServerAPI.mobileContractError() }
        let path = DataScope.url(Self.fileName, for: owner.slot)
        var ledger: CommunityRequestLedger
        if FileManager.default.fileExists(atPath: path.path) {
            let metadata = try path.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
            guard metadata.isRegularFile == true, (metadata.fileSize ?? Int.max) <= 524_288 else { throw CocoaError(.fileReadCorruptFile) }
            ledger = try JSONDecoder().decode(CommunityRequestLedger.self, from: Data(contentsOf: path))
            guard ledger.isValid, ledger.slot == owner.slot else { throw CocoaError(.fileReadCorruptFile) }
        } else { ledger = .init(slot: owner.slot) }
        let key = CommunityRequestLedger.key(origin: owner.origin, operationID: operationID, fingerprint: fingerprint)
        let scope = CommunityRequestLedger.key(origin: owner.origin, operationID: operationID, fingerprint: "")
        let entry = try ledger.reserve(key: key, supported: capability.communityIdempotency, operationScope: scope)
        if entry.mode == .keyed && !capability.communityIdempotency {
            throw ServerAPIError(message: "이 요청은 중복 방지 번호로 전송한 기록이 있습니다. 서버의 중복 방지 지원이 복구되면 같은 번호로 다시 확인할 수 있습니다. 새 글로 바꾸어 재전송하지 않습니다.",
                                 code: "COMMUNITY_KEYED_RETRY_PAUSED")
        }
        guard ledger.isValid else { throw CocoaError(.coderInvalidValue) }
        try owner.validate()
        let encoded = try JSONEncoder().encode(ledger)
        #if os(iOS)
        try encoded.write(to: path, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        #else
        try encoded.write(to: path, options: [.atomic])
        #endif
        return entry.requestID
    }

    /// Call only after a successful receipt AND the old submitted draft has
    /// durably been cleared. Merely receiving HTTP 201 is not enough: the UI may
    /// be cancelled before it acknowledges that response and retries on launch.
    func finishAcknowledgedDraft(owner: MobileRequestOwner, operationID: String) throws {
        try owner.validate()
        let path = DataScope.url(Self.fileName, for: owner.slot)
        guard FileManager.default.fileExists(atPath: path.path) else { return }
        let metadata = try path.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        guard metadata.isRegularFile == true, (metadata.fileSize ?? Int.max) <= 524_288 else { throw CocoaError(.fileReadCorruptFile) }
        var ledger = try JSONDecoder().decode(CommunityRequestLedger.self, from: Data(contentsOf: path))
        guard ledger.isValid, ledger.slot == owner.slot else { throw CocoaError(.fileReadCorruptFile) }
        let scope = CommunityRequestLedger.key(origin: owner.origin, operationID: operationID, fingerprint: "")
        ledger.entries = ledger.entries.filter { $0.value.operationScope != scope }
        try owner.validate()
        let data = try JSONEncoder().encode(ledger)
        #if os(iOS)
        try data.write(to: path, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        #else
        try data.write(to: path, options: [.atomic])
        #endif
    }
}
