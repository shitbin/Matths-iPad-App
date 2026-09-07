import Foundation

extension ServerAPI {
    private struct AcademyAssignmentEnvelope: Codable {
        var schemaVersion: String
        var submission: AcademyAssignmentSubmission
    }
    static func submitAcademyAssignment(weekID: String, answers: [String], authorization: AuthorizationSnapshot) async throws -> AcademyAssignmentSubmission {
        guard weekID.range(of: #"^[A-Za-z0-9_-]{1,160}$"#, options: .regularExpression) != nil,
              (1...100).contains(answers.count) else {
            throw ServerAPIError(message: "과제와 문항 수를 확인해 주세요.", code: "ACADEMY_OMR_INVALID")
        }
        let normalized = answers.map(AcademyAssignmentConfiguration.normalizedAnswer)
        guard normalized.allSatisfy({ !$0.isEmpty && $0.utf16.count <= 80 }) else {
            throw ServerAPIError(message: "모든 문항의 답안을 80자 이내로 입력해 주세요.", code: "ACADEMY_OMR_INVALID")
        }
        let value: AcademyAssignmentEnvelope = try await request("POST", "/api/v1/academy/student/weeks/\(weekID)/submission",
            body: ["answers": normalized], authed: true, authorization: authorization)
        guard value.schemaVersion == "ACADEMY_ASSIGNMENT_V1", value.submission.isValid,
              value.submission.weekId == weekID,
              value.submission.answers.map(AcademyAssignmentConfiguration.normalizedAnswer) == normalized else {
            throw ServerAPIError(message: "제출 결과를 확인하지 못했습니다. 답안은 보관하고 계정의 제출 내역을 다시 확인해 주세요.", code: "ACADEMY_OMR_RECEIPT_INVALID")
        }
        return value.submission
    }
}
