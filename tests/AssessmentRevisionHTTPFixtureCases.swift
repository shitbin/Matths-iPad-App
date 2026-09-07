import Foundation

struct RevisionHTTPError: Error { let status: Int; let code: String? }
enum ServerAPI {
    struct AuthorizationSnapshot { let token: String }
    static var origin: URL!
    static var token = ""
    static func authorizationForCurrentRequest() -> AuthorizationSnapshot { .init(token: token) }
    static func request<T: Decodable>(_ method: String, _ path: String, body: [String: Any]?, authed: Bool,
                                      authorization: AuthorizationSnapshot) async throws -> T {
        precondition(path.hasPrefix("/api/v1/assessments"), "Fixture transport is assessment-only")
        var request = URLRequest(url: origin.appendingPathComponent(path))
        request.httpMethod = method; request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if authed { request.setValue("Bearer \(authorization.token)", forHTTPHeaderField: "Authorization") }
        if let body { request.httpBody = try JSONSerialization.data(withJSONObject: body) }
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            throw RevisionHTTPError(status: status, code: object?["code"] as? String)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}

@main enum AssessmentRevisionHTTPFixtureCases {
    static func main() async throws {
        guard CommandLine.arguments.count == 2 else { throw CocoaError(.fileReadInvalidFileName) }
        let manifestURL = URL(fileURLWithPath: CommandLine.arguments[1])
        let attributes = try FileManager.default.attributesOfItem(atPath: manifestURL.path)
        guard (attributes[.posixPermissions] as? NSNumber)?.intValue == 0o600,
              let manifest = try JSONSerialization.jsonObject(with: Data(contentsOf: manifestURL)) as? [String: Any],
              manifest["fixtureOnly"] as? Bool == true,
              let originText = manifest["origin"] as? String, let origin = URL(string: originText),
              origin.scheme == "http", ["127.0.0.1", "localhost"].contains(origin.host ?? ""), origin.port != nil,
              let accounts = manifest["accounts"] as? [String: [String: Any]],
              let returning = accounts["returningStudent"], let token = returning["token"] as? String, !token.isEmpty,
              let email = returning["email"] as? String, email.hasSuffix("@qa.invalid"),
              let fixtures = manifest["fixtures"] as? [String: Any], let id = fixtures["assessmentAttemptId"] as? String else {
            throw CocoaError(.coderInvalidValue)
        }
        ServerAPI.origin = origin; ServerAPI.token = token
        let original = try await ServerAPI.assessmentAttempt(id)
        guard var first = original.localValue(), first.submittedAt == nil,
              first.remainingSeconds(monotonicElapsed: 0) >= 60,
              let revision = first.serverMutationRevision,
              let questionID = first.questions.first?.serverQuestionId,
              let originalAnswer = first.answers.first else {
            throw CocoaError(.coderInvalidValue)
        }
        var second = first
        first.pendingDraft?.edit(questionID: questionID, answer: "7", expectedRevision: revision)
        second.pendingDraft?.edit(questionID: questionID, answer: "9", expectedRevision: revision)
        let ack = try await ServerAPI.saveAssessmentDraft(id: id, answers: first.pendingDraft!.pending,
                                                        expectedRevision: first.pendingDraft!.baseRevision)
        precondition(ack.mutationRevision == revision + 1)
        do {
            _ = try await ServerAPI.saveAssessmentDraft(id: id, answers: second.pendingDraft!.pending,
                                                      expectedRevision: second.pendingDraft!.baseRevision)
            preconditionFailure("Sequential stale draft overwrote the winner")
        } catch let error as RevisionHTTPError {
            precondition(error.status == 409 && error.code == "ASSESSMENT_DRAFT_CONFLICT")
        }
        do {
            _ = try await ServerAPI.submitAssessment(id: id, answers: second.pendingDraft!.pending,
                                                     expectedRevision: second.pendingDraft!.baseRevision)
            preconditionFailure("Stale native submit was accepted")
        } catch let error as RevisionHTTPError {
            precondition(error.status == 409 && error.code == "ASSESSMENT_WRITE_CONFLICT")
        }
        do {
            _ = try await ServerAPI.expireAssessment(id: id, answers: second.pendingDraft!.pending,
                                                     expectedRevision: second.pendingDraft!.baseRevision)
            preconditionFailure("Stale native expiry was accepted")
        } catch let error as RevisionHTTPError {
            precondition(error.status == 409 && error.code == "ASSESSMENT_WRITE_CONFLICT")
        }
        let winner = try await ServerAPI.assessmentAttempt(id)
        guard let winnerLocal = winner.localValue() else { throw CocoaError(.coderInvalidValue) }
        precondition(winnerLocal.submittedAt == nil && winnerLocal.answers.first == "7")
        precondition(winnerLocal.serverMutationRevision == revision + 1)
        var localStore = AttemptStoreV2(); localStore.upsert(second)
        precondition(localStore.holdPendingDraftForReview(id: id))
        localStore.mergeServerAttempt(winnerLocal)
        precondition(localStore.attempts[0].legacyDraftEvidence?[questionID] == "9")
        precondition(localStore.attempts[0].answers.first == "7")
        precondition(localStore.applyLegacyDraftEvidence(id: id, questionIDs: [questionID]))
        let chosen = localStore.attempts[0].pendingDraft!
        precondition(chosen.baseRevision == revision + 1)
        let accepted = try await ServerAPI.saveAssessmentDraft(id: id, answers: chosen.pending,
                                                             expectedRevision: chosen.baseRevision)
        precondition(accepted.mutationRevision == revision + 2)
        // Leave the dedicated fixture answer as it was, using the new revision;
        // do not finish or regrade the attempt as part of this compatibility test.
        let restored = try await ServerAPI.saveAssessmentDraft(id: id, answers: [questionID: originalAnswer],
                                                              expectedRevision: accepted.mutationRevision)
        precondition(restored.mutationRevision == revision + 3)
        let final = try await ServerAPI.assessmentAttempt(id)
        precondition(final.status == "in-progress" && final.answers.first == originalAnswer)
        print("NATIVE_ASSESSMENT_REVISION_HTTP_PASS: actual native DTO/body + URLSession + loopback Express/Bearer/Mongo; sequential draft/submit/expire stale revision rejected, winner preserved, explicit review accepted, original fixture answer restored. No production endpoint used.")
    }
}
