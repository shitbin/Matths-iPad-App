import Foundation

// Production AppStore signOut()/transitionToSignedOut bodies are extracted by
// the runner and compiled as an extension to this minimal persistence harness.
// Token ownership uses the production state machine; Keychain/UI/file effects
// are isolated doubles, so no real user's credentials or account files change.
@MainActor enum ServerAPI {
    static var ownership = ServerAuthenticationOwnership()
    static var token: String? = "old-test-token"
    static func beginAuthenticationAttempt() -> UUID { ownership.begin() }
    static func beginSignOut() -> UUID { ownership.beginSignOut() }
    static func ownsSignOut(_ id: UUID) -> Bool { ownership.ownsSignOut(id) }
    static func finishSignOut(_ id: UUID) -> Bool {
        guard ownership.completeSignOut(id) else { return false }
        token = nil
        return true
    }
    static func ownsAuthenticationExpiration(_ id: UUID) -> Bool {
        ownership.ownsExpiration(id, hasCredential: token != nil)
    }
    static func finishAuthenticationExpiration(_ id: UUID) -> Bool {
        ownership.completeExpiration(id, hasCredential: token != nil)
    }
    static func accept(_ id: UUID, token value: String = "new-test-token") -> Bool {
        guard ownership.complete(id) else { return false }
        token = value
        return true
    }
    static func receive401(requestToken: String?) -> UUID? {
        guard ServerTokenOwnership.shouldClear(requestToken: requestToken, currentToken: token) else { return nil }
        token = nil
        return ownership.expirationTicket(hasCredential: false)
    }
    static func resetFixture() { ownership = ServerAuthenticationOwnership(); token = "old-test-token"; DataScope.slot = "account-A" }
}
@MainActor enum DataScope { static var slot = "account-A" }
@MainActor enum WidgetBridge { static func clear() {} }
@MainActor enum UserDefaults {
    static let standard = Storage()
    final class Storage { func removeObject(forKey: String) {} }
}
@MainActor final class NotificationInboxStore {
    static let shared = NotificationInboxStore()
    func clear(slot: String) {}
}
@MainActor final class AuthTransitionHarness {
    enum Route { case home }
    var authProvider: String? = "server"
    var serverProfile: String? = "old-profile"
    var route: Route = .home
    var transitionCalls = 0
    var flushIsSuspended = false
    var holdFlush = false
    var continuation: CheckedContinuation<Void, Never>?
    func switchDataSlot(email: String?, flushPending: Bool = true, beforeSwitch: (() -> Bool)? = nil) async -> Bool {
        transitionCalls += 1
        if holdFlush {
            await withCheckedContinuation { continuation = $0; flushIsSuspended = true }
        }
        guard beforeSwitch?() ?? true else { return false }
        DataScope.slot = "guest"
        return true
    }
    func releaseFlush() { let waiter = continuation; continuation = nil; holdFlush = false; waiter?.resume() }
}

@main enum ServerAuthenticationExpiryInterleavingCases {
    @MainActor static func main() async {
        // Original defect: clear(ifMatches:) kept the new attempt, but the
        // delayed observer's unconditional logout/reset destroyed it afterwards.
        ServerAPI.resetFixture()
        let legacyAttempt = ServerAPI.beginAuthenticationAttempt()
        _ = ServerAPI.receive401(requestToken: "old-test-token")
        precondition(ServerAPI.ownership.owns(legacyAttempt))
        var legacyReset = ServerAPI.ownership
        legacyReset.reset()
        precondition(!legacyReset.complete(legacyAttempt), "original unconditional observer reset reproduces sessionAccepted:false")
        precondition(ServerAPI.accept(legacyAttempt), "fixed old 401 during a login does not cancel that login")

        // Notification already queued, login begins before MainActor delivery.
        ServerAPI.resetFixture()
        let queuedExpiration = ServerAPI.receive401(requestToken: "old-test-token")!
        let replacement = ServerAPI.beginAuthenticationAttempt()
        let queuedStore = AuthTransitionHarness()
        let queuedResult = await queuedStore.deliverExpiration(queuedExpiration)
        precondition(!queuedResult)
        precondition(queuedStore.transitionCalls == 0, "stale notification must not supersede account transition generation")
        precondition(ServerAPI.accept(replacement))

        // Notification started flushing the old slot before the new login began.
        ServerAPI.resetFixture()
        let flushingExpiration = ServerAPI.receive401(requestToken: "old-test-token")!
        let flushingStore = AuthTransitionHarness(); flushingStore.holdFlush = true
        let expirationTask = Task { @MainActor in await flushingStore.deliverExpiration(flushingExpiration) }
        while !flushingStore.flushIsSuspended { await Task.yield() }
        let loginDuringFlush = ServerAPI.beginAuthenticationAttempt()
        flushingStore.releaseFlush()
        let expirationResult = await expirationTask.value
        precondition(!expirationResult)
        precondition(DataScope.slot == "account-A")
        precondition(ServerAPI.accept(loginDuringFlush))

        // Exact -signOut/debug setup ordering: sync call schedules cleanup, then
        // a fresh login begins before that Task runs. The later intent must win.
        ServerAPI.resetFixture()
        let oldLogin = ServerAPI.beginAuthenticationAttempt()
        let deferredStore = AuthTransitionHarness()
        deferredStore.signOut()
        precondition(!ServerAPI.ownership.owns(oldLogin), "explicit action cancels an older attempt immediately")
        let afterSignOutCall = ServerAPI.beginAuthenticationAttempt()
        for _ in 0..<10 { await Task.yield() }
        precondition(deferredStore.transitionCalls == 0, "queued old logout must not start an account transition after the newer login")
        precondition(ServerAPI.accept(afterSignOutCall))
        precondition(ServerAPI.token == "new-test-token")

        ServerAPI.resetFixture()
        let logoutStore = AuthTransitionHarness(); logoutStore.holdFlush = true
        let logoutTask = Task { @MainActor in await logoutStore.signOut(discardingCurrentSlot: false) }
        while !logoutStore.flushIsSuspended { await Task.yield() }
        let afterLogoutStarted = ServerAPI.beginAuthenticationAttempt()
        logoutStore.releaseFlush()
        let logoutResult = await logoutTask.value
        precondition(!logoutResult)
        precondition(ServerAPI.accept(afterLogoutStarted), "logout flush cannot cancel a login begun after the action")

        // Normal logout and normal expiry still clear the old authenticated UI.
        ServerAPI.resetFixture()
        let normal = AuthTransitionHarness()
        let normalResult = await normal.signOut(discardingCurrentSlot: false)
        precondition(normalResult)
        precondition(ServerAPI.token == nil && normal.authProvider == nil && DataScope.slot == "guest")
        ServerAPI.resetFixture()
        let normalExpiry = ServerAPI.receive401(requestToken: "old-test-token")!
        let expired = AuthTransitionHarness()
        let normalExpiryResult = await expired.deliverExpiration(normalExpiry)
        precondition(normalExpiryResult)
        precondition(expired.authProvider == nil && DataScope.slot == "guest")
        let duplicateResult = await expired.deliverExpiration(normalExpiry)
        precondition(!duplicateResult, "duplicate notification cannot commit twice")
        print("Production signOut transition interleavings PASS: old 401 during login, queued notification, suspended flush, deferred explicit logout, latest intent, normal logout and expiry.")
    }
}
