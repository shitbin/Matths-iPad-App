//  WeeklyMockAPI.swift
//  Matths
//
//  서버 privateMockExamService와 동일한 주간 공식 모의고사 Bearer 계약.
//  채점·공개 시각·대표 성적·무결성 판단은 서버만 결정하고 앱은 표시/입력만 맡는다.

import Foundation
import UniformTypeIdentifiers

extension ServerAPI {
    struct WeeklyMockEligibility: Codable {
        var allowed: Bool
        var status: String
        var title: String
        var message: String
        var ctaLabel: String
        var packageType: String?
        var availableLearningDays: Int?
    }

    struct WeeklyMockExamSummary: Codable, Identifiable, Hashable {
        var id: String
        var title: String
        var formCode: String
        var attemptNumber: Int
        var isTest: Bool
        var questionCount: Int
        var durationMinutes: Int
        var releaseAt: String?
        var closeAt: String?
        var lobbyOpensAt: String?
        var status: String
        var canEnterRoom: Bool
        var canStart: Bool
        var attemptStatus: String
        var answeredCount: Int
        var score: Double?
        var standardizedPerformance: Double?
        var detailPath: String?
        var paperPath: String?
    }

    struct WeeklyMockSelectionAttempt: Codable, Identifiable, Hashable {
        var id: String
        var attemptNumber: Int
        var formCode: String
        var rawScore: Double?
        var standardizedPerformance: Double?
        var totalPercentile: Double?
        var isRepresentative: Bool
    }

    struct WeeklyMockSelection: Codable, Hashable {
        var weekKey: String
        var attemptCount: Int
        var canChoose: Bool
        var locked: Bool
        var selectionState: String
        var selectionReason: String
        var selectedAttemptId: String?
        var representativeAttemptId: String?
        var attempts: [WeeklyMockSelectionAttempt]
    }

    struct WeeklyMockRankingRow: Codable, Identifiable {
        var rank: Int
        var displayName: String
        var score: Double?
        var standardizedPerformance: Double?
        var attemptCount: Int
        var elapsedMs: Int
        var elapsedLabel: String
        var id: String { "\(rank):\(displayName)" }
    }

    struct WeeklyMockDashboard: Codable {
        struct RankingPending: Codable {
            var title: String
            var status: String
            var publishesAt: String?
        }
        struct RankingSummary: Codable {
            var participantCount: Int
            var averageScore: Double
        }

        var eligibility: WeeklyMockEligibility
        var serverNow: String?
        var nextReleaseAt: String?
        var latestReleaseAt: String?
        var scheduleLabel: String
        var durationMinutes: Int
        var currentExam: WeeklyMockExamSummary?
        var weeklyExams: [WeeklyMockExamSummary]
        var selection: WeeklyMockSelection?
        var rankingTitle: String
        var rankingFinalized: Bool
        var rankingPending: RankingPending?
        var rankingSummary: RankingSummary?
        var weeklyRanking: [WeeklyMockRankingRow]
        var rankingRules: [String]
    }

    struct WeeklyMockAttempt: Codable {
        struct Exam: Codable {
            var id: String
            var title: String
            var weekKey: String?
            var formCode: String
            var attemptNumber: Int
            var isTest: Bool
            var questionCount: Int?
            var questionModes: [String]?
            var durationMinutes: Int?
            var paperPath: String?

            func mode(at index: Int) -> String {
                if let modes = questionModes, modes.indices.contains(index),
                   modes[index] == "multiple-choice" {
                    return "multiple-choice"
                }
                // 서버의 고정 수능형 규약: 1~21 선다, 22~30 단답.
                return index < 21 ? "multiple-choice" : "short-answer"
            }
        }
        struct Progress: Codable {
            var id: String
            var answers: [String]
            var answeredCount: Int
        }
        struct Tools: Codable { var formulaPath: String? }
        struct Result: Codable {
            var standardizedPerformance: Double?
            var totalPercentile: Double?
            var rawScore: Double?
            var correctCount: Int?
            var questionCount: Int
            var elapsedLabel: String
        }
        struct IntegrityReview: Codable {
            var status: String
            var caseId: String
            var detailPath: String
        }
        struct ReviewQuestion: Codable, Identifiable {
            var number: Int
            var mode: String
            var submittedAnswer: String
            var correctAnswer: String
            var isCorrect: Bool
            var points: Double
            var explanation: String?
            var id: Int { number }
        }

        var state: String
        var submitted: Bool
        var serverNow: String?
        var deadline: String?
        var releaseAt: String?
        var canStart: Bool?
        var pendingAggregation: Bool?
        var resultsAvailableAt: String?
        var reviewAvailable: Bool?
        var reviewPublishesAt: String?
        var exam: Exam
        var attempt: Progress?
        var tools: Tools?
        var result: Result?
        var selection: WeeklyMockSelection?
        var integrityReview: IntegrityReview?
        var review: [ReviewQuestion]?
    }

    struct WeeklyMockIntegrityCase: Codable, Identifiable {
        struct Exam: Codable {
            var id: String?
            var title: String
            var formCode: String
            var releaseAt: String?
        }
        struct EvidenceRequest: Codable {
            var requestedAt: String?
            var deadlineAt: String?
            var instructions: String
        }
        struct EvidenceSubmission: Codable, Identifiable {
            struct File: Codable, Identifiable {
                var originalName: String
                var mimeType: String
                var sizeBytes: Int
                var uploadedAt: String?
                var id: String { "\(originalName):\(uploadedAt ?? "")" }
            }
            var receiptId: String
            var submittedAt: String?
            var note: String
            var files: [File]
            var id: String { receiptId }
        }
        struct Decision: Codable {
            var result: String
            var reason: String
            var decidedAt: String?
        }

        var id: String
        var exam: Exam?
        var attemptId: String?
        var weekKey: String
        var status: String
        var requestedQuestionNumbers: [Int]
        var evidenceRequest: EvidenceRequest
        var evidenceSubmissions: [EvidenceSubmission]
        var reviewStatus: String
        var penaltyDecision: String
        var decision: Decision
        var canSubmit: Bool
    }

    struct WeeklyMockObjectionExam: Codable, Identifiable {
        var id: String
        var title: String
        var formCode: String
        var questionCount: Int
        var releaseAt: String?
    }

    struct WeeklyMockObjection: Codable, Identifiable {
        var id: String
        var examId: String?
        var examTitle: String
        var questionNumber: Int
        var issueDetail: String
        var status: String
        var reviewReason: String
        var reviewedAt: String?
        var createdAt: String?
    }

    struct WeeklyMockTelemetryEvent {
        var eventType: String
        var questionNumber: Int?
        var clientAt: Date
        var visibility: String?
        var answerLength: Int?

        var json: [String: Any] {
            var value: [String: Any] = [
                "eventType": eventType,
                "clientAt": ISO8601DateFormatter().string(from: clientAt),
            ]
            if let questionNumber { value["questionNumber"] = questionNumber }
            if let visibility { value["visibility"] = visibility }
            if let answerLength { value["answerLength"] = answerLength }
            return value
        }
    }

    private struct WeeklyMockDashboardEnvelope: Decodable {
        var weeklyMock: WeeklyMockDashboard
    }
    private struct WeeklyMockAttemptEnvelope: Decodable {
        var attempt: WeeklyMockAttempt
    }
    private struct WeeklyMockStartEnvelope: Decodable {
        var replayed: Bool
        var attempt: WeeklyMockAttempt
    }
    struct WeeklyMockDraftResponse: Decodable {
        struct Draft: Decodable {
            var replayed: Bool
            var submitted: Bool
            var answeredCount: Int?
            var savedAt: String?
            var attempt: WeeklyMockAttempt?
        }
        var draft: Draft
    }
    struct WeeklyMockSubmitResponse: Decodable {
        struct Result: Decodable {
            var elapsedMs: Int
            var elapsedLabel: String
            var pendingAggregation: Bool
            var resultsAvailableAt: String?
            var attemptNumber: Int
            var formCode: String
            var isTest: Bool
            var weekKey: String
        }
        var submitted: Bool
        var replayed: Bool
        var result: Result?
        var attempt: WeeklyMockAttempt?
    }
    struct WeeklyMockExpireResponse: Decodable {
        var expired: Bool
        var replayed: Bool
        var state: String
        var attemptId: String?
        var attempt: WeeklyMockAttempt?
    }
    private struct WeeklyMockSelectionEnvelope: Decodable {
        var selected: Bool
        var selection: SelectionResult
        struct SelectionResult: Decodable {
            var selectionState: String
            var selectedAttemptId: String?
        }
    }
    private struct WeeklyMockIntegrityEnvelope: Decodable {
        var integrityCases: [WeeklyMockIntegrityCase]
    }
    private struct WeeklyMockIntegrityDetailEnvelope: Decodable {
        var integrityCase: WeeklyMockIntegrityCase
    }
    struct WeeklyMockEvidenceReceipt: Decodable {
        var submitted: Bool
        var replayed: Bool
        var receiptId: String
        var submittedAt: String?
    }
    private struct WeeklyMockEvidenceEnvelope: Decodable {
        var evidence: WeeklyMockEvidenceReceipt
    }
    private struct WeeklyMockObjectionOptionsEnvelope: Decodable {
        var exams: [WeeklyMockObjectionExam]
    }
    private struct WeeklyMockObjectionsEnvelope: Decodable {
        var objections: [WeeklyMockObjection]
    }
    private struct WeeklyMockObjectionEnvelope: Decodable {
        var replayed: Bool
        var objection: WeeklyMockObjection
    }

    static func weeklyMockDashboard() async throws -> WeeklyMockDashboard {
        let value: WeeklyMockDashboardEnvelope = try await request(
            "GET", "/api/v1/weekly-mock-exams", body: nil, authed: true)
        return value.weeklyMock
    }

    static func weeklyMockAttempt(examId: String) async throws -> WeeklyMockAttempt {
        let value: WeeklyMockAttemptEnvelope = try await request(
            "GET", "/api/v1/weekly-mock-exams/\(examId)", body: nil, authed: true)
        return value.attempt
    }

    static func startWeeklyMock(examId: String) async throws -> WeeklyMockAttempt {
        let value: WeeklyMockStartEnvelope = try await request(
            "POST", "/api/v1/weekly-mock-exams/\(examId)/start", body: [:], authed: true)
        return value.attempt
    }

    static func saveWeeklyMockDraft(
        examId: String,
        answers: [String],
        telemetry: [WeeklyMockTelemetryEvent]
    ) async throws -> WeeklyMockDraftResponse.Draft {
        let value: WeeklyMockDraftResponse = try await request(
            "PATCH", "/api/v1/weekly-mock-exams/\(examId)/draft",
            body: ["answers": answers, "telemetryEvents": telemetry.map(\.json)],
            authed: true)
        return value.draft
    }

    static func submitWeeklyMock(
        examId: String,
        answers: [String],
        telemetry: [WeeklyMockTelemetryEvent]
    ) async throws -> WeeklyMockSubmitResponse {
        try await request(
            "POST", "/api/v1/weekly-mock-exams/\(examId)/submit",
            body: ["answers": answers, "telemetryEvents": telemetry.map(\.json)],
            authed: true)
    }

    static func expireWeeklyMock(examId: String) async throws -> WeeklyMockExpireResponse {
        try await request(
            "POST", "/api/v1/weekly-mock-exams/\(examId)/expire", body: [:], authed: true)
    }

    static func selectWeeklyMockRepresentative(
        weekKey: String,
        attemptId: String? = nil,
        deferSelection: Bool = false
    ) async throws {
        var body: [String: Any] = ["defer": deferSelection]
        if let attemptId { body["attemptId"] = attemptId }
        let _: WeeklyMockSelectionEnvelope = try await request(
            "POST", "/api/v1/weekly-mock-exams/weeks/\(weekKey)/selection",
            body: body, authed: true)
    }

    static func weeklyMockIntegrityCases() async throws -> [WeeklyMockIntegrityCase] {
        let value: WeeklyMockIntegrityEnvelope = try await request(
            "GET", "/api/v1/weekly-mock-exams/integrity-cases", body: nil, authed: true)
        return value.integrityCases
    }

    static func weeklyMockIntegrityCase(id: String) async throws -> WeeklyMockIntegrityCase {
        let value: WeeklyMockIntegrityDetailEnvelope = try await request(
            "GET", "/api/v1/weekly-mock-exams/integrity-cases/\(id)", body: nil, authed: true)
        return value.integrityCase
    }

    static func weeklyMockObjectionOptions() async throws -> [WeeklyMockObjectionExam] {
        let value: WeeklyMockObjectionOptionsEnvelope = try await request(
            "GET", "/api/v1/weekly-mock-exams/objections/options", body: nil, authed: true)
        return value.exams
    }

    static func weeklyMockObjections() async throws -> [WeeklyMockObjection] {
        let value: WeeklyMockObjectionsEnvelope = try await request(
            "GET", "/api/v1/weekly-mock-exams/objections", body: nil, authed: true)
        return value.objections
    }

    static func createWeeklyMockObjection(
        examId: String,
        questionNumber: Int,
        issueDetail: String
    ) async throws -> WeeklyMockObjection {
        let value: WeeklyMockObjectionEnvelope = try await request(
            "POST", "/api/v1/weekly-mock-exams/objections",
            body: [
                "examId": examId,
                "questionNumber": questionNumber,
                "issueDetail": issueDetail,
            ],
            authed: true)
        return value.objection
    }

    /// Bearer로 문제지를 받은 뒤 PDF magic bytes를 확인하고, 백업 제외된 캐시에 둡니다.
    static func downloadWeeklyMockPaper(
        examId: String,
        accountSlot: String
    ) async throws -> URL {
        let request = try authorizedRequest(
            "GET", "/api/v1/weekly-mock-exams/\(examId)/paper", timeout: 120)
        let (temporaryURL, response) = try await URLSession.shared.download(for: request)
        let errorBody = (try? Data(contentsOf: temporaryURL)) ?? Data()
        try validateAuthorizedResponse(
            response,
            errorBody: errorBody,
            requestToken: bearerToken(from: request))

        let handle = try FileHandle(forReadingFrom: temporaryURL)
        let signature = try handle.read(upToCount: 5) ?? Data()
        try handle.close()
        guard String(data: signature, encoding: .ascii) == "%PDF-" else {
            throw ServerAPIError(message: "문제지 파일이 올바른 PDF가 아닙니다.", code: "INVALID_PDF")
        }

        let manager = FileManager.default
        let directory = manager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("WeeklyMockPapers", isDirectory: true)
            .appendingPathComponent(accountSlot, isDirectory: true)
        try manager.createDirectory(at: directory, withIntermediateDirectories: true)
        var resource = URLResourceValues()
        resource.isExcludedFromBackup = true
        var mutableDirectory = directory
        try? mutableDirectory.setResourceValues(resource)

        let destination = directory.appendingPathComponent("\(examId).pdf")
        if manager.fileExists(atPath: destination.path) {
            try manager.removeItem(at: destination)
        }
        try manager.moveItem(at: temporaryURL, to: destination)
        try? manager.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: destination.path)
        return destination
    }

    static func submitWeeklyMockEvidence(
        caseId: String,
        files: [URL],
        note: String,
        submissionId: String
    ) async throws -> WeeklyMockEvidenceReceipt {
        guard !files.isEmpty, files.count <= 10 else {
            throw ServerAPIError(message: "소명 파일을 1개 이상 10개 이하로 선택해주세요.", code: "INVALID_EVIDENCE_FILES")
        }
        let boundary = "Matths-\(UUID().uuidString)"
        var request = try authorizedRequest(
            "POST",
            "/api/v1/weekly-mock-exams/integrity-cases/\(caseId)/evidence",
            contentType: "multipart/form-data; boundary=\(boundary)",
            timeout: 180)
        request.setValue(submissionId, forHTTPHeaderField: "Idempotency-Key")

        let multipart = FileManager.default.temporaryDirectory
            .appendingPathComponent("weekly-mock-evidence-\(UUID().uuidString).body")
        FileManager.default.createFile(atPath: multipart.path, contents: nil)
        let output = try FileHandle(forWritingTo: multipart)
        defer {
            try? output.close()
            try? FileManager.default.removeItem(at: multipart)
        }

        func write(_ text: String) throws {
            try output.write(contentsOf: Data(text.utf8))
        }
        try write("--\(boundary)\r\n")
        try write("Content-Disposition: form-data; name=\"note\"\r\n\r\n")
        try write(note.prefix(2000) + "\r\n")

        for file in files {
            let scoped = file.startAccessingSecurityScopedResource()
            defer { if scoped { file.stopAccessingSecurityScopedResource() } }
            let values = try file.resourceValues(forKeys: [.fileSizeKey, .contentTypeKey])
            guard let size = values.fileSize, size <= 10 * 1024 * 1024 else {
                throw ServerAPIError(message: "소명 파일은 각각 10MB 이하여야 합니다.", code: "EVIDENCE_FILE_TOO_LARGE")
            }
            let type = values.contentType
            guard type?.conforms(to: .pdf) == true || type?.conforms(to: .image) == true else {
                throw ServerAPIError(message: "PDF 또는 이미지 파일만 제출할 수 있습니다.", code: "INVALID_EVIDENCE_TYPE")
            }
            let mime = type?.preferredMIMEType ?? "application/octet-stream"
            let safeName = file.lastPathComponent
                .replacingOccurrences(of: "\"", with: "")
                .replacingOccurrences(of: "\r", with: "")
                .replacingOccurrences(of: "\n", with: "")
            try write("--\(boundary)\r\n")
            try write("Content-Disposition: form-data; name=\"evidenceFiles\"; filename=\"\(safeName)\"\r\n")
            try write("Content-Type: \(mime)\r\n\r\n")
            let input = try FileHandle(forReadingFrom: file)
            while let chunk = try input.read(upToCount: 256 * 1024), !chunk.isEmpty {
                try output.write(contentsOf: chunk)
            }
            try input.close()
            try write("\r\n")
        }
        try write("--\(boundary)--\r\n")
        try output.synchronize()

        let (data, response) = try await URLSession.shared.upload(for: request, fromFile: multipart)
        try validateAuthorizedResponse(
            response,
            errorBody: data,
            requestToken: bearerToken(from: request))
        return try JSONDecoder().decode(WeeklyMockEvidenceEnvelope.self, from: data).evidence
    }
}
