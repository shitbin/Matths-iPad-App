import Foundation

extension ServerAPI {
    struct AdminArenaUser: Codable, Hashable, Identifiable { var id: String; var name: String; var email: String; var accountStatus: String; var warningCount: Int }
    struct AdminArenaParticipant: Codable, Hashable, Identifiable { var id: String; var name: String; var email: String; var result: String; var score: Double?; var correctCount: Int? }
    struct AdminArenaEvidenceFile: Codable, Hashable, Identifiable { var storedName: String; var originalName: String; var mimeType: String; var id: String { storedName } }
    struct AdminArenaAttemptEvidence: Codable, Hashable { var id: String; var status: String; var anomalyFlags: [String]; var files: [AdminArenaEvidenceFile]; var supplementalStatus: String; var supplementalDeadlineAt: String?; var supplementalFiles: [AdminArenaEvidenceFile] }
    struct AdminArenaQuestion: Codable, Hashable, Identifiable { var number: Int; var typeId: String; var prompt: String; var submittedAnswer: String; var correctAnswer: String; var solution: String; var correct: Bool; var responseTimeMs: Int?; var id: Int { number } }
    struct AdminArenaAttempt: Codable, Hashable, Identifiable {
        var id: String; var role: String; var status: String; var score: Double?; var correctCount: Int?; var currentQuestion: Int; var answeredCount: Int; var isLive: Bool; var statusLabel: String; var focusState: String; var activeSolveTimeMs: Int?; var lastHeartbeatAt: String?; var deadlineAt: String?; var submittedAt: String?; var user: AdminArenaUser?; var evidence: AdminArenaAttemptEvidence?; var questions: [AdminArenaQuestion]
    }
    struct AdminArenaLiveStats: Codable, Hashable { var total: Int; var live: Int; var waiting: Int; var stale: Int; var evidence: Int }
    struct AdminArenaLiveMatch: Codable, Hashable, Identifiable { var id: String; var division: String; var matchType: String; var status: String; var tierPairLabel: String; var stageKey: String; var stageLabel: String; var deadlineAt: String?; var deadlineOverdue: Bool; var requestedAt: String?; var startedAt: String?; var challenger: AdminArenaParticipant?; var defender: AdminArenaParticipant?; var challengerAttempt: AdminArenaAttempt?; var defenderAttempt: AdminArenaAttempt? }
    struct AdminArenaLive: Codable, Hashable { var generatedAt: String?; var refreshIntervalSeconds: Int; var truncated: Bool; var stats: AdminArenaLiveStats; var matches: [AdminArenaLiveMatch] }
    struct AdminArenaFilters: Codable, Hashable { var query: String; var dateFrom: String; var dateTo: String; var status: String; var division: String; var matchType: String; var integrityStatus: String; var participantId: String }
    struct AdminArenaHistoryMatch: Codable, Hashable, Identifiable { var id: String; var matchKey: String; var seasonKey: String; var division: String; var matchType: String; var tierPairLabel: String; var status: String; var integrityStatus: String; var winnerRole: String; var challenger: AdminArenaParticipant?; var defender: AdminArenaParticipant?; var requestedAt: String?; var startedAt: String?; var completedAt: String? }
    struct AdminArenaHistory: Codable, Hashable { var filters: AdminArenaFilters; var total: Int; var page: Int; var pageSize: Int; var totalPages: Int; var records: [AdminArenaHistoryMatch] }
    struct AdminArenaHeldMatch: Codable, Hashable, Identifiable { var id: String; var division: String; var matchType: String; var status: String; var integrityStatus: String; var tierPairLabel: String; var reviewDeadlineAt: String?; var challenger: AdminArenaUser?; var defender: AdminArenaUser?; var attempts: [AdminArenaAttempt] }
    struct AdminArenaRiskReason: Codable, Hashable, Identifiable { var label: String; var description: String; var points: Int; var id: String { "\(label):\(points)" } }
    struct AdminArenaRiskCase: Codable, Hashable, Identifiable { var id: String; var user: AdminArenaUser?; var riskScore: Int; var riskLevel: String; var status: String; var reasons: [AdminArenaRiskReason]; var linkedUsers: [AdminArenaUser]; var relatedMatchCount: Int; var createdAt: String? }
    struct AdminArenaCompletedReview: Codable, Hashable, Identifiable { var id: String; var type: String; var decision: String; var action: String; var note: String; var reviewedAt: String?; var user: AdminArenaUser?; var reviewer: AdminArenaUser?; var matchId: String; var caseId: String }
    struct AdminArenaIntegrity: Codable, Hashable { var openCount: Int; var highCount: Int; var heldCount: Int; var completedCount: Int; var heldMatches: [AdminArenaHeldMatch]; var cases: [AdminArenaRiskCase]; var completedReviews: [AdminArenaCompletedReview] }
    struct AdminArenaEvidenceEntry: Codable, Hashable, Identifiable { var id: String; var status: String; var submittedAt: String?; var user: AdminArenaUser?; var matchId: String; var attemptRole: String; var files: [AdminArenaEvidenceFile] }
    struct AdminArenaAuditSummary: Codable, Hashable { var criticalCount: Int; var warningCount: Int; var issueCount: Int; var pendingOutboxCount: Int; var checkedCycles: Int; var checkedMatches: Int; var checkedInvitations: Int; var checkedShopPurchases: Int }
    struct AdminArenaAuditScope: Codable, Hashable { var scanLimit: Int; var issueLimit: Int; var truncated: Bool }
    struct AdminArenaAuditIssue: Codable, Hashable, Identifiable { var id: String; var severity: String; var category: String; var title: String; var detail: String; var entityType: String; var entityId: String; var observedAt: String? }
    struct AdminArenaAudit: Codable, Hashable { var generatedAt: String?; var health: String; var summary: AdminArenaAuditSummary; var scope: AdminArenaAuditScope; var issues: [AdminArenaAuditIssue] }
    struct AdminArenaRankingHealth: Codable, Hashable { var generatedAt: String?; var latestCalculationAt: String?; var activeProfileCount: Int; var duplicateRankCount: Int; var missingRankCount: Int; var staleCount: Int; var pendingOutboxCount: Int; var alerts: [String]; var status: String }
    struct AdminArenaRankingHistory: Codable, Hashable, Identifiable { var id: String; var user: AdminArenaUser?; var matchId: String; var changeType: String; var occurredAt: String? }
    struct AdminArenaOperations: Codable, Hashable { var emailConfigured: Bool; var sharedSessionConfigured: Bool; var schedulerEnabled: Bool; var storageProvider: String }
    struct AdminArenaRanking: Codable, Hashable { var health: AdminArenaRankingHealth; var history: [AdminArenaRankingHistory]; var operations: AdminArenaOperations }
    struct AdminArenaDashboard: Codable, Hashable { var live: AdminArenaLive; var history: AdminArenaHistory; var integrity: AdminArenaIntegrity; var evidence: [AdminArenaEvidenceEntry]; var audit: AdminArenaAudit; var ranking: AdminArenaRanking }

    private struct AdminArenaEnvelope: Codable { var schemaVersion: String; var dashboard: AdminArenaDashboard }
    private struct AdminArenaActionEnvelope: Codable { var schemaVersion: String; var ok: Bool }

    static func adminArenaDashboard(query: [String: String] = [:]) async throws -> AdminArenaDashboard {
        let value: AdminArenaEnvelope = try await request("GET", "/api/v1/admin/arena", body: nil, authed: true, query: query)
        try validateAdminArena(value.schemaVersion); return value.dashboard
    }
    static func reviewAdminArenaMatch(id: String, decision: String, note: String) async throws { try await adminArenaAction("/api/v1/admin/arena/matches/\(id)/review", ["decision":decision,"note":note]) }
    static func requestAdminArenaEvidence(matchID: String, role: String, message: String) async throws { try await adminArenaAction("/api/v1/admin/arena/matches/\(matchID)/supplemental-evidence/\(role)/request", ["requestMessage":message]) }
    static func reviewAdminArenaCase(id: String, decision: String, note: String) async throws { try await adminArenaAction("/api/v1/admin/arena/integrity/\(id)/review", ["decision":decision,"note":note]) }
    static func rebuildAdminArenaRanking() async throws { try await adminArenaAction("/api/v1/admin/arena/ranking/rebuild", [:]) }
    static func runAdminArenaMaintenance(_ task: String) async throws { try await adminArenaAction("/api/v1/admin/arena/maintenance", ["task":task]) }
    static func downloadAdminArenaRankingCSV() async throws -> URL { try await downloadAdminArenaFile(path: "/api/v1/admin/arena/ranking.csv", name: "matths-final-ranking.csv") }
    static func downloadAdminArenaEvidence(id: String, file: AdminArenaEvidenceFile) async throws -> URL {
        let safe = file.storedName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? file.storedName
        return try await downloadAdminArenaFile(path: "/api/v1/admin/arena/evidence/\(id)/\(safe)", name: file.originalName)
    }
    private static func adminArenaAction(_ path: String, _ body: [String:Any]) async throws {
        let value: AdminArenaActionEnvelope = try await request("POST", path, body: body, authed: true)
        try validateAdminArena(value.schemaVersion); guard value.ok else { throw ServerAPIError(message:"Arena 운영 작업을 완료하지 못했습니다.",code:"ADMIN_ARENA_ACTION_FAILED") }
    }
    private static func downloadAdminArenaFile(path:String,name:String) async throws -> URL {
        let request = try authorizedRequest("GET", path, timeout: 180); let (temporary,response) = try await URLSession.shared.download(for:request); let errorBody=(try?Data(contentsOf:temporary)) ?? Data(); _ = try validateAuthorizedResponse(response,errorBody:errorBody,requestToken:bearerToken(from:request)); let directory=FileManager.default.urls(for:.cachesDirectory,in:.userDomainMask)[0].appendingPathComponent("AdminArena",isDirectory:true); try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true); let safe=name.replacingOccurrences(of:"/",with:"-"); let destination=directory.appendingPathComponent("\(UUID().uuidString)-\(safe.isEmpty ? "Arena-file":safe)"); try FileManager.default.moveItem(at:temporary,to:destination); return destination
    }
    private static func validateAdminArena(_ value:String)throws{guard value=="ADMIN_ARENA_NATIVE_V1" else{throw ServerAPIError(message:"Arena 관리자 응답 버전이 앱과 맞지 않습니다.",code:"ADMIN_ARENA_SCHEMA_UNSUPPORTED")}}
}
