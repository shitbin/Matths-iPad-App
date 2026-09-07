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
        page: Int = 1, authorization: AuthorizationSnapshot? = ServerAPI.captureAuthorization()
    ) async throws -> CommunityPage {
        let result: CommunityPage = try await request(
            "GET", "/api/v1/community", body: nil, authed: authorization != nil,
            query: [
                "board": board,
                "search": search,
                "sort": sort,
                "category": category,
                "page": String(page),
            ], authorization: authorization)
        try validateCommunitySchema(result.schemaVersion)
        return result
    }

    static func communityDetail(_ post: CommunityPost, authorization: AuthorizationSnapshot? = ServerAPI.captureAuthorization()) async throws -> CommunityDetail {
        let path: String
        switch post.kind {
        case "NOTICE": path = "/api/v1/community/notices/\(post.id)"
        case "ANNOUNCEMENT": path = "/api/v1/community/announcements/\(post.id)"
        default: path = "/api/v1/community/posts/\(post.id)"
        }
        let result: CommunityDetail = try await request(
            "GET", path, body: nil, authed: authorization != nil, authorization: authorization)
        try validateCommunitySchema(result.schemaVersion)
        return result
    }

    static func communityPostingAccess(authorization: AuthorizationSnapshot = ServerAPI.authorizationForCurrentRequest()) async throws -> CommunityPostingAccess {
        let result: CommunityAccessEnvelope = try await request(
            "GET", "/api/v1/community/posting-access", body: nil, authed: true, authorization: authorization)
        try validateCommunitySchema(result.schemaVersion)
        return result.access
    }

    static func createCommunityPost(
        board: String,
        title: String,
        content: String,
        anonymous: Bool,
        files: [URL], originalNames: [String: String] = [:], account: String = DataScope.slot,
        operationID: String,
        authorization: AuthorizationSnapshot = ServerAPI.authorizationForCurrentRequest()
    ) async throws -> CommunityPost {
        guard files.count <= 5 else {
            throw ServerAPIError(message: "첨부파일은 최대 5개까지 선택할 수 있습니다.", code: "COMMUNITY_FILE_COUNT")
        }
        let owner = MobileRequestOwner(account: account, authorization: authorization)
        let boundary = "Matths-Community-\(UUID().uuidString)"
        var fields: [CommunityMultipartBody.Field] = [
            .init(name: "board", value: board),
            .init(name: "title", value: title),
            .init(name: "content", value: content),
            .init(name: "isAnonymous", value: anonymous ? "true" : "false"),
        ]
        let attachments: [CommunityMultipartBody.Attachment] = files.map { file in
            .init(url: file, filename: originalNames[file.lastPathComponent] ?? file.lastPathComponent,
                  mimeType: communityMimeType(file),
                  maximumBytes: (NativeServiceInputPolicy.imageExtensions.contains(file.pathExtension.lowercased()) ? 10 : 25) * 1024 * 1024)
        }
        let validateOwner: () throws -> Void = {
            try owner.validate()
        }
        try validateOwner()
        let fingerprintFields = ["board": board, "title": title, "content": content, "isAnonymous": String(anonymous)]
        let fingerprint = try CommunityRequestFingerprint.make(operation: "post", fields: fingerprintFields, attachments: attachments, validateOwner: validateOwner)
        let support = try await MobileFeatureSupport.shared.capabilities(for: owner)
        let requestID = try await CommunityRequestIdentity.shared.requestID(owner: owner, operationID: operationID,
                                                                            fingerprint: fingerprint, capability: support)
        if let requestID { fields.append(.init(name: "requestId", value: requestID)) }
        var uploadStarted = false
        do {
            try validateOwner()
            guard files.allSatisfy({ NativeServiceInputPolicy.attachmentExtensions.contains($0.pathExtension.lowercased()) }) else {
                throw CommunityMultipartBody.PreparationError.invalidAttachment
            }
            var request = try authorizedRequest(
                "POST", "/api/v1/community/posts",
                contentType: "multipart/form-data; boundary=\(boundary)", timeout: 120, authorization: authorization)
            return try await CommunityMultipartBody.withPreparedBody(
                boundary: boundary, fields: fields, attachments: attachments, validateOwner: validateOwner
            ) { prepared in
                try validateOwner()
                guard fingerprint == (try CommunityRequestFingerprint.make(operation: "post", fields: fingerprintFields, attachments: attachments,
                                                                            validateOwner: validateOwner)) else {
                    throw CommunityMultipartBody.PreparationError.changedAttachment
                }
                request.setValue(String(prepared.contentLength), forHTTPHeaderField: "Content-Length")
                // httpBody stays nil. URLSession reads the closed staging file.
                uploadStarted = true
                let (data, response) = try await URLSession.shared.upload(for: request, fromFile: prepared.fileURL)
                try validateOwner()
                try validateAuthorizedResponse(response, errorBody: data, requestToken: bearerToken(from: request))
                let result = try JSONDecoder().decode(CommunityPostEnvelope.self, from: data)
                try validateCommunitySchema(result.schemaVersion)
                return result.post
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            if !uploadStarted {
                throw ServerAPIError(
                    message: "첨부파일을 준비하지 못해 등록 요청을 보내지 않았습니다. 지원 형식·용량과 기기의 저장 공간을 확인해 주세요.",
                    code: "COMMUNITY_UPLOAD_NOT_STARTED")
            }
            // Once upload starts, a failed/lost response can be ambiguous. Keep
            // the existing caller's explicit check-before-retry flow.
            throw error
        }
    }

    static func createCommunityComment(
        postId: String, content: String, anonymous: Bool,
        account: String = DataScope.slot, operationID: String,
        authorization: AuthorizationSnapshot = ServerAPI.authorizationForCurrentRequest()
    ) async throws -> CommunityComment {
        let owner = MobileRequestOwner(account: account, authorization: authorization)
        try owner.validate()
        let support = try await MobileFeatureSupport.shared.capabilities(for: owner)
        let fingerprint = try CommunityRequestFingerprint.make(operation: "comment",
            fields: ["postId": postId, "content": content, "isAnonymous": String(anonymous)], attachments: [], validateOwner: owner.validate)
        let requestID = try await CommunityRequestIdentity.shared.requestID(owner: owner, operationID: operationID,
                                                                            fingerprint: fingerprint, capability: support)
        var body: [String: Any] = ["content": content, "isAnonymous": anonymous]
        if let requestID { body["requestId"] = requestID }
        let result: CommunityCommentEnvelope = try await request(
            "POST", "/api/v1/community/posts/\(postId)/comments",
            body: body, authed: true, authorization: authorization)
        try owner.validate()
        try validateCommunitySchema(result.schemaVersion)
        return result.comment
    }

    static func voteCommunityPost(postId: String, value: Int, authorization: AuthorizationSnapshot = ServerAPI.authorizationForCurrentRequest()) async throws -> CommunityVoteEnvelope.Vote {
        let result: CommunityVoteEnvelope = try await request(
            "POST", "/api/v1/community/posts/\(postId)/vote",
            body: ["value": value], authed: true, authorization: authorization)
        try validateCommunitySchema(result.schemaVersion)
        return result.vote
    }

    static func reportCommunityPost(postId: String, reason: String, authorization: AuthorizationSnapshot = ServerAPI.authorizationForCurrentRequest()) async throws {
        let result: CommunityBooleanEnvelope = try await request(
            "POST", "/api/v1/community/posts/\(postId)/report",
            body: ["reason": reason], authed: true, authorization: authorization)
        try validateCommunitySchema(result.schemaVersion)
        guard result.reported == true else { throw communityReceiptError() }
    }

    static func blockCommunityAuthor(postId: String, commentId: String? = nil, authorization: AuthorizationSnapshot = ServerAPI.authorizationForCurrentRequest()) async throws {
        var body: [String: Any] = [:]
        if let commentId { body["commentId"] = commentId }
        let result: CommunityBooleanEnvelope = try await request(
            "POST", "/api/v1/community/posts/\(postId)/block", body: body, authed: true, authorization: authorization)
        try validateCommunitySchema(result.schemaVersion)
        guard result.blocked == true else { throw communityReceiptError() }
    }

    static func deleteCommunityPost(postId: String, authorization: AuthorizationSnapshot = ServerAPI.authorizationForCurrentRequest()) async throws {
        let result: CommunityBooleanEnvelope = try await request(
            "DELETE", "/api/v1/community/posts/\(postId)", body: nil, authed: true, authorization: authorization)
        try validateCommunitySchema(result.schemaVersion)
        guard result.deleted == true else { throw communityReceiptError() }
    }

    static func communityBlockedUsers(authorization: AuthorizationSnapshot = ServerAPI.authorizationForCurrentRequest()) async throws -> [CommunityBlockedUser] {
        let result: CommunityBlocksEnvelope = try await request(
            "GET", "/api/v1/community/blocked-users", body: nil, authed: true, authorization: authorization)
        try validateCommunitySchema(result.schemaVersion)
        return result.blocks
    }

    static func unblockCommunityUser(_ userId: String, authorization: AuthorizationSnapshot = ServerAPI.authorizationForCurrentRequest()) async throws {
        let result: CommunityBooleanEnvelope = try await request(
            "DELETE", "/api/v1/community/blocked-users/\(userId)", body: nil, authed: true, authorization: authorization)
        try validateCommunitySchema(result.schemaVersion)
        guard result.unblocked == true else { throw communityReceiptError() }
    }

    static func downloadCommunityAttachment(_ attachment: CommunityPost.Attachment, accountSlot: String = DataScope.slot,
                                             authorization: AuthorizationSnapshot? = ServerAPI.captureAuthorization()) async throws -> URL {
        guard NativeServiceInputPolicy.isCommunityAttachmentPath(attachment.downloadPath, attachmentID: attachment.id) else {
            throw ServerAPIError(message: "첨부파일 주소를 확인하지 못했습니다.", code: "COMMUNITY_ATTACHMENT_PATH_INVALID")
        }
        let request: URLRequest
        if let authorization {
            request = try authorizedRequest("GET", attachment.downloadPath, timeout: 120, authorization: authorization)
        } else {
            var guest = URLRequest(url: baseURL.appendingPathComponent(attachment.downloadPath))
            guest.timeoutInterval = 120
            guest.setValue(clientBuildVersion, forHTTPHeaderField: "X-Matths-Client-Version")
            request = guest
        }
        let (temporary, response) = try await URLSession.shared.download(for: request)
        let errorBody: Data
        if let status = (response as? HTTPURLResponse)?.statusCode, status >= 400,
           let handle = try? FileHandle(forReadingFrom: temporary) {
            errorBody = (try? handle.read(upToCount: 65_536)) ?? Data(); try? handle.close()
        } else { errorBody = Data() }
        try validateAuthorizedResponse(response, errorBody: errorBody, requestToken: bearerToken(from: request))
        guard !Task.isCancelled, DataScope.slot == accountSlot,
              authorization.map(isCurrentAuthorization) ?? !hasToken else { throw CancellationError() }
        let safeName = attachment.originalName
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        let destination = DataScope.url("community-download-\(UUID().uuidString)-\(safeName)", for: accountSlot)
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

    private static func communityMimeType(_ url: URL) -> String {
        UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
    }
}
