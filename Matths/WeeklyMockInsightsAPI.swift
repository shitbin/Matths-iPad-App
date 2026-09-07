import Foundation

enum WeeklyMockInsightScope: Equatable {
    case teacher(classID: String?)
    case admin(academyID: String?)

    var key: String {
        switch self {
        case .teacher(let id): "teacher:" + (id ?? "academy")
        case .admin(let id): "admin:" + (id ?? "global")
        }
    }
    func path() throws -> String {
        func validated(_ id: String) throws -> String {
            guard id.range(of: "^[a-fA-F0-9]{24}$", options: .regularExpression) != nil else {
                throw ServerAPIError(message: "분석 범위를 확인한 뒤 다시 선택해 주세요.")
            }
            return id
        }
        switch self {
        case .teacher(let id):
            if let id { return "/api/v1/academy/teacher/weekly-mock-insights?classId=\(try validated(id))" }
            return "/api/v1/academy/teacher/weekly-mock-insights"
        case .admin(let id):
            if let id { return "/api/v1/academy/admin/\(try validated(id))/weekly-mock-insights" }
            return "/api/v1/admin/weekly-mock-insights"
        }
    }
}

extension ServerAPI {
    struct WeeklyMockConceptInsight: Codable, Equatable, Identifiable {
        var conceptId: String
        var conceptTitle: String
        var courseTitle: String
        var unitTitle: String
        var responseCount: Int
        var correctCount: Int
        var questionCount: Int
        var examCount: Int
        var accuracy: Int
        var difficulty: Int
        var code: String
        var label: String
        var level: Int
        // Canonical aggregation groups by course + unit + concept. conceptId
        // alone can repeat across courses and is not a safe SwiftUI identity.
        var id: String { [courseTitle, unitTitle, conceptId].joined(separator: "::") }
    }
    struct WeeklyMockInsight: Codable, Equatable {
        var scopeLabel: String
        var examCount: Int
        var participantCount: Int
        var submissionCount: Int
        var averageScore: Double?
        var conceptCount: Int
        var concepts: [WeeklyMockConceptInsight]
        var hardestConcept: WeeklyMockConceptInsight?
        var generatedAt: String
    }
    struct WeeklyMockClassInsight: Codable, Equatable, Identifiable {
        var classId: String
        var className: String
        var isActive: Bool
        var studentCount: Int
        var insight: WeeklyMockInsight
        var id: String { classId }
    }
    struct WeeklyMockInsightsResponse: Codable, Equatable {
        struct Scope: Codable, Equatable { var kind: String; var id: String; var label: String }
        var schemaVersion: String
        var scope: Scope
        var overall: WeeklyMockInsight
        var classes: [WeeklyMockClassInsight]
    }
    static func weeklyMockInsights(scope: WeeklyMockInsightScope, authorization: AuthorizationSnapshot) async throws -> WeeklyMockInsightsResponse {
        let result: WeeklyMockInsightsResponse = try await request("GET", scope.path(), body: nil, authed: true, authorization: authorization)
        guard result.schemaVersion == "WEEKLY_MOCK_INSIGHTS_NATIVE_V1" else {
            throw ServerAPIError(message: "주간 모의고사 분석 형식을 확인할 수 없습니다. 앱과 서버를 업데이트한 뒤 다시 시도해 주세요.")
        }
        let matchesScope: Bool
        switch scope {
        case .teacher(let id): matchesScope = id.map { result.scope.kind == "class" && result.scope.id == $0 } ?? (result.scope.kind == "academy")
        case .admin(let id): matchesScope = id.map { result.scope.kind == "academy" && result.scope.id == $0 } ?? (result.scope.kind == "global" && result.scope.id == "global")
        }
        guard matchesScope else { throw ServerAPIError(message: "요청한 범위와 다른 분석 응답입니다. 다시 조회해 주세요.") }
        return result
    }
}
