import Foundation

extension ServerAPI {
  struct AdminAnalysisPeriod: Codable, Hashable {
    var periodKey: String
    var label: String
  }
  struct AdminAnalysisPeriodOption: Codable, Hashable, Identifiable {
    var key: String
    var label: String
    var id: String { key }
  }
  struct AdminAnalysisSummary: Codable, Hashable {
    var catalogMetricCount: Int
    var observedMetricCount: Int
    var waitingMetricCount: Int
    var reliableMetricCount: Int
    var observationRowCount: Int
  }
  struct AdminAnalysisObservation: Codable, Hashable, Identifiable {
    var valueLabel: String
    var numerator: Double?
    var denominator: Double?
    var sampleSize: Int
    var dimensionsLabel: String
    var note: String
    var id: String { "\(dimensionsLabel):\(valueLabel):\(sampleSize)" }
  }
  struct AdminAnalysisMetric: Codable, Hashable, Identifiable {
    var label: String
    var unit: String
    var status: String
    var statusLabel: String
    var minimumSampleSize: Int
    var observations: [AdminAnalysisObservation]
    var id: String { label }
  }
  struct AdminAnalysisCategory: Codable, Hashable, Identifiable {
    var key: String
    var label: String
    var metrics: [AdminAnalysisMetric]
    var id: String { key }
  }
  struct AdminAnalysisAssumption: Codable, Hashable, Identifiable {
    var label: String
    var assumptionLabel: String
    var actualLabel: String
    var sampleSize: Int
    var ready: Bool
    var minimumSampleSize: Int
    var id: String { label }
  }
  struct AdminDataAnalysis: Codable, Hashable {
    var period: AdminAnalysisPeriod
    var periodOptions: [AdminAnalysisPeriodOption]
    var generatedAt: String?
    var periodClosed: Bool
    var summary: AdminAnalysisSummary
    var categories: [AdminAnalysisCategory]
    var assumptions: [AdminAnalysisAssumption]
  }
  private struct AdminDataAnalysisEnvelope: Codable {
    var schemaVersion: String
    var analysis: AdminDataAnalysis
  }
  private struct AdminDataAnalysisActionEnvelope: Codable {
    var schemaVersion: String
    var ok: Bool
  }

  static func adminDataAnalysis(period: String? = nil) async throws -> AdminDataAnalysis {
    let query = period.map { ["period": $0] } ?? [:]
    let value: AdminDataAnalysisEnvelope = try await request(
      "GET", "/api/v1/admin/data-analysis", body: nil, authed: true, query: query)
    try validateAdminDataAnalysis(value.schemaVersion)
    return value.analysis
  }
  static func rebuildAdminDataAnalysis(period: String) async throws {
    let value: AdminDataAnalysisActionEnvelope = try await request(
      "POST", "/api/v1/admin/data-analysis/rebuild", body: ["periodKey": period], authed: true)
    try validateAdminDataAnalysis(value.schemaVersion)
    guard value.ok else {
      throw ServerAPIError(
        message: "운영 지표를 다시 집계하지 못했습니다.", code: "ADMIN_DATA_ANALYSIS_REBUILD_FAILED")
    }
  }
  private static func validateAdminDataAnalysis(_ value: String) throws {
    guard value == "ADMIN_DATA_ANALYSIS_NATIVE_V1" else {
      throw ServerAPIError(
        message: "운영 지표 응답 버전이 앱과 맞지 않습니다.", code: "ADMIN_DATA_ANALYSIS_SCHEMA_UNSUPPORTED")
    }
  }
}
