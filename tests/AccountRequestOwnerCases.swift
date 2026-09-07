import Foundation

// Test doubles for session state only; AccountRequestOwner is the product code.
@MainActor final class AppStore {
    struct AccountSessionBoundary: Sendable { let slot: String; let generation: UUID }
    var generation = UUID()
    func captureAccountSessionBoundary() -> AccountSessionBoundary {
        AccountSessionBoundary(slot: DataScope.slot, generation: generation)
    }
    func ownsCurrentAccountSession(_ owner: AccountSessionBoundary) -> Bool {
        owner.slot == DataScope.slot && owner.generation == generation
    }
}
@MainActor enum DataScope {
    static var slot = "account-a"
    static var directory: URL { URL(fileURLWithPath: "/fixture/\(slot)") }
}
@MainActor enum ServerAPI {
    struct AuthorizationSnapshot: Sendable { let token: String }
    static var token: String? = "token-a"
    static func captureAuthorization() -> AuthorizationSnapshot? { token.map(AuthorizationSnapshot.init) }
    static func isCurrentAuthorization(_ snapshot: AuthorizationSnapshot) -> Bool { snapshot.token == token }
}

@main enum AccountRequestOwnerCases {
    actor Barrier {
        var waiter: CheckedContinuation<Void, Never>?
        func wait() async { await withCheckedContinuation { waiter = $0 } }
        func release() { waiter?.resume(); waiter = nil }
        var waiting: Bool { waiter != nil }
    }

    @MainActor static func main() async {
        let store = AppStore()
        let first = AccountRequestOwner(store: store)!
        var sends = 0
        let queued = (0..<20).map { _ in Task { @MainActor in
            guard first.isCurrent(in: store) else { return }
            sends += 1
        } }
        // No await before switching: all 20 button tasks are queued but not sent.
        DataScope.slot = "account-b"; ServerAPI.token = "token-b"; store.generation = UUID()
        for task in queued { await task.value }
        precondition(sends == 0, "old account task must not send its body with the new account token")
        precondition(first.authorization.token == "token-a")

        let responseOwner = AccountRequestOwner(store: store)!
        let barrier = Barrier()
        var applied = false
        let response = Task { @MainActor in
            guard responseOwner.isCurrent(in: store) else { return }
            await barrier.wait()
            guard responseOwner.isCurrent(in: store) else { return }
            applied = true
        }
        while !(await barrier.waiting) { await Task.yield() }
        // Same account and token, but a new login generation must still reject.
        store.generation = UUID()
        await barrier.release(); await response.value
        precondition(!applied, "late response must not overwrite a reauthenticated session")

        let refreshOwner = AccountRequestOwner(store: store)!
        ServerAPI.token = "rotated-token"
        precondition(!refreshOwner.isCurrent(in: store))
        ServerAPI.token = nil
        precondition(AccountRequestOwner(store: store) == nil)

        ServerAPI.token = "token-c"
        let cancelOwner = AccountRequestOwner(store: store)!
        let cancelled = Task { @MainActor in
            while !Task.isCancelled { await Task.yield() }
            return cancelOwner.isCurrent(in: store)
        }
        cancelled.cancel()
        let canApplyCancelled = await cancelled.value
        precondition(!canApplyCancelled)
        print("Account request owner: 20 queued mutations rejected after switch, same-account generation, credential rotation, missing auth and cancellation passed")
    }
}
