import Foundation

struct ServerAPIError: LocalizedError {
    var message: String
    var code: String? = nil
    var errorDescription: String? { message }
}
@MainActor enum DataScope {
    static var slot = "invite-account-A"
    static var directory: URL { URL(fileURLWithPath: "/isolated-fixture/" + slot) }
}
@MainActor final class AppStore {
    struct AccountSessionBoundary: Sendable { let slot: String; let generation: UUID }
    struct Profile { var role: String? = "teacher" }
    var generation = UUID()
    var authProvider: String? = "server"
    var serverProfile: Profile? = .init()
    func captureAccountSessionBoundary() -> AccountSessionBoundary { .init(slot: DataScope.slot, generation: generation) }
    func ownsCurrentAccountSession(_ boundary: AccountSessionBoundary) -> Bool { boundary.slot == DataScope.slot && boundary.generation == generation }
}
@MainActor enum ServerAPI {
    struct AuthorizationSnapshot { let token: String }
    static var token = "synthetic-token-A"
    static func captureAuthorization() -> AuthorizationSnapshot? { .init(token: token) }
    nonisolated static func authorizationForCurrentRequest() -> AuthorizationSnapshot { .init(token: "synthetic-token-A") }
    static func isCurrentAuthorization(_ value: AuthorizationSnapshot) -> Bool { value.token == token }
    struct TeacherAcademyDashboard { var marker = "loaded"; var requests: [Int] = []; var isOwner = true }
    struct TeacherAcademyInvite { let id: String }
    static var sent: [[String: Any]] = []
    static var failure: Error?
    static var suspended = false
    static var completion: CheckedContinuation<TeacherAcademyDashboard, Error>?
    static func request(_ method: String, _ path: String, body: [String: Any], authed: Bool, authorization: AuthorizationSnapshot) async throws -> TeacherAcademyDashboard {
        precondition(method == "POST" && path == "/api/v1/academy/teacher/invites" && authed)
        guard isCurrentAuthorization(authorization) else { throw CancellationError() }
        sent.append(body)
        if let failure { throw failure }
        if suspended { return try await withCheckedThrowingContinuation { completion = $0 } }
        return .init(marker: "saved")
    }
    static func revokeAcademyInvite(_ id: String, authorization: AuthorizationSnapshot) async throws -> TeacherAcademyDashboard { .init(marker: "revoked") }
}
@MainActor final class TeacherAcademyScreenModel {
    private let accountOwner: AccountRequestOwner?
    private weak var accountStore: AppStore?
    var generation = UUID()
    enum Section { case overview, settings, requests, students, invites }
    var section: Section = .overview
    var dashboard: ServerAPI.TeacherAcademyDashboard? = .init()
    var setup: Int?
    var inviteLabel = "학생 초대", inviteClassID = ""
    var inviteExpiryDays = 14
    var inviteCreationSequence: UInt = 0
    var inviteMaxUsesText = "30"
    var showsInviteComposer = false
    var actionID: String?, errorMessage: String?, noticeMessage: String?
    private func readable(_ error: Error) -> String { error.localizedDescription }
    // Production initializer, ownership guard, compose/create/discard/perform
    // and install bodies are injected by the runner, not rewritten for tests.
}

@main enum AcademyInviteCases {
    @MainActor static func main() async throws {
        let base = URL(string: "https://www.matths.kr")!
        let token = "synthetic-invite-token-123456789"
        let link = AcademyInvitePresentation.link(token: token, base: base)
        precondition(link?.host == "academy.matths.kr" && link?.path == "/academy/join/" + token)
        precondition(AcademyInvitePresentation.link(token: nil, base: base) == nil)
        for invalid in ["../../secrets", "https://bad.invalid/path", String(repeating: "a", count: 121)] {
            precondition(AcademyInvitePresentation.link(token: invalid, base: base) == nil)
        }
        precondition(AcademyInvitePresentation.link(token: token, base: URL(string: "https://qa.invalid")!)?.host == "qa.invalid")
        let states = ["ACTIVE", "REVOKED", "EXPIRED", "EXHAUSTED"]
        precondition(states.filter(AcademyInviteHistoryFilter.all.includes).count == 4)
        precondition(states.filter(AcademyInviteHistoryFilter.active.includes).count == 1)
        precondition(states.filter(AcademyInviteHistoryFilter.inactive.includes).count == 3)
        precondition(AcademyInvitePresentation.expirationLabel("2026-09-08T03:00:00.000Z").contains("12:00"))
        precondition(AcademyInvitePresentation.expirationLabel("invalid") == "유효기간 확인 필요")

        for days in AcademyInviteDraft.expiryOptions { for uses in [1, 30, 200] {
            let draft = AcademyInviteDraft(label: "  반  초대\n", classID: "class", expiryDays: days, maxUses: uses)
            precondition(draft.validationMessage == nil && draft.normalizedLabel == "반 초대")
            _ = try await ServerAPI.createAcademyInvite(label: draft.label, classID: draft.classID, expiryDays: days, maxUses: uses)
            precondition(NSDictionary(dictionary: ServerAPI.sent.last!).isEqual(to: draft.requestBody))
        }}
        for draft in [AcademyInviteDraft(label: String(repeating: "😀", count: 31)), .init(expiryDays: 8), .init(maxUses: 0), .init(maxUses: 201)] {
            precondition(draft.validationMessage != nil)
            let count = ServerAPI.sent.count
            do { _ = try await ServerAPI.createAcademyInvite(label: draft.label, classID: draft.classID, expiryDays: draft.expiryDays, maxUses: draft.maxUses); preconditionFailure("invalid request admitted") }
            catch { precondition(ServerAPI.sent.count == count) }
        }
        _ = try await ServerAPI.createAcademyInvite(label: "", classID: nil)
        precondition(ServerAPI.sent.last?["label"] as? String == "학생 초대")
        precondition(ServerAPI.sent.last?["expiryDays"] as? Int == 14 && ServerAPI.sent.last?["maxUses"] as? Int == 30)

        let store = AppStore()
        let live = TeacherAcademyScreenModel(store: store)
        live.inviteMaxUsesText = ""
        let beforeBlank = ServerAPI.sent.count
        await live.createInvite()
        precondition(ServerAPI.sent.count == beforeBlank && live.errorMessage != nil, "blank numeric field cannot silently submit the previous 30-use value")
        live.inviteMaxUses = 30
        live.openInviteComposer(); live.inviteLabel = "실패 후 유지"; live.inviteExpiryDays = 30; live.inviteMaxUses = 200
        ServerAPI.failure = ServerAPIError(message: "synthetic save failed")
        await live.createInvite()
        precondition(live.showsInviteComposer && live.inviteLabel == "실패 후 유지" && live.inviteExpiryDays == 30 && live.inviteMaxUses == 200 && live.errorMessage != nil && live.actionID == nil)
        ServerAPI.failure = nil
        await live.createInvite()
        precondition(!live.showsInviteComposer && live.section == .invites && live.dashboard?.marker == "saved" && !live.hasInviteDraftChanges)
        precondition(live.inviteCreationSequence == 1, "successful creation must reveal the newest invite rather than retain an inactive-only filter")
        live.openInviteComposer(); live.inviteLabel = "명시적 취소"; live.discardInviteDraft()
        precondition(!live.showsInviteComposer && !live.hasInviteDraftChanges)

        live.openInviteComposer(); live.inviteLabel = "한 번만 생성"
        ServerAPI.suspended = true; let count = ServerAPI.sent.count
        let pending = Task { await live.createInvite() }
        for _ in 0..<100 where ServerAPI.completion == nil { await Task.yield() }
        precondition(live.actionID == "new-invite")
        for _ in 0..<10 { await live.createInvite() }
        precondition(ServerAPI.sent.count == count + 1)
        live.discardInviteDraft(); precondition(live.showsInviteComposer, "in-flight create cannot be dismissed as cancelled")
        store.generation = UUID(); ServerAPI.token = "synthetic-token-B"; DataScope.slot = "invite-account-B"
        ServerAPI.completion?.resume(returning: .init(marker: "late-A")); ServerAPI.completion = nil
        await pending.value
        precondition(live.dashboard?.marker != "late-A" && live.inviteLabel == "한 번만 생성", "late response cannot clear an old draft or publish into a new owner")
        let sends = ServerAPI.sent.count; await live.createInvite(); precondition(ServerAPI.sent.count == sends)
        print("PASS actual native invite model/API: nine custom payloads, legacy defaults, UTF16 bounds, failure draft retention, confirmed success/return, explicit discard, double tap and retired owner; all history states and safe service links.")
    }
}
