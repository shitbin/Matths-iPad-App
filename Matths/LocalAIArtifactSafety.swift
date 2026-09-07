import Foundation

/// Emergency resource pressure is process-wide, unlike a user's per-request
/// cancellation. Native loader progress callbacks may read this off actor.
final class LocalAIResourceStopSignal: @unchecked Sendable {
    static let shared = LocalAIResourceStopSignal()
    private let lock = NSLock()
    private var requested = false
    var isRequested: Bool { lock.withLock { requested } }
    func set(_ value: Bool) { lock.withLock { requested = value } }
}

/// The entire verify → download → verify → install transaction has one owner.
/// Sharing only the network task is insufficient: two consumers would both move
/// the same completed file. Cancelling a screen detaches that waiter immediately;
/// the explicitly requested artifact continues once for other screens/background
/// URLSession recovery, without allowing the cancelled screen to apply a result.
actor LocalAIArtifactFlight {
    static let shared = LocalAIArtifactFlight()

    private struct Flight {
        let id: UUID
        var waiters: [UUID: CheckedContinuation<Void, Error>]
    }
    private var flights: [String: Flight] = [:]

    func perform(key: String, operation: @escaping @Sendable () async throws -> Void) async throws {
        try Task.checkCancellation()
        let waiterID = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                guard !Task.isCancelled else {
                    continuation.resume(throwing: CancellationError())
                    return
                }
                if flights[key] != nil {
                    flights[key]?.waiters[waiterID] = continuation
                    return
                }
                let flightID = UUID()
                flights[key] = Flight(id: flightID, waiters: [waiterID: continuation])
                Task {
                    let result: Result<Void, Error>
                    do { try await operation(); result = .success(()) }
                    catch { result = .failure(error) }
                    self.finish(key: key, id: flightID, result: result)
                }
            }
            try Task.checkCancellation()
        } onCancel: {
            Task { await self.cancelWaiter(key: key, id: waiterID) }
        }
    }

    func waiterCount(for key: String) -> Int { flights[key]?.waiters.count ?? 0 }

    private func cancelWaiter(key: String, id: UUID) {
        flights[key]?.waiters.removeValue(forKey: id)?.resume(throwing: CancellationError())
    }

    private func finish(key: String, id: UUID, result: Result<Void, Error>) {
        guard flights[key]?.id == id, let flight = flights.removeValue(forKey: key) else { return }
        for continuation in flight.waiters.values { continuation.resume(with: result) }
    }
}

/// A digest+size receipt alone survives same-size corruption or an atomic file
/// replacement. Bind the verified digest to the specific inode and timestamps.
/// Old receipts intentionally fail closed and receive one background rehash.
struct ModelIntegrityReceipt: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let sha256: String
    let identity: Identity

    struct Identity: Codable, Equatable, Sendable {
        let bytes: Int64
        let fileNumber: UInt64
        let modificationDate: Date
        let creationDate: Date

        static func read(at url: URL) throws -> Identity {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            guard attributes[.type] as? FileAttributeType == .typeRegular,
                  let size = attributes[.size] as? NSNumber,
                  let fileNumber = attributes[.systemFileNumber] as? NSNumber,
                  let modification = attributes[.modificationDate] as? Date,
                  let creation = attributes[.creationDate] as? Date else {
                throw CocoaError(.fileReadCorruptFile)
            }
            return Identity(bytes: size.int64Value, fileNumber: fileNumber.uint64Value,
                            modificationDate: modification, creationDate: creation)
        }
    }

    static func read(for model: URL, expectedSHA256: String) -> Bool {
        guard let data = try? Data(contentsOf: receiptURL(for: model)),
              let receipt = try? JSONDecoder().decode(Self.self, from: data),
              receipt.schemaVersion == 2,
              receipt.sha256 == expectedSHA256.lowercased(),
              let current = try? Identity.read(at: model) else { return false }
        return receipt.identity == current
    }

    static func write(for model: URL, sha256: String, verifiedIdentity: Identity) throws {
        // Reject a writer that hashed file A, then observed a concurrent file B.
        guard try Identity.read(at: model) == verifiedIdentity else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let receipt = Self(schemaVersion: 2, sha256: sha256.lowercased(), identity: verifiedIdentity)
        let data = try JSONEncoder().encode(receipt)
        try data.write(to: receiptURL(for: model), options: .atomic)
    }

    static func receiptURL(for model: URL) -> URL {
        model.appendingPathExtension("matths-integrity")
    }
}

enum ModelDownloadResponseValidation {
    /// URLSession handles Range/If-Range and assembles resumed payloads. Do not
    /// mistake Content-Length of a 206 suffix for the complete artifact length.
    /// Check the assembled length against Content-Range's total in that case.
    static func accepts(status: Int, contentLength: Int64?, contentRange: String?, bytes: Int64) -> Bool {
        guard bytes > 0 else { return false }
        if status == 200 {
            guard let contentLength else { return true }
            return contentLength > 0 && contentLength == bytes
        }
        guard status == 206, let range = contentRange,
              range.lowercased().hasPrefix("bytes ") else { return false }
        let pieces = range.dropFirst(6).split(separator: "/", omittingEmptySubsequences: false)
        guard pieces.count == 2, let total = Int64(pieces[1]), total == bytes else { return false }
        let bounds = pieces[0].split(separator: "-", omittingEmptySubsequences: false)
        guard bounds.count == 2, let start = Int64(bounds[0]), let end = Int64(bounds[1]),
              start >= 0, end >= start, end < total else { return false }
        if let contentLength { return contentLength == end - start + 1 }
        return true
    }
}
