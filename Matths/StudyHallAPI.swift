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

    static func studyHall(tab: String = "NJE", authorization: AuthorizationSnapshot = ServerAPI.authorizationForCurrentRequest()) async throws -> StudyHall {
        let value: StudyHallEnvelope = try await request(
            "GET", "/api/v1/study-hall", body: nil, authed: true,
            query: ["tab": tab], authorization: authorization)
        try validateStudyHallSchema(value.schemaVersion)
        return value.hall
    }

    static func studyHallContent(_ contentID: String, authorization: AuthorizationSnapshot = ServerAPI.authorizationForCurrentRequest()) async throws -> StudyHallContent {
        let value: StudyHallContentEnvelope = try await request(
            "GET", "/api/v1/study-hall/content/\(contentID)", body: nil, authed: true, authorization: authorization)
        try validateStudyHallSchema(value.schemaVersion)
        try validateStudyHallContent(value.content, expectedID: contentID)
        return value.content
    }

    static func saveStudyHallAnswers(
        contentID: String,
        answers: [StudyHallAnswer], authorization: AuthorizationSnapshot = ServerAPI.authorizationForCurrentRequest()
    ) async throws -> StudyHallContent {
        try await updateStudyHallAnswers(
            method: "PUT", suffix: "answers", contentID: contentID, answers: answers, authorization: authorization)
    }

    static func submitStudyHallAnswers(
        contentID: String,
        answers: [StudyHallAnswer], authorization: AuthorizationSnapshot = ServerAPI.authorizationForCurrentRequest()
    ) async throws -> StudyHallContent {
        try await updateStudyHallAnswers(
            method: "POST", suffix: "submit", contentID: contentID, answers: answers, authorization: authorization)
    }

    private static func updateStudyHallAnswers(
        method: String,
        suffix: String,
        contentID: String,
        answers: [StudyHallAnswer], authorization: AuthorizationSnapshot
    ) async throws -> StudyHallContent {
        let rows: [[String: Any]] = answers.map {
            ["number": $0.number, "answer": String($0.answer.prefix(100))]
        }
        let value: StudyHallContentEnvelope = try await request(
            method,
            "/api/v1/study-hall/content/\(contentID)/\(suffix)",
            body: ["answers": rows],
            authed: true, authorization: authorization)
        try validateStudyHallSchema(value.schemaVersion)
        try validateStudyHallContent(value.content, expectedID: contentID)
        return value.content
    }

    static func downloadStudyHallAsset(
        contentID: String,
        asset: StudyHallAsset, accountSlot: String = DataScope.slot,
        authorization: AuthorizationSnapshot = ServerAPI.authorizationForCurrentRequest()
    ) async throws -> URL {
        let request = try authorizedRequest(
            "GET",
            "/api/v1/study-hall/content/\(contentID)/files/\(asset.id)",
            timeout: 120, authorization: authorization)
        let (temporaryURL, response) = try await URLSession.shared.download(for: request)
        let errorBody: Data
        if let status = (response as? HTTPURLResponse)?.statusCode, status >= 400,
           let handle = try? FileHandle(forReadingFrom: temporaryURL) {
            errorBody = (try? handle.read(upToCount: 65_536)) ?? Data(); try? handle.close()
        } else { errorBody = Data() }
        let http = try validateAuthorizedResponse(
            response,
            errorBody: errorBody,
            requestToken: bearerToken(from: request))

        guard !Task.isCancelled, DataScope.slot == accountSlot, isCurrentAuthorization(authorization) else { throw CancellationError() }
        let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("StudyHallDownloads", isDirectory: true)
            .appendingPathComponent(accountSlot, isDirectory: true)
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
    private static func validateStudyHallContent(_ value: StudyHallContent, expectedID: String) throws {
        guard value.id == expectedID, (0...500).contains(value.itemCount), value.questions.count <= 500,
              Set(value.questions.map(\.number)).count == value.questions.count,
              Set(value.progress.answers.map(\.number)).count == value.progress.answers.count,
              value.questions.allSatisfy({ (1...500).contains($0.number) }), value.progress.answers.allSatisfy({ (1...500).contains($0.number) }),
              (0...100).contains(value.progress.percent), (0...100).contains(value.progress.scorePercent) else {
            throw ServerAPIError(message: "학습 내용과 답안 정보를 확인하지 못했습니다. 다시 불러와 주세요.", code: "STUDY_HALL_CONTENT_INVALID")
        }
    }
}
