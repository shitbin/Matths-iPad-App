import Foundation

extension ServerAPI {
  struct AdminArenaPolicyRecord: Codable, Hashable, Identifiable {
    var id: String
    var code: String
    var displayName: String
    var status: String
    var effectiveFrom: String?
    var effectiveUntil: String?
    var priceAmount: Int?
    var initialLearningDays: Int?
    var initialPaybackScoreDays: Int?
    var maximumTargetTierGap: Int?
    var revengeStakeMultiplier: Int?
    var revengeFeeDays: Int?
    var changeSummary: String
  }
  struct AdminArenaPolicyMatchmaking: Codable, Hashable {
    var isPaused: Bool
    var reason: String
    var pausedAt: String?
  }
  struct AdminArenaLearningPolicy: Codable, Hashable {
    var active: AdminArenaPolicyRecord
    var policies: [AdminArenaPolicyRecord]
  }
  struct AdminArenaMockPolicy: Codable, Hashable {
    var activePrice: Int
    var billingPeriodDays: Int
    var policies: [AdminArenaPolicyRecord]
  }
  struct AdminArenaShopItem: Codable, Hashable, Identifiable {
    var code: String
    var name: String
    var priceDays: Int
    var enabled: Bool
    var id: String { code }
  }
  struct AdminArenaShopPolicy: Codable, Hashable { var items: [AdminArenaShopItem] }
  struct AdminArenaDivisionPolicy: Codable, Hashable {
    var active: AdminArenaPolicyRecord?
    var upcoming: AdminArenaPolicyRecord?
    var policies: [AdminArenaPolicyRecord]
  }
  struct AdminArenaPaybackRules: Codable, Hashable {
    var cycleDays: Int
    var minimumAttackParticipationDays: Int
  }
  struct AdminArenaPolicyDashboard: Codable, Hashable {
    var matchmaking: AdminArenaPolicyMatchmaking
    var learningPackage: AdminArenaLearningPolicy
    var mockExam: AdminArenaMockPolicy
    var shop: AdminArenaShopPolicy
    var unranked: AdminArenaDivisionPolicy
    var ranked: AdminArenaDivisionPolicy
    var paybackRules: AdminArenaPaybackRules
  }
  private struct AdminArenaPolicyEnvelope: Codable {
    var schemaVersion: String
    var dashboard: AdminArenaPolicyDashboard
  }
  private struct AdminArenaPolicyActionEnvelope: Codable {
    var schemaVersion: String
    var ok: Bool
    var dashboard: AdminArenaPolicyDashboard
  }

  static func adminArenaPolicies() async throws -> AdminArenaPolicyDashboard {
    let value: AdminArenaPolicyEnvelope = try await request(
      "GET", "/api/v1/admin/arena-policies", body: nil, authed: true)
    try validateAdminArenaPolicy(value.schemaVersion)
    return value.dashboard
  }
  static func setAdminArenaMatchmaking(paused: Bool, reason: String) async throws
    -> AdminArenaPolicyDashboard
  {
    try await adminArenaPolicyAction(
      "/api/v1/admin/arena-policies/matchmaking",
      ["action": paused ? "PAUSE" : "RESUME", "reason": reason])
  }
  static func setAdminLearningPrice(_ price: Int, note: String) async throws
    -> AdminArenaPolicyDashboard
  {
    try await adminArenaPolicyAction(
      "/api/v1/admin/arena-policies/learning-package",
      ["priceAmount": price, "changeSummary": note])
  }
  static func setAdminMockPrice(_ price: Int, note: String) async throws
    -> AdminArenaPolicyDashboard
  {
    try await adminArenaPolicyAction(
      "/api/v1/admin/arena-policies/mock-exam",
      ["monthlyPriceAmount": price, "changeSummary": note])
  }
  static func setAdminArenaShop(items: [AdminArenaShopItem], note: String) async throws
    -> AdminArenaPolicyDashboard
  {
    try await adminArenaPolicyAction(
      "/api/v1/admin/arena-policies/shop",
      [
        "items": items.map { ["code": $0.code, "priceDays": $0.priceDays, "enabled": $0.enabled] },
        "changeSummary": note,
      ])
  }
  static func createAdminUnrankedPolicy(_ body: [String: Any]) async throws
    -> AdminArenaPolicyDashboard
  { try await adminArenaPolicyAction("/api/v1/admin/arena-policies/unranked", body) }
  static func createAdminRankedPolicy(_ body: [String: Any]) async throws
    -> AdminArenaPolicyDashboard
  { try await adminArenaPolicyAction("/api/v1/admin/arena-policies/ranked", body) }
  static func activateAdminArenaPolicy(division: String, id: String) async throws
    -> AdminArenaPolicyDashboard
  {
    try await adminArenaPolicyAction("/api/v1/admin/arena-policies/\(division)/\(id)/activate", [:])
  }
  static func retireAdminArenaPolicy(division: String, id: String) async throws
    -> AdminArenaPolicyDashboard
  { try await adminArenaPolicyAction("/api/v1/admin/arena-policies/\(division)/\(id)/retire", [:]) }
  private static func adminArenaPolicyAction(_ path: String, _ body: [String: Any]) async throws
    -> AdminArenaPolicyDashboard
  {
    let value: AdminArenaPolicyActionEnvelope = try await request(
      "POST", path, body: body, authed: true)
    try validateAdminArenaPolicy(value.schemaVersion)
    guard value.ok else {
      throw ServerAPIError(
        message: "Arena 정책 작업을 완료하지 못했습니다.", code: "ADMIN_ARENA_POLICY_ACTION_FAILED")
    }
    return value.dashboard
  }
  private static func validateAdminArenaPolicy(_ value: String) throws {
    guard value == "ADMIN_ARENA_POLICY_NATIVE_V1" else {
      throw ServerAPIError(
        message: "Arena 정책 응답 버전이 앱과 맞지 않습니다.", code: "ADMIN_ARENA_POLICY_SCHEMA_UNSUPPORTED")
    }
  }
}
