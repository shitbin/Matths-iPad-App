import Foundation

@MainActor final class AppStore {
    struct AccountSessionBoundary: Sendable { let slot: String; let generation: UUID }
    var generation = UUID()
    func captureAccountSessionBoundary() -> AccountSessionBoundary { .init(slot: DataScope.slot, generation: generation) }
    func ownsCurrentAccountSession(_ value: AccountSessionBoundary) -> Bool { value.slot == DataScope.slot && value.generation == generation }
}
@MainActor enum DataScope {
    static var slot = "fixture-a"
    static var directory: URL { URL(fileURLWithPath: "/fixture/\(slot)") }
}
struct ServerAPIError: LocalizedError {
    var message: String
    var code: String? = nil
    var statusCode: Int = 0
    var errorDescription: String? { message }
}

// Only external storage is replaced. The model and SHA256 draft value above
// are unchanged product sources; no student's real file or service is touched.
@MainActor enum NativeServiceDraftDisk {
    static var values: [String: NativeServiceDraft] = [:]
    static var backups: [NativeServiceDraft] = []
    static var writes = 0
    static var loadFailure = false, saveFailure = false, backupFailure = false
    static func key(_ slot: String, _ resource: String) -> String { slot + "#" + resource }
    static func load(slot: String, resource: String) throws -> NativeServiceDraft {
        if loadFailure { throw CocoaError(.fileReadCorruptFile) }
        return values[key(slot, resource)] ?? .init(slot: slot, resource: resource)
    }
    static func save(_ value: NativeServiceDraft) throws {
        if saveFailure { throw CocoaError(.fileWriteOutOfSpace) }
        precondition(value.isValid)
        writes += 1; values[key(value.slot, value.resource)] = value
    }
    static func backup(slot: String, resource: String) throws {
        if backupFailure { throw CocoaError(.fileWriteNoPermission) }
        if let value = values[key(slot, resource)] { backups.append(value) }
    }
    static func reset() {
        values = [:]; backups = []; writes = 0
        loadFailure = false; saveFailure = false; backupFailure = false
    }
}

@MainActor enum ServerAPI {
    struct AuthorizationSnapshot { let token: String }
    static var token: String? = "token-a"
    static func captureAuthorization() -> AuthorizationSnapshot? { token.map { .init(token: $0) } }
    static func isCurrentAuthorization(_ value: AuthorizationSnapshot) -> Bool { value.token == token }
    struct AcademyWeekResponse {
        var week: AcademyWeek
        var submission: AcademyAssignmentSubmission?
        var serverTime: String?
    }
    struct Pending { let method: String; let finish: (Result<Any, Error>) -> Void }
    static var pending: [Pending] = []
    static var calls: [String] = []
    static var postedAnswers: [[String]] = []
    static var held = false
    static var plans: [Result<Any, Error>] = []
    static var latest: AcademyWeekResponse!
    static var postReceipt: AcademyAssignmentSubmission!

    static func transport<T>(_ method: String, authorization: AuthorizationSnapshot, fallback: T) async throws -> T {
        guard isCurrentAuthorization(authorization) else { throw CancellationError() }
        calls.append(method)
        if held {
            return try await withCheckedThrowingContinuation { continuation in
                pending.append(.init(method: method, finish: { continuation.resume(with: $0.map { $0 as! T }) }))
            }
        }
        if !plans.isEmpty { return try plans.removeFirst().get() as! T }
        return fallback
    }
    static func academyWeek(_ id: String, authorization: AuthorizationSnapshot) async throws -> AcademyWeekResponse {
        try await transport("GET", authorization: authorization, fallback: latest!)
    }
    static func request<T: Decodable>(_ method: String, _ path: String, body: [String: Any]?, authed: Bool,
                                      authorization: AuthorizationSnapshot) async throws -> T {
        precondition(method == "POST" && path.hasSuffix("/submission") && authed)
        postedAnswers.append(body?["answers"] as! [String])
        let data: Data = try await transport("POST", authorization: authorization, fallback: envelope(postReceipt))
        return try JSONDecoder().decode(T.self, from: data)
    }
    static func envelope(_ receipt: AcademyAssignmentSubmission, schema: String = "ACADEMY_ASSIGNMENT_V1") -> Data {
        let value = try! JSONSerialization.jsonObject(with: JSONEncoder().encode(receipt))
        return try! JSONSerialization.data(withJSONObject: ["schemaVersion": schema, "submission": value])
    }
    static func reset() {
        precondition(pending.isEmpty, "unfinished transport must never escape a scenario")
        token = "token-a"; calls = []; postedAnswers = []; held = false; plans = []
    }
}

@main @MainActor enum AcademyAssignmentStudentModelCases {
    static var count = 0
    static var failures: [String] = []
    static let input = ["1", "2", "3"]
    static func check(_ value: @autoclosure () -> Bool, _ message: String) {
        count += 1
        if !value() { failures.append(message) }
    }
    static func response(_ questions: Int = 3, revision: String = "r1") -> ServerAPI.AcademyWeekResponse {
        let omr = AcademyAssignmentOMR(enabled: true, questionCount: questions,
            sections: [.init(startNumber: 1, endNumber: questions, answerType: .multipleChoice, choiceCount: 5)],
            questions: [], configuredAt: revision, missedSubmissionsFinalizedAt: nil)
        return .init(week: .init(id: "week-1", academicYear: 2026, weekNumber: 1, title: "합성 주차",
            lessonSummary: "합성 수업", concepts: [], assignmentTitle: "합성 과제", assignmentInstructions: "답을 입력하세요",
            dueAt: "2099-01-01T00:00:00Z", files: [], assignmentOmr: omr), submission: nil, serverTime: "2026-09-07T00:00:00Z")
    }
    static func receipt(_ answers: [String] = ["1", "2", "3"], week: String = "week-1") -> AcademyAssignmentSubmission {
        .init(id: "receipt-1", weekId: week, answers: answers,
              answerModes: Array(repeating: .multipleChoice, count: answers.count), answeredCount: answers.count,
              correctByQuestion: Array(repeating: true, count: answers.count), correctCount: answers.count,
              questionCount: answers.count, scorePercent: 100, status: "SUBMITTED",
              submittedAt: "2026-09-07T00:01:00Z", gradedAt: "2026-09-07T00:01:00Z",
              autoZeroedAt: nil, answerKeyConfiguredAt: "r1")
    }
    static func fresh() -> (AppStore, AcademyAssignmentStudentModel) {
        ServerAPI.reset(); NativeServiceDraftDisk.reset(); DataScope.slot = "fixture-a"
        ServerAPI.latest = response(); ServerAPI.postReceipt = receipt()
        let store = AppStore()
        return (store, AcademyAssignmentStudentModel(response: ServerAPI.latest, owner: AccountRequestOwner(store: store)!, store: store))
    }
    static func ready() async -> (AppStore, AcademyAssignmentStudentModel) {
        let (store, model) = fresh(); await model.start()
        for (index, value) in input.enumerated() { model.setAnswer(value, at: index) }
        check(model.canSubmit, "fixture begins as a durable editable complete draft")
        return (store, model)
    }
    static func waitPending(_ method: String) async {
        for _ in 0..<100_000 {
            if ServerAPI.pending.first?.method == method { return }
            await Task.yield()
        }
        fatalError("fixture never reached \(method) boundary")
    }
    static func finish(_ result: Result<Any, Error>) { ServerAPI.pending.removeFirst().finish(result) }
    static var transient: ServerAPIError { .init(message: "synthetic response lost", statusCode: 503) }
    static func persistedAnswers() -> [String]? {
        guard let text = NativeServiceDraftDisk.values.values.first?.fields["answers"] else { return nil }
        return try? JSONDecoder().decode([String].self, from: Data(text.utf8))
    }

    static func main() async throws {
        do {
            let (store, model) = await ready()
            let before = ServerAPI.calls.count, writes = NativeServiceDraftDisk.writes
            let queued = (0..<20).map { _ in Task { @MainActor in await model.submit() } }
            DataScope.slot = "fixture-b"; ServerAPI.token = "token-b"; store.generation = UUID()
            for task in queued { await task.value }
            check(ServerAPI.calls.count == before && NativeServiceDraftDisk.writes == writes, "20 tasks queued for A send/write nothing after switch to B")
            DataScope.slot = "fixture-a"; ServerAPI.token = "token-a"; store.generation = UUID()
            await model.submit()
            check(ServerAPI.calls.count == before, "A→B→A does not revive an old model owner")
        }
        do {
            let (store, model) = await ready(); ServerAPI.held = true
            let task = Task { @MainActor in await model.submit() }
            await waitPending("GET")
            let writes = NativeServiceDraftDisk.writes
            DataScope.slot = "fixture-b"; ServerAPI.token = "token-b"; store.generation = UUID()
            finish(.success(ServerAPI.latest!)); await task.value
            check(ServerAPI.postedAnswers.isEmpty && NativeServiceDraftDisk.writes == writes, "account changed during preflight rejects GET and never POSTs")
        }
        do {
            let (store, model) = await ready(); ServerAPI.held = true
            let task = Task { @MainActor in await model.submit() }
            await waitPending("GET"); finish(.success(ServerAPI.latest!)); await waitPending("POST")
            let writes = NativeServiceDraftDisk.writes
            DataScope.slot = "fixture-b"; ServerAPI.token = "token-b"; store.generation = UUID(); model.retire()
            finish(.success(ServerAPI.envelope(receipt()))); await task.value
            check(model.answers.isEmpty && model.receipt == nil && !model.busy, "retired model rejects late POST receipt and clears student answers")
            check(NativeServiceDraftDisk.writes == writes, "late POST does not save into any account")
        }
        do {
            let (_, model) = await ready(); ServerAPI.held = true
            var entered = 0
            let tasks = (0..<20).map { _ in Task { @MainActor in entered += 1; await model.submit() } }
            await waitPending("GET")
            while entered < 20 { await Task.yield() }
            check(ServerAPI.pending.count == 1, "20 concurrent submits have one admission")
            finish(.success(ServerAPI.latest!)); await waitPending("POST")
            finish(.success(ServerAPI.envelope(receipt())))
            for task in tasks { await task.value }
            check(ServerAPI.postedAnswers == [input] && model.receipt?.answers == input && !model.canSubmit,
                  "one normalized POST, one confirmed receipt, no duplicate submit after confirmation")
        }
        for status in [401, 403, 404] {
            let (_, model) = await ready()
            let draft = NativeServiceDraftDisk.values
            ServerAPI.plans = [.failure(ServerAPIError(message: "denied", statusCode: status))]
            await model.refresh()
            check(model.denied && model.answers.isEmpty && model.receipt == nil && !model.canEdit, "HTTP \(status) discards sensitive rendered state")
            check(NativeServiceDraftDisk.values == draft, "HTTP \(status) does not overwrite preserved draft with empty answers")
        }
        do {
            let (_, model) = await ready()
            ServerAPI.plans = [.failure(transient)]; await model.refresh()
            check(model.answers == input && model.canSubmit && model.errorMessage != nil, "ordinary read error preserves draft and retry path")
        }
        do {
            let (_, model) = await ready(); ServerAPI.latest = response(2, revision: "r2")
            await model.submit()
            check(model.configurationChanged && model.answers == input && !model.canSubmit && ServerAPI.postedAnswers.isEmpty,
                  "preflight configuration change blocks mutation and preserves old answers")
            model.useCurrentConfiguration(reuseAnswers: true)
            check(model.answers == ["1", "2"] && !model.configurationChanged && model.canSubmit,
                  "explicit reuse maps retained answers only after configuration confirmation")
            check(NativeServiceDraftDisk.backups.count == 1, "old question-set draft is backed up before explicit replacement")
        }
        for change in ["revision", "files", "instructions", "title", "disabled", "invalid"] {
            let (_, model) = await ready()
            switch change {
            case "revision": ServerAPI.latest.week.assignmentOmr?.configuredAt = "r2"
            case "files": ServerAPI.latest.week.files = [.init(id: "file-new", originalName: "new.pdf", mimeType: "application/pdf", sizeBytes: 200)]
            case "instructions": ServerAPI.latest.week.assignmentInstructions = "바뀐 문제"
            case "title": ServerAPI.latest.week.assignmentTitle = "새 과제"
            case "disabled": ServerAPI.latest.week.assignmentOmr = nil
            default: ServerAPI.latest.week.assignmentOmr?.questionCount = 101
            }
            await model.submit()
            check(ServerAPI.postedAnswers.isEmpty && model.answers == input && !model.canSubmit, "\(change) change cannot silently submit stale answers")
        }
        do {
            let (_, model) = await ready()
            ServerAPI.latest.week.dueAt = "2026-09-06T00:00:00Z"
            await model.submit()
            check(ServerAPI.postedAnswers.isEmpty && model.deadlinePassed && model.answers == input, "fresh server clock blocks expired deadline without deleting inputs")
        }
        do {
            let (_, model) = await ready()
            var saved = response(); saved.submission = receipt()
            ServerAPI.plans = [.success(response()), .failure(transient), .success(saved)]
            await model.submit()
            check(ServerAPI.postedAnswers.count == 1 && ServerAPI.calls.suffix(3) == ["GET", "POST", "GET"], "lost POST response uses read-only reconciliation, never automatic replay")
            check(model.receipt?.answers == input && !model.canSubmit && model.notice != nil, "same saved receipt reconciles response loss")
        }
        do {
            let (_, model) = await ready()
            var saved = response(); saved.submission = receipt()
            ServerAPI.plans = [.success(saved)]
            await model.submit()
            check(ServerAPI.postedAnswers.isEmpty && model.receipt?.answers == input && !model.canSubmit, "preflight matching receipt resolves previous response loss without another POST")
        }
        do {
            let (_, model) = await ready()
            var other = response(); other.submission = receipt(["5", "5", "5"])
            ServerAPI.plans = [.success(response()), .failure(transient), .success(other)]
            await model.submit()
            check(ServerAPI.postedAnswers.count == 1 && model.answers == input && model.canSubmit && model.errorMessage != nil,
                  "different device receipt is not mistaken for successful local submission")
            check(persistedAnswers() == input, "different device receipt does not replace dirty local draft")
        }
        do {
            let (_, model) = await ready()
            ServerAPI.plans = [.success(response()), .failure(transient), .failure(transient)]
            await model.submit()
            check(model.answers == input && model.canSubmit && ServerAPI.postedAnswers.count == 1, "POST and reconciliation failure preserve input without replay")
        }
        do {
            let (_, model) = await ready()
            ServerAPI.plans = [.success(response()), .failure(transient), .failure(ServerAPIError(message: "revoked", statusCode: 403))]
            await model.submit()
            check(model.denied && model.answers.isEmpty && !model.canEdit && model.receipt == nil, "reconciliation 403 clears sensitive view and wins over transport error")
        }
        for result in [receipt(["5", "5", "5"]), receipt(["1", "2"]), receipt(week: "other-week")] {
            let (_, model) = await ready()
            ServerAPI.plans = [.success(response()), .success(ServerAPI.envelope(result)), .success(response())]
            await model.submit()
            check(model.answers == input && model.canSubmit && model.errorMessage != nil && model.notice == nil,
                  "actual API rejects valid-but-wrong answers/count/week receipt before model confirm")
            check(ServerAPI.calls.suffix(3) == ["GET", "POST", "GET"] && ServerAPI.postedAnswers.count == 1,
                  "rejected receipt triggers read-only reconcile, never a second mutation")
        }
        do {
            let (_, model) = await ready(); ServerAPI.held = true
            var changedReceipt = receipt(); changedReceipt.answerKeyConfiguredAt = "r2"
            var changedResponse = response(revision: "r2"); changedResponse.submission = changedReceipt
            let task = Task { @MainActor in await model.submit() }
            await waitPending("GET"); finish(.success(response()))
            await waitPending("POST")
            // Configuration changes only after the preflight completed and
            // the POST has entered transport, not before model.submit starts.
            finish(.success(ServerAPI.envelope(changedReceipt)))
            await waitPending("GET"); finish(.success(changedResponse)); await task.value
            check(model.configurationChanged && model.answers == input && !model.canSubmit && model.notice == nil,
                  "known answer-key revision changed during POST is not silently confirmed against the old draft")
            check(ServerAPI.calls.suffix(3) == ["GET", "POST", "GET"] && ServerAPI.postedAnswers.count == 1,
                  "known in-flight revision mismatch preserves inputs and reconciles read-only")
        }
        do {
            let (_, model) = await ready()
            var wrongRevisionReceipt = receipt(); wrongRevisionReceipt.answerKeyConfiguredAt = "r2"
            var staleConfigResponse = response(); staleConfigResponse.submission = wrongRevisionReceipt
            ServerAPI.plans = [.success(response()), .failure(transient), .success(staleConfigResponse)]
            await model.submit()
            check(model.answers == input && model.canSubmit && model.notice == nil && model.errorMessage != nil,
                  "matching answers with a mismatched known key revision never reconcile as local success")
        }
        do {
            let (store, model) = await ready(); ServerAPI.held = true
            let task = Task { @MainActor in await model.submit() }
            await waitPending("GET"); finish(.success(response()))
            await waitPending("POST"); finish(.failure(transient))
            await waitPending("GET")
            let writes = NativeServiceDraftDisk.writes
            DataScope.slot = "fixture-b"; ServerAPI.token = "token-b"; store.generation = UUID(); model.retire()
            var saved = response(); saved.submission = receipt()
            finish(.success(saved)); await task.value
            check(model.answers.isEmpty && model.receipt == nil && NativeServiceDraftDisk.writes == writes,
                  "account changes during read-only reconciliation reject late saved receipt")
        }
        do {
            let (_, model) = await ready()
            NativeServiceDraftDisk.saveFailure = true
            model.setAnswer("4", at: 0)
            check(model.answers[0] == "4" && model.draftError != nil && !model.canSubmit, "failed autosave retains RAM input and blocks POST")
            let before = ServerAPI.calls.count; await model.submit()
            check(ServerAPI.calls.count == before, "unsaved draft cannot enter preflight")
            NativeServiceDraftDisk.saveFailure = false; model.retryDraft()
            check(model.draftError == nil && model.canSubmit && persistedAnswers()?.first == "4", "save retry persists latest input and restores submission")
        }
        do {
            let (_, model) = await ready()
            ServerAPI.held = true
            let task = Task { @MainActor in await model.submit() }
            await waitPending("GET"); finish(.success(response())); await waitPending("POST")
            NativeServiceDraftDisk.saveFailure = true
            finish(.success(ServerAPI.envelope(receipt()))); await task.value
            check(model.receipt?.answers == input && !model.canSubmit && model.draftError != nil && model.notice != nil,
                  "confirmed server success plus failed local receipt persistence is truthful and cannot replay")
            ServerAPI.held = false; NativeServiceDraftDisk.saveFailure = false
            ServerAPI.latest.submission = receipt(); await model.refresh()
            check(model.draftError == nil && model.receipt?.answers == input && !model.canSubmit, "read refresh repairs local confirmed-state persistence")
        }
        do {
            let (_, model) = fresh(); NativeServiceDraftDisk.loadFailure = true
            await model.start()
            check(model.draftError != nil && !model.canEdit && NativeServiceDraftDisk.writes == 0, "corrupt disk load never overwrites original or allows input")
            NativeServiceDraftDisk.backupFailure = true; model.useCurrentConfiguration(reuseAnswers: false)
            check(!model.canSubmit && NativeServiceDraftDisk.writes == 0, "backup failure leaves corrupt source untouched")
            NativeServiceDraftDisk.loadFailure = false; NativeServiceDraftDisk.backupFailure = false
            model.useCurrentConfiguration(reuseAnswers: false)
            check(model.canEdit && model.answers == ["", "", ""] && NativeServiceDraftDisk.writes == 1, "explicit backup/new draft recovers after corruption")
        }
        do {
            let (_, model) = await ready()
            NativeServiceDraftDisk.saveFailure = true
            model.setAnswer("4", at: 0)
            let ram = model.answers, disk = NativeServiceDraftDisk.values
            model.useCurrentConfiguration(reuseAnswers: false)
            check(model.answers == ram && NativeServiceDraftDisk.values == disk && !model.canSubmit,
                  "failed recovery save rolls back RAM too, including previously unsaved latest answer")
        }
        do {
            let (store, model) = await ready()
            let draft = NativeServiceDraftDisk.values
            model.retire()
            let relaunched = AcademyAssignmentStudentModel(response: response(), owner: AccountRequestOwner(store: store)!, store: store)
            await relaunched.start()
            check(relaunched.answers == input && relaunched.canSubmit && NativeServiceDraftDisk.values == draft,
                  "same-account model relaunch restores durable dirty answers")
        }
        if !failures.isEmpty {
            for message in failures { fputs("FAIL: \(message)\n", stderr) }
            fputs("Academy assignment student model: \(failures.count) failures / \(count) checks\n", stderr)
            exit(1)
        }
        print("Academy assignment actual student model/API: \(count) checks passed (owner/task/await, 20 admissions, config/deadline, lost receipt/reconcile, injected storage failures and recovery)")
    }
}
