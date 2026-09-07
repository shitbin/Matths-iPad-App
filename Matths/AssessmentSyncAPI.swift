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
        var mutationRevision: Int? = nil

        var serverModifiedAt: Date? { Self.date(updatedAt) }

        func localValue() -> AssessmentAttemptV2? {
            guard let paperScope = PaperScope(rawValue: scope), !id.isEmpty, !courseId.isEmpty,
                  ["in-progress", "submitted", "disqualified"].contains(status),
                  !questions.isEmpty, answers.count == questions.count,
                  Set(questions.map(\.id)).count == questions.count,
                  questions.enumerated().allSatisfy({ $0.element.number == $0.offset + 1 && !$0.element.id.isEmpty }),
                  let started = Self.date(startedAt),
                  mutationRevision.map(AssessmentMutationRevision.isValidServerValue) ?? true else { return nil }
            let submitted = Self.date(submittedAt)
            guard (status == "in-progress") == (submitted == nil),
                  (submitted != nil || timeLimitMs.map({ $0 > 0 }) == true),
                  deadlineAt == nil || Self.date(deadlineAt).map({ $0 > started }) == true else { return nil }
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
                serverUpdatedAt: Self.date(updatedAt),
                serverDeadlineAt: Self.date(deadlineAt),
                pendingDraft: AssessmentDraftRecovery(),
                serverMutationRevision: mutationRevision)
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
    struct AssessmentDraftReceipt: Codable {
        var savedAt: String?; var elapsedTimeMs: Int?; var status: String?; var expired: Bool?
        var mutationRevision: Int? = nil
        var savedDate: Date? {
            guard let savedAt else { return nil }
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return formatter.date(from: savedAt) ?? ISO8601DateFormatter().date(from: savedAt)
        }
    }
    private struct AssessmentDraftEnvelope: Codable {
        var draft: AssessmentDraftReceipt
    }

    static func assessmentSnapshot(authorization: AuthorizationSnapshot = ServerAPI.authorizationForCurrentRequest()) async throws -> [RemoteAssessment] {
        let value: AssessmentsEnvelope = try await request(
            "GET", "/api/v1/assessments", body: nil, authed: true, authorization: authorization)
        return value.assessments
    }

    static func startAssessment(scope: PaperScope, courseId: String,
                                unitId: String?, subunitId: String?,
                                clientStartId: String,
                                authorization: AuthorizationSnapshot = ServerAPI.authorizationForCurrentRequest()) async throws -> RemoteAssessment {
        var body: [String: Any] = [
            "scopeType": scope.rawValue,
            "courseId": courseId,
            "clientStartId": clientStartId,
        ]
        if let unitId { body["unitId"] = unitId }
        if let subunitId { body["subunitId"] = subunitId }
        let value: AssessmentEnvelope = try await request(
            "POST", "/api/v1/assessments/start", body: body, authed: true, authorization: authorization)
        return value.assessment
    }

    static func assessmentAttempt(_ id: String, authorization: AuthorizationSnapshot = ServerAPI.authorizationForCurrentRequest()) async throws -> RemoteAssessment {
        let value: AssessmentEnvelope = try await request(
            "GET", "/api/v1/assessments/\(id)", body: nil, authed: true, authorization: authorization)
        return value.assessment
    }

    @discardableResult
    static func saveAssessmentDraft(id: String, answers: [String: String], expectedRevision: Int? = nil,
                                    authorization: AuthorizationSnapshot = ServerAPI.authorizationForCurrentRequest()) async throws -> AssessmentDraftReceipt {
        let value: AssessmentDraftEnvelope = try await request(
            "PATCH", "/api/v1/assessments/\(id)/draft",
            body: assessmentMutationBody(answers, expectedRevision: expectedRevision), authed: true, authorization: authorization)
        guard value.draft.mutationRevision.map(AssessmentMutationRevision.isValidServerValue) ?? true else {
            throw CocoaError(.coderInvalidValue)
        }
        return value.draft
    }

    static func submitAssessment(id: String, answers: [String: String], expectedRevision: Int? = nil,
                                 authorization: AuthorizationSnapshot = ServerAPI.authorizationForCurrentRequest()) async throws -> RemoteAssessment {
        let value: AssessmentEnvelope = try await request(
            "POST", "/api/v1/assessments/\(id)/submit",
            body: assessmentMutationBody(answers, expectedRevision: expectedRevision), authed: true, authorization: authorization)
        return value.assessment
    }

    static func expireAssessment(id: String, answers: [String: String], expectedRevision: Int? = nil,
                                 authorization: AuthorizationSnapshot = ServerAPI.authorizationForCurrentRequest()) async throws -> RemoteAssessment {
        let value: AssessmentEnvelope = try await request(
            "POST", "/api/v1/assessments/\(id)/expire",
            body: assessmentMutationBody(answers, expectedRevision: expectedRevision), authed: true, authorization: authorization)
        return value.assessment
    }

    private static func assessmentMutationBody(_ answers: [String: String], expectedRevision: Int?) throws -> [String: Any] {
        var body: [String: Any] = ["answers": answers]
        if let expectedRevision {
            guard AssessmentMutationRevision.isValidExpectedValue(expectedRevision) else { throw CocoaError(.coderInvalidValue) }
            body["expectedRevision"] = expectedRevision
        }
        return body
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
