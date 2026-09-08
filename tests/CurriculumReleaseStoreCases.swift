import Foundation

struct ServerAPIError: Error { var statusCode: Int? }
@MainActor enum ServerAPI {
    struct AuthorizationSnapshot { let generation: Int }
    nonisolated static let baseURL = URL(string: "https://qa.invalid")!
    static var generation = 1
    static var authorized = true
    static var response: Data = Data()
    static var failure: Error?
    static var requests = 0
    static func captureAuthorization() -> AuthorizationSnapshot? { authorized ? .init(generation: generation) : nil }
    static func isCurrentAuthorization(_ value: AuthorizationSnapshot) -> Bool { authorized && generation == value.generation }
    static func getCurriculumAvailability(authorization: AuthorizationSnapshot) async throws -> CurriculumAvailabilityResponse {
        requests += 1
        if let failure { throw failure }
        return try JSONDecoder().decode(CurriculumAvailabilityResponse.self, from: response)
    }
}

@main enum CurriculumReleaseStoreCases {
    @MainActor static func main() async throws {
        let environment = "https://qa.invalid/" + UUID().uuidString
        let key = "matths.curriculum.availability.v1." + environment
        defer { UserDefaults.standard.removeObject(forKey: key) }
        var old = CurriculumAvailabilitySnapshot.safeBaseline(environment: environment)
        old.availabilityPolicyRevision = nil
        old.source = .lastVerifiedCache
        for (index, id) in old.orderedCourseIDs.enumerated() { old.locked[id] = index >= 5 }
        UserDefaults.standard.set(try JSONEncoder().encode(old), forKey: key)
        let store = CurriculumAvailabilityStore(environment: environment)
        precondition(store.snapshot.locked.values.allSatisfy { !$0 })
        precondition(store.snapshot.source == .bundledSafeBaseline, "migrated local release policy must not claim a verified live server policy")

        func response(revision: Int?, lockGeometry: Bool) throws -> Data {
            var catalog: [String: Any] = ["schemaVersion": 1, "curriculum": ["id": "kr-2022"],
                "courses": old.orderedCourseIDs.map { ["id": $0, "developmentLocked": $0 == "geometry" ? lockGeometry : old.locked[$0]!] as [String: Any] }]
            if let revision { catalog["availabilityPolicyRevision"] = revision }
            return try JSONSerialization.data(withJSONObject: ["curriculum": catalog])
        }
        ServerAPI.response = try response(revision: nil, lockGeometry: true)
        await store.refresh(force: true)
        precondition(store.snapshot.isAvailable("geometry") && store.snapshot.isAvailable("ai-math"))
        precondition(store.state == .ready && store.snapshot.source == .bundledSafeBaseline)
        let migratedReload = CurriculumAvailabilityStore(environment: environment)
        precondition(migratedReload.snapshot.source == .bundledSafeBaseline,
                     "persisted bundled release policy must not become a supposedly verified server policy on relaunch")
        let count = ServerAPI.requests
        await store.refresh()
        precondition(ServerAPI.requests == count, "verified legacy metadata must also observe the bounded refresh interval")

        store.deny("geometry")
        precondition(!store.snapshot.isAvailable("geometry"))
        await store.refresh(force: true)
        precondition(!store.snapshot.isAvailable("geometry"), "old five-course manifest must not erase an actual 423")
        let relaunched = CurriculumAvailabilityStore(environment: environment)
        precondition(!relaunched.snapshot.isAvailable("geometry"), "explicit server denial survives cache reload")
        let last = store.snapshot
        ServerAPI.failure = URLError(.notConnectedToInternet)
        await store.refresh(force: true)
        precondition(store.state == .offline && store.snapshot == last, "network failure is not an unlock or a successful fetch")
        ServerAPI.failure = nil; ServerAPI.response = Data("{malformed".utf8)
        await store.refresh(force: true)
        precondition(store.state == .failed && store.snapshot == last)
        ServerAPI.authorized = false
        await store.refresh(force: true)
        precondition(store.state == .authenticationRequired && store.snapshot == last)

        ServerAPI.authorized = true
        ServerAPI.response = try response(revision: 2, lockGeometry: true)
        await store.refresh(force: true)
        precondition(!store.snapshot.isAvailable("geometry") && store.snapshot.source == .liveServer,
                     "new revision policy restrictions are honored rather than unconditionally opened")
        ServerAPI.response = try response(revision: 2, lockGeometry: false)
        await store.refresh(force: true)
        precondition(store.snapshot.isAvailable("geometry"), "current verified policy can explicitly reopen a previously denied course")
        precondition(!store.snapshot.isAvailable("not-authored"))
        print("Actual availability Store PASS: old cache/server migration, 13 bundled courses, explicit423 persistence, current revision authority, invalid/offline/auth failure preservation and bounded refresh.")
    }
}
