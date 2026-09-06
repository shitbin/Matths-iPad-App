import Foundation

@main
struct CurriculumParityCases {
    static func main() throws {
        let baseline = CurriculumAvailabilitySnapshot.safeBaseline(environment: "https://www.matths.kr")
        precondition(baseline.locked.values.filter { !$0 }.count == 5)
        precondition(baseline.locked.values.filter { $0 }.count == 8)
        precondition(!baseline.isAvailable("unknown"))
        precondition(!baseline.isAvailable("calculus-2"))
        let decoder = JSONDecoder()
        let good: [String: Any] = ["curriculum": ["schemaVersion": 1, "curriculum": ["id": "kr-2022"], "courses": [
            ["id": "calculus-2", "developmentLocked": false], ["id": "common-math-1", "developmentLocked": true]]]]
        let response = try decoder.decode(CurriculumAvailabilityResponse.self, from: JSONSerialization.data(withJSONObject: good))
        let live = try response.validated(environment: "https://staging.example")
        precondition(live.isAvailable("calculus-2") && !live.isAvailable("common-math-1"))
        precondition(live.environment != baseline.environment)
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
            let actual = vector.snapshot.projection(using: baseline)
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
