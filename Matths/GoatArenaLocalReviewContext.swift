//
//  GoatArenaLocalReviewContext.swift
//  Matths
//
//  GOAT Arena 증거 사진의 로컬 비전 검토에 필요한 최소 공개 맥락.
//  학생에게 이미 공개된 지문과 학생 본인의 답만 잠시 보관한다.
//  서버 정본인 정답·해설·점수는 이 모델에 넣을 필드 자체를 두지 않는다.
//

import Foundation

struct GoatArenaLocalReviewQuestion: Codable, Equatable, Sendable {
    let slot: Int
    let questionVersionId: String
    let statement: String
    let inputMode: String
    let studentAnswer: String
}

struct GoatArenaLocalReviewContext: Codable, Equatable, Sendable {
    let matchId: String
    let attemptId: String
    let questions: [GoatArenaLocalReviewQuestion]
    let updatedAt: Date

    func merging(_ question: GoatArenaLocalReviewQuestion, at date: Date = Date()) -> Self {
        var bySlot = Dictionary(uniqueKeysWithValues: questions.map { ($0.slot, $0) })
        bySlot[question.slot] = question
        return .init(
            matchId: matchId,
            attemptId: attemptId,
            questions: bySlot.values.sorted { $0.slot < $1.slot },
            updatedAt: date
        )
    }

    var cheatingProblemContext: CheatingProblemContext {
        let ordered = questions.sorted { $0.slot < $1.slot }
        let statements = ordered.map { question in
            let statement = question.statement.count <= 82
                ? question.statement
                : String(question.statement.prefix(82)) + "…"
            return "문항 \(question.slot) [\(question.inputMode)]: \(statement)"
        }
        let answers = ordered.map { question in
            let value = question.studentAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
            return "문항 \(question.slot): \(value.isEmpty ? "미입력" : value)"
        }
        return CheatingProblemContext(
            statement: statements.joined(separator: "\n\n"),
            expectedAnswer: "",
            referenceSteps: [],
            studentFinalAnswer: answers.joined(separator: "\n"),
            studentSubmittedAnswers: ordered.compactMap { question in
                let value = question.studentAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
                return value.isEmpty ? nil : value
            },
            requiresWork: true
        )
    }

    static func visualOnlyProblemContext() -> CheatingProblemContext {
        CheatingProblemContext(
            statement: "이전 앱 버전에서 시작된 경기라 공개 문항 맥락을 복구하지 못했습니다. 제출된 손글씨 사진의 시각적 무결성만 검토하세요.",
            expectedAnswer: "",
            referenceSteps: [],
            studentFinalAnswer: nil,
            studentSubmittedAnswers: [],
            requiresWork: true
        )
    }
}

enum GoatArenaLocalReviewContextStore {
    private static let fileName = "goat-arena-local-review-contexts.json"
    private static let retention: TimeInterval = 24 * 60 * 60

    private static var fileURL: URL { DataScope.url(fileName) }

    static func load(matchId: String, attemptId: String, now: Date = Date()) -> GoatArenaLocalReviewContext? {
        readAll(now: now).first {
            $0.matchId == matchId && $0.attemptId == attemptId
        }
    }

    @discardableResult
    static func merge(
        matchId: String,
        attemptId: String,
        question: GoatArenaLocalReviewQuestion,
        now: Date = Date()
    ) -> GoatArenaLocalReviewContext {
        var values = readAll(now: now)
        let existing = values.first {
            $0.matchId == matchId && $0.attemptId == attemptId
        } ?? GoatArenaLocalReviewContext(
            matchId: matchId,
            attemptId: attemptId,
            questions: [],
            updatedAt: now
        )
        let merged = existing.merging(question, at: now)
        values.removeAll {
            $0.matchId == matchId && $0.attemptId == attemptId
        }
        values.append(merged)
        write(values)
        return merged
    }

    static func clear(matchId: String, attemptId: String) {
        write(readAll().filter {
            !($0.matchId == matchId && $0.attemptId == attemptId)
        })
    }

    private static func readAll(now: Date = Date()) -> [GoatArenaLocalReviewContext] {
        guard let data = try? Data(contentsOf: fileURL),
              let values = try? JSONDecoder().decode(
                [GoatArenaLocalReviewContext].self,
                from: data
              ) else {
            return []
        }
        let retained = values.filter {
            now.timeIntervalSince($0.updatedAt) <= retention
        }
        if retained.count != values.count {
            write(retained)
        }
        return retained
    }

    private static func write(_ values: [GoatArenaLocalReviewContext]) {
        guard let data = try? JSONEncoder().encode(values) else { return }
        try? data.write(
            to: fileURL,
            options: [.atomic, .completeFileProtection]
        )
    }
}
