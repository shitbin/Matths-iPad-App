//  ResumableModelDownload.swift
//  Matths
//
//  수 GB 모델 파일용 백그라운드 다운로드 경계. URLSession의 임시 위치를
//  delegate 반환 전에 앱 전용 staging 폴더로 옮기고, 앱이 종료돼도 같은
//  background task에 다시 붙는다. 실패가 resumeData를 주면 다음 시도에 재사용한다.

import CryptoKit
import Foundation

@MainActor
final class ResumableModelDownload: NSObject, URLSessionDownloadDelegate {
    static let shared = ResumableModelDownload()
    static let sessionIdentifier = "kr.matths.local-ai-model-pack.v1"

    enum DownloadError: LocalizedError {
        case invalidResponse
        case missingCompletedFile

        var errorDescription: String? {
            switch self {
            case .invalidResponse: return "모델 다운로드 서버가 올바르게 응답하지 않았습니다."
            case .missingCompletedFile: return "완료된 모델 임시 파일을 다시 찾지 못했습니다."
            }
        }
    }

    private struct Waiter {
        let continuation: CheckedContinuation<URL, Error>
        let progress: (@Sendable (Double) -> Void)?
    }

    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: Self.sessionIdentifier)
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        config.waitsForConnectivity = true
        config.timeoutIntervalForResource = 24 * 60 * 60
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    private var waiters: [String: Waiter] = [:]
    private var backgroundCompletion: (() -> Void)?
    #if DEBUG
    private var selfTestResumeKeys = Set<String>()
    #endif

    private override init() {
        super.init()
        cleanupOldArtifacts()
    }

    func download(
        from url: URL,
        key: String,
        progress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> URL {
        let stableKey = digest(key)
        if let completed = completedURL(for: stableKey) {
            guard FileManager.default.fileExists(atPath: completed.path) else {
                clearCompleted(stableKey)
                throw DownloadError.missingCompletedFile
            }
            return completed
        }

        return try await withCheckedThrowingContinuation { continuation in
            waiters[stableKey] = Waiter(continuation: continuation, progress: progress)
            session.getAllTasks { tasks in
                Task { @MainActor in
                    if let task = tasks.first(where: { $0.taskDescription == stableKey }) {
                        task.resume()
                        return
                    }
                    let resumeURL = self.resumeDataURL(for: stableKey)
                    let task: URLSessionDownloadTask
                    if let data = try? Data(contentsOf: resumeURL), !data.isEmpty {
                        #if DEBUG
                        self.selfTestResumeKeys.insert(stableKey)
                        #endif
                        task = self.session.downloadTask(withResumeData: data)
                    } else {
                        task = self.session.downloadTask(with: url)
                    }
                    task.taskDescription = stableKey
                    task.resume()
                }
            }
        }
    }

    /// 검증·최종 설치가 끝난 뒤 staging 흔적과 resumeData를 지운다.
    func discardArtifact(for key: String) {
        let stableKey = digest(key)
        if let url = completedURL(for: stableKey) { try? FileManager.default.removeItem(at: url) }
        clearCompleted(stableKey)
        try? FileManager.default.removeItem(at: resumeDataURL(for: stableKey))
    }

    func acceptBackgroundEvents(identifier: String, completion: @escaping () -> Void) {
        guard identifier == Self.sessionIdentifier else {
            completion()
            return
        }
        backgroundCompletion = completion
        _ = session
    }

    #if DEBUG
    /// 실제 background URLSession task를 취소해 iOS가 만든 resumeData를 제품 저장 위치에
    /// 남긴다. 자가진단 전용이며 Release에는 컴파일되지 않는다.
    func cancelForSelfTest(key: String) async -> Bool {
        let stableKey = digest(key)
        return await withCheckedContinuation { continuation in
            session.getAllTasks { tasks in
                guard let task = tasks.compactMap({ $0 as? URLSessionDownloadTask })
                    .first(where: { $0.taskDescription == stableKey }) else {
                    continuation.resume(returning: false)
                    return
                }
                task.cancel(byProducingResumeData: { data in
                    Task { @MainActor in
                        if let data, !data.isEmpty {
                            try? data.write(
                                to: self.resumeDataURL(for: stableKey),
                                options: [.atomic])
                        }
                        continuation.resume(returning: data?.isEmpty == false)
                    }
                })
            }
        }
    }

    func selfTestResumeState(key: String) -> (persisted: Bool, used: Bool) {
        let stableKey = digest(key)
        let persisted = ((try? Data(contentsOf: resumeDataURL(for: stableKey)))?.isEmpty == false)
        return (persisted, selfTestResumeKeys.contains(stableKey))
    }
    #endif

    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        let fraction = totalBytesExpectedToWrite > 0
            ? min(1, max(0, Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)))
            : 0
        let key = downloadTask.taskDescription
        Task { @MainActor in
            guard let key else { return }
            self.waiters[key]?.progress?(fraction)
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        let key = downloadTask.taskDescription
        let status = (downloadTask.response as? HTTPURLResponse)?.statusCode
        guard let key else { return }
        guard let status, (200..<300).contains(status) else {
            Task { @MainActor in
                self.finish(key: key, result: .failure(DownloadError.invalidResponse))
            }
            return
        }

        // iOS는 이 delegate 콜백이 반환되는 즉시 location의 임시 파일을 지울 수 있다.
        // actor hop 뒤에 옮기면 이미 사라진 CFNetworkDownload_*.tmp를 가리키게 되므로,
        // 파일시스템 이동만 콜백 안에서 끝내고 actor 상태 갱신만 MainActor로 넘긴다.
        let root = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask)[0]
            .appendingPathComponent("ModelDownloads", isDirectory: true)
        let destination = root.appendingPathComponent("\(key).downloaded")
        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.moveItem(at: location, to: destination)
            Task { @MainActor in
                self.setCompleted(destination, key: key)
                try? FileManager.default.removeItem(at: self.resumeDataURL(for: key))
                self.finish(key: key, result: .success(destination))
            }
        } catch {
            Task { @MainActor in
                self.finish(key: key, result: .failure(error))
            }
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        guard let error, let key = task.taskDescription else { return }
        let resumeData = (error as NSError).userInfo[NSURLSessionDownloadTaskResumeData] as? Data
        Task { @MainActor in
            if let resumeData, !resumeData.isEmpty {
                try? resumeData.write(to: self.resumeDataURL(for: key), options: [.atomic])
            }
            self.finish(key: key, result: .failure(error))
        }
    }

    nonisolated func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        Task { @MainActor in
            let completion = self.backgroundCompletion
            self.backgroundCompletion = nil
            completion?()
        }
    }

    private func finish(key: String, result: Result<URL, Error>) {
        guard let waiter = waiters.removeValue(forKey: key) else { return }
        switch result {
        case .success(let url): waiter.continuation.resume(returning: url)
        case .failure(let error): waiter.continuation.resume(throwing: error)
        }
    }

    private var artifactDirectory: URL {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return root.appendingPathComponent("ModelDownloads", isDirectory: true)
    }

    private func artifactURL(for key: String) -> URL {
        artifactDirectory.appendingPathComponent("\(key).downloaded")
    }

    private func resumeDataURL(for key: String) -> URL {
        try? FileManager.default.createDirectory(at: artifactDirectory, withIntermediateDirectories: true)
        return artifactDirectory.appendingPathComponent("\(key).resume")
    }

    private func completedURL(for key: String) -> URL? {
        guard let value = UserDefaults.standard.string(forKey: "matths.modelDownload.completed.\(key)")
        else { return nil }
        return URL(fileURLWithPath: value)
    }

    private func setCompleted(_ url: URL, key: String) {
        UserDefaults.standard.set(url.path, forKey: "matths.modelDownload.completed.\(key)")
    }

    private func clearCompleted(_ key: String) {
        UserDefaults.standard.removeObject(forKey: "matths.modelDownload.completed.\(key)")
    }

    private func digest(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private func cleanupOldArtifacts(now: Date = Date()) {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: artifactDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]) else { return }
        for file in files {
            let modified = (try? file.resourceValues(
                forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            if now.timeIntervalSince(modified) > 7 * 24 * 60 * 60 {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }
}
