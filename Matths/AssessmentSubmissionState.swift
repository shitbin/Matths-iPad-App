import Foundation

enum AssessmentSubmissionState: Equatable {
    case editable
    case submitting(String)
    case confirmed(String)
    case recovery(attemptID: String, retryAfter: Date?)

    var isSubmitting: Bool { if case .submitting = self { return true }; return false }
    func permitsOutcome(for id: String, currentAttemptID: String?) -> Bool {
        switch self {
        case .submitting(let owner): return owner == id
        case .editable: return currentAttemptID == id
        case .confirmed(let owner), .recovery(let owner, _): return owner == id || currentAttemptID == id
        }
    }
    func permitsAutomaticAttempt(_ id: String, now: Date = Date()) -> Bool {
        switch self {
        case .editable: return true
        case .submitting: return false
        case .confirmed(let confirmedID): return confirmedID != id
        case .recovery(let owner, let retryAfter):
            return owner != id || retryAfter.map { now >= $0 } == true
        }
    }

    static func recover(attemptID: String, failures: Int, status: Int?, now: Date = Date()) -> Self {
        // Authentication/permission/data errors need an explicit user action.
        // Network/timeouts/rate limiting may retry, never once per timer tick.
        // A 409 can mean another device won, or an abandoned attempt. A timer
        // must not replay stale answers before the student reviews fresh state.
        let retryable = status == nil || status == 408 || status == 429 || (status ?? 0) >= 500
        let delay = min(60, 5 * pow(2, Double(min(4, max(1, failures)))))
        return .recovery(attemptID: attemptID, retryAfter: retryable ? now.addingTimeInterval(delay) : nil)
    }
}
