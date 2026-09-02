import Foundation

extension ServerAPI {
    struct StoreCategory: Codable, Identifiable, Hashable {
        var id: String
        var name: String
        var slug: String
        var sortOrder: Int
        var isVisible: Bool
    }

    struct StoreAsset: Codable, Identifiable, Hashable {
        var id: String
        var kind: String
        var originalName: String
        var mimeType: String
        var sizeBytes: Int
        var altText: String
        var downloadCount: Int
    }

    struct StoreBundleItem: Codable, Hashable {
        var name: String
        var description: String
    }

    struct StoreDetailBlock: Codable, Identifiable, Hashable {
        var id: String
        var type: String
        var text: String
        var fontSize: String
        var color: String
        var bold: Bool
        var underline: Bool
        var align: String
        var assetId: String?
        var caption: String
    }

    struct StoreProduct: Codable, Identifiable, Hashable {
        var id: String
        var name: String
        var slug: String
        var category: String
        var badge: String
        var subtitle: String
        var summary: String
        var price: Int
        var originalPrice: Int
        var bundleItems: [StoreBundleItem]
        var thumbnail: StoreAsset?
        var assets: [StoreAsset]
        var detailBlocks: [StoreDetailBlock]
        var status: String
        var viewCount: Int
        var salesCount: Int
        var freeDownloadCount: Int
        var popularityScore: Int
        var freeDownloadFiles: [StoreAsset]
        var createdAt: String?
        var updatedAt: String?
        var publishedAt: String?
    }

    struct StoreCatalog: Codable, Hashable {
        var products: [StoreProduct]
        var query: String
        var sort: String
        var category: String
        var categories: [StoreCategory]
    }

    private struct StoreCatalogEnvelope: Codable {
        var schemaVersion: String
        var catalog: StoreCatalog
    }

    private struct StoreProductEnvelope: Codable {
        var schemaVersion: String
        var product: StoreProduct
        var categories: [StoreCategory]
    }

    static func storeCatalog(
        query: String = "",
        sort: String = "popular",
        category: String = ""
    ) async throws -> StoreCatalog {
        let value: StoreCatalogEnvelope = try await request(
            "GET", "/api/v1/store-products", body: nil, authed: true,
            query: ["query": query, "sort": sort, "category": category])
        try validateStoreCatalogSchema(value.schemaVersion)
        return value.catalog
    }

    static func storeProduct(slug: String) async throws -> StoreProduct {
        let value: StoreProductEnvelope = try await request(
            "GET", "/api/v1/store-products/\(slug)", body: nil, authed: true)
        try validateStoreCatalogSchema(value.schemaVersion)
        return value.product
    }

    static func downloadStoreProductFile(
        slug: String,
        asset: StoreAsset
    ) async throws -> URL {
        try await downloadStoreAsset(
            path: "/api/v1/store-products/\(slug)/files/\(asset.id)",
            asset: asset,
            folder: "StoreDownloads",
            timeout: 120)
    }

    static func downloadStoreProductMedia(
        productID: String,
        asset: StoreAsset
    ) async throws -> URL {
        let folder = "StoreMedia"
        let cached = storeCacheDirectory(folder: folder)
            .appendingPathComponent("\(productID)-\(asset.id)-\(safeStoreFilename(asset.originalName))")
        if FileManager.default.fileExists(atPath: cached.path) { return cached }
        return try await downloadStoreAsset(
            path: "/api/v1/store-products/\(productID)/media/\(asset.id)",
            asset: asset,
            folder: folder,
            filename: cached.lastPathComponent,
            timeout: 60)
    }

    private static func downloadStoreAsset(
        path: String,
        asset: StoreAsset,
        folder: String,
        filename: String? = nil,
        timeout: TimeInterval
    ) async throws -> URL {
        let request = try authorizedRequest("GET", path, timeout: timeout)
        let (temporaryURL, response) = try await URLSession.shared.download(for: request)
        let errorBody = (try? Data(contentsOf: temporaryURL)) ?? Data()
        let http = try validateAuthorizedResponse(
            response, errorBody: errorBody, requestToken: bearerToken(from: request))
        let directory = storeCacheDirectory(folder: folder)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutableDirectory = directory
        try? mutableDirectory.setResourceValues(values)
        let suggested = filename ?? "\(UUID().uuidString)-\(safeStoreFilename(http.suggestedFilename ?? asset.originalName))"
        let destination = directory.appendingPathComponent(suggested)
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.moveItem(at: temporaryURL, to: destination)
        return destination
    }

    private static func storeCacheDirectory(folder: String) -> URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(folder, isDirectory: true)
            .appendingPathComponent(DataScope.slot, isDirectory: true)
    }

    private static func safeStoreFilename(_ value: String) -> String {
        let cleaned = value
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        return cleaned.isEmpty ? "Matths-자료" : cleaned
    }

    private static func validateStoreCatalogSchema(_ value: String) throws {
        guard value == "STORE_CATALOG_NATIVE_V1" else {
            throw ServerAPIError(
                message: "자료 카탈로그 응답 버전이 앱과 맞지 않습니다.",
                code: "STORE_CATALOG_SCHEMA_UNSUPPORTED")
        }
    }
}
