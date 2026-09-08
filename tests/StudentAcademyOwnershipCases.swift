import Foundation

@MainActor final class AppStore {
    struct AccountSessionBoundary: Sendable { let slot: String; let generation: UUID }
    var generation = UUID()
    func captureAccountSessionBoundary() -> AccountSessionBoundary { .init(slot: DataScope.slot, generation: generation) }
    func ownsCurrentAccountSession(_ value: AccountSessionBoundary) -> Bool { value.slot == DataScope.slot && value.generation == generation }
}
@MainActor enum DataScope {
    static var slot = "a"
    static var directory: URL { URL(fileURLWithPath: "/fixture/\(slot)") }
}
struct ServerAPIError: LocalizedError {
    let statusCode: Int
    var errorDescription: String? { "synthetic HTTP \(statusCode)" }
}

// Only the API transport and DTO shapes consumed by this model are fixtures.
// AcademyScreenModel and AccountRequestOwner below are the actual app sources.
@MainActor enum ServerAPI {
    struct AuthorizationSnapshot { let token: String }
    static var token: String? = "a-token"
    static func captureAuthorization() -> AuthorizationSnapshot? { token.map { .init(token: $0) } }
    static func isCurrentAuthorization(_ value: AuthorizationSnapshot) -> Bool { value.token == token }
    struct AcademyDashboard {
        struct Membership { var status = "APPROVED" }
        struct Academy { let id: String }
        var marker: String
        var membership: Membership? = .init()
        var academies: [Academy] = [.init(id: "academy")]
        var attendance: AcademyAttendanceDashboard? = .init()
    }
    struct AcademyAttendanceDashboard {
        struct Session { var id = "session" }
        struct Record { var status = "PRESENT" }
        var session = Session()
    }
    struct AcademyWeekResponse { let id: String }
    struct AcademyWeek { struct File { let id: String } }
    struct Pending { let path: String; let finish: (Result<Any, Error>) -> Void }
    static var pending: [Pending] = []
    static var sent: [String] = []
    static var paused = false
    static var failure: Error?
    static func response<T>(_ path: String, authorization: AuthorizationSnapshot, value: T) async throws -> T {
        guard isCurrentAuthorization(authorization) else { throw CancellationError() }
        sent.append(path)
        if let failure { throw failure }
        if !paused { return value }
        return try await withCheckedThrowingContinuation { continuation in
            pending.append(.init(path: path, finish: { result in
                continuation.resume(with: result.map { $0 as! T })
            }))
        }
    }
    static func academyDashboard(authorization: AuthorizationSnapshot) async throws -> AcademyDashboard {
        try await response("load", authorization: authorization, value: .init(marker: "initial"))
    }
    static func academyWeek(_ weekID: String, authorization: AuthorizationSnapshot) async throws -> AcademyWeekResponse {
        try await response("week", authorization: authorization, value: .init(id: weekID))
    }
    static func requestAcademy(inviteCode: String, authorization: AuthorizationSnapshot) async throws -> AcademyDashboard {
        try await response("join-code", authorization: authorization, value: .init(marker: inviteCode))
    }
    static func requestAcademy(academyID: String, authorization: AuthorizationSnapshot) async throws -> AcademyDashboard {
        try await response("join", authorization: authorization, value: .init(marker: academyID))
    }
    static func leaveAcademy(authorization: AuthorizationSnapshot) async throws -> AcademyDashboard {
        try await response("leave", authorization: authorization, value: .init(marker: "left", membership: nil))
    }
    static func checkInAcademyAttendance(sessionID: String, code: String, authorization: AuthorizationSnapshot) async throws -> AcademyAttendanceDashboard.Record {
        try await response("attendance", authorization: authorization, value: .init())
    }
    static func downloadAcademyFile(weekID: String, file: AcademyWeek.File, account: String, authorization: AuthorizationSnapshot) async throws -> URL {
        try await response("download", authorization: authorization, value: URL(fileURLWithPath: "/fixture/\(account)/preview.pdf"))
    }
}

@main enum StudentAcademyOwnershipCases {
    @MainActor static func waitForPending(_ count: Int) async {
        for _ in 0..<10_000 {
            if ServerAPI.pending.count == count { return }
            await Task.yield()
        }
        fatalError("fixture did not reach the expected await boundary")
    }

    @MainActor static func main() async {
        let store = AppStore()
        let model = AcademyScreenModel()
        var owner = AccountRequestOwner(store: store)!
        await model.load(owner: owner, store: store)
        precondition(model.selectedAcademyID.isEmpty, "loading a list must not silently choose an academy")
        precondition(model.inviteRequestDisabledReason?.contains("초대 코드") == true)
        precondition(model.academyRequestDisabledReason?.contains("선택") == true)
        model.inviteCode = "MTH-ABC01D"
        precondition(model.inviteRequestDisabledReason?.contains("6자리") == true, "ambiguous 0/1 cannot bypass invitation validation")
        model.inviteCode = " mth-a2b3c4 "
        precondition(model.inviteRequestDisabledReason?.contains("공유") == true, "valid code still requires consent")
        model.selectedAcademyID = "academy"
        precondition(model.academyRequestDisabledReason?.contains("공유") == true)
        let beforeConsent = ServerAPI.sent.count
        await model.requestSelectedAcademy(owner: owner, store: store)
        await model.requestWithInviteCode(owner: owner, store: store)
        precondition(ServerAPI.sent.count == beforeConsent, "disabled consent must also be enforced by the actual model")
        model.consent = true
        precondition(model.inviteRequestDisabledReason == nil && model.academyRequestDisabledReason == nil)
        await model.requestWithInviteCode(owner: owner, store: store)
        precondition(model.dashboard?.marker == "MTH-A2B3C4", "invite request uses the normalized code")
        await model.requestSelectedAcademy(owner: owner, store: store)
        precondition(model.dashboard?.marker == "academy")
        model.selectedAcademyID = "removed-academy"
        let beforeStaleSelection = ServerAPI.sent.count
        await model.requestSelectedAcademy(owner: owner, store: store)
        precondition(ServerAPI.sent.count == beforeStaleSelection, "unknown selection cannot be sent")
        await model.load(owner: owner, store: store)
        precondition(model.selectedAcademyID.isEmpty, "removed selection is cleared, not replaced by first academy")
        model.inviteCode = ""; model.consent = false
        let baselineSends = ServerAPI.sent.count
        let obsolete = owner
        let queued = (0..<20).map { _ in Task { @MainActor in await model.leave(owner: obsolete, store: store) } }
        DataScope.slot = "b"; ServerAPI.token = "b-token"; store.generation = UUID(); model.reset()
        for item in queued { await item.value }
        precondition(ServerAPI.sent.count == baselineSends, "queued A leave must never disconnect B")
        DataScope.slot = "a"; ServerAPI.token = "a-token"; store.generation = UUID()
        await model.leave(owner: obsolete, store: store)
        precondition(ServerAPI.sent.count == baselineSends, "same-account relogin cannot revive old callback")
        owner = AccountRequestOwner(store: store)!
        await model.load(owner: owner, store: store)
        model.selectedWeek = .init(id: "protected-week")
        model.previewFile = .init(url: URL(fileURLWithPath: "/fixture/preview.pdf"))
        model.attendanceCode = "123456"; model.consent = true
        ServerAPI.failure = ServerAPIError(statusCode: 503)
        await model.load(owner: owner, store: store)
        precondition(model.dashboard != nil && model.selectedWeek != nil && model.previewFile != nil)
        precondition(model.attendanceCode == "123456" && model.consent && !model.isLoading)
        ServerAPI.failure = ServerAPIError(statusCode: 403)
        await model.load(owner: owner, store: store)
        precondition(model.dashboard == nil && model.selectedWeek == nil && model.previewFile == nil)
        precondition(model.attendanceCode.isEmpty && !model.consent && model.errorMessage != nil)
        ServerAPI.failure = nil

        ServerAPI.paused = true
        let read1 = Task { @MainActor in await model.load(owner: owner, store: store) }
        await waitForPending(1)
        let read2 = Task { @MainActor in await model.load(owner: owner, store: store) }
        await waitForPending(2)
        ServerAPI.pending.remove(at: 1).finish(.success(ServerAPI.AcademyDashboard(marker: "new")))
        await read2.value
        ServerAPI.pending.removeFirst().finish(.success(ServerAPI.AcademyDashboard(marker: "old")))
        await read1.value
        precondition(model.dashboard?.marker == "new" && !model.isLoading)

        let opening = Task { @MainActor in await model.openWeek("week", owner: owner, store: store) }
        await waitForPending(1); model.closeWeek()
        ServerAPI.pending.removeFirst().finish(.success(ServerAPI.AcademyWeekResponse(id: "week")))
        await opening.value
        precondition(model.selectedWeek == nil && !model.actionInProgress, "closed detail must not reopen")

        model.selectedWeek = .init(id: "week")
        let download = Task { @MainActor in await model.download(weekID: "week", file: .init(id: "file"), owner: owner, store: store) }
        await waitForPending(1); model.closeWeek()
        ServerAPI.pending.removeFirst().finish(.success(URL(fileURLWithPath: "/fixture/late.pdf")))
        await download.value
        precondition(model.previewFile == nil && model.downloadingFileID == nil)

        let beforeTaps = ServerAPI.sent.count
        var entered = 0
        let taps = (0..<20).map { _ in Task { @MainActor in
            entered += 1
            await model.leave(owner: owner, store: store)
        } }
        await waitForPending(1)
        while entered < 20 { await Task.yield() }
        precondition(ServerAPI.sent.count == beforeTaps + 1, "20 taps must admit one leave")
        ServerAPI.pending.removeFirst().finish(.success(ServerAPI.AcademyDashboard(marker: "left", membership: nil)))
        for tap in taps { await tap.value }
        precondition(!model.actionInProgress && model.dashboard?.marker == "left")

        let changing = Task { @MainActor in await model.leave(owner: owner, store: store) }
        await waitForPending(1)
        let duringChange = Task { @MainActor in await model.load(owner: owner, store: store) }
        await waitForPending(2)
        ServerAPI.pending.removeFirst().finish(.success(ServerAPI.AcademyDashboard(marker: "confirmed-left", membership: nil)))
        await changing.value
        ServerAPI.pending.removeFirst().finish(.success(ServerAPI.AcademyDashboard(marker: "stale-membership")))
        await duringChange.value
        precondition(model.dashboard?.marker == "confirmed-left", "pre-mutation GET snapshot must not undo confirmed leave")

        let retired = Task { @MainActor in await model.openWeek("retired", owner: owner, store: store) }
        await waitForPending(1); model.retire()
        ServerAPI.pending.removeFirst().finish(.success(ServerAPI.AcademyWeekResponse(id: "retired")))
        await retired.value
        precondition(model.selectedWeek == nil && model.dashboard == nil)
        print("Student academy actual model: explicit selection, invitation/consent reasons and request guards, removed selection, 20 queued cross-account leaves, A→B→A, 403 purge vs 503 preservation, reversed reads, stale GET after mutation, late detail/download after close, 20 duplicate leaves and retired-screen callbacks passed")
    }
}
