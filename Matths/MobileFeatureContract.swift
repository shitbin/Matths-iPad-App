import Foundation

/// Authentication returns a deliberately smaller user object than GET /me.
/// Missing tutorial state means "not loaded", never "do not start".
enum FirstLearningProfileReadiness {
    static func needsHydration(authProvider: String?, tutorialStatus: String?, shouldAutoStart: Bool?) -> Bool {
        authProvider == "server" && (tutorialStatus == nil || shouldAutoStart == nil)
    }
    static func trigger(slot: String, authProvider: String?, role: String?, tutorialStatus: String?, shouldAutoStart: Bool?) -> String {
        [slot, authProvider ?? "none", role ?? "unknown", tutorialStatus ?? "unloaded",
         shouldAutoStart.map(String.init) ?? "unloaded"].joined(separator: ":")
    }
}

/// Capability absence is explicit. A timeout, invalid response or 401 is never
/// evidence that a mutation may safely fall back to a legacy, keyless request.
struct MobileFeatureCapabilities: Codable, Equatable, Sendable {
    let schemaVersion: String
    let firstLearningState: Bool
    let firstLearningStateVersion: Int
    let communityIdempotency: Bool
    let communityIdempotencyVersion: Int
    static let legacy = Self(schemaVersion: "MOBILE_CAPABILITIES_V1", firstLearningState: false,
                             firstLearningStateVersion: 1, communityIdempotency: false, communityIdempotencyVersion: 1)
    var isValid: Bool {
        schemaVersion == "MOBILE_CAPABILITIES_V1" && firstLearningStateVersion == 1 && communityIdempotencyVersion == 1
    }
}

/// This DTO deliberately has no account slot, token, disk queue counters,
/// confirmed progress, pass, unlock or official achievement fields.
struct FirstLearningRemoteState: Codable, Equatable, Sendable {
    struct Answer: Codable, Equatable, Sendable { let problemId: String; let correct: Bool }
    var flowVersion: Int
    var stage: String
    var goal: String
    var diagnosticAnswers: [Int]
    var conceptId: String?
    var seed: String?
    var expectedProblemIds: [String]
    var problemContentFingerprint: String?
    var checkedAnswers: [Answer]
    var topicRead: Bool
    var startedAt: String?
    var learningStartedAt: String?
    var baselineProgress: Int?

    init(_ journey: FirstLearningJourney) {
        flowVersion = 2; stage = journey.stage.rawValue; goal = journey.goal.rawValue
        diagnosticAnswers = journey.diagnosticAnswers; conceptId = journey.conceptID
        seed = journey.seed.map(String.init); expectedProblemIds = journey.expectedProblemIDs
        problemContentFingerprint = journey.problemContentFingerprint
        checkedAnswers = journey.expectedProblemIDs.compactMap { id in
            journey.checkedAnswers[id].map { Answer(problemId: id, correct: $0) }
        }
        topicRead = journey.topicRead; startedAt = Self.dateString(journey.startedAt)
        learningStartedAt = journey.learningStartedAt.map(Self.dateString)
        baselineProgress = journey.baselineProgress
    }
    var isValid: Bool {
        guard flowVersion == 2, let stage = FirstLearningJourney.Stage(rawValue: stage),
              LearningGoal(rawValue: goal) != nil, diagnosticAnswers.count <= 2,
              diagnosticAnswers.enumerated().allSatisfy({ ($0.offset == 0 ? [6, 7, 8] : [2, 3, 4]).contains($0.element) }),
              conceptId.map(Self.safeID) ?? true,
              seed.map({ UInt64($0).map(String.init) == $0 }) ?? true,
              expectedProblemIds.count <= 3, expectedProblemIds.allSatisfy(Self.safeID),
              Set(expectedProblemIds).count == expectedProblemIds.count,
              checkedAnswers.count <= 3, Set(checkedAnswers.map(\.problemId)).count == checkedAnswers.count,
              Set(checkedAnswers.map(\.problemId)).isSubset(of: Set(expectedProblemIds)),
              problemContentFingerprint.map({ $0.count == 64 && $0.allSatisfy { "0123456789abcdef".contains($0) } }) ?? true,
              startedAt.map({ Self.date($0) != nil }) ?? true,
              learningStartedAt.map({ Self.date($0) != nil }) ?? true,
              baselineProgress.map({ (0...100).contains($0) }) ?? true else { return false }
        if [.checks, .awaitingSync, .result, .completed].contains(stage) {
            guard conceptId != nil, seed != nil, expectedProblemIds.count == 3, topicRead else { return false }
        }
        return ![.awaitingSync, .result, .completed].contains(stage) || checkedAnswers.count == 3
    }

    /// Restored results must pass the existing independent canonical learning
    /// refresh. A remote UX blob can never import proof of a server receipt.
    func localJourney(slot: String, deadLetters: Int, quarantined: Int) throws -> FirstLearningJourney {
        guard isValid, let remoteStage = FirstLearningJourney.Stage(rawValue: stage),
              let goal = LearningGoal(rawValue: goal) else { throw CocoaError(.coderInvalidValue) }
        var local = FirstLearningJourney(slot: slot)
        local.stage = [.result, .completed].contains(remoteStage) ? .awaitingSync : remoteStage
        local.goal = goal; local.diagnosticAnswers = diagnosticAnswers; local.conceptID = conceptId
        local.seed = seed.flatMap(UInt64.init); local.expectedProblemIDs = expectedProblemIds
        local.problemContentFingerprint = problemContentFingerprint
        local.checkedAnswers = Dictionary(uniqueKeysWithValues: checkedAnswers.map { ($0.problemId, $0.correct) })
        local.topicRead = topicRead; local.startedAt = startedAt.flatMap(Self.date) ?? Date()
        local.learningStartedAt = learningStartedAt.flatMap(Self.date); local.baselineProgress = baselineProgress
        local.deadLetterBaseline = deadLetters; local.quarantineBaseline = quarantined
        guard local.isValid else { throw CocoaError(.coderInvalidValue) }
        return local
    }
    private static func safeID(_ value: String) -> Bool {
        !value.isEmpty && value.utf8.count <= 128 && value.utf8.allSatisfy {
            (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) || $0 == 45 || $0 == 95
        }
    }
    private static func dateString(_ value: Date) -> String {
        let formatter = ISO8601DateFormatter(); formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: value)
    }
    private static func date(_ value: String) -> Date? {
        guard value.range(of: #"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,3})?Z$"#, options: .regularExpression) != nil else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = value.contains(".") ? [.withInternetDateTime, .withFractionalSeconds] : [.withInternetDateTime]
        return formatter.date(from: value)
    }
}

struct FirstLearningRemoteEnvelope: Codable, Equatable, Sendable {
    let schemaVersion: String
    let supported: Bool
    let revision: Int
    let state: FirstLearningRemoteState?
    let updatedAt: String?
    var isValid: Bool { schemaVersion == "FIRST_LEARNING_V1" && supported && revision >= 0 && state?.isValid != false }
}

struct FirstLearningSyncCache: Codable, Equatable {
    var version = 1
    let slot: String
    let origin: String
    var revision: Int
    var baseState: FirstLearningRemoteState?
    /// The local representation may intentionally lower a remote result to
    /// awaitingSync; use this separate baseline when detecting local edits.
    var localBaseline: FirstLearningRemoteState?
    var terminalAcknowledged = false
    var isValid: Bool {
        version == 1 && !slot.isEmpty && !origin.isEmpty && revision >= 0
            && baseState?.isValid != false && localBaseline?.isValid != false
    }
}

enum FirstLearningMergeDecision: Equatable {
    case adoptRemote, uploadLocal, acknowledged, conflict
    static func decide(local: FirstLearningRemoteState, cache: FirstLearningSyncCache?,
                       remote: FirstLearningRemoteEnvelope, pristine: Bool) -> Self {
        guard remote.isValid, local.isValid else { return .conflict }
        if local == remote.state { return .acknowledged }
        guard let cache else { return pristine ? .adoptRemote : (remote.revision == 0 && remote.state == nil ? .uploadLocal : .conflict) }
        let unchangedRemote = cache.revision == remote.revision && cache.baseState == remote.state
        if unchangedRemote {
            if cache.terminalAcknowledged && remote.state == nil { return .acknowledged }
            return cache.localBaseline == local ? .acknowledged : .uploadLocal
        }
        return cache.localBaseline == local ? .adoptRemote : .conflict
    }
}
