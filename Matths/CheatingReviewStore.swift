//  CheatingReviewStore.swift
//  Matths
//
//  계정별 온디바이스 풀이 무결성 검토 기록.
//  서버에는 보내지 않으며, 최근 기록과 좌표 근거를 기기 안에만 보관한다.

import Foundation
import UIKit

@MainActor
enum CheatingReviewDisk {
    private static var dir: URL {
        let url = DataScope.url("cheating-reviews")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private static var imagesDir: URL {
        let url = dir.appendingPathComponent("images", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private static var indexURL: URL { dir.appendingPathComponent("index.json") }

    /// 일반 검토는 중단으로 닫고, 서버 증거와 연결된 GOAT 검토만 보존 이미지·맥락·
    /// 전송 대상이 모두 있을 때 다음 실행에서 안전하게 처음부터 다시 시작한다.
    static func loadRecoveringInterrupted() -> [CheatingReviewRecord] {
        guard let data = try? Data(contentsOf: indexURL),
              var records = try? JSONDecoder().decode([CheatingReviewRecord].self, from: data)
        else { return [] }

        let hadInterrupted = records.contains {
            $0.state == .pending && !isResumableArenaReview($0)
        }
        if hadInterrupted {
            for i in records.indices where !isResumableArenaReview(records[i]) {
                records[i].recoverInterrupted()
            }
        }
        // pending이 없어도 시작 시점에 보존 기간을 적용한다. 그렇지 않으면 새 기록이
        // 생기지 않는 기기에서 오래된 풀이 사진이 계속 남는다.
        save(records)
        return loadWithoutRecovery().sorted { $0.createdAt > $1.createdAt }
    }

    static func begin(source: CheatingReviewSource,
                      problemID: String?,
                      context: CheatingProblemContext,
                      imageData: Data,
                      arenaDelivery: GoatArenaCheatingReviewDelivery? = nil)
    -> (record: CheatingReviewRecord, imagePath: String?) {
        let id = UUID()
        let imageFile = writeReviewImage(imageData, id: id)
        let record = CheatingReviewRecord.pending(
            source: source, problemID: problemID,
            problemStatement: context.statement,
            studentFinalAnswer: context.studentFinalAnswer,
            imageFile: imageFile,
            problemContext: arenaDelivery == nil ? nil : context,
            arenaDelivery: arenaDelivery,
            id: id)
        var records = loadWithoutRecovery()
        records.insert(record, at: 0)
        save(records)
        return (record, imageFile.map { imagesDir.appendingPathComponent($0).path })
    }

    static func begin(source: CheatingReviewSource,
                      problemID: String?,
                      context: CheatingProblemContext,
                      existingImagePath: String) -> (record: CheatingReviewRecord, imagePath: String?) {
        let data = try? Data(contentsOf: URL(fileURLWithPath: existingImagePath))
        return begin(source: source, problemID: problemID, context: context, imageData: data ?? Data())
    }

    /// 완료는 pending 기록에만 쓸 수 있다. 백그라운드 중단 뒤 늦게 돌아온 모델 출력은 버린다.
    static func finish(id: UUID, result: CheatingDetectionResult) -> [CheatingReviewRecord] {
        var records = loadWithoutRecovery()
        guard let i = records.firstIndex(where: { $0.id == id }), records[i].state == .pending
        else { return records.sorted { $0.createdAt > $1.createdAt } }
        records[i].finish(result)
        save(records)
        return records.sorted { $0.createdAt > $1.createdAt }
    }

    static func interruptPending(reason: String) -> [CheatingReviewRecord] {
        var records = loadWithoutRecovery()
        var changed = false
        for i in records.indices where records[i].state == .pending {
            records[i].finish(.inconclusive(reason))
            changed = true
        }
        if changed { save(records) }
        return records.sorted { $0.createdAt > $1.createdAt }
    }

    static func imageURL(for record: CheatingReviewRecord) -> URL? {
        record.imageFile.map { imagesDir.appendingPathComponent($0) }
    }

    private static func isResumableArenaReview(_ record: CheatingReviewRecord) -> Bool {
        record.state == .pending &&
            record.source == .goatArenaEvidence &&
            record.problemContext != nil &&
            record.arenaDelivery != nil &&
            record.imageFile != nil
    }

    private static func loadWithoutRecovery() -> [CheatingReviewRecord] {
        guard let data = try? Data(contentsOf: indexURL),
              let records = try? JSONDecoder().decode([CheatingReviewRecord].self, from: data)
        else { return [] }
        return records
    }

    private static func save(_ input: [CheatingReviewRecord]) {
        // 축소본이어도 학생 풀이 원본이다. 최근 30일·30건만 기기 안에 둔다.
        let cutoff = Date().addingTimeInterval(-30 * 24 * 60 * 60)
        let records = Array(input
            .filter { $0.createdAt >= cutoff }
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(30))
        let kept = Set(records.compactMap(\.imageFile))
        if let files = try? FileManager.default.contentsOfDirectory(atPath: imagesDir.path) {
            for file in files where !kept.contains(file) {
                try? FileManager.default.removeItem(at: imagesDir.appendingPathComponent(file))
            }
        }
        guard let data = try? JSONEncoder().encode(records) else { return }
        try? data.write(to: indexURL, options: [.atomic, .completeFileProtection])
    }

    private static func writeReviewImage(_ data: Data, id: UUID) -> String? {
        guard !data.isEmpty,
              let image = PhotoDownsampler.image(from: data, maxPixel: PhotoIntake.maxPixel)
        else { return nil }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let flattened = UIGraphicsImageRenderer(size: image.size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: image.size))
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
        guard let jpeg = flattened.jpegData(compressionQuality: 0.84) else { return nil }
        let name = "\(id.uuidString).jpg"
        do {
            try jpeg.write(
                to: imagesDir.appendingPathComponent(name),
                options: [.atomic, .completeFileProtection])
            return name
        } catch {
            return nil
        }
    }
}
