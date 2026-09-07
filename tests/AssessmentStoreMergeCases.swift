import Foundation

// Network must never run in these domain/adapter tests.
enum ServerAPI {
    struct AuthorizationSnapshot {}
    static func authorizationForCurrentRequest() -> AuthorizationSnapshot { .init() }
    static func request<T: Decodable>(_ method: String, _ path: String, body: [String: Any]?, authed: Bool,
        authorization: AuthorizationSnapshot) async throws -> T { throw URLError(.unsupportedURL) }
}

@main
struct AssessmentStoreMergeCases {
    static func main() throws {
        let q = ServerAPI.RemoteAssessment.Question(id: "q-1", number: 1, typeKey: "fixture", prompt: "3+4", choices: [], answer: "", points: 3, solution: "", submittedAnswer: "", isCorrect: nil)
        var remote = ServerAPI.RemoteAssessment(id: "attempt-a", scope: "subunit", courseId: "common-math-1", unitId: "u", subunitId: "s", title: "Fixture", status: "in-progress", questions: [q], answers: [""], startedAt: "2026-09-07T00:00:00Z", deadlineAt: "2026-09-07T00:10:00Z", submittedAt: nil, scorePercent: nil, passed: nil, timeLimitMs: 600000, disqualified: false, updatedAt: "2026-09-07T00:00:00Z")
        guard var local = remote.localValue() else { throw CocoaError(.coderInvalidValue) }
        precondition(local.serverDeadlineAt?.timeIntervalSince(local.createdAt) == 600)
        var pending = AssessmentDraftRecovery()
        pending.edit(questionID: "q-1", answer: "7")
        local.pendingDraft = pending; local.answers = ["7"]
        var store = AttemptStoreV2(); store.upsert(local)
        store.replaceServerSnapshot([remote.localValue()!])
        precondition(store.attempts.first?.answers == ["7"], "Server refresh overwrote offline answer")
        store.replaceServerSnapshot([])
        precondition(store.attempts.count == 1, "Partial snapshot removed pending work")
        let savedAt = Date(timeIntervalSince1970: 1_788_739_260)
        store.acknowledgeDraft(id: local.id, sent: ["q-1": "older"], savedAt: savedAt)
        precondition(store.attempts.first?.pendingDraft?.pending == ["q-1": "7"])
        // A fresh server terminal result wins, but unconfirmed draft evidence remains.
        remote.status = "submitted"; remote.submittedAt = "2026-09-07T00:02:00Z"
        remote.scorePercent = 79; remote.passed = false
        store.replaceServerSnapshot([remote.localValue()!])
        precondition(store.attempts.first?.scorePercent == 79 && store.attempts.first?.passed == false)
        precondition(store.attempts.first?.answers == [""])
        precondition(store.attempts.first?.pendingDraft?.pending == ["q-1": "7"])
        remote.scorePercent = 80; remote.passed = true; remote.updatedAt = "2026-09-07T00:03:00Z"
        store.replaceServerSnapshot([remote.localValue()!])
        precondition(store.attempts.first?.passed == true)
        remote.status = "in-progress"; remote.submittedAt = nil; remote.updatedAt = "2026-09-07T00:04:00Z"
        store.replaceServerSnapshot([remote.localValue()!])
        precondition(store.attempts.first?.submittedAt != nil, "Late response reopened a submitted assessment")
        remote.status = "abandoned"
        precondition(remote.localValue() == nil)
        remote.status = "in-progress"; remote.answers = []
        precondition(remote.localValue() == nil)
        remote.answers = [""]; remote.startedAt = "malformed"
        precondition(remote.localValue() == nil, "Invalid start date silently became now")
        remote.startedAt = "2026-09-07T00:00:00Z"; remote.deadlineAt = "2026-09-06T00:00:00Z"
        precondition(remote.localValue() == nil)

        remote.deadlineAt = "2026-09-07T00:10:00Z"
        remote.scorePercent = nil; remote.passed = nil; remote.answers = [""]
        let currentServer = remote.localValue()!
        precondition(currentServer.pendingDraft != nil, "Fresh DTO must not masquerade as an old untracked draft")
        var oldBuild = currentServer
        oldBuild.pendingDraft = nil; oldBuild.answers = ["7"]
        let oldData = try JSONEncoder().encode(oldBuild)
        let oldObject = try JSONSerialization.jsonObject(with: oldData) as! [String: Any]
        precondition(!oldObject.keys.contains("pendingDraft"))
        let oldReloaded = try JSONDecoder().decode(AssessmentAttemptV2.self, from: oldData)
        var upgraded = AttemptStoreV2(); upgraded.upsert(oldReloaded)
        upgraded.replaceServerSnapshot([currentServer])
        precondition(upgraded.attempts[0].answers == [""], "Legacy evidence must not become an official answer automatically")
        precondition(upgraded.attempts[0].legacyDraftEvidence == ["q-1": "7"], "Upgrade lost an old offline answer")
        precondition(upgraded.attempts[0].pendingDraft?.isEmpty == true, "Upgrade must not upload ambiguous old answers")
        upgraded.replaceServerSnapshot([])
        precondition(upgraded.attempts.count == 1 && upgraded.attempts[0].hasLegacyDraftEvidence)
        let evidenceReload = try JSONDecoder().decode(AssessmentAttemptV2.self, from: JSONEncoder().encode(upgraded.attempts[0]))
        precondition(evidenceReload.legacyDraftEvidence == ["q-1": "7"], "Process restart lost legacy review evidence")
        precondition(!upgraded.applyLegacyDraftEvidence(id: "a-different-attempt", questionIDs: ["q-1"]))
        precondition(!upgraded.applyLegacyDraftEvidence(id: oldBuild.id, questionIDs: ["unknown-id"]))
        precondition(upgraded.applyLegacyDraftEvidence(id: oldBuild.id, questionIDs: ["q-1"]))
        precondition(upgraded.attempts[0].answers == ["7"] && upgraded.attempts[0].pendingDraft?.pending == ["q-1": "7"])
        precondition(!upgraded.attempts[0].hasLegacyDraftEvidence)
        upgraded.acknowledgeDraft(id: oldBuild.id, sent: ["q-1": ""], savedAt: nil)
        precondition(upgraded.attempts[0].pendingDraft?.pending == ["q-1": "7"], "Old ACK cleared a newly approved recovery")

        // A legacy empty string may be a deliberate offline erase, not no evidence.
        oldBuild.answers = [""]
        var withServerAnswer = currentServer; withServerAnswer.answers = ["9"]
        var clearReview = AttemptStoreV2(); clearReview.upsert(oldBuild)
        clearReview.replaceServerSnapshot([withServerAnswer])
        precondition(clearReview.attempts[0].legacyDraftEvidence == ["q-1": ""])
        precondition(clearReview.attempts[0].answers == ["9"])
        precondition(clearReview.applyLegacyDraftEvidence(id: oldBuild.id, questionIDs: ["q-1"]))
        precondition(clearReview.attempts[0].pendingDraft?.pending == ["q-1": ""])

        var matching = AttemptStoreV2(); matching.upsert(oldBuild)
        matching.replaceServerSnapshot([currentServer])
        precondition(!matching.attempts[0].hasLegacyDraftEvidence, "Equal server/local values do not need a conflict prompt")

        oldBuild.answers = ["7"]
        var terminal = currentServer; terminal.submittedAt = Date(); terminal.passed = true; terminal.scorePercent = 100
        var finalReview = AttemptStoreV2(); finalReview.upsert(oldBuild)
        finalReview.replaceServerSnapshot([terminal])
        precondition(finalReview.attempts[0].answers == [""] && finalReview.attempts[0].passed == true)
        precondition(finalReview.attempts[0].legacyDraftEvidence == ["q-1": "7"])
        precondition(!finalReview.applyLegacyDraftEvidence(id: oldBuild.id, questionIDs: ["q-1"]), "Evidence changed an official terminal result")
        // Direct submit/get receipt is another integration path, outside snapshot merge.
        finalReview.upsert(terminal)
        precondition(finalReview.attempts[0].hasLegacyDraftEvidence, "Direct receipt erased unreviewed evidence")
        finalReview.replaceServerSnapshot([])
        precondition(finalReview.attempts.count == 1 && finalReview.attempts[0].passed == true,
                     "A latest-100 API response removed an older official pass")
        precondition(finalReview.discardLegacyDraftEvidence(id: oldBuild.id))
        precondition(!finalReview.attempts[0].hasLegacyDraftEvidence && finalReview.attempts[0].passed == true)
        finalReview.replaceServerSnapshot([])
        precondition(finalReview.attempts.count == 1, "A clean terminal receipt outside the latest page was removed")
        precondition(!finalReview.discardLegacyDraftEvidence(id: oldBuild.id))

        var cancelled = AttemptStoreV2(); cancelled.upsert(oldBuild)
        let cancellationDate = remote.serverModifiedAt!.addingTimeInterval(60)
        precondition(!cancelled.markServerAbandoned(id: "unknown", updatedAt: cancellationDate))
        precondition(cancelled.markServerAbandoned(id: oldBuild.id, updatedAt: cancellationDate))
        precondition(cancelled.attempts[0].isServerCancelled && cancelled.attempts[0].answers == ["7"])
        precondition(cancelled.attempts[0].legacyDraftEvidence == ["q-1": "7"])
        precondition(cancelled.openAttempt(scopeKey: oldBuild.scopeKey) == nil)
        precondition(!cancelled.applyLegacyDraftEvidence(id: oldBuild.id, questionIDs: ["q-1"]))
        cancelled.replaceServerSnapshot([currentServer])
        precondition(cancelled.attempts[0].isServerCancelled, "Late active snapshot reopened abandoned attempt")
        cancelled.upsert(terminal)
        precondition(cancelled.attempts[0].isServerCancelled && cancelled.attempts[0].submittedAt == nil,
                     "A late submit receipt reopened an explicitly abandoned attempt")
        cancelled.replaceServerSnapshot([])
        precondition(cancelled.attempts.count == 1, "List omission deleted abandoned local evidence")
        let cancelledReload = try JSONDecoder().decode(AssessmentAttemptV2.self, from: JSONEncoder().encode(cancelled.attempts[0]))
        precondition(cancelledReload.isServerCancelled && cancelledReload.hasLegacyDraftEvidence)
        var cancelledPass = AttemptStoreV2(); cancelledPass.upsert(terminal)
        precondition(cancelledPass.passed(scopeKey: terminal.scopeKey))
        precondition(cancelledPass.markServerAbandoned(id: terminal.id, updatedAt: cancellationDate))
        precondition(cancelledPass.submitted(scopeKey: terminal.scopeKey).isEmpty)
        precondition(!cancelledPass.passed(scopeKey: terminal.scopeKey) && cancelledPass.bestScore(scopeKey: terminal.scopeKey) == nil)
        precondition(cancelledPass.avoidedTypeKeys(scopeKey: terminal.scopeKey).isEmpty)
        precondition(cancelledPass.markServerAbandoned(id: terminal.id, updatedAt: cancellationDate.addingTimeInterval(-1)))
        precondition(cancelledPass.attempts[0].serverUpdatedAt == cancellationDate, "An old cancellation receipt regressed the server timestamp")
        var oldCancellation = AttemptStoreV2(); oldCancellation.upsert(currentServer)
        precondition(oldCancellation.markServerAbandoned(id: currentServer.id, updatedAt: currentServer.serverUpdatedAt!.addingTimeInterval(-1)))
        precondition(oldCancellation.openAttempt(scopeKey: currentServer.scopeKey) == nil, "Timestamp ordering overrode explicit terminal cancellation")
        var otherRemote = remote; otherRemote.id = "another-active-attempt"
        let otherActive = otherRemote.localValue()!
        var singleGet = AttemptStoreV2(); singleGet.upsert(currentServer); singleGet.upsert(otherActive)
        singleGet.mergeServerAttempt(withServerAnswer)
        precondition(singleGet.attempts.count == 2, "A single GET removed another clean active attempt")
        precondition(singleGet.attempts.first(where: { $0.id == currentServer.id })?.answers == ["9"])
        precondition(singleGet.attempts.first(where: { $0.id == otherActive.id })?.answers == [""])
        singleGet.replaceServerSnapshot([withServerAnswer])
        precondition(singleGet.attempts.count == 1, "List refresh must retain its distinct missing-active semantics")

        var concurrentDraft = currentServer
        concurrentDraft.answers = ["newest-local"]
        var concurrentPending = AssessmentDraftRecovery()
        concurrentPending.edit(questionID: "q-1", answer: "newest-local")
        concurrentDraft.pendingDraft = concurrentPending
        concurrentDraft.legacyDraftEvidence = ["q-1": "older-local"]
        var conflictStore = AttemptStoreV2(); conflictStore.upsert(concurrentDraft)
        precondition(conflictStore.holdPendingDraftForReview(id: concurrentDraft.id))
        precondition(conflictStore.attempts[0].pendingDraft?.isEmpty == true, "409 must stop automatic replay")
        precondition(conflictStore.attempts[0].legacyDraftEvidence == ["q-1": "newest-local"], "409 lost the edit made during upload")
        conflictStore.mergeServerAttempt(withServerAnswer)
        precondition(conflictStore.attempts[0].answers == ["9"], "Conflict refresh overwrote a different-device winner")
        precondition(conflictStore.attempts[0].legacyDraftEvidence == ["q-1": "newest-local"])
        let conflictReload = try JSONDecoder().decode(AssessmentAttemptV2.self, from: JSONEncoder().encode(conflictStore.attempts[0]))
        precondition(conflictReload.hasLegacyDraftEvidence && conflictReload.pendingDraft?.isEmpty == true)
        precondition(conflictStore.applyLegacyDraftEvidence(id: concurrentDraft.id, questionIDs: ["q-1"]))
        precondition(conflictStore.attempts[0].pendingDraft?.pending == ["q-1": "newest-local"], "Explicit review did not restore retry ownership")
        precondition(!cancelledPass.holdPendingDraftForReview(id: terminal.id), "Cancelled/terminal records cannot become editable recovery")

        var revisionServer = currentServer; revisionServer.serverMutationRevision = 0
        var revisionLocal = revisionServer
        var revisionPending = AssessmentDraftRecovery()
        revisionPending.edit(questionID: "q-1", answer: "7", expectedRevision: revisionLocal.serverMutationRevision)
        revisionLocal.pendingDraft = revisionPending; revisionLocal.answers = ["7"]
        var revisions = AttemptStoreV2(); revisions.upsert(revisionLocal)
        revisionServer.serverMutationRevision = 1; revisionServer.answers = ["other-device"]
        revisions.mergeServerAttempt(revisionServer)
        precondition(revisions.attempts[0].serverMutationRevision == 1)
        precondition(revisions.attempts[0].pendingDraft?.baseRevision == 0, "A GET silently rebased an old edit onto another device's change")
        var inFlightEdit = revisions.attempts[0]
        inFlightEdit.pendingDraft?.edit(questionID: "q-1", answer: "8", expectedRevision: 1)
        inFlightEdit.answers = ["8"]; revisions.upsert(inFlightEdit)
        precondition(revisions.attempts[0].pendingDraft?.baseRevision == 0, "Additional typing changed the original dirty baseline")
        revisions.acknowledgeDraft(id: revisionLocal.id, sent: ["q-1": "7"], savedAt: nil,
                                   expectedRevision: 0, mutationRevision: 1)
        precondition(revisions.attempts[0].pendingDraft?.pending == ["q-1": "8"])
        precondition(revisions.attempts[0].pendingDraft?.baseRevision == 1, "Own ACK did not advance remaining in-flight edits")
        _ = revisions.holdPendingDraftForReview(id: revisionLocal.id)
        revisionServer.serverMutationRevision = 2; revisionServer.answers = ["newest-server"]
        revisions.mergeServerAttempt(revisionServer)
        precondition(revisions.attempts[0].answers == ["newest-server"])
        precondition(revisions.applyLegacyDraftEvidence(id: revisionLocal.id, questionIDs: ["q-1"]))
        precondition(revisions.attempts[0].pendingDraft?.baseRevision == 2, "Explicit review did not adopt the displayed server baseline")
        revisions.acknowledgeDraft(id: revisionLocal.id, sent: ["q-1": "8"], savedAt: nil,
                                   expectedRevision: 1, mutationRevision: 2)
        precondition(revisions.attempts[0].pendingDraft?.pending == ["q-1": "8"], "Old ACK erased the same answer chosen at a newer revision")
        let revisionReload = try JSONDecoder().decode(AssessmentAttemptV2.self, from: JSONEncoder().encode(revisions.attempts[0]))
        precondition(revisionReload.pendingDraft?.baseRevision == 2 && revisionReload.serverMutationRevision == 2)
        var staleRevision = revisionServer; staleRevision.serverMutationRevision = 1
        staleRevision.serverUpdatedAt = Date.distantFuture
        revisions.mergeServerAttempt(staleRevision)
        precondition(revisions.attempts[0].serverMutationRevision == 2, "A later wall clock overrode a lower server revision")
        print("Production assessment store and DTO: dirty merge, terminal/abandoned authority, legacy evidence review/restart, latest-100 preservation and malformed schema: PASS")
    }
}
