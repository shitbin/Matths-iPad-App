import Foundation

extension ServerAPI {
  struct AdminForensicImageMetadata: Codable, Hashable {
    var format: String
    var width: Int
    var height: Int
    var ocrAttempts: Int
  }
  struct AdminForensicPayload: Codable, Hashable, Identifiable {
    var userId: String
    var examId: String
    var sourceType: String
    var downloadedAt: String
    var traceCode: String
    var documentIssueId: String
    var id: String { documentIssueId }
    enum CodingKeys: String, CodingKey {
      case userId = "user_id"
      case examId = "exam_id"
      case sourceType = "source_type"
      case downloadedAt = "downloaded_at"
      case traceCode = "trace_code"
      case documentIssueId = "document_issue_id"
    }
  }
  struct AdminForensicMatch: Codable, Hashable, Identifiable {
    var issuanceId: String
    var documentIssueId: String
    var traceCode: String
    var userId: String
    var username: String
    var email: String
    var name: String
    var examId: String
    var sourceType: String
    var sourceId: String
    var originalName: String
    var downloadedAt: String?
    var pageCount: Int
    var signatureVerified: Bool
    var recognitionMethod: String
    var ocrConfidence: Double?
    var matchedCandidate: String
    var id: String { issuanceId }
  }
  struct AdminPdfForensicAnalysis: Codable, Hashable {
    var inputType: String
    var pageCount: Int
    var imageCount: Int
    var imageMetadata: AdminForensicImageMetadata?
    var traceCodes: [String]
    var validPayloads: [AdminForensicPayload]
    var pageTraceCount: Int
    var ocrCandidateCount: Int
    var ocrCandidates: [String]?
    var matches: [AdminForensicMatch]
  }
  private struct AdminPdfForensicsEnvelope: Codable {
    var schemaVersion: String
    var analysis: AdminPdfForensicAnalysis
  }

  static func analyzeAdminPdfForensics(data: Data, filename: String, mimeType: String) async throws
    -> AdminPdfForensicAnalysis
  {
    guard !data.isEmpty, data.count <= 50 * 1024 * 1024 else {
      throw ServerAPIError(message: "유출 추적 파일은 50MB 이하로 선택해 주세요.", code: "FORENSICS_FILE_TOO_LARGE")
    }
    let boundary = "Matths-Admin-Forensics-\(UUID().uuidString)"
    var request = try authorizedRequest(
      "POST", "/api/v1/admin/pdf-forensics/analyze",
      contentType: "multipart/form-data; boundary=\(boundary)", timeout: 240)
    var body = Data()
    body.append(Data("--\(boundary)\r\n".utf8))
    let safe = filename.replacingOccurrences(of: "\"", with: "")
    body.append(
      Data("Content-Disposition: form-data; name=\"forensicFile\"; filename=\"\(safe)\"\r\n".utf8))
    body.append(Data("Content-Type: \(mimeType)\r\n\r\n".utf8))
    body.append(data)
    body.append(Data("\r\n--\(boundary)--\r\n".utf8))
    request.httpBody = body
    let (responseData, response) = try await URLSession.shared.data(for: request)
    try validateAuthorizedResponse(
      response, errorBody: responseData, requestToken: bearerToken(from: request))
    let value = try JSONDecoder().decode(AdminPdfForensicsEnvelope.self, from: responseData)
    guard value.schemaVersion == "ADMIN_PDF_FORENSICS_NATIVE_V1" else {
      throw ServerAPIError(
        message: "유출 추적 응답 버전이 앱과 맞지 않습니다.", code: "ADMIN_PDF_FORENSICS_SCHEMA_UNSUPPORTED")
    }
    return value.analysis
  }
}
