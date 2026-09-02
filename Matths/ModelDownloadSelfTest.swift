import CryptoKit
import Foundation

#if DEBUG
/// 모델 수 GB를 다시 받지 않고도 최종 설치·background resume 경계를 실제 iPad에서 검증한다.
enum ModelDownloadSelfTest {
    private struct FileResult {
        let atomicReplacement: Bool
        let integrityReceiptMatches: Bool
        let corruptHeaderRejected: Bool
        let wrongSHARejected: Bool
        let destinationPreservedAfterFailures: Bool
        let insufficientStorageRejected: Bool

        var passed: Bool {
            atomicReplacement && integrityReceiptMatches && corruptHeaderRejected &&
                wrongSHARejected && destinationPreservedAfterFailures && insufficientStorageRejected
        }
    }

    private struct ResumeResult {
        let resumeDataPersisted: Bool
        let resumedFromPersistedData: Bool
        let resumedDownloadCompleted: Bool
        let completedBytes: Int64
        let error: String?

        var passed: Bool {
            resumeDataPersisted && resumedFromPersistedData && resumedDownloadCompleted &&
                completedBytes > 0
        }
    }

    private struct Report: Codable {
        let schemaVersion: String
        let recordedAt: Date
        let deviceModel: String
        let atomicReplacement: Bool
        let integrityReceiptMatches: Bool
        let corruptHeaderRejected: Bool
        let wrongSHARejected: Bool
        let destinationPreservedAfterFailures: Bool
        let insufficientStorageRejected: Bool
        let resumeDataPersisted: Bool?
        let resumedFromPersistedData: Bool?
        let resumedDownloadCompleted: Bool?
        let completedBytes: Int64?
        let resumeError: String?
        let status: String
    }

    static func runIfRequested() {
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("-modelDownloadSelfTest") else { return }
        let files = runFileBoundary()
        let resumeURL = argumentValue("-modelDownloadResumeURL", in: arguments).flatMap(URL.init(string:))
        guard let resumeURL else {
            writeReport(files: files, resume: nil)
            return
        }
        Task { @MainActor in
            let resume = await runResumeBoundary(url: resumeURL)
            writeReport(files: files, resume: resume)
        }
    }

    private static func runFileBoundary() -> FileResult {
        let fm = FileManager.default
        let documents = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let root = documents.appendingPathComponent("ModelDownloadSelfTest", isDirectory: true)
        let destination = root.appendingPathComponent("model.gguf")
        let receipt = destination.appendingPathExtension("matths-integrity")
        try? fm.removeItem(at: root)

        var atomicReplacement = false
        var integrityReceiptMatches = false
        var corruptHeaderRejected = false
        var wrongSHARejected = false
        var destinationPreservedAfterFailures = false
        var insufficientStorageRejected = false

        do {
            try fm.createDirectory(at: root, withIntermediateDirectories: true)
            try payload(byte: 0x11).write(to: destination, options: .atomic)

            let staged = root.appendingPathComponent("valid.part")
            let replacement = payload(byte: 0x22)
            try replacement.write(to: staged, options: .atomic)
            let expected = sha256(replacement)
            try LocalAIModelPack.installValidatedGGUF(
                staged: staged,
                destination: destination,
                minimumBytes: 4,
                expectedSHA256: expected)
            atomicReplacement = (try Data(contentsOf: destination)) == replacement
            integrityReceiptMatches = (try? String(contentsOf: receipt, encoding: .utf8)) ==
                "\(expected)\n\(replacement.count)\n"

            let preservedHash = try LocalAIModelPack.sha256(of: destination)
            let corrupt = root.appendingPathComponent("corrupt.part")
            try Data(repeating: 0x33, count: 32 * 1_024).write(to: corrupt, options: .atomic)
            do {
                try LocalAIModelPack.installValidatedGGUF(
                    staged: corrupt, destination: destination, minimumBytes: 4)
            } catch {
                corruptHeaderRejected = true
            }

            let wrongSHA = root.appendingPathComponent("wrong-sha.part")
            try payload(byte: 0x44).write(to: wrongSHA, options: .atomic)
            do {
                try LocalAIModelPack.installValidatedGGUF(
                    staged: wrongSHA,
                    destination: destination,
                    minimumBytes: 4,
                    expectedSHA256: String(repeating: "0", count: 64))
            } catch {
                wrongSHARejected = true
            }
            destinationPreservedAfterFailures =
                (try LocalAIModelPack.sha256(of: destination)) == preservedHash

            do {
                try LocalAIModelPack.requireStorage(
                    availableBytes: 999_999_999,
                    downloadBytes: 1_000_000_000)
            } catch LocalAIModelPack.PackError.insufficientStorage(let requiredGB) {
                insufficientStorageRejected = requiredGB == 2
            }
        } catch {
            NSLog("ModelDownloadSelfTest file boundary failed: %@", String(describing: error))
        }
        try? fm.removeItem(at: root)
        return FileResult(
            atomicReplacement: atomicReplacement,
            integrityReceiptMatches: integrityReceiptMatches,
            corruptHeaderRejected: corruptHeaderRejected,
            wrongSHARejected: wrongSHARejected,
            destinationPreservedAfterFailures: destinationPreservedAfterFailures,
            insufficientStorageRejected: insufficientStorageRejected)
    }

    @MainActor
    private static func runResumeBoundary(url: URL) async -> ResumeResult {
        let broker = ResumableModelDownload.shared
        let key = "device-resume-qa|\(url.absoluteString)"
        broker.discardArtifact(for: key)
        let first = Task { @MainActor in
            try await broker.download(from: url, key: key)
        }
        try? await Task.sleep(for: .milliseconds(900))
        _ = await broker.cancelForSelfTest(key: key)
        _ = try? await first.value
        let persisted = broker.selfTestResumeState(key: key).persisted

        var completed = false
        var completedBytes: Int64 = 0
        var resumeError: String?
        do {
            let file = try await broker.download(from: url, key: key)
            let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
            completedBytes = (attributes[.size] as? NSNumber)?.int64Value ?? 0
            completed = completedBytes > 0
        } catch {
            NSLog("ModelDownloadSelfTest resume boundary failed: %@", String(describing: error))
            resumeError = String(describing: error)
        }
        let used = broker.selfTestResumeState(key: key).used
        broker.discardArtifact(for: key)
        return ResumeResult(
            resumeDataPersisted: persisted,
            resumedFromPersistedData: used,
            resumedDownloadCompleted: completed,
            completedBytes: completedBytes,
            error: resumeError)
    }

    private static func writeReport(files: FileResult, resume: ResumeResult?) {
        let passed = files.passed && (resume?.passed ?? true)
        let report = Report(
            schemaVersion: "MATTHS_MODEL_DOWNLOAD_DEVICE_QA_V1",
            recordedAt: Date(),
            deviceModel: ProcessInfo.processInfo.hostName,
            atomicReplacement: files.atomicReplacement,
            integrityReceiptMatches: files.integrityReceiptMatches,
            corruptHeaderRejected: files.corruptHeaderRejected,
            wrongSHARejected: files.wrongSHARejected,
            destinationPreservedAfterFailures: files.destinationPreservedAfterFailures,
            insufficientStorageRejected: files.insufficientStorageRejected,
            resumeDataPersisted: resume?.resumeDataPersisted,
            resumedFromPersistedData: resume?.resumedFromPersistedData,
            resumedDownloadCompleted: resume?.resumedDownloadCompleted,
            completedBytes: resume?.completedBytes,
            resumeError: resume?.error,
            status: passed ? "PASS" : "FAIL")
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        if let data = try? JSONEncoder.pretty.encode(report) {
            try? data.write(
                to: documents.appendingPathComponent("model-download-device-qa.json"),
                options: .atomic)
        }
    }

    private static func argumentValue(_ name: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: name), index + 1 < arguments.count else { return nil }
        return arguments[index + 1]
    }

    private static func payload(byte: UInt8) -> Data {
        var data = Data([0x47, 0x47, 0x55, 0x46])
        data.append(Data(repeating: byte, count: 256 * 1_024))
        return data
    }

    private static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

private extension JSONEncoder {
    static var pretty: JSONEncoder {
        let value = JSONEncoder()
        value.outputFormatting = [.prettyPrinted, .sortedKeys]
        value.dateEncodingStrategy = .iso8601
        return value
    }
}
#endif
