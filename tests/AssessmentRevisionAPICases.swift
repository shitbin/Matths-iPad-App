import Foundation

// Controlled wire boundary only. The production native DTO/body construction,
// dirty baseline and ACK/merge logic are compiled unchanged below.
enum RevisionFixtureError: Error { case conflict }
enum ServerAPI {
    struct AuthorizationSnapshot {}
    static var revision = 0
    static var answer = ""
    static var status = "in-progress"
    static var includesRevision = true
    static var sentBodies: [[String: Any]] = []
    static func authorizationForCurrentRequest() -> AuthorizationSnapshot { .init() }
    static func remote() -> RemoteAssessment {
        let terminal = status != "in-progress"
        let q = RemoteAssessment.Question(id: "q1", number: 1, typeKey: "fixture", prompt: "3+4", choices: [], answer: "", points: 3, solution: "", submittedAnswer: answer, isCorrect: nil)
        return RemoteAssessment(id: "attempt", scope: "subunit", courseId: "common-math-1", unitId: "u", subunitId: "s", title: "Fixture", status: status, questions: [q], answers: [answer], startedAt: "2026-09-07T00:00:00Z", deadlineAt: "2026-09-07T00:10:00Z", submittedAt: terminal ? "2026-09-07T00:03:00Z" : nil, scorePercent: terminal ? 0 : nil, passed: terminal ? false : nil, timeLimitMs: 600000, disqualified: status == "disqualified", updatedAt: "2026-09-07T00:03:00Z", mutationRevision: includesRevision ? revision : nil)
    }
    static func request<T: Decodable>(_ method: String, _ path: String, body: [String: Any]?, authed: Bool,
                                      authorization: AuthorizationSnapshot) async throws -> T {
        precondition(authed)
        if let body {
            sentBodies.append(body)
            if status == "in-progress", let expected = body["expectedRevision"] as? Int, expected != revision {
                throw RevisionFixtureError.conflict
            }
            if status == "in-progress" {
                if let next = (body["answers"] as? [String: String])?["q1"] { answer = next }
                revision += 1
                if path.hasSuffix("/submit") { status = "submitted" }
                if path.hasSuffix("/expire") { status = "disqualified" }
            }
        }
        let data: Data
        if path.hasSuffix("/draft") {
            var receipt: [String: Any] = ["savedAt": "2026-09-07T00:03:00Z", "elapsedTimeMs": 180000]
            if includesRevision { receipt["mutationRevision"] = revision }
            data = try JSONSerialization.data(withJSONObject: ["draft": receipt])
        } else { data = try JSONEncoder().encode(["assessment": remote()]) }
        return try JSONDecoder().decode(T.self, from: data)
    }
}

@main enum AssessmentRevisionAPICases {
    static func main() async throws {
        let baseline = try await ServerAPI.assessmentAttempt("attempt")
        precondition(baseline.localValue()?.serverMutationRevision == 0, "Known server revision zero was mistaken for missing")
        var first = AssessmentDraftRecovery(), second = AssessmentDraftRecovery()
        first.edit(questionID: "q1", answer: "7", expectedRevision: baseline.mutationRevision)
        second.edit(questionID: "q1", answer: "9", expectedRevision: baseline.mutationRevision)
        let ack = try await ServerAPI.saveAssessmentDraft(id: "attempt", answers: first.pending, expectedRevision: first.baseRevision)
        precondition(ack.mutationRevision == 1 && ServerAPI.sentBodies.last?["expectedRevision"] as? Int == 0)
        do {
            _ = try await ServerAPI.saveAssessmentDraft(id: "attempt", answers: second.pending, expectedRevision: second.baseRevision)
            preconditionFailure("Stale native draft omitted its original revision")
        } catch RevisionFixtureError.conflict {}
        precondition(ServerAPI.answer == "7" && second.pending == ["q1": "9"])
        for operation in ["submit", "expire"] {
            do {
                if operation == "submit" { _ = try await ServerAPI.submitAssessment(id: "attempt", answers: second.pending, expectedRevision: second.baseRevision) }
                else { _ = try await ServerAPI.expireAssessment(id: "attempt", answers: second.pending, expectedRevision: second.baseRevision) }
                preconditionFailure("Stale native terminal mutation omitted its original revision")
            } catch RevisionFixtureError.conflict {}
        }
        let count = ServerAPI.sentBodies.count
        for invalid in [-1, AssessmentMutationRevision.maximumSafeInteger] {
            do {
                _ = try await ServerAPI.saveAssessmentDraft(id: "attempt", answers: [:], expectedRevision: invalid)
                preconditionFailure("Invalid expected revision reached transport")
            } catch is CocoaError {}
        }
        precondition(ServerAPI.sentBodies.count == count)
        let latest = try await ServerAPI.assessmentAttempt("attempt")
        var reviewed = AssessmentDraftRecovery()
        reviewed.edit(questionID: "q1", answer: "9", expectedRevision: latest.mutationRevision)
        let accepted = try await ServerAPI.saveAssessmentDraft(id: "attempt", answers: reviewed.pending, expectedRevision: reviewed.baseRevision)
        precondition(accepted.mutationRevision == 2 && ServerAPI.answer == "9")

        ServerAPI.includesRevision = false
        let legacy = try await ServerAPI.assessmentAttempt("attempt")
        precondition(legacy.mutationRevision == nil && legacy.localValue()?.serverMutationRevision == nil)
        let legacyAck = try await ServerAPI.saveAssessmentDraft(id: "attempt", answers: ["q1": "legacy"], expectedRevision: nil)
        precondition(legacyAck.mutationRevision == nil)
        precondition(ServerAPI.sentBodies.last?.keys.contains("expectedRevision") == false, "Unknown legacy revision became zero or JSON null")
        var invalidDTO = latest
        invalidDTO.mutationRevision = -1; precondition(invalidDTO.localValue() == nil)
        invalidDTO.mutationRevision = AssessmentMutationRevision.maximumSafeInteger + 1
        precondition(invalidDTO.localValue() == nil)
        print("Native assessment revision wire: known zero, dirty CAS on draft/submit/expire, sequential conflict preservation, explicit latest review, safe integer bounds and legacy key omission: PASS (controlled HTTP boundary)")
    }
}
