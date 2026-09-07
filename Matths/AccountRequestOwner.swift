import Foundation

/// Capture on the button/timer callback, before creating an unstructured Task.
/// Both the account generation and Bearer credential must still match before a
/// mutation is sent and before any result touches the current screen/store.
@MainActor
struct AccountRequestOwner {
    let id = UUID()
    let account: AppStore.AccountSessionBoundary
    let authorization: ServerAPI.AuthorizationSnapshot
    let slot: String
    let directory: URL

    init?(store: AppStore) {
        guard let authorization = ServerAPI.captureAuthorization() else { return nil }
        self.account = store.captureAccountSessionBoundary()
        self.authorization = authorization
        self.slot = DataScope.slot
        self.directory = DataScope.directory
    }

    func isCurrent(in store: AppStore) -> Bool {
        !Task.isCancelled && store.ownsCurrentAccountSession(account)
            && ServerAPI.isCurrentAuthorization(authorization)
    }
}
