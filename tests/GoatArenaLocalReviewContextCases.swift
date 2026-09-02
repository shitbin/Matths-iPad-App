import Foundation

// 제품 DataScope 대신 격리된 임시 디렉터리만 쓰는 테스트 대역.
enum DataScope {
    static let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("matths-arena-review-\(UUID().uuidString)", isDirectory: true)

    static func url(_ name: String) -> URL {
        root.appendingPathComponent(name)
    }
}

@main
struct GoatArenaLocalReviewContextCases {
    static func main() throws {
        try FileManager.default.createDirectory(
            at: DataScope.root,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: DataScope.root) }

        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let base = GoatArenaLocalReviewContext(
            matchId: "match-1",
            attemptId: "attempt-1",
            questions: [],
            updatedAt: now
        )
        let q2 = GoatArenaLocalReviewQuestion(
            slot: 2,
            questionVersionId: "qv-2",
            statement: "두 번째 공개 지문",
            inputMode: "SHORT_ANSWER",
            studentAnswer: "17"
        )
        let q1 = GoatArenaLocalReviewQuestion(
            slot: 1,
            questionVersionId: "qv-1",
            statement: "첫 번째 공개 지문",
            inputMode: "SHORT_ANSWER",
            studentAnswer: "42"
        )
        let merged = base.merging(q2, at: now).merging(q1, at: now)
        precondition(merged.questions.map(\.slot) == [1, 2])

        let review = merged.cheatingProblemContext
        precondition(review.expectedAnswer.isEmpty)
        precondition(review.referenceSteps.isEmpty)
        precondition(review.studentSubmittedAnswers == ["42", "17"])
        precondition(review.statement.contains("첫 번째 공개 지문"))
        precondition(review.statement.contains("두 번째 공개 지문"))

        let storedJSON = String(
            decoding: try JSONEncoder().encode(merged),
            as: UTF8.self
        )
        precondition(!storedJSON.contains("expectedAnswer"))
        precondition(!storedJSON.contains("referenceSteps"))

        _ = GoatArenaLocalReviewContextStore.merge(
            matchId: merged.matchId,
            attemptId: merged.attemptId,
            question: q1,
            now: now
        )
        _ = GoatArenaLocalReviewContextStore.merge(
            matchId: merged.matchId,
            attemptId: merged.attemptId,
            question: q2,
            now: now
        )
        precondition(
            GoatArenaLocalReviewContextStore.load(
                matchId: merged.matchId,
                attemptId: merged.attemptId,
                now: now
            )?.questions.count == 2
        )

        GoatArenaLocalReviewContextStore.clear(
            matchId: merged.matchId,
            attemptId: merged.attemptId
        )
        precondition(
            GoatArenaLocalReviewContextStore.load(
                matchId: merged.matchId,
                attemptId: merged.attemptId,
                now: now
            ) == nil
        )

        _ = GoatArenaLocalReviewContextStore.merge(
            matchId: "expired",
            attemptId: "expired-attempt",
            question: q1,
            now: now.addingTimeInterval(-25 * 60 * 60)
        )
        precondition(
            GoatArenaLocalReviewContextStore.load(
                matchId: "expired",
                attemptId: "expired-attempt",
                now: now
            ) == nil
        )

        print("GOAT Arena local review context cases passed")
    }
}
