import Foundation

extension ServerAPI {
    struct AdminStoreStudyHall: Codable, Hashable {
        var tabs: [StudyHallTab]
        var activeTab: String
        var items: [StudyHallContent]
        var editing: StudyHallContent?
    }

    struct AdminStoreCategory: Codable, Hashable, Identifiable {
        var id: String
        var name: String
        var slug: String
        var sortOrder: Int
        var isVisible: Bool
        var productCount: Int
    }

    struct AdminStoreCatalog: Codable, Hashable {
        var products: [StoreProduct]
        var editing: StoreProduct?
        var categories: [AdminStoreCategory]
    }

    struct AdminStoreDashboard: Codable, Hashable {
        var studyHall: AdminStoreStudyHall
        var store: AdminStoreCatalog
    }

    private struct AdminStoreEnvelope: Codable {
        var schemaVersion: String
        var ok: Bool?
        var contentId: String?
        var productId: String?
        var dashboard: AdminStoreDashboard
    }

    static func adminStoreDashboard() async throws -> AdminStoreDashboard {
        let value: AdminStoreEnvelope = try await request("GET", "/api/v1/admin/store", body: nil, authed: true)
        try validateAdminStore(value.schemaVersion)
        return value.dashboard
    }

    static func saveAdminStudyHallContent(
        id: String?, fields: [String: String], files: [String: [URL]], removeAssetIDs: [String] = []
    ) async throws -> AdminStoreDashboard {
        try await adminStoreMultipart(
            path: id.map { "/api/v1/admin/store/study-hall/\($0)" } ?? "/api/v1/admin/store/study-hall",
            fields: fields, files: files, repeatedFields: ["removeAssetIds": removeAssetIDs]).dashboard
    }

    static func archiveAdminStudyHallContent(id: String) async throws -> AdminStoreDashboard {
        try await adminStoreMutation(path: "/api/v1/admin/store/study-hall/\(id)/archive", body: [:]).dashboard
    }

    static func saveAdminStoreProduct(
        id: String?, fields: [String: String], files: [String: [URL]], removeAssetIDs: [String] = []
    ) async throws -> AdminStoreDashboard {
        try await adminStoreMultipart(
            path: id.map { "/api/v1/admin/store/products/\($0)" } ?? "/api/v1/admin/store/products",
            fields: fields, files: files, repeatedFields: ["removeAssetIds": removeAssetIDs]).dashboard
    }

    static func deleteAdminStoreProduct(id: String) async throws -> AdminStoreDashboard {
        try await adminStoreMutation(path: "/api/v1/admin/store/products/\(id)/delete", body: [:]).dashboard
    }

    static func createAdminStoreCategory(name: String) async throws -> AdminStoreDashboard {
        try await adminStoreMutation(path: "/api/v1/admin/store/categories", body: ["name": name]).dashboard
    }

    static func updateAdminStoreCategory(id: String, name: String, isVisible: Bool) async throws -> AdminStoreDashboard {
        try await adminStoreMutation(path: "/api/v1/admin/store/categories/\(id)", body: ["name": name, "isVisible": isVisible]).dashboard
    }

    static func reorderAdminStoreCategories(ids: [String]) async throws -> AdminStoreDashboard {
        try await adminStoreMutation(path: "/api/v1/admin/store/categories/reorder", body: ["categoryIds": ids]).dashboard
    }

    static func deleteAdminStoreCategory(id: String) async throws -> AdminStoreDashboard {
        try await adminStoreMutation(path: "/api/v1/admin/store/categories/\(id)/delete", body: [:]).dashboard
    }

    private static func adminStoreMutation(path: String, body: [String: Any]) async throws -> AdminStoreEnvelope {
        let value: AdminStoreEnvelope = try await request("POST", path, body: body, authed: true)
        try validateAdminStore(value.schemaVersion)
        guard value.ok == true else { throw ServerAPIError(message: "수험관 작업을 완료하지 못했습니다.", code: "ADMIN_STORE_ACTION_FAILED") }
        return value
    }

    private static func adminStoreMultipart(
        path: String, fields: [String: String], files: [String: [URL]], repeatedFields: [String: [String]] = [:]
    ) async throws -> AdminStoreEnvelope {
        let boundary = "Matths-Admin-Store-\(UUID().uuidString)"
        let request = try authorizedRequest("POST", path, contentType: "multipart/form-data; boundary=\(boundary)", timeout: 900)
        let bodyURL = FileManager.default.temporaryDirectory.appendingPathComponent("admin-store-\(UUID().uuidString).body")
        FileManager.default.createFile(atPath: bodyURL.path, contents: nil)
        let output = try FileHandle(forWritingTo: bodyURL)
        defer { try? output.close(); try? FileManager.default.removeItem(at: bodyURL) }
        func write(_ value: String) throws { try output.write(contentsOf: Data(value.utf8)) }
        for (name, value) in fields {
            try write("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n")
        }
        for (name, values) in repeatedFields {
            for value in values {
                try write("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n")
            }
        }
        for (field, urls) in files {
            for file in urls {
                let access = file.startAccessingSecurityScopedResource()
                defer { if access { file.stopAccessingSecurityScopedResource() } }
                let name = file.lastPathComponent.replacingOccurrences(of: "\"", with: "")
                try write("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(field)\"; filename=\"\(name)\"\r\nContent-Type: \(adminStoreMIME(file))\r\n\r\n")
                let input = try FileHandle(forReadingFrom: file)
                while let chunk = try input.read(upToCount: 1_048_576), !chunk.isEmpty { try output.write(contentsOf: chunk) }
                try input.close(); try write("\r\n")
            }
        }
        try write("--\(boundary)--\r\n"); try output.synchronize()
        let (data, response) = try await URLSession.shared.upload(for: request, fromFile: bodyURL)
        try validateAuthorizedResponse(response, errorBody: data, requestToken: bearerToken(from: request))
        let value = try JSONDecoder().decode(AdminStoreEnvelope.self, from: data)
        try validateAdminStore(value.schemaVersion)
        guard value.ok == true else { throw ServerAPIError(message: "파일을 저장하지 못했습니다.", code: "ADMIN_STORE_UPLOAD_FAILED") }
        return value
    }

    private static func adminStoreMIME(_ url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "webp": return "image/webp"
        case "pdf": return "application/pdf"
        case "json": return "application/json"
        case "zip": return "application/zip"
        case "doc": return "application/msword"
        case "docx": return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case "xls": return "application/vnd.ms-excel"
        case "xlsx": return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        case "ppt": return "application/vnd.ms-powerpoint"
        case "pptx": return "application/vnd.openxmlformats-officedocument.presentationml.presentation"
        default: return "application/octet-stream"
        }
    }

    private static func validateAdminStore(_ value: String) throws {
        guard value == "ADMIN_STORE_NATIVE_V1" else {
            throw ServerAPIError(message: "수험관 관리자 응답 버전이 앱과 맞지 않습니다.", code: "ADMIN_STORE_SCHEMA_UNSUPPORTED")
        }
    }
}
