import Foundation
import Combine
import OSLog

@MainActor
final class CurriculumAvailabilityStore: ObservableObject {
    static let shared = CurriculumAvailabilityStore()
    enum State: Equatable { case ready, refreshing, offline, authenticationRequired, failed }
    @Published private(set) var snapshot: CurriculumAvailabilitySnapshot
    @Published private(set) var state: State = .ready
    private var inFlight: Task<Void, Never>?
    private var requestID = UUID()
    private let log = Logger(subsystem: "kr.matths.app", category: "curriculum")
    private let environment: String
    private var cacheKey: String { "matths.curriculum.availability.v1." + environment }

    init(environment: String = ServerAPI.baseURL.absoluteString) {
        self.environment = environment
        var initial = CurriculumAvailabilitySnapshot.safeBaseline(environment: environment)
        let key = "matths.curriculum.availability.v1." + environment
        if let data = UserDefaults.standard.data(forKey: key),
           var cached = try? JSONDecoder().decode(CurriculumAvailabilitySnapshot.self, from: data),
           cached.isValid, cached.environment == environment {
            if (cached.availabilityPolicyRevision ?? 1) < CurriculumAvailabilitySnapshot.currentPolicyRevision {
                cached = cached.migratingLegacyDevelopmentPolicy()
            } else if cached.source != .bundledSafeBaseline {
                cached.source = .lastVerifiedCache
            }
            initial = cached
        }
        snapshot = initial
        CurriculumPolicy.apply(initial)
    }

    func refresh(force: Bool = false) async {
        if let inFlight { await inFlight.value; return }
        guard let authorization = ServerAPI.captureAuthorization() else {
            state = .authenticationRequired
            return
        }
        if !force, lastVerifiedUptime > 0,
           ProcessInfo.processInfo.systemUptime - lastVerifiedUptime < 60 { return }
        let identity = UUID()
        requestID = identity
        state = .refreshing
        let task = Task { [weak self] in
            guard let self else { return }
            do {
                let response = try await ServerAPI.getCurriculumAvailability(authorization: authorization)
                let value = try response.validated(environment: self.environment)
                guard !Task.isCancelled, self.requestID == identity,
                      ServerAPI.isCurrentAuthorization(authorization) else { return }
                self.apply(value)
                self.state = .ready
            } catch {
                guard !Task.isCancelled, self.requestID == identity else { return }
                if let api = error as? ServerAPIError, api.statusCode == 401 {
                    self.state = .authenticationRequired
                } else if let url = error as? URLError,
                          [.notConnectedToInternet, .networkConnectionLost, .timedOut].contains(url.code) {
                    self.state = .offline
                } else { self.state = .failed }
                self.log.info("availabilityLoad failed; verified snapshot retained")
            }
        }
        inFlight = task
        await task.value
        if requestID == identity { inFlight = nil }
    }

    func cancelSessionRequest() {
        requestID = UUID()
        inFlight?.cancel()
        inFlight = nil
        state = .authenticationRequired
    }

    /// A 423 invalidates earlier in-flight snapshots before publishing the denial.
    func deny(_ courseID: String) {
        cancelSessionRequest()
        var value = snapshot
        if !value.orderedCourseIDs.contains(courseID) { value.orderedCourseIDs.append(courseID) }
        value.locked[courseID] = true
        value.explicitServerDenials = Array(Set(value.explicitServerDenials ?? []).union([courseID])).sorted()
        value.availabilityPolicyRevision = CurriculumAvailabilitySnapshot.currentPolicyRevision
        value.fetchedAt = Date()
        value.source = .liveServer
        apply(value)
        state = .ready
        log.info("server423 course entry denied")
    }

    private func apply(_ incoming: CurriculumAvailabilitySnapshot) {
        let value = incoming.preservingExplicitServerDenials(from: snapshot)
        lastVerifiedUptime = ProcessInfo.processInfo.systemUptime
        CurriculumPolicy.apply(value)
        if let data = try? JSONEncoder().encode(value) { UserDefaults.standard.set(data, forKey: cacheKey) }
        // Dates do not trigger another curriculum render when only freshness changed.
        let changed = snapshot.locked != value.locked || snapshot.orderedCourseIDs != value.orderedCourseIDs
        if changed || snapshot.source != value.source { snapshot = value }
        else {
            // Keep freshness without a Published assignment.
            lastVerifiedAt = value.fetchedAt
        }
        log.info("availabilityApply verified")
    }
    private var lastVerifiedAt: Date?
    private var lastVerifiedUptime: TimeInterval = 0
}

extension ServerAPI {
    static func getCanonicalLearning(authorization: AuthorizationSnapshot) async throws -> CanonicalLearningSnapshot {
        struct Envelope: Decodable { let learning: CanonicalLearningSnapshot }
        let response: Envelope = try await request("GET", "/api/v1/learning", body: nil, authed: true, authorization: authorization)
        guard response.learning.isValid else { throw CurriculumPolicyError.malformed }
        return response.learning
    }

    static func getCurriculumAvailability(authorization: AuthorizationSnapshot) async throws -> CurriculumAvailabilityResponse {
        try await request("GET", "/api/v1/curriculum", body: nil, authed: true, authorization: authorization)
    }
}
