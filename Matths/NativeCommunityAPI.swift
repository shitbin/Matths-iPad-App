import Foundation
import UniformTypeIdentifiers

extension ServerAPI {
    struct CommunityPage: Codable {
        struct Board: Codable {
            struct Affiliation: Codable { var code: String; var name: String }
            var id: String
            var label: String
            var schoolAccessRestricted: Bool
            var selectedSchool: Affiliation?
            var selectedUniversity: Affiliation?
        }
        struct Query: Codable { var search: String; var sort: String; var category: String }
        struct Category: Codable, Identifiable, Hashable {
            var value: String
            var label: String
            var id: String { value }
        }
        struct Pagination: Codable {
            var page: Int
            var totalPages: Int
            var total: Int
            var hasPrevious: Bool
            var hasNext: Bool
        }
        var schemaVersion: String
        var board: Board
        var query: Query
        var operationsCategories: [Category]?
        var posts: [CommunityPost]
        var popularPosts: [CommunityPost]
        var pagination: Pagination
        var signedIn: Bool
    }

    struct CommunityPost: Codable, Identifiable, Hashable {
        struct Attachment: Codable, Identifiable, Hashable {
            var id: String
            var originalName: String
            var mimeType: String
            var sizeBytes: Int
            var isImage: Bool
            var downloadPath: String
        }
        var id: String
        var kind: String
        var boardType: String
        var boardCategory: String
        var boardCategoryLabel: String
        var title: String
        var contentPreview: String
        var authorName: String
        var anonymous: Bool
        var pinned: Bool
        var popular: Bool
        var viewCount: Int
        var upvoteCount: Int
        var downvoteCount: Int
        var attachmentCount: Int
        var createdAt: String?
        var content: String? = nil
        var attachments: [Attachment]? = nil
        var canDelete: Bool? = nil
        var canBlock: Bool? = nil
    }

    struct CommunityComment: Codable, Identifiable, Hashable {
        var id: String
        var authorName: String
        var anonymous: Bool
        var content: String
        var createdAt: String?
        var canBlock: Bool
    }

    struct CommunityDetail: Codable {
        var schemaVersion: String
        var post: CommunityPost
        var comments: [CommunityComment]
        var viewerVote: Int
        var viewerReported: Bool
        var signedIn: Bool
    }

    struct CommunityPostingAccess: Codable {
        var warningCount: Int
        var canUploadFiles: Bool
        var dailyLimit: Int
        var postsCreatedToday: Int
        var remainingPosts: Int
    }

    struct CommunityBlockedUser: Codable, Identifiable {
        var id: String
        var displayName: String
        var anonymous: Bool
        var sourceType: String
        var createdAt: String?
    }

    private struct CommunityAccessEnvelope: Codable {
        var schemaVersion: String
        var access: CommunityPostingAccess
    }
    private struct CommunityPostEnvelope: Codable {
        var schemaVersion: String
        var post: CommunityPost
    }
    private struct CommunityCommentEnvelope: Codable {
        var schemaVersion: String
        var comment: CommunityComment
    }
    struct CommunityVoteEnvelope: Codable {
        struct Vote: Codable {
            var upvoteCount: Int
            var downvoteCount: Int
            var voteScore: Int
            var viewerVote: Int
        }
        var schemaVersion: String
        var vote: Vote
    }
    private struct CommunityBooleanEnvelope: Codable {
        var schemaVersion: String
        var reported: Bool? = nil
        var deleted: Bool? = nil
        var blocked: Bool? = nil
        var unblocked: Bool? = nil
    }
    private struct CommunityBlocksEnvelope: Codable {
        var schemaVersion: String
        var blocks: [CommunityBlockedUser]
    }

    static func communityPage(
        board: String,
        search: String = "",
        sort: String = "latest",
        category: String = "",
        page: Int = 1
    ) async throws -> CommunityPage {
        let result: CommunityPage = try await request(
            "GET", "/api/v1/community", body: nil, authed: hasToken,
            query: [
                "board": board,
                "search": search,
                "sort": sort,
                "category": category,
                "page": String(page),
            ])
        try validateCommunitySchema(result.schemaVersion)
        return result
    }

    static func communityDetail(_ post: CommunityPost) async throws -> CommunityDetail {
        let path: String
        switch post.kind {
        case "NOTICE": path = "/api/v1/community/notices/\(post.id)"
        case "ANNOUNCEMENT": path = "/api/v1/community/announcements/\(post.id)"
        default: path = "/api/v1/community/posts/\(post.id)"
        }
        let result: CommunityDetail = try await request(
            "GET", path, body: nil, authed: hasToken)
        try validateCommunitySchema(result.schemaVersion)
        return result
    }

    static func communityPostingAccess() async throws -> CommunityPostingAccess {
        let result: CommunityAccessEnvelope = try await request(
            "GET", "/api/v1/community/posting-access", body: nil, authed: true)
        try validateCommunitySchema(result.schemaVersion)
        return result.access
    }

    static func createCommunityPost(
        board: String,
        title: String,
        content: String,
        anonymous: Bool,
        files: [URL]
    ) async throws -> CommunityPost {
        guard files.count <= 5 else {
            throw ServerAPIError(message: "첨부파일은 최대 5개까지 선택할 수 있습니다.", code: "COMMUNITY_FILE_COUNT")
        }
        let boundary = "Matths-Community-\(UUID().uuidString)"
        var request = try authorizedRequest(
            "POST", "/api/v1/community/posts",
            contentType: "multipart/form-data; boundary=\(boundary)", timeout: 120)
        var body = Data()
        func append(_ value: String) { body.append(Data(value.utf8)) }
        func field(_ name: String, _ value: String) {
            append("--\(boundary)\r\n")
            append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
            append("\(value)\r\n")
        }
        field("board", board)
        field("title", title)
        field("content", content)
        field("isAnonymous", anonymous ? "true" : "false")
        var totalBytes = 0
        for file in files {
            let data = try Data(contentsOf: file, options: [.mappedIfSafe])
            totalBytes += data.count
            guard data.count <= 10 * 1024 * 1024, totalBytes <= 50 * 1024 * 1024 else {
                throw ServerAPIError(message: "첨부파일은 파일당 10MB, 전체 50MB까지 올릴 수 있습니다.", code: "COMMUNITY_FILE_TOO_LARGE")
            }
            let filename = safeMultipartFilename(file.lastPathComponent)
            append("--\(boundary)\r\n")
            append("Content-Disposition: form-data; name=\"communityFiles\"; filename=\"\(filename)\"\r\n")
            append("Content-Type: \(communityMimeType(file))\r\n\r\n")
            body.append(data)
            append("\r\n")
        }
        append("--\(boundary)--\r\n")
        request.httpBody = body
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateAuthorizedResponse(response, errorBody: data, requestToken: bearerToken(from: request))
        let result = try JSONDecoder().decode(CommunityPostEnvelope.self, from: data)
        try validateCommunitySchema(result.schemaVersion)
        return result.post
    }

    static func createCommunityComment(
        postId: String, content: String, anonymous: Bool
    ) async throws -> CommunityComment {
        let result: CommunityCommentEnvelope = try await request(
            "POST", "/api/v1/community/posts/\(postId)/comments",
            body: ["content": content, "isAnonymous": anonymous], authed: true)
        try validateCommunitySchema(result.schemaVersion)
        return result.comment
    }

    static func voteCommunityPost(postId: String, value: Int) async throws -> CommunityVoteEnvelope.Vote {
        let result: CommunityVoteEnvelope = try await request(
            "POST", "/api/v1/community/posts/\(postId)/vote",
            body: ["value": value], authed: true)
        try validateCommunitySchema(result.schemaVersion)
        return result.vote
    }

    static func reportCommunityPost(postId: String, reason: String) async throws {
        let result: CommunityBooleanEnvelope = try await request(
            "POST", "/api/v1/community/posts/\(postId)/report",
            body: ["reason": reason], authed: true)
        try validateCommunitySchema(result.schemaVersion)
        guard result.reported == true else { throw communityReceiptError() }
    }

    static func blockCommunityAuthor(postId: String, commentId: String? = nil) async throws {
        var body: [String: Any] = [:]
        if let commentId { body["commentId"] = commentId }
        let result: CommunityBooleanEnvelope = try await request(
            "POST", "/api/v1/community/posts/\(postId)/block", body: body, authed: true)
        try validateCommunitySchema(result.schemaVersion)
        guard result.blocked == true else { throw communityReceiptError() }
    }

    static func deleteCommunityPost(postId: String) async throws {
        let result: CommunityBooleanEnvelope = try await request(
            "DELETE", "/api/v1/community/posts/\(postId)", body: nil, authed: true)
        try validateCommunitySchema(result.schemaVersion)
        guard result.deleted == true else { throw communityReceiptError() }
    }

    static func communityBlockedUsers() async throws -> [CommunityBlockedUser] {
        let result: CommunityBlocksEnvelope = try await request(
            "GET", "/api/v1/community/blocked-users", body: nil, authed: true)
        try validateCommunitySchema(result.schemaVersion)
        return result.blocks
    }

    static func unblockCommunityUser(_ userId: String) async throws {
        let result: CommunityBooleanEnvelope = try await request(
            "DELETE", "/api/v1/community/blocked-users/\(userId)", body: nil, authed: true)
        try validateCommunitySchema(result.schemaVersion)
        guard result.unblocked == true else { throw communityReceiptError() }
    }

    static func downloadCommunityAttachment(_ attachment: CommunityPost.Attachment) async throws -> URL {
        let request: URLRequest
        if hasToken {
            request = try authorizedRequest("GET", attachment.downloadPath, timeout: 120)
        } else {
            var guest = URLRequest(url: baseURL.appendingPathComponent(attachment.downloadPath))
            guest.timeoutInterval = 120
            guest.setValue(clientBuildVersion, forHTTPHeaderField: "X-Matths-Client-Version")
            request = guest
        }
        let (temporary, response) = try await URLSession.shared.download(for: request)
        let errorBody = (try? Data(contentsOf: temporary)) ?? Data()
        try validateAuthorizedResponse(response, errorBody: errorBody, requestToken: bearerToken(from: request))
        let safeName = attachment.originalName
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        let destination = DataScope.url("community-download-\(attachment.id)-\(safeName)")
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.moveItem(at: temporary, to: destination)
        return destination
    }

    private static func validateCommunitySchema(_ version: String) throws {
        guard version == "COMMUNITY_NATIVE_V1" else {
            throw ServerAPIError(message: "게시판 데이터 형식이 바뀌었습니다. 앱을 업데이트해주세요.", code: "COMMUNITY_SCHEMA_UNSUPPORTED")
        }
    }

    private static func communityReceiptError() -> ServerAPIError {
        ServerAPIError(message: "게시판 처리 결과를 확인할 수 없습니다.", code: "COMMUNITY_RECEIPT_INVALID")
    }

    private static func safeMultipartFilename(_ value: String) -> String {
        value.replacingOccurrences(of: "\"", with: "_")
            .replacingOccurrences(of: "\r", with: "_")
            .replacingOccurrences(of: "\n", with: "_")
    }

    private static func communityMimeType(_ url: URL) -> String {
        UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
    }
}
