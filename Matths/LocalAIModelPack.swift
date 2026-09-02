//  LocalAIModelPack.swift
//  Matths
//
//  시험지 분석용 모델을 역할별로 준비한다. 8GB 기기에서는 사진 판독 VLM과
//  수학 추론 LLM을 디스크에는 함께 두되 메모리에는 하나씩만 올린다.

import CryptoKit
import Foundation

@MainActor
final class LocalAIModelPack: ObservableObject {
    static let shared = LocalAIModelPack()

    enum State: Equatable {
        case idle
        case checking
        case downloading(String)
        case ready
        case failed(String)
    }

    enum PackError: LocalizedError {
        case insufficientStorage(requiredGB: Int)
        case badResponse(String)
        case invalidFile(String)

        var errorDescription: String? {
            switch self {
            case .insufficientStorage(let requiredGB):
                return "로컬 AI 모델을 받으려면 약 \(requiredGB)GB의 여유 공간이 필요합니다."
            case .badResponse(let name):
                return "\(name) 다운로드 서버가 올바르게 응답하지 않았습니다."
            case .invalidFile(let name):
                return "\(name) 다운로드가 완전하지 않아 다시 받아야 합니다."
            }
        }
    }

    @Published private(set) var state: State = .idle

    /// 여러 화면이 같은 순간 모델팩 준비를 요청해도 수 GB 파일을 중복으로 받지 않는다.
    /// async 함수는 다운로드를 기다리는 동안 재진입할 수 있으므로 state만으로는 부족하다.
    private var preparation: (id: UUID, task: Task<Void, Error>)?

    private init() {}

    var statusText: String {
        switch state {
        case .idle: return "분석 모델 확인 전"
        case .checking: return "기기 저장 공간과 모델 파일 확인 중"
        case .downloading(let name): return "\(name) 내려받는 중"
        case .ready: return "사진 판독·수학 추론 모델 준비 완료"
        case .failed(let message): return message
        }
    }

    /// 필요한 파일을 모두 준비한다. 같은 모델이 두 역할을 맡는 12GB 이상 기기는
    /// 중복 다운로드하지 않는다.
    func prepareForSheetAnalysis() async throws {
        if let running = preparation {
            try await running.task.value
            return
        }

        let id = UUID()
        let task = Task { @MainActor [weak self] in
            guard let self else { throw CancellationError() }
            try await self.performPreparation()
        }
        preparation = (id, task)
        defer {
            // 같은 작업을 기다리던 호출이 늦게 돌아와 새 작업을 지우지 않게 id를 확인한다.
            if preparation?.id == id { preparation = nil }
        }
        try await task.value
    }

    private func performPreparation() async throws {
        state = .checking
        do {
            let vision = ModelDownloader.analysisVisionSpec
            let reasoning = ModelDownloader.analysisReasoningSpec
            var artifacts: [(name: String, file: String, url: URL, expectedBytes: Int64, sha256: String?)] = [
                (vision.shortName, vision.file, vision.url,
                 Self.expectedBytes(for: vision.file), Self.expectedSHA256(for: vision.file)),
            ]
            if !vision.mmprojFile.isEmpty {
                guard let mmprojURL = vision.mmprojURL else {
                    throw PackError.invalidFile("\(vision.shortName) 사진 모듈 주소")
                }
                artifacts.append((
                    "\(vision.shortName) 사진 모듈",
                    vision.mmprojFile,
                    mmprojURL,
                    Self.expectedBytes(for: vision.mmprojFile),
                    Self.expectedSHA256(for: vision.mmprojFile)))
            }
            if reasoning.file != vision.file {
                artifacts.append((
                    reasoning.shortName,
                    reasoning.file,
                    reasoning.url,
                    Self.expectedBytes(for: reasoning.file),
                    Self.expectedSHA256(for: reasoning.file)))
            }

            var seen = Set<String>()
            artifacts = artifacts.filter { seen.insert($0.file).inserted }
            var missing: [(name: String, file: String, url: URL, expectedBytes: Int64, sha256: String?)] = []
            for artifact in artifacts {
                if !(await Self.verifyExistingArtifact(
                    artifact.file,
                    expectedBytes: artifact.expectedBytes
                )) {
                    missing.append(artifact)
                }
            }
            try Self.requireStorage(for: missing.reduce(0) { $0 + $1.expectedBytes })

            for artifact in missing {
                state = .downloading(artifact.name)
                try await Self.download(artifact)
            }
            state = .ready
        } catch {
            #if DEBUG
            print("AI 분석 모델팩 준비 실패:", error)
            #endif
            state = .failed(ModelDownloader.userFacingDownloadFailure(error))
            throw error
        }
    }

    nonisolated static func fileReady(
        _ file: String,
        expectedBytes: Int64? = nil
    ) -> Bool {
        guard !file.isEmpty else { return false }
        let url = AITutor.modelsDir.appendingPathComponent(file)
        let knownBytes = expectedBytes ?? Self.expectedBytes(for: file)
        guard basicFileReady(at: url, expectedBytes: knownBytes),
              let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? NSNumber else { return false }
        guard let expectedSHA256 = expectedSHA256(for: file) else { return true }
        return integrityReceiptMatches(
            for: url,
            expectedSHA256: expectedSHA256,
            byteCount: size.int64Value)
    }

    /// 업데이트 이전에 받아 둔 모델은 영수증 파일이 없을 수 있다. 수 GB 파일을
    /// UI 스레드에서 읽지 않고 한 번만 백그라운드 검증한 뒤 영수증을 만든다.
    /// 해시가 다르면 기존 파일은 절대 로드하지 않고 정상 다운로드 경로로 보낸다.
    nonisolated static func verifyExistingArtifact(
        _ file: String,
        expectedBytes: Int64? = nil
    ) async -> Bool {
        guard !file.isEmpty else { return false }
        let url = AITutor.modelsDir.appendingPathComponent(file)
        let knownBytes = expectedBytes ?? Self.expectedBytes(for: file)
        guard basicFileReady(at: url, expectedBytes: knownBytes),
              let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? NSNumber else { return false }
        guard let expectedSHA256 = expectedSHA256(for: file) else { return true }
        if integrityReceiptMatches(
            for: url,
            expectedSHA256: expectedSHA256,
            byteCount: size.int64Value
        ) {
            return true
        }
        let actualSHA256 = try? await Task.detached(priority: .utility) {
            try sha256(of: url)
        }.value
        guard actualSHA256 == expectedSHA256.lowercased() else { return false }
        do {
            try writeIntegrityReceipt(
                for: url,
                sha256: expectedSHA256,
                byteCount: size.int64Value)
            return true
        } catch {
            return false
        }
    }

    private nonisolated static func basicFileReady(
        at url: URL,
        expectedBytes: Int64
    ) -> Bool {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? NSNumber else { return false }
        let minimum = Int64(max(64 * 1_048_576, Int(Double(expectedBytes) * 0.97)))
        return size.int64Value >= minimum && hasGGUFHeader(at: url)
    }

    private nonisolated static func integrityReceiptURL(for modelURL: URL) -> URL {
        modelURL.appendingPathExtension("matths-integrity")
    }

    private nonisolated static func integrityReceiptMatches(
        for modelURL: URL,
        expectedSHA256: String,
        byteCount: Int64
    ) -> Bool {
        guard let value = try? String(
            contentsOf: integrityReceiptURL(for: modelURL),
            encoding: .utf8)
        else { return false }
        return value == "\(expectedSHA256.lowercased())\n\(byteCount)\n"
    }

    private nonisolated static func writeIntegrityReceipt(
        for modelURL: URL,
        sha256: String,
        byteCount: Int64
    ) throws {
        try "\(sha256.lowercased())\n\(byteCount)\n".write(
            to: integrityReceiptURL(for: modelURL),
            atomically: true,
            encoding: .utf8)
    }

    /// 크기가 큰 HTML 오류 페이지나 중간 프록시 응답을 모델로 열면 llama.cpp가
    /// 프로세스를 종료할 수 있다. 전체 수 GB를 다시 읽지 않고 GGUF magic만 확인한다.
    nonisolated static func hasGGUFHeader(at url: URL) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: 4) else { return false }
        return data == Data([0x47, 0x47, 0x55, 0x46]) // "GGUF"
    }

    /// 검증을 끝낸 staged 파일만 최종 이름으로 원자 교체한다. 교체가 실패해도
    /// 기존 정상 모델은 그대로 남는다(remove → move의 크래시 공백을 만들지 않는다).
    nonisolated static func installValidatedGGUF(
        staged: URL,
        destination: URL,
        minimumBytes: Int64 = 64 * 1_048_576,
        expectedSHA256: String? = nil
    ) throws {
        defer {
            if FileManager.default.fileExists(atPath: staged.path) {
                try? FileManager.default.removeItem(at: staged)
            }
        }
        let attributes = try FileManager.default.attributesOfItem(atPath: staged.path)
        let size = (attributes[.size] as? NSNumber)?.int64Value ?? 0
        guard size >= minimumBytes, hasGGUFHeader(at: staged) else {
            throw PackError.invalidFile(destination.lastPathComponent)
        }
        var verifiedSHA256: String?
        if let expectedSHA256 {
            let actualSHA256 = try sha256(of: staged)
            guard actualSHA256 == expectedSHA256.lowercased() else {
                throw PackError.invalidFile(destination.lastPathComponent)
            }
            verifiedSHA256 = actualSHA256
        }

        try FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: destination.path) {
            _ = try FileManager.default.replaceItemAt(
                destination,
                withItemAt: staged,
                backupItemName: nil,
                options: [])
        } else {
            try FileManager.default.moveItem(at: staged, to: destination)
        }
        if let verifiedSHA256 {
            try writeIntegrityReceipt(
                for: destination,
                sha256: verifiedSHA256,
                byteCount: size)
        } else {
            try? FileManager.default.removeItem(at: integrityReceiptURL(for: destination))
        }
    }

    /// 수 GB 파일을 Data 한 덩어리로 올리지 않고 4MB씩 읽어 검증한다.
    /// 검증은 호출부에서 메인 액터 밖으로 보낸다.
    nonisolated static func sha256(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 4 * 1_048_576), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    nonisolated static func requireStorage(for bytes: Int64) throws {
        guard bytes > 0 else { return }
        let values = try? AITutor.modelsDir.deletingLastPathComponent()
            .resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        guard let available = values?.volumeAvailableCapacityForImportantUsage else { return }
        try requireStorage(availableBytes: available, downloadBytes: bytes)
    }

    /// 실기 자가진단도 제품과 같은 15% staging 여유 계산을 사용한다. 용량이 부족한
    /// 기기를 실제로 가득 채우지 않고도 fail-closed 문구와 경계를 검증할 수 있게 순수
    /// 계산 부분만 분리한다.
    nonisolated static func requireStorage(
        availableBytes: Int64,
        downloadBytes: Int64
    ) throws {
        guard downloadBytes > 0 else { return }
        // URLSession 임시 파일과 최종 이동이 잠깐 겹칠 수 있으므로 15% 여유를 둔다.
        let required = Int64(ceil(Double(downloadBytes) * 1.15))
        if availableBytes < required {
            let gb = Int(ceil(Double(required) / 1_000_000_000))
            throw PackError.insufficientStorage(requiredGB: gb)
        }
    }

    private nonisolated static func download(
        _ artifact: (name: String, file: String, url: URL, expectedBytes: Int64, sha256: String?)
    ) async throws {
        let downloadKey = "\(artifact.url.absoluteString)|\(artifact.file)|\(artifact.expectedBytes)"
        let temporary = try await ResumableModelDownload.shared.download(
            from: artifact.url,
            key: downloadKey)
        defer { Task { @MainActor in ResumableModelDownload.shared.discardArtifact(for: downloadKey) } }
        let minimum = Int64(Double(artifact.expectedBytes) * 0.97)
        let attributes = try FileManager.default.attributesOfItem(atPath: temporary.path)
        let size = (attributes[.size] as? NSNumber)?.int64Value ?? 0
        guard size >= minimum, Self.hasGGUFHeader(at: temporary) else {
            throw PackError.invalidFile(artifact.name)
        }

        let directory = AITutor.modelsDir
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true)
        let destination = directory.appendingPathComponent(artifact.file)
        let staged = directory.appendingPathComponent("staged-\(UUID().uuidString).part")
        try FileManager.default.moveItem(at: temporary, to: staged)
        try Self.installValidatedGGUF(
            staged: staged,
            destination: destination,
            minimumBytes: minimum,
            expectedSHA256: artifact.sha256)
    }

    nonisolated static func expectedBytes(for file: String) -> Int64 {
        switch file {
        case ModelDownloader.specVision3B.file:
            return 1_929_901_056
        case ModelDownloader.specVision3B.mmprojFile:
            return 844_757_728
        case ModelDownloader.specDeepSeek7B.file:
            return 3_808_390_880
        #if DEBUG
        case ModelDownloader.specLing3Q3.file:
            return 3_841_570_656
        #endif
        case ModelDownloader.spec9B.file:
            return 5_680_522_464
        case ModelDownloader.spec9BLite.file:
            return 3_190_613_216
        case ModelDownloader.spec9BLiteText.file:
            return 4_016_235_744
        case ModelDownloader.spec9B.mmprojFile:
            return 918_166_080
        default:
            return 128 * 1_048_576
        }
    }

    /// Hugging Face의 해당 GGUF 파일 포인터에 공개된 SHA-256.
    /// 확인하지 못한 모델에는 값을 추측해서 넣지 않는다.
    nonisolated static func expectedSHA256(for file: String) -> String? {
        switch file {
        case ModelDownloader.specVision3B.file:
            return "d02fe9b69ad8cadbbd228e387667af66612c44bed29ffc8eb1e7caf9ac486c12"
        case ModelDownloader.specVision3B.mmprojFile:
            return "980c9b2f78c04e6cff93d277ada09e768394f112d75db3b4e9dea8a69f9fb904"
        case ModelDownloader.specDeepSeek7B.file:
            return "0931f946c6f439a3b5cc0226f39dce14c092c2ee4386be98f12ca6305cef7ec7"
        #if DEBUG
        case ModelDownloader.specLing3Q3.file:
            return "3481953f64fa2dad7e22a254faba1681ab5b83061ac378ea144704fe6019bba2"
        #endif
        case ModelDownloader.spec9B.file:
            return "03b74727a860a56338e042c4420bb3f04b2fec5734175f4cb9fa853daf52b7e8"
        case ModelDownloader.spec9BLite.file:
            return "570ce2bbc92545cffbcb01df43cba59d86093dadc34c25da9f554d256bc70b91"
        case ModelDownloader.spec9BLiteText.file:
            return "40d0f32cd3030b04f0784139a589fb63e876cfbf8667d56311b79783c74fd149"
        case ModelDownloader.spec9B.mmprojFile:
            return "f70dc3509053962b0d0d3ee8a7eacebf5d60aa560cad78254ae8698516ae029f"
        default:
            return nil
        }
    }
}
