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

    private var waiters: [String: [UUID: Waiter]] = [:]
    private var startingKeys = Set<String>()
    private var activeTaskIdentifiers: [String: Int] = [:]
    private var retiredTaskIdentifiers = Set<Int>()
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
        try Task.checkCancellation()
        let stableKey = digest(key)
        if let completed = completedURL(for: stableKey) {
            if FileManager.default.fileExists(atPath: completed.path) {
                return completed
            }
            // iOS may purge a staged artifact or the old cleanup may have removed
            // it. A stale receipt is a cache miss, not a permanently failed retry.
            clearCompleted(stableKey)
        }

        let waiterID = UUID()
        let result = try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
                guard !Task.isCancelled else {
                    continuation.resume(throwing: CancellationError())
                    return
                }
                waiters[stableKey, default: [:]][waiterID] = Waiter(
                    continuation: continuation, progress: progress)
                guard startingKeys.insert(stableKey).inserted else { return }
                session.getAllTasks { tasks in
                    Task { @MainActor in
                        guard self.startingKeys.contains(stableKey) else { return }
                        let matching = tasks.filter {
                            $0.taskDescription == stableKey && $0.state != .completed && $0.state != .canceling
                        }
                        if let task = matching.first {
                            self.activeTaskIdentifiers[stableKey] = task.taskIdentifier
                            // Repair duplicate historical background tasks once.
                            matching.dropFirst().forEach {
                                self.retiredTaskIdentifiers.insert($0.taskIdentifier)
                                $0.cancel()
                            }
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
                            var request = URLRequest(url: url)
                            // Byte offsets and Content-Length must describe the
                            // GGUF itself, not a transparently inflated response.
                            request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
                            task = self.session.downloadTask(with: request)
                        }
                        task.taskDescription = stableKey
                        self.activeTaskIdentifiers[stableKey] = task.taskIdentifier
                        task.resume()
                    }
                }
            }
        } onCancel: {
            Task { @MainActor in
                // A cancelled UI stops waiting; the single background download
                // remains resumable and can serve another feature on this device.
                self.waiters[stableKey]?.removeValue(forKey: waiterID)?
                    .continuation.resume(throwing: CancellationError())
            }
        }
        try Task.checkCancellation()
        return result
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
        let taskID = downloadTask.taskIdentifier
        Task { @MainActor in
            guard let key, self.acceptsCallback(key: key, taskID: taskID) else { return }
            for waiter in self.waiters[key]?.values ?? [:].values {
                waiter.progress?(fraction)
            }
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        let key = downloadTask.taskDescription
        let response = downloadTask.response as? HTTPURLResponse
        let taskID = downloadTask.taskIdentifier
        guard let key else { return }
        let bytes = ((try? FileManager.default.attributesOfItem(atPath: location.path)[.size]) as? NSNumber)?.int64Value ?? 0
        guard let response,
              ModelDownloadResponseValidation.accepts(
                status: response.statusCode,
                contentLength: response.value(forHTTPHeaderField: "Content-Length").flatMap(Int64.init),
                contentRange: response.value(forHTTPHeaderField: "Content-Range"),
                bytes: bytes) else {
            Task { @MainActor in
                guard self.acceptsCallback(key: key, taskID: taskID) else { return }
                try? FileManager.default.removeItem(at: self.resumeDataURL(for: key))
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
        let destination = root.appendingPathComponent("\(key).\(taskID).downloaded")
        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.moveItem(at: location, to: destination)
            Task { @MainActor in
                guard self.acceptsCallback(key: key, taskID: taskID) else {
                    try? FileManager.default.removeItem(at: destination)
                    return
                }
                var protectedRoot = root
                var values = URLResourceValues()
                values.isExcludedFromBackup = true
                try? protectedRoot.setResourceValues(values)
                self.setCompleted(destination, key: key)
                try? FileManager.default.removeItem(at: self.resumeDataURL(for: key))
                self.finish(key: key, result: .success(destination))
            }
        } catch {
            Task { @MainActor in
                guard self.acceptsCallback(key: key, taskID: taskID) else { return }
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
        let taskID = task.taskIdentifier
        let resumeData = (error as NSError).userInfo[NSURLSessionDownloadTaskResumeData] as? Data
        Task { @MainActor in
            guard self.acceptsCallback(key: key, taskID: taskID) else { return }
            if let resumeData, !resumeData.isEmpty {
                try? resumeData.write(to: self.resumeDataURL(for: key), options: [.atomic])
            } else {
                // Invalid/obsolete resume data must not poison every retry.
                try? FileManager.default.removeItem(at: self.resumeDataURL(for: key))
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
        startingKeys.remove(key)
        if let taskID = activeTaskIdentifiers.removeValue(forKey: key) {
            retiredTaskIdentifiers.insert(taskID)
        }
        for waiter in waiters.removeValue(forKey: key)?.values ?? [:].values {
            waiter.continuation.resume(with: result)
        }
    }

    private func acceptsCallback(key: String, taskID: Int) -> Bool {
        // No in-memory identifier is normal after background process relaunch.
        // Once a caller has attached, only its exact task may finish the flight.
        guard !retiredTaskIdentifiers.contains(taskID) else { return false }
        if let current = activeTaskIdentifiers[key] { return current == taskID }
        activeTaskIdentifiers[key] = taskID
        return true
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
        let candidate = URL(fileURLWithPath: value).standardizedFileURL
        guard candidate.deletingLastPathComponent() == artifactDirectory.standardizedFileURL,
              candidate.lastPathComponent.hasPrefix(key),
              candidate.pathExtension == "downloaded" else {
            clearCompleted(key)
            return nil
        }
        return candidate
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
