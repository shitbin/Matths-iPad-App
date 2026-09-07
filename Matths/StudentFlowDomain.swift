import Foundation

/// A preference changes which valid activity is presented, never curriculum order,
/// eligibility, deadlines, grading or the server's next-concept calculation.
enum LearningGoal: String, Codable, CaseIterable, Identifiable {
    case school, review, examination, measure
    var id: String { rawValue }
    var title: String {
        switch self {
        case .school: "학교 진도 따라가기"
        case .review: "틀린 문제 줄이기"
        case .examination: "시험 대비하기"
        case .measure: "실력 확인하기"
        }
    }
    init(legacyTitle: String?) {
        self = Self.allCases.first { $0.title == legacyTitle } ?? .school
    }
}

struct TodayActionCandidate: Codable, Equatable, Identifiable {
    enum Kind: String, Codable { case timedWork, academy, deadline, review, curriculum, assessment, explore }
    enum Destination: Codable, Equatable {
        case officialAssessment(String), weeklyMock(String), arena(String), academyWeek(String)
        case academyAttendance, review, concept(String), assessments, learn
    }
    enum Source: String, Codable { case serverAssessment, serverAcademy, serverWeeklyMock, serverArena, canonicalLearning, durableReview, navigation }
    enum Freshness: String, Codable { case current, cached, local }
    let id: String
    let kind: Kind
    let title: String
    let reason: String
    let action: String
    let minutes: Int?
    let destination: Destination
    let source: Source
    var freshness: Freshness = .local
    var fetchedAt: Date?
    var deadline: Date?
    var position: String?

    /// Stale server state may open a fresh detail lookup, not promise permission
    /// to start or claim that an old attempt is still running.
    func presentation(at now: Date) -> Self {
        guard let fetchedAt, freshness == .current,
              now.timeIntervalSince(fetchedAt) > 300 || now < fetchedAt else { return self }
        var copy = self
        copy.freshness = .cached
        return copy
    }
    var visibleAction: String { freshness == .cached ? "최신 상태 확인" : action }
    var visibleReason: String { freshness == .cached ? "마지막으로 확인한 기록입니다. 열어서 현재 상태를 확인해 주세요." : reason }
}

enum TodayActionResolver {
    static func resolve(_ candidates: [TodayActionCandidate], goal: LearningGoal = .school, now: Date = Date()) -> TodayActionCandidate? {
        candidates.map { $0.presentation(at: now) }.sorted {
            let left = priority($0, goal: goal), right = priority($1, goal: goal)
            if left != right { return left < right }
            if $0.deadline != $1.deadline { return ($0.deadline ?? .distantFuture) < ($1.deadline ?? .distantFuture) }
            return $0.id < $1.id
        }.first
    }
    private static func priority(_ item: TodayActionCandidate, goal: LearningGoal) -> Int {
        if item.freshness == .cached { return 80 }
        switch item.kind {
        case .timedWork: return 0
        case .academy: return 10
        case .deadline: return 20
        case .review: return goal == .review ? 30 : 50
        case .curriculum: return goal == .school ? 30 : 55
        case .assessment: return goal == .measure || goal == .examination ? 30 : 60
        case .explore: return 100
        }
    }
}

enum TodayActivityPolicy {
    static func isSafeServerID(_ value: String) -> Bool {
        !value.isEmpty && value.utf8.count <= 128
            && value.unicodeScalars.allSatisfy { CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_" )).contains($0) }
    }
    static func canOfferWeekly(status: String, eligibilityAllowed: Bool, canEnterRoom: Bool) -> Bool {
        status == "in_progress" || (eligibilityAllowed && canEnterRoom && ["new", "lobby"].contains(status))
    }
    static func canOfferArena(matchStatus: String, attemptStatus: String?, integrity: String, actions: [String]?) -> Bool {
        guard attemptStatus == "IN_PROGRESS", ["PENDING", "CLEAR"].contains(integrity),
              ["MATCHED", "READY", "IN_PROGRESS", "SUBMITTED"].contains(matchStatus) else { return false }
        return actions.map { !Set($0).isDisjoint(with: ["SAVE_ANSWER", "ADVANCE", "SUBMIT"]) } ?? true
    }
}

/// Versioned, account-owned navigation receipt. It records actual answers from
/// the existing learning mutation boundary; it cannot award a concept PASS.
struct FirstLearningJourney: Codable, Equatable {
    enum Stage: String, Codable { case goal, diagnosis, lesson, checks, awaitingSync, result, completed, skipped }
    static let version = 2
    var schemaVersion = Self.version
    var slot: String
    var stage: Stage = .goal
    var goal: LearningGoal = .school
    var diagnosticAnswers: [Int] = []
    var conceptID: String?
    var seed: UInt64?
    var expectedProblemIDs: [String] = []
    var problemContentFingerprint: String?
    var checkedAnswers: [String: Bool] = [:]
    var topicRead = false
    var startedAt = Date()
    var learningStartedAt: Date?
    var baselineProgress: Int?
    var deadLetterBaseline: Int = 0
    var quarantineBaseline: Int = 0
    var confirmedProgress: Int?
    var serverConfirmedAt: Date?
    var pendingTutorialAction: String?
    var completedAt: Date?

    var diagnosticCorrectCount: Int {
        zip(diagnosticAnswers, [7, 3]).filter { $0 == $1 }.count
    }
    var answeredCount: Int { expectedProblemIDs.filter { checkedAnswers[$0] != nil }.count }
    var correctCount: Int { expectedProblemIDs.filter { checkedAnswers[$0] == true }.count }
    var isLearningFinished: Bool { topicRead && expectedProblemIDs.count == 3 && answeredCount == 3 }
    var canCompleteTutorial: Bool { isLearningFinished && serverConfirmedAt != nil && stage == .result }
    var isTerminal: Bool { stage == .completed || stage == .skipped }

    mutating func selectGoal(_ goal: LearningGoal) {
        guard stage == .goal else { return }
        self.goal = goal; stage = .diagnosis
    }
    mutating func answerDiagnosis(_ value: Int) {
        guard stage == .diagnosis, diagnosticAnswers.count < 2 else { return }
        diagnosticAnswers.append(value)
        if diagnosticAnswers.count == 2 { stage = .lesson }
    }
    mutating func prepare(conceptID: String, seed: UInt64, problemIDs: [String], baselineProgress: Int?, contentFingerprint: String? = nil, deadLetters: Int = 0, quarantined: Int = 0, now: Date) -> Bool {
        guard stage == .lesson, !conceptID.isEmpty, problemIDs.count == 3,
              Set(problemIDs).count == 3, problemIDs.allSatisfy({ !$0.isEmpty }) else { return false }
        self.conceptID = conceptID; self.seed = seed; expectedProblemIDs = problemIDs
        problemContentFingerprint = contentFingerprint
        self.baselineProgress = baselineProgress; learningStartedAt = now
        deadLetterBaseline = deadLetters; quarantineBaseline = quarantined
        return true
    }
    mutating func beginChecks() -> Bool {
        guard stage == .lesson, conceptID != nil, seed != nil, expectedProblemIDs.count == 3 else { return false }
        topicRead = true; stage = .checks
        return true
    }
    mutating func recordAnswer(slot: String, conceptID: String?, problemID: String, correct: Bool) -> Bool {
        guard slot == self.slot, stage == .checks, conceptID == self.conceptID,
              expectedProblemIDs.contains(problemID), checkedAnswers[problemID] == nil else { return false }
        checkedAnswers[problemID] = correct
        if isLearningFinished { stage = .awaitingSync }
        return true
    }
    mutating func confirmServer(progress: Int, now: Date) -> Bool {
        guard stage == .awaitingSync, isLearningFinished, (0...100).contains(progress) else { return false }
        confirmedProgress = progress; serverConfirmedAt = now; stage = .result
        return true
    }
    mutating func finish(now: Date) -> Bool {
        guard canCompleteTutorial else { return false }
        stage = .completed; completedAt = now; pendingTutorialAction = "COMPLETE"
        return true
    }
    mutating func skip() { stage = .skipped; pendingTutorialAction = "SKIP" }

    var isValid: Bool {
        schemaVersion == Self.version && !slot.isEmpty && diagnosticAnswers.count <= 2
            && diagnosticAnswers.enumerated().allSatisfy({ index, value in (index == 0 ? [6, 7, 8] : [2, 3, 4]).contains(value) })
            && deadLetterBaseline >= 0 && quarantineBaseline >= 0
            && expectedProblemIDs.count <= 3 && Set(expectedProblemIDs).count == expectedProblemIDs.count
            && Set(checkedAnswers.keys).isSubset(of: Set(expectedProblemIDs))
            && (![Stage.checks, .awaitingSync, .result, .completed].contains(stage)
                || (conceptID != nil && seed != nil && expectedProblemIDs.count == 3 && topicRead))
            && (![Stage.awaitingSync, .result, .completed].contains(stage) || isLearningFinished)
            && (![Stage.result, .completed].contains(stage) || serverConfirmedAt != nil)
    }
}
