import Foundation

@MainActor enum DataScope {
    static var slot = "a"
    static var directory: URL { URL(fileURLWithPath: "/synthetic/\(slot)") }
}
struct ServerAPIError: LocalizedError { var message: String?; var errorDescription: String? { message } }
@MainActor enum ServerAPI {
    struct AuthorizationSnapshot { let token: String }
    struct AppleWithdrawalReauthentication {}
    struct KakaoWithdrawalReauthentication {}
    struct GoogleWithdrawalReauthentication {}
    static var token: String? = "token-a"
    static var requests = 0
    static var fail = false
    static var pause = false
    static var pending: CheckedContinuation<Void, Never>?
    static func captureAuthorization() -> AuthorizationSnapshot? { token.map { .init(token: $0) } }
    static func isCurrentAuthorization(_ value: AuthorizationSnapshot) -> Bool { value.token == token }
    static func response(_ authorization: AuthorizationSnapshot) async throws -> Bool {
        precondition(isCurrentAuthorization(authorization))
        requests += 1
        if pause { await withCheckedContinuation { pending = $0 } }
        if fail { throw URLError(.notConnectedToInternet) }
        return true
    }
    static func withdrawMe(password: String, acknowledgeAnonymousRetention: Bool, authorization: AuthorizationSnapshot) async throws -> Bool { try await response(authorization) }
    static func withdrawMe(reauthentication: AppleWithdrawalReauthentication, acknowledgeAnonymousRetention: Bool, authorization: AuthorizationSnapshot) async throws -> Bool { try await response(authorization) }
    static func withdrawMe(reauthentication: KakaoWithdrawalReauthentication, acknowledgeAnonymousRetention: Bool, authorization: AuthorizationSnapshot) async throws -> Bool { try await response(authorization) }
    static func withdrawMe(reauthentication: GoogleWithdrawalReauthentication, acknowledgeAnonymousRetention: Bool, authorization: AuthorizationSnapshot) async throws -> Bool { try await response(authorization) }
}
@MainActor final class AppStore {
    struct AccountSessionBoundary { let slot: String; let generation: UUID }
    var generation = UUID()
    var signedOutSlots: [String] = []
    var invalidatedSlots: [String] = []
    var pendingInvalidation: CheckedContinuation<Void, Never>?
    func captureAccountSessionBoundary() -> AccountSessionBoundary { .init(slot: DataScope.slot, generation: generation) }
    func ownsCurrentAccountSession(_ value: AccountSessionBoundary) -> Bool { value.slot == DataScope.slot && value.generation == generation }
    func invalidateLearningPersistence(for slot: String) async {
        invalidatedSlots.append(slot)
        await withCheckedContinuation { pendingInvalidation = $0 }
    }
    func signOut(discardingCurrentSlot: Bool) async -> Bool {
        signedOutSlots.append(DataScope.slot)
        DataScope.slot = "guest"; ServerAPI.token = nil; generation = UUID()
        return true
    }
}
@MainActor final class DeletionHarness {
    static var purged: [String] = []
    let store = AppStore()
    var presentedAccount: AppStore.AccountSessionBoundary?
    var canSubmit = true
    var busy = false
    var appleReauthentication: ServerAPI.AppleWithdrawalReauthentication?
    var kakaoReauthentication: ServerAPI.KakaoWithdrawalReauthentication?
    var googleReauthentication: ServerAPI.GoogleWithdrawalReauthentication?
    var reauthenticationOwner: AccountRequestOwner?
    var password = "synthetic-only"
    var agreed = true
    var errorText: String?
    var dismissed = false
    init() { presentedAccount = store.captureAccountSessionBoundary() }
    func dismiss() { dismissed = true }
    static func purgeWithdrawnSlot(named slot: String, directory: URL) { purged.append(slot) }
    static func withdrawalFailureMessage(_ error: Error) -> String { "synthetic request failed" }
    func switchAccount(_ slot: String) { DataScope.slot = slot; ServerAPI.token = "token-\(UUID())"; store.generation = UUID() }
}
@main enum AccountDeletionLateCleanupCases {
    @MainActor static var failures: [String] = []
    @MainActor static func check(_ value: Bool, _ name: String) { if !value { failures.append(name) } }
    @MainActor static func wait(_ predicate: () -> Bool) async {
        for _ in 0..<10_000 { if predicate() { return }; await Task.yield() }
        fatalError("cleanup did not reach requested await")
    }
    @MainActor static func settle() async { for _ in 0..<300 { await Task.yield() } }
    @MainActor static func fixture() -> DeletionHarness {
        DataScope.slot = "a"; ServerAPI.token = "token-a"; ServerAPI.fail = false
        ServerAPI.pause = false; ServerAPI.pending = nil; DeletionHarness.purged = []
        return DeletionHarness()
    }
    @MainActor static func main() async {
        let normal = fixture(); normal.exerciseSubmit()
        await wait { normal.store.pendingInvalidation != nil }
        normal.store.pendingInvalidation?.resume(); normal.store.pendingInvalidation = nil; await settle()
        check(normal.store.signedOutSlots == ["a"] && DeletionHarness.purged == ["a"] && DataScope.slot == "guest", "normal deletion closes and purges only its owner")

        for nextSlot in ["b", "a"] {
            let changed = fixture(); changed.exerciseSubmit()
            await wait { changed.store.pendingInvalidation != nil }
            changed.switchAccount(nextSlot)
            changed.store.pendingInvalidation?.resume(); changed.store.pendingInvalidation = nil; await settle()
            check(changed.store.signedOutSlots.isEmpty && DataScope.slot == nextSlot,
                  "invalidation await must not log out replacement \(nextSlot) session")
            check(nextSlot != "a" || DeletionHarness.purged.isEmpty,
                  "invalidation await must not purge a reused same-account slot")
        }
        let reused = fixture(); ServerAPI.pause = true; reused.exerciseSubmit()
        await wait { ServerAPI.pending != nil }
        reused.switchAccount("b"); ServerAPI.pending?.resume(); ServerAPI.pending = nil
        await wait { reused.store.pendingInvalidation != nil }
        reused.switchAccount("a")
        reused.store.pendingInvalidation?.resume(); reused.store.pendingInvalidation = nil; await settle()
        check(reused.store.signedOutSlots.isEmpty && DeletionHarness.purged.isEmpty && DataScope.slot == "a",
              "A→B before response→A during cleanup must preserve the new A slot")

        let bounced = fixture(); ServerAPI.pause = true; bounced.exerciseSubmit()
        await wait { ServerAPI.pending != nil }
        bounced.switchAccount("b"); ServerAPI.pending?.resume(); ServerAPI.pending = nil
        await wait { bounced.store.pendingInvalidation != nil }
        bounced.switchAccount("a"); bounced.switchAccount("b")
        bounced.store.pendingInvalidation?.resume(); bounced.store.pendingInvalidation = nil; await settle()
        check(bounced.store.signedOutSlots.isEmpty && DeletionHarness.purged.isEmpty && DataScope.slot == "b",
              "A→B→A→B must preserve the reused A directory even though the final current slot differs")

        let other = fixture(); ServerAPI.pause = true; other.exerciseSubmit()
        await wait { ServerAPI.pending != nil }
        other.switchAccount("b"); ServerAPI.pending?.resume(); ServerAPI.pending = nil
        await wait { other.store.pendingInvalidation != nil }
        other.store.pendingInvalidation?.resume(); other.store.pendingInvalidation = nil; await settle()
        check(other.store.signedOutSlots.isEmpty && DeletionHarness.purged == ["a"] && DataScope.slot == "b",
              "stable other-account session still permits cleanup of only the original withdrawn slot")

        let failed = fixture(); ServerAPI.fail = true; failed.exerciseSubmit(); await settle()
        check(failed.store.invalidatedSlots.isEmpty && failed.store.signedOutSlots.isEmpty && DeletionHarness.purged.isEmpty,
              "request failure performs no invalidation, sign-out or purge")
        if !failures.isEmpty { failures.forEach { print("FAIL: \($0)") }; exit(1) }
        print("PASS: actual withdrawal submit preserves new accounts and same-slot sessions across invalidation awaits; normal and failed deletion boundaries retained")
    }
}
