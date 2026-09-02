import Foundation

extension ServerAPI {
    struct AdminUserSchool: Codable, Hashable {
        var code: String?
        var name: String
        var region: String
    }

    struct AdminUserUniversity: Codable, Hashable {
        var name: String
        var region: String
    }

    struct AdminUserArenaActivity: Codable, Hashable {
        var level: Int
        var totalMatches: Int
        var matchesToNext: Int
        var isMaxLevel: Bool
    }

    struct AdminUserSummary: Codable, Identifiable, Hashable {
        var id: String
        var entityType: String
        var name: String
        var realName: String
        var email: String
        var role: String
        var school: AdminUserSchool?
        var university: AdminUserUniversity?
        var schoolGrade: Int?
        var educationStatus: String
        var isActive: Bool
        var accountStatus: String
        var accountStatusReason: String
        var suspendedUntil: String?
        var warningCount: Int
        var totalStudySeconds: Int
        var totalConnectedSeconds: Int
        var currentStreak: Int
        var longestStreak: Int
        var lastStudyDate: String?
        var lastLoginAt: String?
        var createdAt: String?
        var teacherAccessExpiresAt: String?
        var identityVerificationStatus: String
        var identityDuplicateAlertedAt: String?
        var parentChildCount: Int
        var arenaActivityLevel: AdminUserArenaActivity?
    }

    struct AdminUserFilter: Codable, Hashable {
        var query: String
        var schoolCode: String
        var grade: String
        var state: String
        var role: String
    }

    struct AdminUserPagination: Codable, Hashable {
        var page: Int
        var total: Int
        var totalPages: Int
        var perPage: Int
        var hasPrevious: Bool
        var hasNext: Bool
    }

    struct AdminUserSchoolOption: Codable, Hashable, Identifiable {
        var code: String
        var name: String
        var id: String { code }
    }

    struct AdminUserList: Codable, Hashable {
        var items: [AdminUserSummary]
        var schools: [AdminUserSchoolOption]
        var filter: AdminUserFilter
        var pagination: AdminUserPagination
    }

    struct AdminUserStreak: Codable, Hashable {
        var current: Int
        var longest: Int
        var lastStudyDate: String?
    }

    struct AdminUserLearningProgress: Codable, Identifiable, Hashable {
        var id: String
        var courseTitle: String
        var unitTitle: String
        var conceptTitle: String
        var status: String
        var completionPercent: Int
        var lastStudiedAt: String?
    }

    struct AdminUserLearning: Codable, Hashable {
        var currentConcept: AdminUserLearningProgress?
        var progressCount: Int
        var completedCount: Int
        var totalAttempts: Int
        var correctAttempts: Int
        var correctRate: Int
        var progress: [AdminUserLearningProgress]
    }

    struct AdminUserPackageAccess: Codable, Hashable {
        var packageType: String
        var label: String
        var availableLearningDays: Int
        var paybackScoreDays: Int
        var endsAt: String?
    }

    struct AdminUserAssessment: Codable, Identifiable, Hashable {
        var id: String
        var title: String
        var status: String
        var scorePercent: Int?
        var answeredCount: Int
        var startedAt: String?
        var submittedAt: String?
    }

    struct AdminUserRecord: Codable, Identifiable, Hashable {
        var id: String
        var kind: String
        var title: String
        var detail: String
        var status: String
        var createdAt: String?
    }

    struct AdminParentChild: Codable, Identifiable, Hashable {
        var id: String
        var name: String
        var realName: String
        var email: String
        var schoolName: String
        var schoolGrade: Int?
        var accountStatus: String
        var lastLoginAt: String?
        var todayStudyMinutes: Int
        var todaySolvedProblems: Int
        var weeklyStudyMinutes: Int
        var correctRate: Int
        var packageLabel: String
        var finalRank: Int?
        var arenaRank: String
        var emailEnabled: Bool
        var lowLearningEnabled: Bool
        var minimumMinutesPerDay: Int
        var lowLearningConsecutiveDays: Int
        var inactivityEnabled: Bool
        var inactivityDays: Int
    }

    struct AdminParentDetail: Codable, Hashable {
        var acceptedTermsAt: String?
        var children: [AdminParentChild]
    }

    struct AdminUserDetail: Codable, Hashable {
        var user: AdminUserSummary
        var streak: AdminUserStreak?
        var learning: AdminUserLearning
        var packageAccess: AdminUserPackageAccess?
        var arenaActivityLevel: AdminUserArenaActivity?
        var identityMatches: [AdminUserSummary]
        var assessments: [AdminUserAssessment]
        var records: [AdminUserRecord]
        var parent: AdminParentDetail?
    }

    struct AdminAuditPerson: Codable, Hashable {
        var id: String
        var name: String
        var nickname: String
        var email: String
    }

    struct AdminAuditItem: Codable, Identifiable, Hashable {
        var id: String
        var action: String
        var actionLabel: String
        var detail: String
        var actor: AdminAuditPerson?
        var target: AdminAuditPerson?
        var createdAt: String?
    }

    struct AdminAuditPage: Codable, Hashable {
        var items: [AdminAuditItem]
        var pagination: AdminUserPagination
    }

    struct AdminFullAuditPage: Codable, Hashable {
        struct Filter: Codable, Hashable {
            var adminUserId: String
            var query: String
        }
        var items: [AdminAuditItem]
        var admins: [AdminAuditPerson]
        var filter: Filter
        var pagination: AdminUserPagination
    }

    struct AdminUserActivityItem: Codable, Identifiable, Hashable {
        var id: String
        var kind: String
        var title: String
        var subtitle: String
        var detail: String
        var status: String
        var metadata: String
        var attemptId: String
        var occurredAt: String?
    }

    struct AdminUserActivityPage: Codable, Hashable {
        var user: AdminUserSummary
        var kind: String
        var items: [AdminUserActivityItem]
        var pagination: AdminUserPagination
    }

    struct AdminAssessmentChoice: Codable, Hashable, Identifiable {
        var key: String
        var text: String
        var id: String { key }
    }

    struct AdminAssessmentQuestion: Codable, Hashable, Identifiable {
        var id: String
        var number: Int
        var prompt: String
        var choices: [AdminAssessmentChoice]
        var submittedAnswer: String
        var answer: String
        var isCorrect: Bool?
        var points: Int
        var responseTimeMs: Int
        var answerChanges: Int
        var typeLabel: String
        var solution: String
    }

    struct AdminAssessmentAttempt: Codable, Hashable, Identifiable {
        var id: String
        var title: String
        var scopeType: String
        var status: String
        var disqualifiedReason: String
        var scorePercent: Int?
        var earnedPoints: Int
        var totalPoints: Int
        var elapsedTimeMs: Int
        var passed: Bool?
        var hasFinalScore: Bool
        var answeredCount: Int
        var startedAt: String?
        var submittedAt: String?
        var deadlineAt: String?
        var questions: [AdminAssessmentQuestion]
    }

    struct AdminAssessmentDetail: Codable, Hashable {
        var user: AdminUserSummary
        var attempt: AdminAssessmentAttempt
    }

    private struct AdminUsersEnvelope: Codable {
        var schemaVersion: String
        var users: AdminUserList
    }

    private struct AdminUserDetailEnvelope: Codable {
        var schemaVersion: String
        var detail: AdminUserDetail
    }

    private struct AdminSanctionsEnvelope: Codable {
        var schemaVersion: String
        var sanctions: AdminAuditPage
    }

    private struct AdminAuditEnvelope: Codable {
        var schemaVersion: String
        var audit: AdminFullAuditPage
    }

    private struct AdminUserActivityEnvelope: Codable {
        var schemaVersion: String
        var activity: AdminUserActivityPage
    }

    private struct AdminAssessmentDetailEnvelope: Codable {
        var schemaVersion: String
        var assessment: AdminAssessmentDetail
    }

    private struct AdminUserMutationEnvelope: Codable {
        var schemaVersion: String
        var ok: Bool
        var delivered: Bool?
        var purged: Bool?
        var detail: AdminUserDetail?
    }

    static func adminUsers(
        query: String = "", schoolCode: String = "", grade: String = "",
        state: String = "", role: String = "", page: Int = 1
    ) async throws -> AdminUserList {
        let value: AdminUsersEnvelope = try await request(
            "GET", "/api/v1/admin/users", body: nil, authed: true,
            query: [
                "query": query, "school": schoolCode, "grade": grade,
                "state": state, "role": role, "page": String(max(1, page)),
            ])
        try validateAdminUsersSchema(value.schemaVersion)
        return value.users
    }

    static func adminUser(id: String) async throws -> AdminUserDetail {
        let value: AdminUserDetailEnvelope = try await request(
            "GET", "/api/v1/admin/users/\(id)", body: nil, authed: true)
        try validateAdminUsersSchema(value.schemaVersion)
        return value.detail
    }

    static func adminUserActivity(
        userID: String, kind: String = "learning", page: Int = 1
    ) async throws -> AdminUserActivityPage {
        let value: AdminUserActivityEnvelope = try await request(
            "GET", "/api/v1/admin/users/\(userID)/activity", body: nil, authed: true,
            query: ["kind": kind, "page": String(max(1, page))])
        try validateAdminUsersSchema(value.schemaVersion)
        return value.activity
    }

    static func adminUserAssessment(
        userID: String, attemptID: String
    ) async throws -> AdminAssessmentDetail {
        let value: AdminAssessmentDetailEnvelope = try await request(
            "GET", "/api/v1/admin/users/\(userID)/assessments/\(attemptID)",
            body: nil, authed: true)
        try validateAdminUsersSchema(value.schemaVersion)
        return value.assessment
    }

    static func adminParent(id: String) async throws -> AdminUserDetail {
        let value: AdminUserDetailEnvelope = try await request(
            "GET", "/api/v1/admin/parents/\(id)", body: nil, authed: true)
        try validateAdminUsersSchema(value.schemaVersion)
        return value.detail
    }

    static func adminSanctions(page: Int = 1) async throws -> AdminAuditPage {
        let value: AdminSanctionsEnvelope = try await request(
            "GET", "/api/v1/admin/sanctions", body: nil, authed: true,
            query: ["page": String(max(1, page))])
        try validateAdminUsersSchema(value.schemaVersion)
        return value.sanctions
    }

    static func adminAudit(query: String = "", adminID: String = "", page: Int = 1) async throws -> AdminFullAuditPage {
        let value: AdminAuditEnvelope = try await request(
            "GET", "/api/v1/admin/audit-log", body: nil, authed: true,
            query: ["query": query, "admin": adminID, "page": String(max(1, page))])
        try validateAdminUsersSchema(value.schemaVersion)
        return value.audit
    }

    static func requestAdminNicknameChange(userID: String, reason: String) async throws {
        _ = try await adminUserMutation(
            path: "/api/v1/admin/users/\(userID)/nickname-request",
            body: ["reason": reason])
    }

    static func sendAdminUserNotification(
        userID: String, title: String, message: String, href: String
    ) async throws {
        _ = try await adminUserMutation(
            path: "/api/v1/admin/users/\(userID)/notification",
            body: ["title": title, "message": message, "href": href])
    }

    @discardableResult
    static func sendAdminUserEmail(userID: String, subject: String, message: String) async throws -> Bool {
        let value = try await adminUserMutation(
            path: "/api/v1/admin/users/\(userID)/email",
            body: ["subject": subject, "message": message])
        return value.delivered ?? false
    }

    static func sendAdminPasswordReset(userID: String) async throws {
        _ = try await adminUserMutation(
            path: "/api/v1/admin/users/\(userID)/password-reset", body: [:])
    }

    static func updateAdminUserRole(
        userID: String, role: String, teacherAccessExpiresAt: String, reason: String
    ) async throws -> AdminUserDetail? {
        try await adminUserMutation(
            path: "/api/v1/admin/users/\(userID)/role",
            body: [
                "role": role,
                "teacherAccessExpiresAt": teacherAccessExpiresAt,
                "reason": reason,
            ]).detail
    }

    static func updateAdminUserAccountStatus(
        userID: String, status: String, suspensionDays: String, reason: String
    ) async throws -> AdminUserDetail? {
        try await adminUserMutation(
            path: "/api/v1/admin/users/\(userID)/account-status",
            body: ["status": status, "suspensionDays": suspensionDays, "reason": reason]).detail
    }

    static func updateAdminUserWarnings(
        userID: String, warningCount: Int, reason: String
    ) async throws -> AdminUserDetail? {
        try await adminUserMutation(
            path: "/api/v1/admin/users/\(userID)/warnings",
            body: ["warningCount": warningCount, "reason": reason]).detail
    }

    static func updateAdminUserPackage(
        userID: String, packageType: String, reason: String
    ) async throws -> AdminUserDetail? {
        try await adminUserMutation(
            path: "/api/v1/admin/users/\(userID)/package-access",
            body: ["packageType": packageType, "reason": reason]).detail
    }

    @discardableResult
    static func withdrawAdminUser(
        userID: String, reason: String, dataRetention: String, confirmation: String
    ) async throws -> Bool {
        let value = try await adminUserMutation(
            path: "/api/v1/admin/users/\(userID)/withdraw",
            body: [
                "reason": reason,
                "dataRetention": dataRetention,
                "confirmation": confirmation,
            ])
        return value.purged ?? false
    }

    static func updateAdminParentStatus(
        parentID: String, isActive: Bool, reason: String
    ) async throws -> AdminUserDetail? {
        try await adminUserMutation(
            path: "/api/v1/admin/parents/\(parentID)/account-status",
            body: ["isActive": isActive, "reason": reason]).detail
    }

    static func updateAdminParentChildNotifications(
        parentID: String, childID: String, emailEnabled: Bool,
        lowLearningEnabled: Bool, minimumMinutesPerDay: Int,
        lowLearningConsecutiveDays: Int, inactivityEnabled: Bool,
        inactivityDays: Int
    ) async throws -> AdminUserDetail? {
        try await adminUserMutation(
            path: "/api/v1/admin/parents/\(parentID)/children/\(childID)/notifications",
            body: [
                "emailEnabled": emailEnabled,
                "lowLearningEnabled": lowLearningEnabled,
                "minimumMinutesPerDay": minimumMinutesPerDay,
                "lowLearningConsecutiveDays": lowLearningConsecutiveDays,
                "inactivityEnabled": inactivityEnabled,
                "inactivityDays": inactivityDays,
            ]).detail
    }

    static func unlinkAdminParentChild(
        parentID: String, childID: String, reason: String
    ) async throws -> AdminUserDetail? {
        try await adminUserMutation(
            path: "/api/v1/admin/parents/\(parentID)/children/\(childID)/unlink",
            body: ["reason": reason]).detail
    }

    private static func adminUserMutation(
        path: String, body: [String: Any]
    ) async throws -> AdminUserMutationEnvelope {
        let value: AdminUserMutationEnvelope = try await request(
            "POST", path, body: body, authed: true)
        try validateAdminUsersSchema(value.schemaVersion)
        guard value.ok else {
            throw ServerAPIError(
                message: "사용자 관리 작업을 저장하지 못했습니다.",
                code: "ADMIN_USER_ACTION_FAILED")
        }
        return value
    }

    private static func validateAdminUsersSchema(_ value: String) throws {
        guard value == "ADMIN_USERS_NATIVE_V1" else {
            throw ServerAPIError(
                message: "관리자 사용자 응답 버전이 앱과 맞지 않습니다.",
                code: "ADMIN_USERS_SCHEMA_UNSUPPORTED")
        }
    }
}
