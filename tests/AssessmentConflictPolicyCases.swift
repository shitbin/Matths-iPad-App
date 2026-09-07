import Foundation

@main enum AssessmentConflictPolicyCases {
    static func main() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("assessment-conflict-tests-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let journal = AssessmentStartJournal(directory: directory)
        let scope = "subunit/common-math-1/u/s"
        let ticket = try await journal.ticket(scope: scope, slot: "synthetic-account")
        let notAbandoned: [(Int?, String?)] = [
            (nil, nil), (409, nil), (409, "CONFLICT"),
            (409, "ASSESSMENT_DRAFT_CONFLICT"), (409, "ASSESSMENT_WRITE_CONFLICT"),
            (409, "ASSESSMENT_START_ID_CONFLICT"), (409, "START_ID_CONFLICT"),
            (400, "ASSESSMENT_ABANDONED"), (401, "ASSESSMENT_ABANDONED"),
            (404, "ASSESSMENT_ABANDONED"), (500, "ASSESSMENT_ABANDONED")
        ]
        for (status, code) in notAbandoned {
            let released = try await journal.acknowledgeAbandoned(scope: scope, ticket: ticket,
                slot: "synthetic-account", status: status, code: code)
            precondition(!released, "Only authoritative abandoned may release a start ticket")
            let stillSame = try await journal.ticket(scope: scope, slot: "synthetic-account")
            precondition(stillSame == ticket, "Generic/error conflict silently minted a duplicate start")
        }
        let reopened = AssessmentStartJournal(directory: directory)
        let persisted = try await reopened.ticket(scope: scope, slot: "synthetic-account")
        precondition(persisted == ticket, "Process restart lost the unresolved request identity")
        let other = try await reopened.ticket(scope: scope, slot: "other-account")
        let released = try await reopened.acknowledgeAbandoned(scope: scope, ticket: ticket,
            slot: "synthetic-account", status: 409, code: "ASSESSMENT_ABANDONED")
        precondition(released)
        let newTicket = try await reopened.ticket(scope: scope, slot: "synthetic-account")
        precondition(newTicket != ticket)
        let otherAfter = try await reopened.ticket(scope: scope, slot: "other-account")
        precondition(otherAfter == other, "Abandoning one account changed another account's ticket")
        _ = try await reopened.acknowledgeAbandoned(scope: scope, ticket: ticket,
            slot: "synthetic-account", status: 409, code: "ASSESSMENT_ABANDONED")
        let afterOldAck = try await reopened.ticket(scope: scope, slot: "synthetic-account")
        precondition(afterOldAck == newTicket, "Late old cancellation cleared the new start identity")
        precondition(AssessmentServerConflict(status: 409, code: "ASSESSMENT_DRAFT_CONFLICT") == .draft)
        precondition(AssessmentServerConflict(status: 409, code: "ASSESSMENT_WRITE_CONFLICT") == .write)
        precondition(AssessmentServerConflict(status: 409, code: "ASSESSMENT_START_ID_CONFLICT") == .startID)
        let now = Date(timeIntervalSince1970: 0)
        let conflict = AssessmentSubmissionState.recover(attemptID: "attempt", failures: 1, status: 409, now: now)
        precondition(!conflict.permitsAutomaticAttempt("attempt", now: now.addingTimeInterval(86_400)), "Timer blindly retried a conflict")
        let transport = AssessmentSubmissionState.recover(attemptID: "attempt", failures: 1, status: 503, now: now)
        precondition(transport.permitsAutomaticAttempt("attempt", now: now.addingTimeInterval(60)))
        precondition(!AssessmentSubmissionState.submitting("b").permitsOutcome(for: "a", currentAttemptID: "b"), "Late A draft conflict unlocked B submission")
        precondition(!AssessmentSubmissionState.submitting("b").permitsOutcome(for: "a", currentAttemptID: "a"), "Navigation cannot steal an in-flight submission lock")
        precondition(AssessmentSubmissionState.submitting("a").permitsOutcome(for: "a", currentAttemptID: "b"), "The owner must still be able to finish after navigation")
        precondition(!AssessmentSubmissionState.editable.permitsOutcome(for: "a", currentAttemptID: "b"))
        precondition(AssessmentSubmissionState.editable.permitsOutcome(for: "a", currentAttemptID: "a"))
        print("Assessment 409 compatibility: exact abandoned-only journal release, scope/account/restart/late-ACK preservation, typed conflict separation and no timer replay: PASS")
    }
}
