import Foundation

@main
struct ServerTokenOwnershipCases {
    static func main() {
        precondition(ServerTokenOwnership.shouldClear(
            requestToken: "account-a-token",
            currentToken: "account-a-token"))
        precondition(!ServerTokenOwnership.shouldClear(
            requestToken: "account-a-token",
            currentToken: "account-b-token"))
        precondition(!ServerTokenOwnership.shouldClear(
            requestToken: nil,
            currentToken: "account-b-token"))
        precondition(!ServerTokenOwnership.shouldClear(
            requestToken: "",
            currentToken: "account-b-token"))
        precondition(!ServerTokenOwnership.shouldClear(
            requestToken: "account-a-token",
            currentToken: nil))
        precondition(ServerTokenOwnership.restoredSessionAction(
            authProvider: "server", hasToken: true) == .keep)
        precondition(ServerTokenOwnership.restoredSessionAction(
            authProvider: "server", hasToken: false) == .requireSignIn)
        precondition(ServerTokenOwnership.restoredSessionAction(
            authProvider: nil, hasToken: true) == .discardOrphanedToken)
        precondition(ServerTokenOwnership.restoredSessionAction(
            authProvider: "guest", hasToken: false) == .keep)
        precondition(ServerTokenOwnership.sanitizedPersistedProvider("server") == "server")
        precondition(ServerTokenOwnership.sanitizedPersistedProvider("guest") == "guest")
        precondition(ServerTokenOwnership.sanitizedPersistedProvider("debug") == nil)
        precondition(ServerTokenOwnership.sanitizedPersistedProvider("unknown") == nil)
        precondition(ServerTokenOwnership.sanitizedPersistedProvider(nil) == nil)
        precondition(DataScope.releaseRecoveryTarget(
            currentSlot: "demo", previousSlot: "guest") == "guest")
        precondition(DataScope.releaseRecoveryTarget(
            currentSlot: "demo", previousSlot: "acct-012345abcdef") == "acct-012345abcdef")
        precondition(DataScope.releaseRecoveryTarget(
            currentSlot: "demo", previousSlot: "acct-012345ABCDEf") == "acct-012345abcdef")
        precondition(DataScope.releaseRecoveryTarget(
            currentSlot: "demo", previousSlot: "acct-012345abcdeg") == "guest")
        precondition(DataScope.releaseRecoveryTarget(
            currentSlot: "demo", previousSlot: "../../private") == "guest")
        precondition(DataScope.releaseRecoveryTarget(
            currentSlot: "guest", previousSlot: "acct-012345abcdef") == "guest")
        print("Stale 401 responses cannot clear a newer account token.")
    }
}
