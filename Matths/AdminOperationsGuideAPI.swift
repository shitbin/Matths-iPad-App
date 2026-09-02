import Foundation

extension ServerAPI {
  struct AdminGuideDatabase: Codable, Hashable {
    var connectionState: String
    var databaseName: String
    var note: String
    var categoryCount: Int
    var modelCount: Int
    var fieldCount: Int
  }
  struct AdminGuideCapacity: Codable, Hashable {
    var level: String?
    var usedPercent: Double?
    var usedBytes: Double?
    var totalBytes: Double?
  }
  struct AdminGuideEnvironment: Codable, Hashable {
    var cloudinaryConfigured: Bool
    var persistentLocalReady: Bool
    var r2BackupConfigured: Bool
    var localCapacity: AdminGuideCapacity?
    var userCloudTempDirectory: String
  }
  struct AdminGuideWorkflow: Codable, Hashable, Identifiable {
    var title: String
    var cadence: String
    var objective: String
    var steps: [String]
    var hardStops: String
    var audit: String
    var id: String { title }
  }
  struct AdminGuideStorage: Codable, Hashable, Identifiable {
    var owner: String
    var fileType: String
    var purpose: String
    var primary: String
    var backup: String
    var retention: String
    var access: String
    var id: String { "\(owner):\(fileType)" }
  }
  struct AdminGuideIncident: Codable, Hashable, Identifiable {
    var title: String
    var checks: [String]
    var id: String { title }
  }
  struct AdminGuideField: Codable, Hashable, Identifiable {
    var field: String
    var type: String
    var rules: String
    var defaultValue: String
    var id: String { field }
  }
  struct AdminGuideIndex: Codable, Hashable, Identifiable {
    var keys: String
    var unique: Bool
    var ttl: String
    var partial: String
    var id: String { keys }
  }
  struct AdminGuideModel: Codable, Hashable, Identifiable {
    var modelName: String
    var collectionName: String
    var categoryId: String
    var fieldCount: Int
    var fields: [AdminGuideField]
    var indexes: [AdminGuideIndex]
    var timestamps: Bool
    var id: String { modelName }
  }
  struct AdminGuideSchemaCategory: Codable, Hashable, Identifiable {
    var id: String
    var label: String
    var description: String
    var models: [AdminGuideModel]
  }
  struct AdminOperationsGuide: Codable, Hashable {
    var generatedAt: String
    var database: AdminGuideDatabase
    var environment: AdminGuideEnvironment
    var schemaCategories: [AdminGuideSchemaCategory]
    var storageMatrix: [AdminGuideStorage]
    var retentionPolicies: [[String]]
    var schedulers: [[String]]
    var permissionMatrix: [[String]]
    var incidentPlaybook: [AdminGuideIncident]
    var operatingWorkflows: [AdminGuideWorkflow]
    var environmentConfiguration: [[String]]
  }
  private struct AdminOperationsGuideEnvelope: Codable {
    var schemaVersion: String
    var guide: AdminOperationsGuide
  }
  static func adminOperationsGuide() async throws -> AdminOperationsGuide {
    let value: AdminOperationsGuideEnvelope = try await request(
      "GET", "/api/v1/admin/operations-guide", body: nil, authed: true)
    guard value.schemaVersion == "ADMIN_OPERATIONS_GUIDE_NATIVE_V1" else {
      throw ServerAPIError(
        message: "운영 매뉴얼 응답 버전이 앱과 맞지 않습니다.", code: "ADMIN_OPERATIONS_GUIDE_SCHEMA_UNSUPPORTED")
    }
    return value.guide
  }
}
