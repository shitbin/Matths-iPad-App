import Foundation

extension ServerAPI {
    struct AdminArchiveFolder: Codable, Hashable, Identifiable {
        var id: String
        var parentFolderId: String?
        var name: String
        var description: String
        var slug: String
        var isPublished: Bool
        var accessLevel: String
        var requiredAccessLevel: String
        var isPinned: Bool
        var pinnedAt: String?
        var itemCount: Int
        var isLocked: Bool
        var createdAt: String?
        var depth: Int?
        var pathLabel: String?
    }

    struct AdminArchiveItem: Codable, Hashable, Identifiable {
        var id: String
        var folderId: String?
        var title: String
        var description: String
        var category: String
        var originalName: String
        var mimeType: String
        var sizeBytes: Int
        var storageProvider: String
        var storagePurpose: String
        var backupStatus: String
        var backedUpAt: String?
        var downloadCount: Int
        var createdAt: String?
        var deletedAt: String?
        var purgeAfter: String?
        var isPublished: Bool
    }

    struct AdminArchiveBreadcrumb: Codable, Hashable, Identifiable { var id: String; var name: String }

    struct AdminArchiveDashboard: Codable, Hashable {
        var isAdmin: Bool
        var categories: [String]
        var folders: [AdminArchiveFolder]
        var folderOptions: [AdminArchiveFolder]
        var breadcrumbs: [AdminArchiveBreadcrumb]
        var selectedFolder: AdminArchiveFolder?
        var items: [AdminArchiveItem]
        var trashItems: [AdminArchiveItem]
    }

    private struct AdminArchiveEnvelope: Codable {
        var schemaVersion: String
        var ok: Bool?
        var uploadedCount: Int?
        var notified: Bool?
        var affectedCount: Int?
        var archive: AdminArchiveDashboard
    }

    static func adminArchive(folderID: String? = nil) async throws -> AdminArchiveDashboard {
        let value: AdminArchiveEnvelope = try await request("GET", "/api/v1/admin/archive", body: nil, authed: true, query: folderID.map { ["folderId": $0] } ?? [:])
        try validateAdminArchive(value.schemaVersion); return value.archive
    }
    static func createAdminArchiveFolder(name: String, description: String, parentID: String?, accessLevel: String) async throws -> AdminArchiveDashboard {
        try await adminArchiveMutation(path: "/api/v1/admin/archive/folders", body: ["name": name, "description": description, "parentFolderId": parentID ?? "", "accessLevel": accessLevel]).archive
    }
    static func updateAdminArchiveFolder(id: String, name: String, description: String, accessLevel: String) async throws -> AdminArchiveDashboard {
        try await adminArchiveMutation(path: "/api/v1/admin/archive/folders/\(id)", body: ["name": name, "description": description, "accessLevel": accessLevel]).archive
    }
    static func pinAdminArchiveFolder(id: String, pinned: Bool) async throws -> AdminArchiveDashboard {
        try await adminArchiveMutation(path: "/api/v1/admin/archive/folders/\(id)/pin", body: ["pinned": pinned]).archive
    }
    static func deleteAdminArchiveFolder(id: String) async throws -> AdminArchiveDashboard {
        try await adminArchiveMutation(path: "/api/v1/admin/archive/folders/\(id)/delete", body: [:]).archive
    }
    static func deleteAdminArchiveItem(id: String, folderID: String?) async throws -> AdminArchiveDashboard {
        try await adminArchiveMutation(path: "/api/v1/admin/archive/items/\(id)/delete", body: ["folderId": folderID ?? ""]).archive
    }
    static func deleteAdminArchiveItems(ids: [String], folderID: String?) async throws -> AdminArchiveDashboard {
        try await adminArchiveMutation(path: "/api/v1/admin/archive/items/bulk-delete", body: ["itemIds": ids, "folderId": folderID ?? ""]).archive
    }
    static func moveAdminArchiveItems(ids: [String], destinationFolderID: String?, folderID: String?) async throws -> AdminArchiveDashboard {
        try await adminArchiveMutation(path: "/api/v1/admin/archive/items/bulk-move", body: ["itemIds": ids, "destinationFolderId": destinationFolderID ?? "", "folderId": folderID ?? ""]).archive
    }
    static func restoreAdminArchiveItem(id: String) async throws -> AdminArchiveDashboard {
        try await adminArchiveMutation(path: "/api/v1/admin/archive/trash/\(id)/restore", body: [:]).archive
    }
    static func purgeAdminArchiveItem(id: String) async throws -> AdminArchiveDashboard {
        try await adminArchiveMutation(path: "/api/v1/admin/archive/trash/\(id)/purge", body: [:]).archive
    }

    static func uploadAdminArchive(files: [URL], description: String, category: String, folderID: String?, notifyUsers: Bool) async throws -> AdminArchiveDashboard {
        let boundary = "Matths-Admin-Archive-\(UUID().uuidString)"
        let request = try authorizedRequest("POST", "/api/v1/admin/archive/upload", contentType: "multipart/form-data; boundary=\(boundary)", timeout: 600)
        let bodyURL = FileManager.default.temporaryDirectory.appendingPathComponent("admin-archive-\(UUID().uuidString).body")
        FileManager.default.createFile(atPath: bodyURL.path, contents: nil)
        let output = try FileHandle(forWritingTo: bodyURL)
        defer { try? output.close(); try? FileManager.default.removeItem(at: bodyURL) }
        func write(_ value: String) throws { try output.write(contentsOf: Data(value.utf8)) }
        for (name, value) in ["description": description, "category": category, "folderId": folderID ?? "", "notifyUsers": notifyUsers ? "true" : "false"] {
            try write("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n")
        }
        for file in files {
            let access = file.startAccessingSecurityScopedResource(); defer { if access { file.stopAccessingSecurityScopedResource() } }
            let safeName = file.lastPathComponent.replacingOccurrences(of: "\"", with: "")
            try write("--\(boundary)\r\nContent-Disposition: form-data; name=\"archiveFiles\"; filename=\"\(safeName)\"\r\nContent-Type: application/octet-stream\r\n\r\n")
            let input = try FileHandle(forReadingFrom: file)
            while let chunk = try input.read(upToCount: 1_048_576), !chunk.isEmpty { try output.write(contentsOf: chunk) }
            try input.close(); try write("\r\n")
        }
        try write("--\(boundary)--\r\n"); try output.synchronize()
        let (data, response) = try await URLSession.shared.upload(for: request, fromFile: bodyURL)
        try validateAuthorizedResponse(response, errorBody: data, requestToken: bearerToken(from: request))
        let value = try JSONDecoder().decode(AdminArchiveEnvelope.self, from: data)
        try validateAdminArchive(value.schemaVersion)
        guard value.ok == true else { throw ServerAPIError(message: "자료를 등록하지 못했습니다.", code: "ADMIN_ARCHIVE_UPLOAD_FAILED") }
        return value.archive
    }

    static func downloadAdminArchiveItem(_ item: AdminArchiveItem) async throws -> URL {
        let request = try authorizedRequest("GET", "/api/v1/archive/items/\(item.id)/download", timeout: 120)
        let (temporary, response) = try await URLSession.shared.download(for: request)
        let errorBody = (try? Data(contentsOf: temporary)) ?? Data()
        let http = try validateAuthorizedResponse(response, errorBody: errorBody, requestToken: bearerToken(from: request))
        let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("AdminArchive", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let name = (http.suggestedFilename ?? item.originalName).replacingOccurrences(of: "/", with: "-")
        let destination = directory.appendingPathComponent("\(UUID().uuidString)-\(name.isEmpty ? "자료" : name)")
        try FileManager.default.moveItem(at: temporary, to: destination); return destination
    }

    private static func adminArchiveMutation(path: String, body: [String: Any]) async throws -> AdminArchiveEnvelope {
        let value: AdminArchiveEnvelope = try await request("POST", path, body: body, authed: true)
        try validateAdminArchive(value.schemaVersion)
        guard value.ok == true else { throw ServerAPIError(message: "자료실 작업을 완료하지 못했습니다.", code: "ADMIN_ARCHIVE_ACTION_FAILED") }
        return value
    }
    private static func validateAdminArchive(_ value: String) throws {
        guard value == "ADMIN_ARCHIVE_NATIVE_V1" else { throw ServerAPIError(message: "자료실 관리자 응답 버전이 앱과 맞지 않습니다.", code: "ADMIN_ARCHIVE_SCHEMA_UNSUPPORTED") }
    }
}
