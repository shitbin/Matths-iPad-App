import Foundation

extension ServerAPI {
    struct AdminCommunityPerson: Codable, Hashable {
        var id: String
        var name: String
        var email: String
        var role: String
        var warningCount: Int
    }
    struct AdminCommunityPost: Codable, Identifiable, Hashable {
        var id: String
        var boardType: String
        var schoolCode: String
        var schoolName: String
        var title: String
        var content: String
        var status: String
        var isPinned: Bool
        var warningIssued: Bool
        var moderationReason: String
        var viewCount: Int
        var createdAt: String?
        var author: AdminCommunityPerson
    }
    struct AdminCommunityNotice: Codable, Identifiable, Hashable {
        var id: String
        var boardType: String
        var schoolCode: String
        var schoolName: String
        var universityCode: String
        var universityName: String
        var title: String
        var content: String
        var status: String
        var isPinned: Bool
        var isSystem: Bool
        var createdAt: String?
        var updatedAt: String?
    }
    struct AdminCommunityComment: Codable, Identifiable, Hashable {
        var id: String
        var postId: String
        var postTitle: String
        var content: String
        var status: String
        var warningIssued: Bool
        var moderationReason: String
        var createdAt: String?
        var author: AdminCommunityPerson
    }
    struct AdminCommunityReport: Codable, Identifiable, Hashable {
        var id: String
        var status: String
        var reason: String
        var resolution: String
        var createdAt: String?
        var reporter: AdminCommunityPerson
        var reportedUser: AdminCommunityPerson
        var post: AdminCommunityPost?
    }
    struct AdminCommunityFilters: Codable, Hashable { var board: String; var status: String; var search: String }
    struct AdminCommunityStats: Codable, Hashable { var total: Int; var published: Int; var hidden: Int; var deleted: Int }
    struct AdminCommunityPagination: Codable, Hashable {
        var page: Int; var totalPages: Int; var total: Int; var hasPrevious: Bool; var hasNext: Bool
    }
    struct AdminCommunityDashboard: Codable, Hashable {
        var posts: [AdminCommunityPost]
        var notices: [AdminCommunityNotice]
        var comments: [AdminCommunityComment]
        var reports: [AdminCommunityReport]
        var boardLabels: [String: String]
        var filters: AdminCommunityFilters
        var stats: AdminCommunityStats
        var pagination: AdminCommunityPagination
    }
    private struct AdminCommunityEnvelope: Codable {
        var schemaVersion: String
        var community: AdminCommunityDashboard
    }
    private struct AdminCommunityMutationEnvelope: Codable {
        var schemaVersion: String
        var ok: Bool
        var community: AdminCommunityDashboard
    }

    static func adminCommunity(board: String = "", status: String = "", search: String = "", page: Int = 1) async throws -> AdminCommunityDashboard {
        let value: AdminCommunityEnvelope = try await request(
            "GET", "/api/v1/admin/community", body: nil, authed: true,
            query: ["board": board, "status": status, "search": search, "page": String(max(1, page))])
        try validateAdminCommunity(value.schemaVersion)
        return value.community
    }
    static func createAdminCommunityNotice(board: String, schoolCode: String, schoolName: String, universityCode: String, universityName: String, title: String, content: String) async throws -> AdminCommunityDashboard {
        try await communityMutation(path: "/api/v1/admin/community/notices", body: [
            "board": board, "schoolCode": schoolCode, "schoolName": schoolName,
            "universityCode": universityCode, "universityName": universityName,
            "title": title, "content": content,
        ])
    }
    static func updateAdminCommunityNotice(_ item: AdminCommunityNotice, board: String, schoolCode: String, schoolName: String, universityCode: String, universityName: String, title: String, content: String) async throws -> AdminCommunityDashboard {
        try await communityMutation(path: "/api/v1/admin/community/notices/\(item.id)", body: [
            "board": board, "schoolCode": schoolCode, "schoolName": schoolName,
            "universityCode": universityCode, "universityName": universityName,
            "title": title, "content": content,
        ])
    }
    static func pinAdminCommunityNotice(id: String, pinned: Bool) async throws -> AdminCommunityDashboard {
        try await communityMutation(path: "/api/v1/admin/community/notices/\(id)/pin", body: ["pinned": pinned])
    }
    static func moderateAdminCommunityNotice(id: String, action: String) async throws -> AdminCommunityDashboard {
        try await communityMutation(path: "/api/v1/admin/community/notices/\(id)/status", body: ["action": action])
    }
    static func reviewAdminCommunityReport(id: String, status: String, resolution: String) async throws -> AdminCommunityDashboard {
        try await communityMutation(path: "/api/v1/admin/community/reports/\(id)/review", body: ["status": status, "resolution": resolution])
    }
    static func editAdminCommunityPost(id: String, title: String, content: String, reason: String) async throws -> AdminCommunityDashboard {
        try await communityMutation(path: "/api/v1/admin/community/posts/\(id)", body: ["title": title, "content": content, "reason": reason])
    }
    static func pinAdminCommunityPost(id: String, pinned: Bool) async throws -> AdminCommunityDashboard {
        try await communityMutation(path: "/api/v1/admin/community/posts/\(id)/pin", body: ["pinned": pinned])
    }
    static func moderateAdminCommunityPost(id: String, action: String, reason: String, reportID: String = "") async throws -> AdminCommunityDashboard {
        try await communityMutation(path: "/api/v1/admin/community/posts/\(id)/status", body: ["action": action, "reason": reason, "reportId": reportID])
    }
    static func warnAdminCommunityPost(id: String, reason: String, reportID: String = "") async throws -> AdminCommunityDashboard {
        try await communityMutation(path: "/api/v1/admin/community/posts/\(id)/warn", body: ["reason": reason, "reportId": reportID])
    }
    static func moderateAdminCommunityComment(id: String, action: String, reason: String) async throws -> AdminCommunityDashboard {
        try await communityMutation(path: "/api/v1/admin/community/comments/\(id)/status", body: ["action": action, "reason": reason])
    }
    static func warnAdminCommunityComment(id: String, reason: String) async throws -> AdminCommunityDashboard {
        try await communityMutation(path: "/api/v1/admin/community/comments/\(id)/warn", body: ["reason": reason])
    }
    private static func communityMutation(path: String, body: [String: Any]) async throws -> AdminCommunityDashboard {
        let value: AdminCommunityMutationEnvelope = try await request("POST", path, body: body, authed: true)
        try validateAdminCommunity(value.schemaVersion)
        guard value.ok else { throw ServerAPIError(message: "게시판 관리 작업을 저장하지 못했습니다.", code: "ADMIN_COMMUNITY_ACTION_FAILED") }
        return value.community
    }
    private static func validateAdminCommunity(_ value: String) throws {
        guard value == "ADMIN_COMMUNITY_NATIVE_V1" else {
            throw ServerAPIError(message: "게시판 관리 응답 버전이 앱과 맞지 않습니다.", code: "ADMIN_COMMUNITY_SCHEMA_UNSUPPORTED")
        }
    }
}
