import Foundation

enum AssessmentMutationRevision {
    static let maximumSafeInteger = 9_007_199_254_740_991
    static func isValidServerValue(_ value: Int) -> Bool { (0...maximumSafeInteger).contains(value) }
    // The server must still be able to increment the successful mutation safely.
    static func isValidExpectedValue(_ value: Int) -> Bool { (0..<maximumSafeInteger).contains(value) }
}

/// HTTP status alone cannot authorize abandoning an idempotent start. Keep the
/// exact server codes distinct from a generic 409 or transport failure.
enum AssessmentServerConflict: Equatable {
    case abandoned, draft, write, startID, other

    init?(status: Int?, code: String?) {
        guard status == 409 else { return nil }
        switch code {
        case "ASSESSMENT_ABANDONED": self = .abandoned
        case "ASSESSMENT_DRAFT_CONFLICT": self = .draft
        case "ASSESSMENT_WRITE_CONFLICT": self = .write
        case "ASSESSMENT_START_ID_CONFLICT": self = .startID
        default: self = .other
        }
    }

    var releasesStartTicket: Bool { self == .abandoned }
}

/// Only answers not acknowledged by the server live here. An empty string is a
/// deliberate clear, not a missing answer. IDs survive remote question ordering.
struct AssessmentDraftRecovery: Codable, Sendable, Equatable {
    private(set) var pending: [String: String] = [:]
    private(set) var baseRevision: Int?
    var isEmpty: Bool { pending.isEmpty }

    mutating func edit(questionID: String, answer: String, expectedRevision: Int? = nil) {
        guard !questionID.isEmpty else { return }
        if pending.isEmpty { baseRevision = expectedRevision }
        pending[questionID] = answer
    }

    mutating func acknowledge(_ sent: [String: String], expectedRevision: Int? = nil, mutationRevision: Int? = nil) {
        // Equal answer strings at a later review revision are a new decision.
        // An older request cannot acknowledge that newer decision by coincidence.
        guard baseRevision == expectedRevision else { return }
        // An older upload finishing cannot acknowledge an edit made while it ran.
        for (id, value) in sent where pending[id] == value { pending.removeValue(forKey: id) }
        if pending.isEmpty { baseRevision = nil }
        else if let mutationRevision { baseRevision = mutationRevision }
    }

    func overlay(server: [String], questionIDs: [String]) -> [String] {
        questionIDs.enumerated().map { index, id in
            pending[id] ?? (server.indices.contains(index) ? server[index] : "")
        }
    }
}

enum AssessmentSnapshotPolicy {
    static func accepts(localTerminal: Bool, remoteTerminal: Bool,
                        localUpdatedAt: Date?, remoteUpdatedAt: Date?,
                        localRevision: Int? = nil, remoteRevision: Int? = nil) -> Bool {
        if localTerminal && !remoteTerminal { return false }
        if remoteTerminal && !localTerminal { return true }
        if let localRevision, let remoteRevision, localRevision != remoteRevision {
            return remoteRevision > localRevision
        }
        if let localUpdatedAt, let remoteUpdatedAt, remoteUpdatedAt < localUpdatedAt { return false }
        return true
    }
}
