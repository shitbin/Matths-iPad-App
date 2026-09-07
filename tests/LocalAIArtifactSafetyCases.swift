import Foundation

@main
enum LocalAIArtifactSafetyCases {
    actor Gate {
        var starts = 0
        var open = false
        var continuations: [CheckedContinuation<Void, Never>] = []
        func operation() async {
            starts += 1
            guard !open else { return }
            await withCheckedContinuation { continuations.append($0) }
        }
        func release() { open = true; continuations.forEach { $0.resume() }; continuations = [] }
    }
    enum Failure: Error { case injected }

    static func main() async throws {
        try await twentyConcurrentConsumers()
        try await cancellationDetachesWithoutDuplicateInstall()
        try await failureIsSharedAndRetryStartsOnce()
        try await independentArtifactsCanPrepareInParallel()
        try receiptsRejectMutationAndReplacement()
        try responseFaultInjection()
        print("AI artifact safety: 20-way single-flight, cancellation, retry, file identity, 1%-step truncation and Range contracts passed")
    }

    static func waitFor(_ predicate: @escaping () async -> Bool) async throws {
        for _ in 0..<2_000 {
            if await predicate() { return }
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        throw Failure.injected
    }

    static func twentyConcurrentConsumers() async throws {
        let flight = LocalAIArtifactFlight(), gate = Gate()
        let jobs = (0..<20).map { _ in Task {
            try await flight.perform(key: "same-model") { await gate.operation() }
        } }
        try await waitFor { await flight.waiterCount(for: "same-model") == 20 }
        // Registration and starting the operation are separate actor events.
        // Under contention all waiters may be registered while the operation
        // Task has not reached Gate yet; that is zero work, not duplicate work.
        try await waitFor { await gate.starts > 0 }
        let before = await gate.starts
        precondition(before == 1, "20 model requests must verify/install exactly once; actual starts=\(before)")
        await gate.release()
        for job in jobs { try await job.value }
        let after = await flight.waiterCount(for: "same-model")
        precondition(after == 0)
    }

    static func cancellationDetachesWithoutDuplicateInstall() async throws {
        let flight = LocalAIArtifactFlight(), gate = Gate()
        let first = Task { try await flight.perform(key: "cancel") { await gate.operation() } }
        try await waitFor { await flight.waiterCount(for: "cancel") == 1 }
        try await waitFor { await gate.starts > 0 }
        first.cancel()
        do { try await first.value; preconditionFailure("cancelled screen must stop waiting") }
        catch is CancellationError { }
        let second = Task { try await flight.perform(key: "cancel") { await gate.operation() } }
        try await waitFor { await flight.waiterCount(for: "cancel") == 1 }
        let starts = await gate.starts
        precondition(starts == 1, "reattachment must not spawn another writer")
        await gate.release()
        try await second.value
    }

    static func failureIsSharedAndRetryStartsOnce() async throws {
        let flight = LocalAIArtifactFlight(), gate = Gate()
        let jobs = (0..<20).map { _ in Task {
            try await flight.perform(key: "failure") { await gate.operation(); throw Failure.injected }
        } }
        try await waitFor { await flight.waiterCount(for: "failure") == 20 }
        await gate.release()
        for job in jobs {
            do { try await job.value; preconditionFailure("failure must reach every waiter") }
            catch Failure.injected { }
        }
        try await flight.perform(key: "failure") { await gate.operation() }
        let starts = await gate.starts
        precondition(starts == 2, "failed flight must permit one clean retry")
    }

    static func independentArtifactsCanPrepareInParallel() async throws {
        let flight = LocalAIArtifactFlight(), gate = Gate()
        let a = Task { try await flight.perform(key: "vision") { await gate.operation() } }
        let b = Task { try await flight.perform(key: "reasoning") { await gate.operation() } }
        try await waitFor { await gate.starts == 2 }
        await gate.release()
        try await a.value; try await b.value
    }

    static func receiptsRejectMutationAndReplacement() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("artifact-safety-\(UUID())")
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }
        let file = root.appendingPathComponent("test.gguf"), hash = String(repeating: "a", count: 64)
        let payload = Data("GGUFsame-sized-test".utf8)
        try payload.write(to: file, options: .atomic)
        let identity = try ModelIntegrityReceipt.Identity.read(at: file)
        try ModelIntegrityReceipt.write(for: file, sha256: hash, verifiedIdentity: identity)
        precondition(ModelIntegrityReceipt.read(for: file, expectedSHA256: hash))
        precondition(!ModelIntegrityReceipt.read(for: file, expectedSHA256: String(repeating: "b", count: 64)))

        try payload.write(to: file, options: .atomic)
        precondition(!ModelIntegrityReceipt.read(for: file, expectedSHA256: hash), "same-size replacement invalidates receipt")
        do {
            try ModelIntegrityReceipt.write(for: file, sha256: hash, verifiedIdentity: identity)
            preconditionFailure("file replacement during hashing must reject stale digest")
        } catch is CocoaError { }

        let next = try ModelIntegrityReceipt.Identity.read(at: file)
        try ModelIntegrityReceipt.write(for: file, sha256: hash, verifiedIdentity: next)
        let handle = try FileHandle(forWritingTo: file)
        try handle.seek(toOffset: 5); try handle.write(contentsOf: Data([0x78])); try handle.close()
        // Explicit timestamp avoids filesystem clock granularity hiding this fixture's mutation.
        try fm.setAttributes([.modificationDate: next.modificationDate.addingTimeInterval(1)], ofItemAtPath: file.path)
        precondition(!ModelIntegrityReceipt.read(for: file, expectedSHA256: hash), "same-size in-place mutation invalidates receipt")

        try "\(hash)\n\(payload.count)\n".write(to: ModelIntegrityReceipt.receiptURL(for: file), atomically: true, encoding: .utf8)
        precondition(!ModelIntegrityReceipt.read(for: file, expectedSHA256: hash), "legacy size-only receipt requires rehash")
        let link = root.appendingPathComponent("link.gguf")
        try fm.createSymbolicLink(at: link, withDestinationURL: file)
        do { _ = try ModelIntegrityReceipt.Identity.read(at: link); preconditionFailure("symlink is not a verified artifact") }
        catch is CocoaError { }
    }

    static func responseFaultInjection() throws {
        let full: Int64 = 10_000
        for percent in 1..<100 {
            let partial = Int64(percent) * 100
            precondition(!ModelDownloadResponseValidation.accepts(status: 200, contentLength: full, contentRange: nil, bytes: partial), "truncated file at \(percent)%")
            let suffix = full - partial
            let range = "bytes \(partial)-9999/10000"
            precondition(ModelDownloadResponseValidation.accepts(status: 206, contentLength: suffix, contentRange: range, bytes: full))
            precondition(!ModelDownloadResponseValidation.accepts(status: 206, contentLength: suffix, contentRange: range, bytes: suffix), "unassembled Range suffix must not install")
        }
        precondition(ModelDownloadResponseValidation.accepts(status: 200, contentLength: full, contentRange: nil, bytes: full), "Range unsupported full restart is valid")
        precondition(!ModelDownloadResponseValidation.accepts(status: 206, contentLength: 100, contentRange: "bytes 9900-9999/*", bytes: full))
        precondition(!ModelDownloadResponseValidation.accepts(status: 206, contentLength: 99, contentRange: "bytes 9900-9999/10000", bytes: full))
        for status in [204, 301, 403, 404, 416, 500] {
            precondition(!ModelDownloadResponseValidation.accepts(status: status, contentLength: full, contentRange: nil, bytes: full))
        }
    }
}
