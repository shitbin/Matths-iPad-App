import Foundation

extension ServerAPI {
    struct AdminOperationsStats: Codable, Hashable {
        var activeUsers: Int?
        var activeParents: Int?
        var pendingInquiries: Int?
        var publishedAnnouncements: Int?
        var archiveItems: Int?
        var archiveFolders: Int?
        var pendingAcademies: Int?
    }

    struct AdminOperationsPerson: Codable, Hashable {
        var id: String
        var name: String
        var email: String
    }

    struct AdminOperationsTodo: Codable, Identifiable, Hashable {
        var id: String
        var category: String
        var title: String
        var description: String
        var href: String
        var status: String
        var createdAt: String?
        var completedAt: String?
        var actor: AdminOperationsPerson?
        var target: AdminOperationsPerson?
        var completedBy: AdminOperationsPerson?
    }

    struct AdminInquiryReply: Codable, Hashable {
        var message: String
        var sentTo: String
        var repliedAt: String?
    }

    struct AdminOperationsInquiry: Codable, Identifiable, Hashable {
        var id: String
        var subject: String
        var content: String
        var status: String
        var inquiryType: String
        var contactEmail: String
        var createdAt: String?
        var adminReply: AdminInquiryReply?
    }

    struct AdminOperationsAnnouncement: Codable, Identifiable, Hashable {
        var id: String
        var title: String
        var content: String
        var boardCategory: String
        var href: String
        var isPublished: Bool
        var createdAt: String?
        var publishedAt: String?
        var dashboardEndsAt: String?
        var deliveredAt: String?
    }

    struct AdminOperationsAnnouncementList: Codable, Hashable {
        var status: String
        var items: [AdminOperationsAnnouncement]
    }

    struct AdminOperationsDashboard: Codable, Hashable {
        var stats: AdminOperationsStats
        var pendingTodoCount: Int
        var priorityTodos: [AdminOperationsTodo]
        var recentInquiries: [AdminOperationsInquiry]
    }

    struct AdminOperationsPagination: Codable, Hashable {
        var page: Int
        var total: Int
        var totalPages: Int
        var hasPrevious: Bool
        var hasNext: Bool
    }

    struct AdminOperationsTodoPage: Codable, Hashable {
        struct Filter: Codable, Hashable {
            var category: String
            var status: String
            var dateFrom: String?
            var dateTo: String?
            var nickname: String?
        }

        var items: [AdminOperationsTodo]
        var filter: Filter
        var pagination: AdminOperationsPagination
    }

    struct AdminOperationsInquiryPage: Codable, Hashable {
        struct Filter: Codable, Hashable { var status: String }

        var items: [AdminOperationsInquiry]
        var filter: Filter
        var pagination: AdminOperationsPagination
    }

    private struct AdminOperationsEnvelope: Codable {
        var schemaVersion: String
        var operations: AdminOperationsDashboard
    }

    private struct AdminTodoEnvelope: Codable {
        var schemaVersion: String
        var todos: AdminOperationsTodoPage
    }

    private struct AdminInquiryEnvelope: Codable {
        var schemaVersion: String
        var inquiries: AdminOperationsInquiryPage
    }

    private struct AdminOperationMutationEnvelope: Codable {
        var schemaVersion: String
        var ok: Bool
        var delivered: Bool?
    }

    private struct AdminAnnouncementListEnvelope: Codable {
        var schemaVersion: String
        var announcements: AdminOperationsAnnouncementList
    }

    private struct AdminAnnouncementEnvelope: Codable {
        var schemaVersion: String
        var announcement: AdminOperationsAnnouncement
    }

    static func adminOperationsDashboard() async throws -> AdminOperationsDashboard {
        let value: AdminOperationsEnvelope = try await request(
            "GET", "/api/v1/admin/operations", body: nil, authed: true)
        try validateAdminOperationsSchema(value.schemaVersion)
        return value.operations
    }

    static func adminOperationsTodos(
        category: String = "",
        status: String = "pending",
        page: Int = 1,
        nickname: String = ""
    ) async throws -> AdminOperationsTodoPage {
        let value: AdminTodoEnvelope = try await request(
            "GET", "/api/v1/admin/todos", body: nil, authed: true,
            query: [
                "category": category,
                "status": status,
                "page": String(max(1, page)),
                "nickname": nickname,
            ])
        try validateAdminOperationsSchema(value.schemaVersion)
        return value.todos
    }

    static func setAdminTodo(id: String, completed: Bool) async throws {
        let action = completed ? "complete" : "reopen"
        let value: AdminOperationMutationEnvelope = try await request(
            "POST", "/api/v1/admin/todos/\(id)/\(action)", body: [:], authed: true)
        try validateAdminOperationsSchema(value.schemaVersion)
        guard value.ok else {
            throw ServerAPIError(message: "운영 할 일 상태를 저장하지 못했습니다.", code: "ADMIN_TODO_SAVE_FAILED")
        }
    }

    static func adminOperationsInquiries(
        status: String = "pending",
        page: Int = 1
    ) async throws -> AdminOperationsInquiryPage {
        let value: AdminInquiryEnvelope = try await request(
            "GET", "/api/v1/admin/inquiries", body: nil, authed: true,
            query: ["status": status, "page": String(max(1, page))])
        try validateAdminOperationsSchema(value.schemaVersion)
        return value.inquiries
    }

    @discardableResult
    static func replyToAdminInquiry(id: String, message: String) async throws -> Bool {
        let value: AdminOperationMutationEnvelope = try await request(
            "POST", "/api/v1/admin/inquiries/\(id)/reply",
            body: ["message": message], authed: true)
        try validateAdminOperationsSchema(value.schemaVersion)
        guard value.ok else {
            throw ServerAPIError(message: "문의 답변을 전송하지 못했습니다.", code: "ADMIN_REPLY_FAILED")
        }
        return value.delivered ?? false
    }

    static func updateAdminInquiryStatus(id: String, status: String) async throws {
        let value: AdminOperationMutationEnvelope = try await request(
            "POST", "/api/v1/admin/inquiries/\(id)/status",
            body: ["status": status], authed: true)
        try validateAdminOperationsSchema(value.schemaVersion)
        guard value.ok else {
            throw ServerAPIError(message: "문의 상태를 저장하지 못했습니다.", code: "ADMIN_INQUIRY_SAVE_FAILED")
        }
    }

    static func adminOperationsAnnouncements(
        status: String = "all"
    ) async throws -> AdminOperationsAnnouncementList {
        let value: AdminAnnouncementListEnvelope = try await request(
            "GET", "/api/v1/admin/announcements", body: nil, authed: true,
            query: ["status": status])
        try validateAdminOperationsSchema(value.schemaVersion)
        return value.announcements
    }

    static func createAdminAnnouncement(
        title: String,
        content: String,
        category: String,
        publishNow: Bool,
        dashboardEndDate: String
    ) async throws -> AdminOperationsAnnouncement {
        let value: AdminAnnouncementEnvelope = try await request(
            "POST", "/api/v1/admin/announcements",
            body: [
                "title": title,
                "content": content,
                "boardCategory": category,
                "publishNow": publishNow,
                "dashboardEndDate": dashboardEndDate,
            ],
            authed: true)
        try validateAdminOperationsSchema(value.schemaVersion)
        return value.announcement
    }

    static func setAdminAnnouncementPublished(id: String, published: Bool) async throws {
        let value: AdminOperationMutationEnvelope = try await request(
            "POST", "/api/v1/admin/announcements/\(id)/status",
            body: ["publish": published], authed: true)
        try validateAdminOperationsSchema(value.schemaVersion)
        guard value.ok else {
            throw ServerAPIError(message: "공지 공개 상태를 저장하지 못했습니다.", code: "ADMIN_ANNOUNCEMENT_SAVE_FAILED")
        }
    }

    private static func validateAdminOperationsSchema(_ value: String) throws {
        guard value == "ADMIN_OPERATIONS_NATIVE_V1" else {
            throw ServerAPIError(
                message: "관리자 운영 응답 버전이 앱과 맞지 않습니다.",
                code: "ADMIN_OPERATIONS_SCHEMA_UNSUPPORTED")
        }
    }
}
