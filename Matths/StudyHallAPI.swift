import Foundation

extension ServerAPI {
    struct StudyHallTab: Codable, Identifiable, Hashable {
        var code: String
        var label: String
        var summary: String
        var id: String { code }
    }

    struct StudyHallAnswer: Codable, Hashable {
        var number: Int
        var answer: String
    }

    struct StudyHallProgress: Codable, Hashable {
        var status: String
        var lastQuestionNumber: Int
        var answeredCount: Int
        var correctCount: Int
        var scorePoints: Double
        var totalPoints: Double
        var scorePercent: Int
        var percent: Int
        var answers: [StudyHallAnswer]
        var submittedAt: String?
    }

    struct StudyHallAsset: Codable, Identifiable, Hashable {
        var id: String
        var kind: String
        var originalName: String
        var mimeType: String
        var sizeBytes: Int
        var downloadCount: Int
    }

    struct StudyHallQuestion: Codable, Identifiable, Hashable {
        var id: String
        var number: Int
        var stem: String
        var choices: [String]
        var answerType: String
        var points: Double
        var correctAnswer: String?
        var explanation: String?
        var isCorrect: Bool?
    }

    struct StudyHallContent: Codable, Identifiable, Hashable {
        var id: String
        var contentType: String
        var tabLabel: String
        var series: String
        var title: String
        var description: String
        var grade: String
        var subject: String
        var itemCount: Int
        var difficulty: String
        var timeLimitMinutes: Int
        var recommendedStudyDays: Int
        var estimatedMinutes: Int
        var year: Int
        var month: Int
        var week: Int
        var session: Int
        var phase: String
        var finalCategory: String
        var errorCategory: String
        var commonMistake: String
        var wrongApproach: String
        var correctApproach: String
        var relatedProblem: String
        var questions: [StudyHallQuestion]
        var assets: [StudyHallAsset]
        var thumbnail: StudyHallAsset?
        var questionPdf: StudyHallAsset?
        var solutionPdf: StudyHallAsset?
        var contentFiles: [StudyHallAsset]
        var status: String
        var sortOrder: Int
        var publishAt: String?
        var createdAt: String?
        var updatedAt: String?
        var progress: StudyHallProgress
    }

    struct StudyHall: Codable, Hashable {
        var tabs: [StudyHallTab]
        var activeTab: String
        var items: [StudyHallContent]
        var continuing: StudyHallContent?
    }

    private struct StudyHallEnvelope: Codable {
        var schemaVersion: String
        var hall: StudyHall
    }

    private struct StudyHallContentEnvelope: Codable {
        var schemaVersion: String
        var content: StudyHallContent
    }

    static func studyHall(tab: String = "NJE") async throws -> StudyHall {
        let value: StudyHallEnvelope = try await request(
            "GET", "/api/v1/study-hall", body: nil, authed: true,
            query: ["tab": tab])
        try validateStudyHallSchema(value.schemaVersion)
        return value.hall
    }

    static func studyHallContent(_ contentID: String) async throws -> StudyHallContent {
        let value: StudyHallContentEnvelope = try await request(
            "GET", "/api/v1/study-hall/content/\(contentID)", body: nil, authed: true)
        try validateStudyHallSchema(value.schemaVersion)
        return value.content
    }

    static func saveStudyHallAnswers(
        contentID: String,
        answers: [StudyHallAnswer]
    ) async throws -> StudyHallContent {
        try await updateStudyHallAnswers(
            method: "PUT", suffix: "answers", contentID: contentID, answers: answers)
    }

    static func submitStudyHallAnswers(
        contentID: String,
        answers: [StudyHallAnswer]
    ) async throws -> StudyHallContent {
        try await updateStudyHallAnswers(
            method: "POST", suffix: "submit", contentID: contentID, answers: answers)
    }

    private static func updateStudyHallAnswers(
        method: String,
        suffix: String,
        contentID: String,
        answers: [StudyHallAnswer]
    ) async throws -> StudyHallContent {
        let rows: [[String: Any]] = answers.map {
            ["number": $0.number, "answer": String($0.answer.prefix(100))]
        }
        let value: StudyHallContentEnvelope = try await request(
            method,
            "/api/v1/study-hall/content/\(contentID)/\(suffix)",
            body: ["answers": rows],
            authed: true)
        try validateStudyHallSchema(value.schemaVersion)
        return value.content
    }

    static func downloadStudyHallAsset(
        contentID: String,
        asset: StudyHallAsset
    ) async throws -> URL {
        let request = try authorizedRequest(
            "GET",
            "/api/v1/study-hall/content/\(contentID)/files/\(asset.id)",
            timeout: 120)
        let (temporaryURL, response) = try await URLSession.shared.download(for: request)
        let errorBody = (try? Data(contentsOf: temporaryURL)) ?? Data()
        let http = try validateAuthorizedResponse(
            response,
            errorBody: errorBody,
            requestToken: bearerToken(from: request))

        let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("StudyHallDownloads", isDirectory: true)
            .appendingPathComponent(DataScope.slot, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutableDirectory = directory
        try? mutableDirectory.setResourceValues(values)
        let suggested = (http.suggestedFilename ?? asset.originalName)
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        let destination = directory.appendingPathComponent(
            "\(UUID().uuidString)-\(suggested.isEmpty ? "Matths-학습자료" : suggested)")
        try FileManager.default.moveItem(at: temporaryURL, to: destination)
        return destination
    }

    private static func validateStudyHallSchema(_ value: String) throws {
        guard value == "STUDY_HALL_NATIVE_V1" else {
            throw ServerAPIError(
                message: "학습 콘텐츠 응답 버전이 앱과 맞지 않습니다.",
                code: "STUDY_HALL_SCHEMA_UNSUPPORTED")
        }
    }
}
