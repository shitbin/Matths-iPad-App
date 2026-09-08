import Foundation

enum DataScope {
    static let slot = "isolated-demo-assessment"
    static func url(_ name: String) -> URL { FileManager.default.temporaryDirectory.appendingPathComponent(name) }
    static func url(_ name: String, for slot: String) -> URL { url(name) }
}

enum ServerAPI {
    struct AuthorizationSnapshot {}
    static var response = Data()
    static func authorizationForCurrentRequest() -> AuthorizationSnapshot { .init() }
    static func request<T: Decodable>(_ method: String, _ path: String, body: [String: Any]?, authed: Bool,
                                      authorization: AuthorizationSnapshot) async throws -> T {
        try JSONDecoder().decode(T.self, from: response)
    }
}

@main enum DemoAssessmentContractCases {
    static func main() async throws {
        let now = Date(timeIntervalSince1970: 1_788_840_000)
        ServerAPI.response = Data(DemoTemplate.resolve(DemoAssessmentFixtures.assessments, now: now).utf8)
        let values = try await ServerAPI.assessmentSnapshot()
        let invalid = values.filter { $0.localValue() == nil }
        if CommandLine.arguments.contains("--diagnose") {
            print("demo snapshot rows=\(values.count), localValue valid=\(values.count - invalid.count), invalid IDs=\(invalid.map(\.id))")
            return
        }
        precondition(values.count == 3)
        precondition(invalid.isEmpty, "all demo snapshot rows must satisfy the actual production RemoteAssessment conversion")
        precondition(values.filter { $0.status == "submitted" }.count == 2)
        precondition(values.filter { $0.status == "in-progress" }.count == 1)
        for value in values {
            let local = value.localValue()!
            precondition(local.serverBacked == true && local.serverDeadlineAt! > local.createdAt)
        }
        // Keep the production integrity guard strict; correcting fixtures must
        // not make a deadline equal to/before its start valid in a real response.
        var malformed = values[0]
        malformed.deadlineAt = malformed.startedAt
        precondition(malformed.localValue() == nil)
        malformed.deadlineAt = "not-a-date"
        precondition(malformed.localValue() == nil)
        for template in [
            DemoAssessmentFixtures.assessmentDetail(id: "demo-assessment-03"),
            DemoAssessmentFixtures.startedAssessment(body: ["scopeType": "subunit", "courseId": "common-math-1"]),
            DemoAssessmentFixtures.submittedAssessment(id: "demo-assessment-03")
        ] {
            ServerAPI.response = Data(DemoTemplate.resolve(template, now: now).utf8)
            let detail = try await ServerAPI.assessmentAttempt("demo-assessment-03")
            precondition(detail.localValue() != nil, "demo detail/start/submit must satisfy the same converter")
        }
        print("PASS: actual demo templates and production AssessmentSyncAPI decode all 3 snapshot rows plus detail/start/submit; malformed deadline guard retained")
    }
}
