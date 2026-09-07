import Foundation

@main
enum ServerAuthenticationOwnershipCases {
    static func main() {
        var ownership = ServerAuthenticationOwnership()
        let first = UUID()
        let second = UUID()

        precondition(ownership.begin(id: first) == first)
        precondition(ownership.owns(first))

        precondition(ownership.begin(id: second) == second)
        precondition(!ownership.complete(first), "superseded login must not become the session")
        precondition(ownership.owns(second))
        precondition(ownership.complete(second))
        precondition(!ownership.complete(second), "a response can be accepted only once")

        let cancelled = ownership.begin()
        ownership.cancel(UUID())
        precondition(ownership.owns(cancelled), "another request cannot cancel the owner")
        ownership.cancel(cancelled)
        precondition(!ownership.owns(cancelled))

        let reset = ownership.begin()
        ownership.reset()
        precondition(!ownership.owns(reset), "logout invalidates every in-flight login")

        let inFlight = ownership.begin()
        precondition(ownership.expirationTicket(hasCredential: false) == nil,
                     "old 401 must not publish cleanup while a new login owns authentication")
        precondition(ownership.complete(inFlight))
        let expiration = ownership.expirationTicket(hasCredential: false)!
        let replacement = ownership.begin()
        precondition(!ownership.ownsExpiration(expiration, hasCredential: false))
        precondition(!ownership.completeExpiration(expiration, hasCredential: false),
                     "expiry received before login must not reset the newer owner")
        precondition(ownership.complete(replacement))
        precondition(!ownership.completeExpiration(expiration, hasCredential: true))

        let cancelledByLogout = ownership.begin()
        let logout = ownership.beginSignOut()
        precondition(!ownership.complete(cancelledByLogout), "explicit logout cancels the already-running attempt immediately")
        let newerThanLogout = ownership.begin()
        precondition(!ownership.completeSignOut(logout), "delayed explicit logout must not cancel a later login")
        precondition(ownership.complete(newerThanLogout))
        let finalLogout = ownership.beginSignOut()
        precondition(ownership.completeSignOut(finalLogout))
        precondition(!ownership.completeSignOut(finalLogout), "logout commit is single-use")

        let cancelledRetry = ownership.begin()
        ownership.cancel(cancelledRetry)
        let cleanupAfterFailure = ownership.expirationTicket(hasCredential: false)!
        precondition(ownership.completeExpiration(cleanupAfterFailure, hasCredential: false),
                     "failed re-login must still permit expired old UI cleanup")

        print("Newest login ownership, stale 401 cleanup, explicit logout ordering and failed retry expiration passed.")
    }
}
