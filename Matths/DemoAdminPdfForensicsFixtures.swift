#if DEBUG
  import Foundation
  enum DemoAdminPdfForensicsFixtures {
    static let analysis =
      #"{"schemaVersion":"ADMIN_PDF_FORENSICS_NATIVE_V1","analysis":{"inputType":"PDF","pageCount":12,"imageCount":0,"imageMetadata":null,"traceCodes":["MTH-A1B2C3D4E5F6"],"validPayloads":[],"pageTraceCount":12,"ocrCandidateCount":0,"ocrCandidates":[],"matches":[{"issuanceId":"issue-1","documentIssueId":"DOC-2026-000184","traceCode":"MTH-A1B2C3D4E5F6","userId":"user-1","username":"김민준","email":"minjun@example.com","name":"김민준","examId":"mock-2026-09-01","sourceType":"WEEKLY_MOCK","sourceId":"mock-1","originalName":"9월_1주차_모의고사.pdf","downloadedAt":"2026-09-01T08:20:00.000Z","pageCount":12,"signatureVerified":true,"recognitionMethod":"PDF_SIGNATURE","ocrConfidence":null,"matchedCandidate":""}]}}"#
  }
#endif
