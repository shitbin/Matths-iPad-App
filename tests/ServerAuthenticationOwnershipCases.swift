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

        print("Only the newest live authentication attempt can install a session token.")
    }
}
