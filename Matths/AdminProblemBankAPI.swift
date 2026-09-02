import Foundation

extension ServerAPI {
  struct AdminProblemValidation: Codable, Hashable {
    var passed: Bool
    var sampleCount: Int
    var validationMode: String
    var calculatorFree: Bool
    var answerVerified: Bool
    var failures: [String]
  }
  struct AdminProblemTypeCategory: Codable, Hashable, Identifiable {
    var key: String
    var label: String
    var description: String
    var count: Int
    var id: String { key }
  }
  struct AdminProblemTypeRecord: Codable, Hashable, Identifiable {
    var id: String
    var category: String
    var engineKey: String
    var displayName: String
    var courseId: String
    var unitId: String
    var conceptId: String
    var enabled: Bool
    var selectionWeight: Int
    var revision: Int
    var operatorNote: String
    var sourceFile: String
    var sourceSnapshot: String
    var sourceHash: String
    var codeChanged: Bool
    var validation: AdminProblemValidation
  }
  struct AdminProblemTypes: Codable, Hashable {
    var categories: [AdminProblemTypeCategory]
    var selectedCategory: String
    var entries: [AdminProblemTypeRecord]
    var inspected: AdminProblemTypeRecord?
    var history: [AdminProblemTypeRecord]
  }
  struct AdminProblemVersion: Codable, Hashable, Identifiable {
    var id: String
    var code: String
    var displayName: String
    var status: String
    var engineVersion: String
    var changeSummary: String
    var contentHash: String
    var activatedAt: String?
    var updatedAt: String?
    var validation: AdminProblemValidation
  }
  struct AdminArenaAvailableProblemType: Codable, Hashable, Identifiable {
    var id: String
    var label: String
    var courseId: String
    var expectedTimeMs: Int
  }
  struct AdminArenaTierConfiguration: Codable, Hashable, Identifiable {
    var difficultyTier: String
    var typeIds: [String]
    var id: String { difficultyTier }
  }
  struct AdminArenaTypeSetting: Codable, Hashable, Identifiable {
    var typeId: String
    var enabled: Bool
    var selectionWeight: Int
    var answerMin: Int
    var answerMax: Int
    var difficultyNote: String
    var id: String { typeId }
  }
  struct AdminProblemDataForm: Codable, Hashable {
    var code: String
    var displayName: String
    var changeSummary: String
    var tierConfigurations: [AdminArenaTierConfiguration]
    var typeSettings: [AdminArenaTypeSetting]
  }
  struct AdminProblemData: Codable, Hashable {
    var active: AdminProblemVersion
    var recent: [AdminProblemVersion]
    var editableId: String
    var availableTypes: [AdminArenaAvailableProblemType]
    var difficultyTiers: [String]
    var form: AdminProblemDataForm
  }
  struct AdminTierBaseType: Codable, Hashable, Identifiable {
    var id: String
    var label: String
  }
  struct AdminPublicDifficulty: Codable, Hashable, Identifiable {
    var difficultyCode: String
    var catalogTier: String
    var minimumTypeVariants: Int
    var variantCount: Int
    var packComposition: String
    var id: String { difficultyCode }
  }
  struct AdminTierCatalog: Codable, Hashable {
    var active: AdminProblemVersion?
    var recent: [AdminProblemVersion]
    var baseTypes: [AdminTierBaseType]
    var publicDifficultyCatalog: [AdminPublicDifficulty]
  }
  struct AdminProblemBankDashboard: Codable, Hashable {
    var types: AdminProblemTypes
    var problem: AdminProblemData
    var tiers: AdminTierCatalog
  }
  private struct AdminProblemBankEnvelope: Codable {
    var schemaVersion: String
    var dashboard: AdminProblemBankDashboard
  }
  private struct AdminProblemBankActionEnvelope: Codable {
    var schemaVersion: String
    var ok: Bool
  }
  private struct AdminProblemBankCreateEnvelope: Codable {
    var schemaVersion: String
    var ok: Bool
    var versionId: String
  }

  static func adminProblemBanks(
    category: String? = nil, query: String? = nil, inspect: String? = nil, edit: String? = nil
  ) async throws -> AdminProblemBankDashboard {
    var values: [String: String] = [:]
    if let category { values["category"] = category }
    if let query, !query.isEmpty { values["query"] = query }
    if let inspect, !inspect.isEmpty { values["inspectVersionId"] = inspect }
    if let edit, !edit.isEmpty { values["editVersionId"] = edit }
    let value: AdminProblemBankEnvelope = try await request(
      "GET", "/api/v1/admin/problem-banks", body: nil, authed: true, query: values)
    try validateAdminProblemBank(value.schemaVersion)
    return value.dashboard
  }
  static func syncAdminProblemTypes() async throws {
    try await adminProblemAction("/api/v1/admin/problem-banks/types/sync", [:])
  }
  static func reviseAdminProblemType(id: String, enabled: Bool, weight: Int, note: String)
    async throws
  {
    try await adminProblemAction(
      "/api/v1/admin/problem-banks/types/\(id)/revise",
      ["enabled": enabled, "selectionWeight": weight, "operatorNote": note])
  }
  static func createAdminTierProblemType(
    name: String, baseTypeID: String, tiers: [String], note: String
  ) async throws {
    try await adminProblemAction(
      "/api/v1/admin/problem-banks/arena/types",
      [
        "displayName": name, "baseTypeId": baseTypeID, "difficultyTiers": tiers,
        "operatorNote": note,
      ])
  }
  static func createAdminProblemData(_ body: [String: Any]) async throws -> String {
    let value: AdminProblemBankCreateEnvelope = try await request(
      "POST", "/api/v1/admin/problem-banks/arena/data", body: body, authed: true)
    try validateAdminProblemBank(value.schemaVersion)
    return value.versionId
  }
  static func updateAdminProblemData(id: String, body: [String: Any]) async throws {
    try await adminProblemAction("/api/v1/admin/problem-banks/arena/data/\(id)", body)
  }
  static func activateAdminProblemData(id: String) async throws {
    try await adminProblemAction("/api/v1/admin/problem-banks/arena/data/\(id)/activate", [:])
  }
  private static func adminProblemAction(_ path: String, _ body: [String: Any]) async throws {
    let value: AdminProblemBankActionEnvelope = try await request(
      "POST", path, body: body, authed: true)
    try validateAdminProblemBank(value.schemaVersion)
    guard value.ok else {
      throw ServerAPIError(
        message: "문제 데이터 작업을 완료하지 못했습니다.", code: "ADMIN_PROBLEM_BANK_ACTION_FAILED")
    }
  }
  private static func validateAdminProblemBank(_ value: String) throws {
    guard value == "ADMIN_PROBLEM_BANK_NATIVE_V1" else {
      throw ServerAPIError(
        message: "문제 데이터 응답 버전이 앱과 맞지 않습니다.", code: "ADMIN_PROBLEM_BANK_SCHEMA_UNSUPPORTED")
    }
  }
}
