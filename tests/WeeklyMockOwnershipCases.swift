import Foundation

@MainActor final class AppStore {
    struct AccountSessionBoundary: Sendable { let slot: String; let generation: UUID }
    var generation = UUID()
    func captureAccountSessionBoundary() -> AccountSessionBoundary { .init(slot: DataScope.slot, generation: generation) }
    func ownsCurrentAccountSession(_ owner: AccountSessionBoundary) -> Bool { owner.slot == DataScope.slot && owner.generation == generation }
}
@MainActor enum DataScope {
    static var slot = "a"
    static var directory: URL { URL(fileURLWithPath: "/fixture/\(slot)") }
}
enum ServerAPI {
    struct AuthorizationSnapshot: Sendable { let token: String? }
    static var token: String? = "token-a"
    static var sent: [(path: String, token: String)] = []
    static func captureAuthorization() -> AuthorizationSnapshot? { token.map { .init(token: $0) } }
    static func authorizationForCurrentRequest() -> AuthorizationSnapshot { .init(token: token) }
    static func isCurrentAuthorization(_ value: AuthorizationSnapshot) -> Bool { value.token != nil && value.token == token }
    struct Recorded: Error {}
    static func request<T: Decodable>(_ method: String, _ path: String, body: [String: Any]?, authed: Bool,
                                      authorization: AuthorizationSnapshot? = nil) async throws -> T {
        // Transport boundary only is replaced. Product API wrappers must forward
        // the frozen credential; a missing snapshot must fail this harness.
        guard let authorization, let captured = authorization.token else { fatalError("weekly wrapper discarded authorization") }
        guard captured == token else { throw CancellationError() }
        sent.append((path, captured))
        throw Recorded()
    }
    static func authorizedRequest(_ method: String, _ path: String, contentType: String? = nil,
                                  timeout: TimeInterval = 60, authorization: AuthorizationSnapshot? = nil) throws -> URLRequest {
        guard let authorization, let captured = authorization.token else { fatalError("weekly transfer discarded authorization") }
        guard captured == token else { throw CancellationError() }
        sent.append((path, captured))
        throw Recorded() // Never opens a network connection or touches user files.
    }
    static func bearerToken(from request: URLRequest) -> String? { nil }
    static func validateAuthorizedResponse(_ response: URLResponse, errorBody: Data, requestToken: String?) throws {}
}
struct ServerAPIError: Error {
    let message: String?
    let code: String?
    let statusCode: Int?
    init(message: String? = nil, code: String? = nil, statusCode: Int? = nil) {
        self.message = message; self.code = code; self.statusCode = statusCode
    }
}

@main enum WeeklyMockOwnershipCases {
    @MainActor static func main() async throws {
        func exam(modes: [String]?) throws -> ServerAPI.WeeklyMockAttempt.Exam {
            var value: [String: Any] = ["id": "format-test", "title": "Format contract", "formCode": "A", "attemptNumber": 1, "isTest": true, "questionCount": 30]
            if let modes { value["questionModes"] = modes }
            return try JSONDecoder().decode(ServerAPI.WeeklyMockAttempt.Exam.self, from: JSONSerialization.data(withJSONObject: value))
        }
        // v3 canonical server permits mixed answer modes at every number. The
        // first 21 questions are no longer always objective when metadata exists.
        let mixedModes = (0..<30).map { $0 % 2 == 0 ? "short-answer" : "multiple-choice" }
        let mixedExam = try exam(modes: mixedModes)
        for index in 0..<30 { precondition(mixedExam.mode(at: index) == mixedModes[index], "v3 question \(index + 1) ignored canonical answer mode") }
        let legacyExam = try exam(modes: nil)
        for index in 0..<30 { precondition(legacyExam.mode(at: index) == (index < 21 ? "multiple-choice" : "short-answer")) }
        let shortMetadata = try exam(modes: ["short-answer"])
        precondition(shortMetadata.mode(at: 0) == "short-answer" && shortMetadata.mode(at: 1) == "multiple-choice")
        print("Weekly mock v3 answer modes: 30 mixed canonical types and legacy missing/partial metadata passed")
        let store = AppStore()
        let owner = AccountRequestOwner(store: store)!
        let queued = (0..<20).map { _ in Task { @MainActor in
            guard owner.isCurrent(in: store) else { return }
            _ = try? await ServerAPI.startWeeklyMock(examId: "exam-a", authorization: owner.authorization)
        } }
        DataScope.slot = "b"; ServerAPI.token = "token-b"; store.generation = UUID()
        for task in queued { await task.value }
        precondition(ServerAPI.sent.isEmpty, "A's queued start must never create B's attempt")
        DataScope.slot = "a"; ServerAPI.token = "token-a"; store.generation = UUID()
        precondition(!owner.isCurrent(in: store), "A→B→A cannot resurrect the mounted owner")

        let gate = WeeklyMockOperationGate()
        let first = gate.begin("load")!
        let newest = gate.begin("load")!
        precondition(!gate.accepts(first) && gate.accepts(newest))
        gate.finish(first)
        precondition(gate.accepts(newest), "stale finish cannot release a new request")
        gate.finish(newest)
        let starts = (0..<20).compactMap { _ in gate.begin("start", exclusive: true) }
        precondition(starts.count == 1, "20 simultaneous taps admit only one operation")
        gate.reset()
        precondition(!gate.accepts(starts[0]))
        let afterDenial = gate.begin("start", exclusive: true)!
        gate.finish(starts[0])
        precondition(gate.accepts(afterDenial))
        gate.retire()
        precondition(!gate.accepts(afterDenial) && gate.begin("load") == nil)
        gate.activate()
        precondition(!gate.accepts(afterDenial) && gate.begin("load") != nil, "reappearing screen must use a new epoch")
        precondition(WeeklyMockOperationGate.removesProtectedContent(statusCode: 403))
        for code in [nil, 408, 409, 429, 500, 503] {
            precondition(!WeeklyMockOperationGate.removesProtectedContent(statusCode: code), "transport/conflict must preserve draft")
        }

        let live = AccountRequestOwner(store: store)!
        let auth = live.authorization
        // Invoke each actual production wrapper. The recording transport throws
        // after checking the supplied credential, so response fixtures are not
        // confused with live API completion evidence.
        _ = try? await ServerAPI.weeklyMockDashboard(authorization: auth)
        _ = try? await ServerAPI.weeklyMockAttempt(examId: "exam", authorization: auth)
        _ = try? await ServerAPI.startWeeklyMock(examId: "exam", authorization: auth)
        _ = try? await ServerAPI.saveWeeklyMockDraft(examId: "exam", answers: [], telemetry: [], authorization: auth)
        _ = try? await ServerAPI.submitWeeklyMock(examId: "exam", answers: [], telemetry: [], authorization: auth)
        _ = try? await ServerAPI.expireWeeklyMock(examId: "exam", authorization: auth)
        try? await ServerAPI.selectWeeklyMockRepresentative(weekKey: "week", authorization: auth)
        _ = try? await ServerAPI.weeklyMockIntegrityCases(authorization: auth)
        _ = try? await ServerAPI.weeklyMockIntegrityCase(id: "case", authorization: auth)
        _ = try? await ServerAPI.weeklyMockObjectionOptions(authorization: auth)
        _ = try? await ServerAPI.weeklyMockObjections(authorization: auth)
        _ = try? await ServerAPI.createWeeklyMockObjection(examId: "exam", questionNumber: 1, issueDetail: "synthetic", authorization: auth)
        _ = try? await ServerAPI.downloadWeeklyMockPaper(examId: "exam", accountSlot: "a", authorization: auth)
        _ = try? await ServerAPI.submitWeeklyMockEvidence(caseId: "case", files: [URL(fileURLWithPath: "/fixture/nonexistent")], note: "", submissionId: "command", authorization: auth)
        precondition(ServerAPI.sent.count == 14 && ServerAPI.sent.allSatisfy { $0.token == "token-a" })
        ServerAPI.token = "token-b"
        _ = try? await ServerAPI.startWeeklyMock(examId: "exam", authorization: auth)
        _ = try? await ServerAPI.downloadWeeklyMockPaper(examId: "exam", accountSlot: "a", authorization: auth)
        precondition(ServerAPI.sent.count == 14, "stale frozen credential must not use current token")
        print("Weekly mock ownership: 20 queued cross-account starts rejected; A→B→A, latest-only reads, 20 duplicate admissions, retired callbacks, 403-only eviction and 14 product API forwarding paths passed")
    }
}
