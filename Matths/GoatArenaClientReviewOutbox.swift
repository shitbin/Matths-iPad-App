//  GoatArenaClientReviewOutbox.swift
//  증거 사진을 먼저 접수한 뒤 끝나는 온디바이스 비전 검토의 후속 전송 큐.

import Foundation

@MainActor
enum GoatArenaClientReviewOutbox {
    struct Item: Codable, Identifiable, Equatable {
        let id: String
        let matchId: String
        let evidenceId: String
        let metadata: ServerAPI.GoatArenaClientReviewMetadata
        let completedAt: Date
        let clientBuildVersion: String
        let createdAt: Date
    }

    private struct FinalizedItem: Codable, Equatable {
        let id: String
        let outcome: String
        let finalizedAt: Date
    }

    private static let fileName = "goat-arena-client-review-outbox.json"
    private static let finalizedFileName = "goat-arena-client-review-finalized.json"
    private static var isFlushing = false
    private static var fileURL: URL { DataScope.url(fileName) }
    private static var finalizedFileURL: URL { DataScope.url(finalizedFileName) }

    static func enqueue(_ item: Item) {
        let queueURL = fileURL
        let receiptURL = finalizedFileURL
        guard !finalizedIDs(from: receiptURL).contains(item.id) else { return }
        var values = read(from: queueURL).filter { $0.id != item.id }
        values.append(item)
        write(values, to: queueURL)
    }

    /// 로컬 판정 완료 저장 직후, outbox 저장 전에 프로세스가 종료될 수 있다.
    /// 완료 기록에서 같은 reviewId를 다시 만들어 그 한 줄짜리 crash gap을 메운다.
    /// 서버는 reviewId 멱등이고, 로컬 final receipt가 확인된 항목은 재구성하지 않는다.
    static func recoverCompleted(_ records: [CheatingReviewRecord]) {
        let finalized = finalizedIDs(from: finalizedFileURL)
        for record in records where record.state == .completed {
            guard !finalized.contains(record.id.uuidString),
                  let result = record.result,
                  let delivery = record.arenaDelivery else { continue }
            enqueue(item(
                reviewId: record.id,
                result: result,
                delivery: delivery,
                completedAt: record.finishedAt ?? record.createdAt
            ))
        }
    }

    static func item(
        reviewId: UUID,
        result: CheatingDetectionResult,
        delivery: GoatArenaCheatingReviewDelivery,
        completedAt: Date = Date()
    ) -> Item {
        let spec = ModelDownloader.analysisVisionSpec
        let metadata = ServerAPI.GoatArenaClientReviewMetadata(
            model: spec.shortName,
            modelVersion: spec.file,
            reviewState: result.verdict.rawValue,
            signals: result.verdict == .suspicious
                ? Array(Set(result.evidence.filter(\.isStrong).map { $0.kind.rawValue })).sorted()
                : [])
        return Item(
            id: reviewId.uuidString,
            matchId: delivery.matchId,
            evidenceId: delivery.evidenceId,
            metadata: metadata,
            completedAt: completedAt,
            clientBuildVersion: delivery.clientBuildVersion,
            createdAt: completedAt
        )
    }

    static func flush() async {
        guard !isFlushing else { return }
        isFlushing = true
        let startingSlot = DataScope.slot
        var shouldContinue = false
        // await 중 로그아웃/로그인이 일어나도 다른 계정의 파일을 갱신하지 않도록
        // URL을 시작 슬롯에 고정한다.
        let queueURL = fileURL
        let receiptURL = finalizedFileURL
        defer {
            isFlushing = false
            if DataScope.slot != startingSlot || shouldContinue {
                Task { await flush() }
            }
        }

        // 성공 영수증 저장 뒤 큐 파일 갱신 전에 종료된 경우도 다시 보내지 않는다.
        let stored = read(from: queueURL)
        let finalized = finalizedIDs(from: receiptURL)
        let pending = stored.filter { !finalized.contains($0.id) }
        if pending != stored {
            write(pending, to: queueURL)
        }

        var stoppedForTransientFailure = false
        for item in pending.sorted(by: { $0.createdAt < $1.createdAt }) {
            do {
                _ = try await ServerAPI.submitGoatArenaClientReview(
                    matchId: item.matchId,
                    evidenceId: item.evidenceId,
                    reviewId: item.id,
                    metadata: item.metadata,
                    completedAt: item.completedAt,
                    clientBuildVersion: item.clientBuildVersion)
                markFinalized(item.id, outcome: "delivered", at: receiptURL)
                removeFromQueue(item.id, at: queueURL)
            } catch let error as ServerAPIError {
                // 인증/망 장애는 다음 foreground에서 같은 reviewId로 재시도한다.
                // 대상 소멸·형식 충돌은 영구 실패라 개인정보가 큐에 남지 않게 폐기한다.
                // 코드 없는 404(HTTP_404)도 영구 실패로 다룬다 — 예전에는 Cafe24 배포 지연을
                // 기다리려고 재시도했지만, 신 서버는 이 라우트를 아예 제공하지 않아
                // foreground 마다 같은 실패를 반복하며 검토 메타데이터만 큐에 남았다.
                if let outcome = permanentOutcome(for: error) {
                    markFinalized(item.id, outcome: outcome, at: receiptURL)
                    removeFromQueue(item.id, at: queueURL)
                    continue
                }
                stoppedForTransientFailure = true
                break
            } catch {
                stoppedForTransientFailure = true
                break
            }
        }

        // flush가 await 중일 때 새 항목이 들어오면 stale snapshot으로 덮어쓰지 않고,
        // 이번 전송이 정상 종료된 경우에만 곧바로 다음 batch를 처리한다.
        shouldContinue = !stoppedForTransientFailure && !read(from: queueURL).isEmpty
    }

    private static func read(from url: URL) -> [Item] {
        guard let data = try? Data(contentsOf: url),
              let values = try? JSONDecoder().decode([Item].self, from: data)
        else { return [] }
        let cutoff = Date().addingTimeInterval(-30 * 24 * 60 * 60)
        return values.filter { $0.createdAt >= cutoff }
    }

    private static func write(_ input: [Item], to url: URL) {
        let values = Array(input.sorted { $0.createdAt > $1.createdAt }.prefix(25))
        guard let data = try? JSONEncoder().encode(values) else { return }
        try? data.write(to: url, options: [.atomic, .completeFileProtection])
    }

    private static func removeFromQueue(_ id: String, at url: URL) {
        let values = read(from: url).filter { $0.id != id }
        write(values, to: url)
    }

    private static func permanentOutcome(for error: ServerAPIError) -> String? {
        let code = error.code ?? ""
        let permanentCodes: Set<String> = [
            "ARENA_EVIDENCE_NOT_FOUND",
            "ARENA_CLIENT_REVIEW_CONFLICT",
            "ARENA_CLIENT_REVIEW_LIMIT",
            "INVALID_ARENA_CLIENT_REVIEW_TARGET",
            "INVALID_ARENA_CLIENT_REVIEW",
            "GOAT_ARENA_COMMAND_INPUT_INVALID",
            "GOAT_ARENA_MATCH_NOT_FOUND",
        ]
        if permanentCodes.contains(code) {
            return "terminal-\(code)"
        }
        // 라우트 없음(HTTP_404)은 재시도해도 결과가 같다 — 큐에 개인 검토 정보를 남기지 않는다.
        if error.isRouteMissing {
            return "terminal-route-missing"
        }
        guard let status = error.statusCode else { return nil }
        if status == 400 || status == 409 || status == 410 || status == 422 {
            return "terminal-\(status)"
        }
        return nil
    }

    private static func finalizedIDs(from url: URL) -> Set<String> {
        guard let data = try? Data(contentsOf: url),
              let values = try? JSONDecoder().decode([FinalizedItem].self, from: data)
        else { return [] }
        let cutoff = Date().addingTimeInterval(-30 * 24 * 60 * 60)
        return Set(values.filter { $0.finalizedAt >= cutoff }.map(\.id))
    }

    private static func markFinalized(_ id: String, outcome: String, at url: URL) {
        let current: [FinalizedItem]
        if let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode([FinalizedItem].self, from: data) {
            current = decoded
        } else {
            current = []
        }
        var values = current.filter { $0.id != id }
        values.append(FinalizedItem(id: id, outcome: outcome, finalizedAt: Date()))
        let cutoff = Date().addingTimeInterval(-30 * 24 * 60 * 60)
        values = Array(values
            .filter { $0.finalizedAt >= cutoff }
            .sorted { $0.finalizedAt > $1.finalizedAt }
            .prefix(64))
        guard let data = try? JSONEncoder().encode(values) else { return }
        try? data.write(to: url, options: [.atomic, .completeFileProtection])
    }
}
