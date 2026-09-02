import Foundation

extension ServerAPI {
    struct AdminMockFormSchedule: Codable, Hashable, Identifiable {
        var formCode: String
        var attemptNumber: Int
        var label: String
        var fixedDate: String?
        var isTest: Bool
        var isCustom: Bool
        var id: String { formCode }
    }

    struct AdminMockFormulaResource: Codable, Hashable, Identifiable {
        var id: String
        var versionLabel: String
        var isActive: Bool
        var originalName: String
        var createdAt: String?
    }

    struct AdminMockExam: Codable, Hashable, Identifiable {
        var id: String
        var title: String
        var weekKey: String
        var weekLabel: String
        var attemptNumber: Int
        var formCode: String
        var isTest: Bool
        var releaseAt: String?
        var closeAt: String?
        var aggregationStartsAt: String?
        var rankingPublishesAt: String?
        var archiveAt: String?
        var status: String
        var questionCount: Int
        var attemptCount: Int
        var integrityCaseCount: Int
        var notificationSentAt: String?
        var rankingFinalizedAt: String?
        var archivedAt: String?
        var canDelete: Bool
        var originalName: String
        var answerSheetName: String
        var hasAnswerSheet: Bool
    }

    struct AdminMockDashboard: Codable, Hashable {
        var nextSunday: String
        var defaultExamDate: String
        var defaultDurationMinutes: Int
        var formSchedules: [AdminMockFormSchedule]
        var formulaResources: [AdminMockFormulaResource]
        var exams: [AdminMockExam]
    }

    struct AdminMockPerson: Codable, Hashable {
        var id: String
        var name: String
        var nickname: String
        var email: String
    }

    struct AdminMockExplanation: Codable, Hashable {
        var intent: String
        var concept: String
        var steps: [String]
        var summary: String
        var commonMistake: String
    }

    struct AdminMockQuestionReview: Codable, Hashable, Identifiable {
        var number: Int
        var mode: String
        var submittedAnswer: String
        var correctAnswer: String
        var isCorrect: Bool
        var points: Int
        var explanation: AdminMockExplanation?
        var id: Int { number }
    }

    struct AdminMockEvent: Codable, Hashable, Identifiable {
        var id: String
        var eventType: String
        var questionNumber: Int?
        var metadata: String
        var serverAt: String?
    }

    struct AdminMockEvidenceFile: Codable, Hashable, Identifiable {
        var archiveItemId: String
        var originalName: String
        var id: String { archiveItemId }
    }

    struct AdminMockEvidenceSubmission: Codable, Hashable, Identifiable {
        var id: String
        var receiptId: String
        var submittedAt: String?
        var note: String
        var files: [AdminMockEvidenceFile]
    }

    struct AdminMockSuspicionSignal: Codable, Hashable, Identifiable {
        var code: String
        var detail: String
        var id: String { "\(code):\(detail)" }
    }

    struct AdminMockIntegrityCase: Codable, Hashable, Identifiable {
        var id: String
        var status: String
        var riskScore: Int
        var requestedQuestionNumbers: [Int]
        var suspicionSignals: [AdminMockSuspicionSignal]
        var requestedAt: String?
        var instructions: String
        var evidenceSubmissions: [AdminMockEvidenceSubmission]
        var reviewStatus: String
        var penaltyDecision: String
        var decisionReason: String
        var reviewedAt: String?
    }

    struct AdminMockAttempt: Codable, Hashable, Identifiable {
        var id: String
        var user: AdminMockPerson?
        var status: String
        var score: Int
        var correctCount: Int
        var questionCount: Int
        var elapsedMs: Int
        var integrityStatus: String
        var incorrectQuestionNumbers: [Int]
        var standardPerformance: Double?
        var submittedAt: String?
        var review: [AdminMockQuestionReview]
        var events: [AdminMockEvent]
        var integrityCase: AdminMockIntegrityCase?
    }

    struct AdminMockExamDetail: Codable, Hashable {
        var exam: AdminMockExam
        var attempts: [AdminMockAttempt]
    }

    struct AdminMockObjection: Codable, Hashable, Identifiable {
        var id: String
        var user: AdminMockPerson?
        var examId: String
        var examTitle: String
        var questionNumber: Int
        var currentAnswer: String
        var issueDetail: String
        var status: String
        var reviewReason: String
        var createdAt: String?
        var reviewedAt: String?
    }

    private struct AdminMockDashboardEnvelope: Codable { var schemaVersion: String; var dashboard: AdminMockDashboard }
    private struct AdminMockDetailEnvelope: Codable { var schemaVersion: String; var detail: AdminMockExamDetail }
    private struct AdminMockObjectionEnvelope: Codable { var schemaVersion: String; var objection: AdminMockObjection }
    private struct AdminMockMutationEnvelope: Codable {
        var schemaVersion: String
        var ok: Bool
        var affectedAttemptCount: Int?
        var createdCount: Int?
    }

    static func adminWeeklyMockDashboard() async throws -> AdminMockDashboard {
        let value: AdminMockDashboardEnvelope = try await request("GET", "/api/v1/admin/weekly-mock-exams", body: nil, authed: true)
        try validateAdminWeeklyMock(value.schemaVersion); return value.dashboard
    }

    static func adminWeeklyMockDetail(examID: String) async throws -> AdminMockExamDetail {
        let value: AdminMockDetailEnvelope = try await request("GET", "/api/v1/admin/weekly-mock-exams/\(examID)", body: nil, authed: true)
        try validateAdminWeeklyMock(value.schemaVersion); return value.detail
    }

    static func downloadAdminWeeklyMockFile(examID: String, fileType: String, fileName: String) async throws -> URL {
        try await downloadAdminMockFile(
            path: "/api/v1/admin/weekly-mock-exams/\(examID)/files/\(fileType)",
            fileName: fileName.isEmpty ? "\(examID)-\(fileType).pdf" : fileName)
    }

    static func downloadAdminMockEvidence(caseID: String, archiveItemID: String, fileName: String) async throws -> URL {
        try await downloadAdminMockFile(
            path: "/api/v1/admin/weekly-mock-integrity/\(caseID)/evidence/\(archiveItemID)",
            fileName: fileName.isEmpty ? archiveItemID : fileName)
    }

    static func requestAdminMockIntegrityEvidence(examID: String, attemptID: String, questionNumbers: String, instructions: String) async throws {
        _ = try await adminMockMutation(path: "/api/v1/admin/weekly-mock-exams/\(examID)/attempts/\(attemptID)/integrity-request", body: ["requestedQuestionNumbers": questionNumbers, "instructions": instructions])
    }

    static func reviewAdminMockIntegrity(examID: String, caseID: String, reviewStatus: String, penaltyDecision: String, reason: String) async throws {
        _ = try await adminMockMutation(path: "/api/v1/admin/weekly-mock-exams/\(examID)/integrity/\(caseID)/review", body: ["reviewStatus": reviewStatus, "penaltyDecision": penaltyDecision, "reason": reason])
    }

    @discardableResult
    static func correctAdminMockAnswers(examID: String, questionNumber: Int, questionContent: String, newAnswer: String, reason: String) async throws -> Int {
        let value = try await adminMockMutation(path: "/api/v1/admin/weekly-mock-exams/\(examID)/answer-corrections", body: ["corrections": [["questionNumber": questionNumber, "questionContent": questionContent, "newAnswer": newAnswer]], "reason": reason])
        return value.affectedAttemptCount ?? 0
    }

    static func deleteAdminWeeklyMock(examID: String) async throws {
        _ = try await adminMockMutation(path: "/api/v1/admin/weekly-mock-exams/\(examID)/delete", body: [:])
    }

    @discardableResult
    static func uploadAdminWeeklyMock(
        examURL: URL, answerKeyURL: URL, answerSheetURL: URL?, title: String,
        examDate: String, customReleaseAt: String, formCode: String
    ) async throws -> Int {
        var files = [
            AdminMockUploadPart(name: "examFiles", url: examURL, mimeType: "application/pdf"),
            AdminMockUploadPart(name: "answerKeyFiles", url: answerKeyURL, mimeType: "application/json"),
        ]
        if let answerSheetURL { files.append(.init(name: "answerSheetFiles", url: answerSheetURL, mimeType: "application/pdf")) }
        let value: AdminMockMutationEnvelope = try await uploadAdminMockMultipart(
            path: "/api/v1/admin/weekly-mock-exams/upload",
            fields: ["titles": title, "examDates": examDate, "customReleaseAts": customReleaseAt, "formCodes": formCode],
            files: files)
        return value.createdCount ?? 0
    }

    static func uploadAdminWeeklyMockFormula(fileURL: URL, versionLabel: String) async throws {
        let _: AdminMockMutationEnvelope = try await uploadAdminMockMultipart(
            path: "/api/v1/admin/weekly-mock-formulas/upload", fields: ["versionLabel": versionLabel],
            files: [.init(name: "formulaFile", url: fileURL, mimeType: "application/pdf")])
    }

    static func deleteAdminWeeklyMockFormula(resourceID: String) async throws {
        _ = try await adminMockMutation(path: "/api/v1/admin/weekly-mock-formulas/\(resourceID)/delete", body: [:])
    }

    static func adminWeeklyMockObjection(id: String) async throws -> AdminMockObjection {
        let value: AdminMockObjectionEnvelope = try await request("GET", "/api/v1/admin/weekly-mock-objections/\(id)", body: nil, authed: true)
        try validateAdminWeeklyMock(value.schemaVersion); return value.objection
    }

    static func rejectAdminWeeklyMockObjection(id: String, reason: String) async throws {
        _ = try await adminMockMutation(path: "/api/v1/admin/weekly-mock-objections/\(id)/reject", body: ["reason": reason])
    }

    static func acceptAdminWeeklyMockObjection(id: String, newAnswer: String, questionContent: String, reason: String) async throws {
        _ = try await adminMockMutation(path: "/api/v1/admin/weekly-mock-objections/\(id)/accept", body: ["newAnswer": newAnswer, "questionContent": questionContent, "reason": reason])
    }

    private static func adminMockMutation(path: String, body: [String: Any]) async throws -> AdminMockMutationEnvelope {
        let value: AdminMockMutationEnvelope = try await request("POST", path, body: body, authed: true)
        try validateAdminWeeklyMock(value.schemaVersion)
        guard value.ok else { throw ServerAPIError(message: "모의고사 관리자 작업을 완료하지 못했습니다.", code: "ADMIN_MOCK_ACTION_FAILED") }
        return value
    }

    private static func validateAdminWeeklyMock(_ value: String) throws {
        guard value == "ADMIN_WEEKLY_MOCK_NATIVE_V1" else {
            throw ServerAPIError(message: "모의고사 관리자 응답 버전이 앱과 맞지 않습니다.", code: "ADMIN_WEEKLY_MOCK_SCHEMA_UNSUPPORTED")
        }
    }

    private static func downloadAdminMockFile(path: String, fileName: String) async throws -> URL {
        let request = try authorizedRequest("GET", path, timeout: 120)
        let (temporaryURL, response) = try await URLSession.shared.download(for: request)
        let errorBody = (try? Data(contentsOf: temporaryURL)) ?? Data()
        try validateAuthorizedResponse(response, errorBody: errorBody, requestToken: bearerToken(from: request))
        guard !errorBody.isEmpty else {
            throw ServerAPIError(message: "파일이 비어 있습니다.", code: "EMPTY_ADMIN_MOCK_FILE")
        }
        let safeName = fileName.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
        let manager = FileManager.default
        let directory = manager.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("AdminWeeklyMock", isDirectory: true)
        try manager.createDirectory(at: directory, withIntermediateDirectories: true)
        var values = URLResourceValues(); values.isExcludedFromBackup = true; var mutable = directory; try? mutable.setResourceValues(values)
        let destination = directory.appendingPathComponent("\(UUID().uuidString)-\(safeName)")
        try manager.moveItem(at: temporaryURL, to: destination)
        try? manager.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: destination.path)
        return destination
    }

    private struct AdminMockUploadPart { let name: String; let url: URL; let mimeType: String }

    private static func uploadAdminMockMultipart(
        path: String, fields: [String: String], files: [AdminMockUploadPart]
    ) async throws -> AdminMockMutationEnvelope {
        let boundary = "Matths-Admin-Mock-\(UUID().uuidString)"
        let request = try authorizedRequest("POST", path, contentType: "multipart/form-data; boundary=\(boundary)", timeout: 300)
        let bodyURL = FileManager.default.temporaryDirectory.appendingPathComponent("admin-mock-\(UUID().uuidString).body")
        FileManager.default.createFile(atPath: bodyURL.path, contents: nil)
        let output = try FileHandle(forWritingTo: bodyURL)
        defer { try? output.close(); try? FileManager.default.removeItem(at: bodyURL) }
        func write(_ value: String) throws { try output.write(contentsOf: Data(value.utf8)) }
        for (name, value) in fields {
            try write("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n")
        }
        for file in files {
            let accessed = file.url.startAccessingSecurityScopedResource(); defer { if accessed { file.url.stopAccessingSecurityScopedResource() } }
            let safeName = file.url.lastPathComponent.replacingOccurrences(of: "\"", with: "")
            try write("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(file.name)\"; filename=\"\(safeName)\"\r\nContent-Type: \(file.mimeType)\r\n\r\n")
            let input = try FileHandle(forReadingFrom: file.url)
            while let chunk = try input.read(upToCount: 1_048_576), !chunk.isEmpty { try output.write(contentsOf: chunk) }
            try input.close(); try write("\r\n")
        }
        try write("--\(boundary)--\r\n"); try output.synchronize()
        let (data, response) = try await URLSession.shared.upload(for: request, fromFile: bodyURL)
        try validateAuthorizedResponse(response, errorBody: data, requestToken: bearerToken(from: request))
        let value = try JSONDecoder().decode(AdminMockMutationEnvelope.self, from: data)
        try validateAdminWeeklyMock(value.schemaVersion)
        guard value.ok else { throw ServerAPIError(message: "모의고사 파일을 등록하지 못했습니다.", code: "ADMIN_MOCK_UPLOAD_FAILED") }
        return value
    }
}
