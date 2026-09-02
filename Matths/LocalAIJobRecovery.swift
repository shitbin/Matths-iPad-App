//  LocalAIJobRecovery.swift
//  Matths
//
//  온디바이스 시험지 분석은 큰 모델을 순차로 여는 동안 iPadOS가 앱을 종료할 수 있다.
//  모델의 KV cache를 복원하는 척하지 않고, 원본 사진과 마지막 단계만 계정 슬롯에
//  보존한다. 다음 실행에서는 같은 사진으로 파이프라인을 처음부터 안전하게 다시 돈다.

import Foundation

enum LocalAIJobRecovery {
    struct PendingJob: Codable, Equatable {
        let schemaVersion: Int
        let createdAt: Date
        var updatedAt: Date
        var stageLabel: String
        let sourceFileName: String
    }

    static let directoryName = "local-ai-pending-sheet"
    static let imageFileName = "source.jpg"
    static let metadataFileName = "job.json"
    static let maximumAge: TimeInterval = 24 * 60 * 60

    static var directory: URL { DataScope.url(directoryName) }

    @discardableResult
    static func begin(sourcePath: String, stageLabel: String = "분석 준비") throws -> String {
        try begin(sourcePath: sourcePath, stageLabel: stageLabel, in: directory)
    }

    @discardableResult
    static func begin(sourcePath: String, stageLabel: String, in directory: URL) throws -> String {
        let fm = FileManager.default
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)

        let sourceURL = URL(fileURLWithPath: sourcePath).standardizedFileURL
        let imageURL = directory.appendingPathComponent(imageFileName).standardizedFileURL
        if sourceURL != imageURL {
            let data = try Data(contentsOf: sourceURL, options: [.mappedIfSafe])
            try data.write(to: imageURL, options: [.atomic, .completeFileProtection])
        } else if !fm.fileExists(atPath: imageURL.path) {
            throw CocoaError(.fileNoSuchFile)
        }

        let now = Date()
        let job = PendingJob(
            schemaVersion: 1,
            createdAt: now,
            updatedAt: now,
            stageLabel: stageLabel,
            sourceFileName: imageFileName)
        try write(job, in: directory)
        return imageURL.path
    }

    static func update(stageLabel: String) {
        update(stageLabel: stageLabel, in: directory)
    }

    static func update(stageLabel: String, in directory: URL) {
        guard var job = loadMetadata(in: directory) else { return }
        job.stageLabel = stageLabel
        job.updatedAt = Date()
        try? write(job, in: directory)
    }

    static func restore(now: Date = Date()) -> (job: PendingJob, imagePath: String)? {
        restore(in: directory, now: now)
    }

    static func restore(in directory: URL, now: Date = Date()) -> (job: PendingJob, imagePath: String)? {
        guard let job = loadMetadata(in: directory), job.schemaVersion == 1 else {
            clear(in: directory)
            return nil
        }
        guard now.timeIntervalSince(job.createdAt) <= maximumAge else {
            clear(in: directory)
            return nil
        }
        let imageURL = directory.appendingPathComponent(job.sourceFileName).standardizedFileURL
        guard FileManager.default.fileExists(atPath: imageURL.path) else {
            clear(in: directory)
            return nil
        }
        return (job, imageURL.path)
    }

    static func owns(path: String) -> Bool {
        owns(path: path, in: directory)
    }

    static func owns(path: String, in directory: URL) -> Bool {
        URL(fileURLWithPath: path).standardizedFileURL
            == directory.appendingPathComponent(imageFileName).standardizedFileURL
    }

    static func clear() {
        clear(in: directory)
    }

    static func clear(in directory: URL) {
        try? FileManager.default.removeItem(at: directory)
    }

    private static func metadataURL(in directory: URL) -> URL {
        directory.appendingPathComponent(metadataFileName)
    }

    private static func loadMetadata(in directory: URL) -> PendingJob? {
        guard let data = try? Data(contentsOf: metadataURL(in: directory)) else { return nil }
        return try? JSONDecoder().decode(PendingJob.self, from: data)
    }

    private static func write(_ job: PendingJob, in directory: URL) throws {
        let data = try JSONEncoder().encode(job)
        try data.write(to: metadataURL(in: directory), options: [.atomic, .completeFileProtection])
    }
}
