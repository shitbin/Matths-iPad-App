import Foundation

@main
struct AssessmentDraftRecoveryCases {
    static func main() throws {
        var recovery = AssessmentDraftRecovery()
        recovery.edit(questionID: "q1", answer: "new")
        recovery.edit(questionID: "q2", answer: "")
        precondition(recovery.overlay(server: ["old", "erase me"], questionIDs: ["q1", "q2"]) == ["new", ""])
        let sent = recovery.pending
        recovery.edit(questionID: "q1", answer: "newer")
        recovery.acknowledge(sent)
        precondition(recovery.pending == ["q1": "newer"], "Old ACK erased an edit made in flight")
        precondition(recovery.overlay(server: ["other", "old"], questionIDs: ["q2", "q1"]) == ["other", "newer"])
        let restored = try JSONDecoder().decode(AssessmentDraftRecovery.self, from: JSONEncoder().encode(recovery))
        precondition(restored == recovery, "Process restart lost dirty answers")
        recovery.acknowledge(["q1": "newer"])
        precondition(recovery.isEmpty)
        let now = Date(timeIntervalSince1970: 100)
        let retry = AssessmentSubmissionState.recover(attemptID: "exam", failures: 1, status: 503, now: now)
        precondition(!retry.permitsAutomaticAttempt("exam", now: now.addingTimeInterval(1)))
        precondition(retry.permitsAutomaticAttempt("exam", now: now.addingTimeInterval(10)))
        let auth = AssessmentSubmissionState.recover(attemptID: "exam", failures: 1, status: 401, now: now)
        precondition(!auth.permitsAutomaticAttempt("exam", now: now.addingTimeInterval(3600)))
        precondition(auth.permitsAutomaticAttempt("another", now: now))
        precondition(!AssessmentSubmissionState.submitting("exam").permitsAutomaticAttempt("exam", now: now))
        precondition(!AssessmentSubmissionState.confirmed("exam").permitsAutomaticAttempt("exam", now: now))
        precondition(!AssessmentSnapshotPolicy.accepts(localTerminal: true, remoteTerminal: false, localUpdatedAt: now, remoteUpdatedAt: now.addingTimeInterval(1)))
        precondition(!AssessmentSnapshotPolicy.accepts(localTerminal: false, remoteTerminal: false, localUpdatedAt: now, remoteUpdatedAt: now.addingTimeInterval(-1)))
        precondition(AssessmentSnapshotPolicy.accepts(localTerminal: false, remoteTerminal: true, localUpdatedAt: now, remoteUpdatedAt: now.addingTimeInterval(-1)))
        print("Assessment dirty-answer merge, explicit clearing, reordered IDs, old ACK, process restore and terminal monotonicity: PASS")
    }
}
