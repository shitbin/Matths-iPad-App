//  TutorConversationStore.swift
//  계정별 온디바이스 튜터 대화와 첨부 사진의 복구 저장소.

import Foundation

struct TutorConversationRecord: Codable, Equatable, Identifiable {
    let id: UUID
    let role: String
    var text: String
    var imageFile: String?
    var done: Bool
    let createdAt: Date
}

enum TutorConversationStore {
    static let directoryName = "tutor-conversation"
    static let indexFileName = "messages.json"
    static let maximumAge: TimeInterval = 30 * 24 * 60 * 60
    static let maximumMessages = 60

    private static var directory: URL { DataScope.url(directoryName) }

    static func load(now: Date = Date()) -> [TutorConversationRecord] {
        load(in: directory, now: now)
    }

    static func load(in directory: URL, now: Date = Date()) -> [TutorConversationRecord] {
        let index = directory.appendingPathComponent(indexFileName)
        guard let data = try? Data(contentsOf: index),
              var records = try? JSONDecoder().decode([TutorConversationRecord].self, from: data)
        else { return [] }

        let cutoff = now.addingTimeInterval(-maximumAge)
        records = Array(records
            .filter { $0.createdAt >= cutoff && ($0.role == "user" || $0.role == "assistant") }
            .suffix(maximumMessages))

        // 생성 중 앱이 종료된 답변을 빈 말풍선으로 되살리지 않는다. 마지막 사용자
        // 질문까지만 저장되고 죽은 경우도 같은 중단 안내로 대화를 닫는다.
        for index in records.indices where records[index].role == "assistant" && !records[index].done {
            records[index].text = "이전 답변은 앱이 종료되어 중단됐습니다. 같은 질문을 다시 보내 주세요."
            records[index].done = true
        }
        if records.last?.role == "user" {
            records.append(TutorConversationRecord(
                id: UUID(),
                role: "assistant",
                text: "이전 답변은 앱이 종료되어 중단됐습니다. 같은 질문을 다시 보내 주세요.",
                imageFile: nil,
                done: true,
                createdAt: now))
        }
        return Array(records.suffix(maximumMessages))
    }

    static func save(_ records: [TutorConversationRecord]) {
        save(records, in: directory)
    }

    static func save(_ input: [TutorConversationRecord], in directory: URL) {
        let records = Array(input.suffix(maximumMessages))
        do {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(records)
            try data.write(
                to: directory.appendingPathComponent(indexFileName),
                options: [.atomic, .completeFileProtection])
            removeOrphanedAttachments(keeping: Set(records.compactMap(\.imageFile)), in: directory)
        } catch {
            // 대화 저장 실패가 로컬 모델 답변 자체를 막아서는 안 된다.
        }
    }

    /// PhotosPicker 임시 파일은 언제든 사라질 수 있어 슬롯 안으로 먼저 복사한다.
    /// 반환값은 현재 실행에서 바로 비전 모델과 썸네일이 읽을 수 있는 절대 경로다.
    static func importAttachment(from sourcePath: String) throws -> String {
        try importAttachment(from: sourcePath, in: directory)
    }

    static func importAttachment(from sourcePath: String, in directory: URL) throws -> String {
        let source = URL(fileURLWithPath: sourcePath).standardizedFileURL
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if source.deletingLastPathComponent() == directory.standardizedFileURL {
            return source.path
        }
        let destination = directory
            .appendingPathComponent("photo-\(UUID().uuidString).jpg")
            .standardizedFileURL
        let data = try Data(contentsOf: source, options: [.mappedIfSafe])
        try data.write(to: destination, options: [.atomic, .completeFileProtection])

        let temporary = FileManager.default.temporaryDirectory.standardizedFileURL
        if source.deletingLastPathComponent() == temporary,
           source.lastPathComponent.hasPrefix("matths-chat-") {
            try? FileManager.default.removeItem(at: source)
        }
        return destination.path
    }

    static func attachmentPath(for fileName: String) -> String? {
        attachmentPath(for: fileName, in: directory)
    }

    static func attachmentPath(for fileName: String, in directory: URL) -> String? {
        guard fileName == URL(fileURLWithPath: fileName).lastPathComponent else { return nil }
        let url = directory.appendingPathComponent(fileName).standardizedFileURL
        guard url.deletingLastPathComponent() == directory.standardizedFileURL,
              FileManager.default.fileExists(atPath: url.path) else { return nil }
        return url.path
    }

    static func ownedAttachmentName(for path: String?) -> String? {
        ownedAttachmentName(for: path, in: directory)
    }

    static func ownedAttachmentName(for path: String?, in directory: URL) -> String? {
        guard let path else { return nil }
        let url = URL(fileURLWithPath: path).standardizedFileURL
        guard url.deletingLastPathComponent() == directory.standardizedFileURL,
              url.lastPathComponent.hasPrefix("photo-") else { return nil }
        return url.lastPathComponent
    }

    static func clear() {
        try? FileManager.default.removeItem(at: directory)
    }

    private static func removeOrphanedAttachments(keeping names: Set<String>, in directory: URL) {
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: directory.path) else { return }
        for file in files where file.hasPrefix("photo-") && !names.contains(file) {
            try? FileManager.default.removeItem(at: directory.appendingPathComponent(file))
        }
    }
}
