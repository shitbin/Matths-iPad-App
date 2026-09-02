import Foundation

extension ServerAPI {
    struct RemoteAssessment: Codable {
        struct Question: Codable {
            var id: String
            var number: Int
            var typeKey: String
            var prompt: String
            var choices: [String]
            var answer: String
            var points: Int
            var solution: String
            var submittedAnswer: String
            var isCorrect: Bool?
        }

        var id: String
        var scope: String
        var courseId: String
        var unitId: String?
        var subunitId: String?
        var title: String
        var status: String
        var questions: [Question]
        var answers: [String]
        var startedAt: String?
        var deadlineAt: String?
        var submittedAt: String?
        var scorePercent: Int?
        var passed: Bool?
        var timeLimitMs: Int?
        var disqualified: Bool
        var updatedAt: String?

        func localValue() -> AssessmentAttemptV2? {
            guard let paperScope = PaperScope(rawValue: scope) else { return nil }
            let started = Self.date(startedAt) ?? Date()
            let submitted = Self.date(submittedAt)
            return AssessmentAttemptV2(
                id: id,
                scope: paperScope,
                courseId: courseId,
                unitId: unitId,
                subunitId: subunitId,
                title: title,
                questions: questions.map {
                    PaperQuestion(
                        no: $0.number,
                        typeKey: $0.typeKey,
                        prompt: $0.prompt,
                        choices: $0.choices.isEmpty ? nil : $0.choices,
                        answer: $0.answer,
                        points: $0.points,
                        solution: $0.solution,
                        serverQuestionId: $0.id)
                },
                answers: answers,
                submittedAt: submitted,
                scorePercent: scorePercent,
                passed: passed,
                createdAt: started,
                timeLimitMs: timeLimitMs,
                disqualified: disqualified,
                serverBacked: true,
                serverUpdatedAt: Self.date(updatedAt))
        }

        private static func date(_ value: String?) -> Date? {
            guard let value else { return nil }
            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return fractional.date(from: value) ?? ISO8601DateFormatter().date(from: value)
        }
    }

    private struct AssessmentEnvelope: Codable { var assessment: RemoteAssessment }
    private struct AssessmentsEnvelope: Codable { var assessments: [RemoteAssessment] }
    private struct AssessmentDraftEnvelope: Codable {
        struct Draft: Codable { var savedAt: String?; var elapsedTimeMs: Int?; var status: String?; var expired: Bool? }
        var draft: Draft
    }

    static func assessmentSnapshot() async throws -> [RemoteAssessment] {
        let value: AssessmentsEnvelope = try await request(
            "GET", "/api/v1/assessments", body: nil, authed: true)
        return value.assessments
    }

    static func startAssessment(scope: PaperScope, courseId: String,
                                unitId: String?, subunitId: String?,
                                clientStartId: String) async throws -> RemoteAssessment {
        var body: [String: Any] = [
            "scopeType": scope.rawValue,
            "courseId": courseId,
            "clientStartId": clientStartId,
        ]
        if let unitId { body["unitId"] = unitId }
        if let subunitId { body["subunitId"] = subunitId }
        let value: AssessmentEnvelope = try await request(
            "POST", "/api/v1/assessments/start", body: body, authed: true)
        return value.assessment
    }

    static func assessmentAttempt(_ id: String) async throws -> RemoteAssessment {
        let value: AssessmentEnvelope = try await request(
            "GET", "/api/v1/assessments/\(id)", body: nil, authed: true)
        return value.assessment
    }

    static func saveAssessmentDraft(id: String, answers: [String: String]) async throws {
        let _: AssessmentDraftEnvelope = try await request(
            "PATCH", "/api/v1/assessments/\(id)/draft",
            body: ["answers": answers], authed: true)
    }

    static func submitAssessment(id: String, answers: [String: String]) async throws -> RemoteAssessment {
        let value: AssessmentEnvelope = try await request(
            "POST", "/api/v1/assessments/\(id)/submit",
            body: ["answers": answers], authed: true)
        return value.assessment
    }

    static func expireAssessment(id: String, answers: [String: String]) async throws -> RemoteAssessment {
        let value: AssessmentEnvelope = try await request(
            "POST", "/api/v1/assessments/\(id)/expire",
            body: ["answers": answers], authed: true)
        return value.assessment
    }
}

enum AssessmentSyncPayload {
    static func answers(for attempt: AssessmentAttemptV2) -> [String: String] {
        var result: [String: String] = [:]
        for (index, question) in attempt.questions.enumerated()
        where attempt.answers.indices.contains(index) {
            result[question.serverQuestionId ?? String(question.no)] = attempt.answers[index]
        }
        return result
    }
}
