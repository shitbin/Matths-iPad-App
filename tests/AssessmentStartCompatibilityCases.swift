import Foundation

// Isolated host dependencies. The journal, DTO, model and startServerPaper body
// are production code; only the HTTP boundary and persistence outcome are fakes.
enum DataScope {
    static let root = FileManager.default.temporaryDirectory.appendingPathComponent("assessment-start-client-\(UUID())")
    static let slot = "unused-current-slot"
    static func url(_ name: String) -> URL { url(name, for: slot) }
    static func url(_ name: String, for slot: String) -> URL {
        let directory = root.appendingPathComponent(slot)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent(name)
    }
}
struct ServerAPIError: Error {
    let code: String?
    let statusCode: Int?
    var errorDescription: String? { "Synthetic server error: \(code ?? "none")" }
}
enum CurriculumPolicyError: Error { case malformed }
struct AssessCourse { let courseId: String }
struct AssessUnit { let unitId: String }
struct AssessSubunit { let id: String }

enum ServerAPI {
    struct AuthorizationSnapshot {}
    static var failure: ServerAPIError?
    static var response: Data?
    static var requests = 0
    static func captureAuthorization() -> AuthorizationSnapshot? { .init() }
    static func authorizationForCurrentRequest() -> AuthorizationSnapshot { .init() }
    static func isCurrentAuthorization(_ value: AuthorizationSnapshot) -> Bool { true }
    static func request<T: Decodable>(_ method: String, _ path: String, body: [String: Any]?, authed: Bool,
                                      authorization: AuthorizationSnapshot) async throws -> T {
        precondition(method == "POST" && path == "/api/v1/assessments/start")
        requests += 1
        if let failure { throw failure }
        guard let response else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode(T.self, from: response)
    }
}

@MainActor final class AppStore {
    struct AccountSessionBoundary { let slot: String; let generation: UUID }
    enum Snapshot { case assessments([AssessmentAttemptV2]) }
    enum Route { case assess, paper, curriculum }
    let slot: String
    var accountGeneration = UUID()
    var assessmentStartGeneration = UUID()
    var assessmentStarting = true
    var assessmentSyncError: String?
    var attemptsV2 = AttemptStoreV2()
    var currentAttemptID: String?
    var assessmentReturnRoute = Route.assess
    var selectedCourseV2ID: String?
    var route = Route.assess
    var persistenceSucceeds = true
    var onPersist: (() -> Void)?
    init(slot: String) { self.slot = slot }
    var account: AccountSessionBoundary { .init(slot: slot, generation: accountGeneration) }
    func isLearningAccountOperationActive(for owner: AccountSessionBoundary) -> Bool {
        owner.slot == slot && owner.generation == accountGeneration
    }
    func persistLearningImmediately(_ snapshot: Snapshot, for slot: String) async -> Bool {
        onPersist?()
        return persistenceSucceeds
    }
}

@main enum AssessmentStartCompatibilityCases {
    @MainActor static func main() async throws {
        defer { try? FileManager.default.removeItem(at: DataScope.root) }
        let scope = "subunit/common-math-1/u/s"
        let errors: [(Int?, String?, Bool)] = [
            (409, "ASSESSMENT_ABANDONED", true),
            (409, "ASSESSMENT_DRAFT_CONFLICT", false),
            (409, "ASSESSMENT_WRITE_CONFLICT", false),
            (409, "ASSESSMENT_START_ID_CONFLICT", false),
            (409, nil, false), (409, "CONFLICT", false),
            (503, nil, false), (401, "ASSESSMENT_ABANDONED", false)
        ]
        for (index, scenario) in errors.enumerated() {
            let store = AppStore(slot: "case-\(index)")
            let ticket = try await AssessmentStartJournal.shared.ticket(scope: scope, slot: store.slot)
            ServerAPI.failure = .init(code: scenario.1, statusCode: scenario.0)
            ServerAPI.requests = 0
            await store.exerciseAssessmentStart()
            let after = try await AssessmentStartJournal.shared.ticket(scope: scope, slot: store.slot)
            precondition((after != ticket) == scenario.2, "Actual start catch released/preserved the wrong ticket")
            precondition(ServerAPI.requests == 1, "Start error triggered a blind second start")
            precondition(store.currentAttemptID == nil && !store.assessmentStarting)
        }

        let q = ServerAPI.RemoteAssessment.Question(id: "q1", number: 1, typeKey: "fixture", prompt: "3+4", choices: [], answer: "", points: 3, solution: "", submittedAnswer: "", isCorrect: nil)
        var remote = ServerAPI.RemoteAssessment(id: "known-attempt", scope: "subunit", courseId: "common-math-1", unitId: "u", subunitId: "s", title: "Fixture", status: "in-progress", questions: [q], answers: [""], startedAt: "2026-09-07T00:00:00Z", deadlineAt: "2026-09-07T00:10:00Z", submittedAt: nil, scorePercent: nil, passed: nil, timeLimitMs: 600000, disqualified: false, updatedAt: "2026-09-07T00:00:00Z")
        let store = AppStore(slot: "known-local-evidence")
        let ticket = try await AssessmentStartJournal.shared.ticket(scope: scope, slot: store.slot)
        var local = remote.localValue()!
        local.clientStartID = ticket
        local.answers = ["7"]
        var pending = AssessmentDraftRecovery(); pending.edit(questionID: "q1", answer: "7")
        local.pendingDraft = pending
        store.attemptsV2.upsert(local)
        store.persistenceSucceeds = false
        ServerAPI.failure = .init(code: "ASSESSMENT_ABANDONED", statusCode: 409)
        await store.exerciseAssessmentStart()
        let retained = try await AssessmentStartJournal.shared.ticket(scope: scope, slot: store.slot)
        precondition(retained == ticket, "Persistence failure discarded the only stable cancellation identity")
        precondition(store.attemptsV2.attempts[0].isServerCancelled && store.attemptsV2.attempts[0].answers == ["7"])
        precondition(store.attemptsV2.attempts[0].pendingDraft?.pending == ["q1": "7"])
        store.persistenceSucceeds = true
        await store.exerciseAssessmentStart()
        let released = try await AssessmentStartJournal.shared.ticket(scope: scope, slot: store.slot)
        precondition(released != ticket && store.attemptsV2.attempts[0].answers == ["7"])

        let switched = AppStore(slot: "switch-during-save")
        let switchTicket = try await AssessmentStartJournal.shared.ticket(scope: scope, slot: switched.slot)
        local.clientStartID = switchTicket; switched.attemptsV2.upsert(local)
        switched.onPersist = { switched.accountGeneration = UUID() }
        await switched.exerciseAssessmentStart()
        let afterSwitch = try await AssessmentStartJournal.shared.ticket(scope: scope, slot: switched.slot)
        precondition(afterSwitch == switchTicket, "Stale account continuation released the start journal")

        // Legacy deployments still send a successful envelope with abandoned status.
        let legacy = AppStore(slot: "old-server-envelope")
        let legacyTicket = try await AssessmentStartJournal.shared.ticket(scope: scope, slot: legacy.slot)
        remote.status = "abandoned"
        ServerAPI.failure = nil; ServerAPI.response = try JSONEncoder().encode(["assessment": remote])
        await legacy.exerciseAssessmentStart()
        let afterLegacy = try await AssessmentStartJournal.shared.ticket(scope: scope, slot: legacy.slot)
        precondition(afterLegacy != legacyTicket)
        remote.status = "in-progress"
        ServerAPI.response = try JSONEncoder().encode(["assessment": remote])
        let direct = AppStore(slot: "direct-entry-origin")
        direct.assessmentReturnRoute = .curriculum
        await direct.exerciseAssessmentStart()
        precondition(direct.route == .paper && direct.assessmentReturnRoute == .assess,
                     "a direct start must not inherit the previous course origin")
        let courseEntry = AppStore(slot: "course-entry-origin")
        await courseEntry.exerciseCourseAssessmentStart()
        precondition(courseEntry.route == .paper && courseEntry.assessmentReturnRoute == .curriculum)
        precondition(courseEntry.selectedCourseV2ID == "common-math-1", "course selection survives authentication/reset")
        print("Actual startServerPaper body: typed 409/legacy-envelope cancellation, generic/key-conflict retention, no blind retry, failed persistence, local evidence and account-switch guards: PASS")
    }
}
