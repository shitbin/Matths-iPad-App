import Foundation

@main
struct CurriculumParityCases {
    static func main() throws {
        let baseline = CurriculumAvailabilitySnapshot.safeBaseline(environment: "https://www.matths.kr")
        precondition(baseline.locked.values.filter { !$0 }.count == 13)
        precondition(baseline.locked.values.filter { $0 }.count == 0)
        precondition(!baseline.isAvailable("unknown"))
        precondition(baseline.isAvailable("calculus-2"))
        let decoder = JSONDecoder()
        let good: [String: Any] = ["curriculum": ["schemaVersion": 1, "availabilityPolicyRevision": 2, "curriculum": ["id": "kr-2022"], "courses": [
            ["id": "calculus-2", "developmentLocked": false], ["id": "common-math-1", "developmentLocked": true]]]]
        let response = try decoder.decode(CurriculumAvailabilityResponse.self, from: JSONSerialization.data(withJSONObject: good))
        let live = try response.validated(environment: "https://staging.example")
        precondition(live.isAvailable("calculus-2") && !live.isAvailable("common-math-1"))
        precondition(live.environment != baseline.environment)
        var old = baseline
        old.availabilityPolicyRevision = nil
        for (index, id) in old.orderedCourseIDs.enumerated() { old.locked[id] = index >= 5 }
        let migrated = try decoder.decode(CurriculumAvailabilitySnapshot.self, from: JSONEncoder().encode(old)).migratingLegacyDevelopmentPolicy()
        precondition(migrated.locked.values.allSatisfy { !$0 } && migrated.source == .bundledSafeBaseline)
        let legacyEnvelope: [String: Any] = ["curriculum": ["schemaVersion": 1, "curriculum": ["id": "kr-2022"],
            "courses": old.orderedCourseIDs.map { ["id": $0, "developmentLocked": old.locked[$0]!] as [String: Any] }]]
        let legacyLive = try decoder.decode(CurriculumAvailabilityResponse.self, from: JSONSerialization.data(withJSONObject: legacyEnvelope)).validated(environment: baseline.environment)
        precondition(legacyLive.isAvailable("geometry") && legacyLive.source == .bundledSafeBaseline)
        var explicitDenied = baseline
        explicitDenied.locked["geometry"] = true; explicitDenied.explicitServerDenials = ["geometry"]
        let preserved = legacyLive.preservingExplicitServerDenials(from: explicitDenied)
        precondition(!preserved.isAvailable("geometry"), "old deployment metadata must not erase an actual 423")
        var foreignDenial = explicitDenied; foreignDenial.environment = "https://another-server.invalid"
        precondition(legacyLive.preservingExplicitServerDenials(from: foreignDenial).isAvailable("geometry"), "another environment's denial cannot leak into this release policy")
        precondition(live.preservingExplicitServerDenials(from: explicitDenied) == live, "a current revision server policy remains authoritative")
        for bad: Any in ["false", NSNull(), 0] {
            let json: [String: Any] = ["curriculum": ["schemaVersion": 1, "curriculum": ["id": "kr-2022"],
                                                   "courses": [["id": "calculus-2", "developmentLocked": bad]]]]
            do {
                _ = try decoder.decode(CurriculumAvailabilityResponse.self, from: JSONSerialization.data(withJSONObject: json))
                preconditionFailure("Malformed boolean widened access")
            } catch {}
        }
        for ids in [[], ["a", "a"], ["bad/id"]] {
            let json: [String: Any] = ["curriculum": ["schemaVersion": 1, "curriculum": ["id": "kr-2022"],
                                                   "courses": ids.map { ["id": $0, "developmentLocked": false] as [String:Any] }]]
            do {
                _ = try decoder.decode(CurriculumAvailabilityResponse.self, from: JSONSerialization.data(withJSONObject: json)).validated(environment: "production")
                preconditionFailure("Invalid course IDs accepted")
            } catch {}
        }
        CurriculumPolicy.apply(live)
        var denied = live; denied.locked["calculus-2"] = true
        CurriculumPolicy.apply(denied)
        precondition(!CurriculumPolicy.isAvailable("calculus-2"))
        CurriculumPolicy.apply(baseline)
        struct Fixture: Decodable {
            struct Row: Decodable {
                struct Expected: Decodable { let percent: Int; let done: Int; let total: Int; let nextConceptID: String? }
                let name: String; let snapshot: CanonicalLearningSnapshot; let expected: Expected
            }
            let webCommit: String; let vectors: [Row]
        }
        let fixture = try decoder.decode(Fixture.self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))
        precondition(fixture.webCommit == "e3cc06360415a4c60460895b01f06a3248dae665")
        for vector in fixture.vectors {
            // These are immutable e3cc063 golden vectors for its historical
            // five-course policy, not the current 13-course release decision.
            let actual = vector.snapshot.projection(using: old)
            let expected = vector.expected
            precondition(actual.percent == expected.percent && actual.done == expected.done && actual.total == expected.total && actual.nextConceptID == expected.nextConceptID, vector.name)
        }
        precondition(!PasswordChangeValidation.isValid("1234567", confirmation: "1234567"))
        precondition(!PasswordChangeValidation.isValid("12345678", confirmation: "12345678"))
        precondition(PasswordChangeValidation.isValid("abcd1234", confirmation: "abcd1234"))
        precondition(PasswordChangeValidation.isValid("🔒🔒🔒a1", confirmation: "🔒🔒🔒a1"))
        precondition(!PasswordChangeValidation.isValid(String(repeating: "한", count: 25), confirmation: String(repeating: "한", count: 25)))
        precondition(!PasswordChangeValidation.isValid("12345678", confirmation: "87654321"))
        print("Availability validation/cache isolation/423 policy, \(fixture.vectors.count) exact-Web projections, and password boundary cases PASS")
    }
}
