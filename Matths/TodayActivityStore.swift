import Foundation
import Combine

/// Read-only aggregation of existing contracts. Partial failures retain only
/// that source's last snapshot and demote it to a status-check action.
@MainActor
final class TodayActivityStore: ObservableObject {
    static let shared = TodayActivityStore()
    @Published private(set) var candidates: [TodayActionCandidate] = []
    @Published private(set) var refreshing = false
    @Published private(set) var failedSources: Set<TodayActionCandidate.Source> = []
    private var slot = DataScope.slot
    private var lastRefreshUptime: TimeInterval?
    private var task: Task<Void, Never>?
    private var requestID = UUID()
    private var taskOwner: AppStore.AccountSessionBoundary?
    private var taskAuthorization: ServerAPI.AuthorizationSnapshot?
    private var taskRole: String?
    private var scopeSubscription: AnyCancellable?
    private struct AcademyRequest {
        let id: UUID
        let owner: AppStore.AccountSessionBoundary
        let authorization: ServerAPI.AuthorizationSnapshot
        let role: String
        let task: Task<ServerAPI.AcademyDashboard, Error>
    }
    private struct AcademyCache {
        let owner: AppStore.AccountSessionBoundary
        let authorization: ServerAPI.AuthorizationSnapshot
        let role: String
        let uptime: TimeInterval
        let value: ServerAPI.AcademyDashboard
    }
    private var academyTask: AcademyRequest?
    private var academyCache: AcademyCache?
    private init() {
        scopeSubscription = NotificationCenter.default.publisher(for: DataScope.didSwitchNotification)
            .sink { [weak self] _ in MainActor.assumeIsolated { self?.reset() } }
    }
    private func reset() {
        requestID = UUID()
        task?.cancel(); task = nil; taskOwner = nil; taskAuthorization = nil; taskRole = nil
        academyTask?.task.cancel(); academyTask = nil
        candidates = []; failedSources = []; refreshing = false
        slot = DataScope.slot; lastRefreshUptime = nil; academyCache = nil
    }
    func academyContext(store: AppStore, authorization: ServerAPI.AuthorizationSnapshot) async throws -> ServerAPI.AcademyDashboard {
        if slot != DataScope.slot { reset() }
        guard store.authProvider == "server", ServerAPI.isCurrentAuthorization(authorization) else { throw CancellationError() }
        let role = store.serverProfile?.role ?? "student"
        if let cache = academyCache, store.ownsCurrentAccountSession(cache.owner),
           ServerAPI.isCurrentAuthorization(cache.authorization), cache.role == role,
           (0..<60).contains(ProcessInfo.processInfo.systemUptime - cache.uptime) { return cache.value }
        academyCache = nil
        if let existing = academyTask {
            if store.ownsCurrentAccountSession(existing.owner), ServerAPI.isCurrentAuthorization(existing.authorization), existing.role == role {
                let value = try await existing.task.value
                guard !Task.isCancelled, store.ownsCurrentAccountSession(existing.owner),
                      ServerAPI.isCurrentAuthorization(existing.authorization), (store.serverProfile?.role ?? "student") == role else { throw CancellationError() }
                return value
            }
            existing.task.cancel(); academyTask = nil
        }
        let owner = store.captureAccountSessionBoundary()
        let identity = UUID()
        let pending = Task { try await ServerAPI.academyDashboard(authorization: authorization) }
        academyTask = AcademyRequest(id: identity, owner: owner, authorization: authorization, role: role, task: pending)
        defer { if academyTask?.id == identity { academyTask = nil } }
        let value = try await pending.value
        guard !Task.isCancelled, academyTask?.id == identity, store.ownsCurrentAccountSession(owner),
              ServerAPI.isCurrentAuthorization(authorization), (store.serverProfile?.role ?? "student") == role else { throw CancellationError() }
        academyCache = AcademyCache(owner: owner, authorization: authorization, role: role, uptime: ProcessInfo.processInfo.systemUptime, value: value)
        return value
    }
    func refresh(store: AppStore, force: Bool = false) async {
        if slot != DataScope.slot { reset() }
        if let taskOwner, !store.ownsCurrentAccountSession(taskOwner) { reset() }
        if let taskAuthorization, !ServerAPI.isCurrentAuthorization(taskAuthorization) { reset() }
        if let taskRole, taskRole != (store.serverProfile?.role ?? "student") { reset() }
        guard store.authProvider == "server", !["teacher", "admin"].contains(store.serverProfile?.role ?? "student"),
              let authorization = ServerAPI.captureAuthorization() else { reset(); return }
        if let task { await task.value; return }
        if !force, let lastRefreshUptime, ProcessInfo.processInfo.systemUptime - lastRefreshUptime < 60 { return }
        let owner = store.captureAccountSessionBoundary()
        let role = store.serverProfile?.role ?? "student"
        let identity = UUID(); requestID = identity
        taskOwner = owner; taskAuthorization = authorization; taskRole = role
        refreshing = true
        let pending = Task { @MainActor [weak self] in
            guard let self else { return }
            // 각 출처는 동시에 시작하지만 도착하는 즉시 자기 결과만 반영한다.
            // 한 서비스가 느리거나 실패해도 이미 확인한 평가·Arena 과업을 가리지 않는다.
            async let weekly: Void = self.refreshWeekly(identity, owner, authorization, role, store)
            async let arena: Void = self.refreshArena(identity, owner, authorization, role, store)
            async let academy: Void = self.refreshAcademy(identity, owner, authorization, role, store)
            async let assessments: Void = self.refreshAssessments(identity, owner, authorization, role, store)
            _ = await (weekly, arena, academy, assessments)
            guard self.isCurrent(identity, owner, authorization, role, store) else { return }
            self.lastRefreshUptime = ProcessInfo.processInfo.systemUptime
            self.refreshing = false
            WidgetBridge.publish(from: store)
        }
        task = pending
        await pending.value
        if requestID == identity { task = nil; refreshing = false }
    }
    private func isCurrent(_ identity: UUID, _ owner: AppStore.AccountSessionBoundary,
                           _ authorization: ServerAPI.AuthorizationSnapshot, _ role: String,
                           _ store: AppStore) -> Bool {
        !Task.isCancelled && requestID == identity && store.ownsCurrentAccountSession(owner)
            && ServerAPI.isCurrentAuthorization(authorization)
            && (store.serverProfile?.role ?? "student") == role
    }
    private func refreshWeekly(_ identity: UUID, _ owner: AppStore.AccountSessionBoundary,
                               _ authorization: ServerAPI.AuthorizationSnapshot, _ role: String,
                               _ store: AppStore) async {
        let result = await Self.result { try await Self.weekly(authorization) }
        guard isCurrent(identity, owner, authorization, role, store) else { return }
        apply(result, source: .serverWeeklyMock, project: TodayActivityProjection.weekly)
        WidgetBridge.publish(from: store)
    }
    private func refreshArena(_ identity: UUID, _ owner: AppStore.AccountSessionBoundary,
                              _ authorization: ServerAPI.AuthorizationSnapshot, _ role: String,
                              _ store: AppStore) async {
        let result = await Self.result { try await Self.arena(authorization) }
        guard isCurrent(identity, owner, authorization, role, store) else { return }
        apply(result, source: .serverArena, project: TodayActivityProjection.arena)
        WidgetBridge.publish(from: store)
    }
    private func refreshAcademy(_ identity: UUID, _ owner: AppStore.AccountSessionBoundary,
                                _ authorization: ServerAPI.AuthorizationSnapshot, _ role: String,
                                _ store: AppStore) async {
        let result = await Self.result { try await academyContext(store: store, authorization: authorization) }
        guard isCurrent(identity, owner, authorization, role, store) else { return }
        apply(result, source: .serverAcademy, project: TodayActivityProjection.academy)
        WidgetBridge.publish(from: store)
    }
    private func refreshAssessments(_ identity: UUID, _ owner: AppStore.AccountSessionBoundary,
                                    _ authorization: ServerAPI.AuthorizationSnapshot, _ role: String,
                                    _ store: AppStore) async {
        let result = await Self.result { try await ServerAPI.assessmentSnapshot(authorization: authorization) }
        guard isCurrent(identity, owner, authorization, role, store) else { return }
        apply(result, source: .serverAssessment, project: TodayActivityProjection.assessments)
        WidgetBridge.publish(from: store)
    }
    private func apply<T>(_ result: Result<T, Error>, source: TodayActionCandidate.Source,
                          project: (T, Date) -> [TodayActionCandidate]) {
        switch result {
        case .success(let value):
            candidates.removeAll { $0.source == source }
            candidates.append(contentsOf: project(value, Date()))
            failedSources.remove(source)
        case .failure:
            failedSources.insert(source)
            candidates = candidates.map { value in
                var item = value
                if item.source == source { item.freshness = .cached }
                return item
            }
        }
    }
    private static func result<T>(_ load: () async throws -> T) async -> Result<T, Error> {
        do { return .success(try await load()) } catch { return .failure(error) }
    }
    private static func weekly(_ authorization: ServerAPI.AuthorizationSnapshot) async throws -> ServerAPI.WeeklyMockDashboard {
        struct Envelope: Decodable { let weeklyMock: ServerAPI.WeeklyMockDashboard }
        let value: Envelope = try await ServerAPI.request("GET", "/api/v1/weekly-mock-exams", body: nil, authed: true, authorization: authorization)
        return value.weeklyMock
    }
    private static func arena(_ authorization: ServerAPI.AuthorizationSnapshot) async throws -> ServerAPI.GoatArenaSnapshot {
        let value: ServerAPI.GoatArenaResponse = try await ServerAPI.request("GET", "/api/v1/goat-arena", body: nil, authed: true, authorization: authorization)
        guard value.arena.readModelVersion == "GOAT_ARENA_V1" else { throw CocoaError(.coderReadCorrupt) }
        return value.arena
    }
}

enum TodayActivityProjection {
    static func assessments(_ values: [ServerAPI.RemoteAssessment], now: Date) -> [TodayActionCandidate] {
        values.compactMap { value in
            guard value.status == "in-progress", TodayActivityPolicy.isSafeServerID(value.id), let attempt = value.localValue(),
                  CurriculumPolicy.isAvailable(attempt.courseId) else { return nil }
            return .init(id: "official:" + attempt.id, kind: .timedWork, title: attempt.title,
                         reason: "진행 중으로 확인한 공식 평가입니다. 저장한 답안에서 이어가세요.",
                         action: "평가 이어 보기", minutes: nil, destination: .officialAssessment(attempt.id),
                         source: .serverAssessment, freshness: .current, fetchedAt: now,
                         deadline: attempt.serverDeadlineAt,
                         position: "\(attempt.answers.filter { !$0.isEmpty }.count) / \(attempt.questions.count)문항 입력")
        }
    }
    static func date(_ text: String?) -> Date? {
        guard let text else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: text) ?? ISO8601DateFormatter().date(from: text)
    }
    static func weekly(_ value: ServerAPI.WeeklyMockDashboard, now: Date) -> [TodayActionCandidate] {
        // The server's canEnterRoom/canStart and eligibility flags are authority;
        // date is a sorting/display hint, never a local expiry or access decision.
        var seen: Set<String> = []
        return (value.weeklyExams + [value.currentExam].compactMap { $0 }).compactMap { exam in
            guard seen.insert(exam.id).inserted, TodayActivityPolicy.isSafeServerID(exam.id),
                  exam.questionCount > 0, exam.durationMinutes > 0,
                  (0...exam.questionCount).contains(exam.answeredCount) else { return nil }
            let ongoing = exam.attemptStatus == "in_progress"
            guard TodayActivityPolicy.canOfferWeekly(status: exam.attemptStatus, eligibilityAllowed: value.eligibility.allowed, canEnterRoom: exam.canEnterRoom) else { return nil }
            return .init(id: "weekly:" + exam.id, kind: ongoing ? .timedWork : .deadline,
                         title: exam.title, reason: ongoing ? "응시 중인 주간 모의고사가 있어요. 저장한 답안에서 이어가세요." : (exam.canStart ? "지금 응시할 수 있는 주간 모의고사입니다. 시험장에 들어가 마감과 준비 사항을 확인하세요." : "대기실이 열려 있어요. 입장해서 시작 시각과 준비 사항을 확인하세요."),
                         action: ongoing ? "모의고사 이어 풀기" : (exam.canStart ? "모의고사 준비 확인" : "대기실 열기"), minutes: ongoing ? nil : exam.durationMinutes,
                         destination: .weeklyMock(exam.id), source: .serverWeeklyMock,
                         freshness: .current, fetchedAt: now, deadline: date(exam.closeAt),
                         position: ongoing ? "\(exam.answeredCount) / \(exam.questionCount)문항 입력" : "\(exam.questionCount)문항")
        }
    }
    static func academy(_ value: ServerAPI.AcademyDashboard, now: Date) -> [TodayActionCandidate] {
        var items: [TodayActionCandidate] = []
        if let attendance = value.attendance, attendance.canCheckIn, TodayActivityPolicy.isSafeServerID(attendance.session.id) {
            items.append(.init(id: "attendance:" + attendance.session.id, kind: .academy,
                               title: "학원 수업 출석 확인", reason: "학원에서 출석 확인을 받고 있어요.", action: "출석 확인", minutes: nil,
                               destination: .academyAttendance, source: .serverAcademy, freshness: .current, fetchedAt: now,
                               deadline: date(attendance.session.checkInClosesAt)))
        }
        guard value.membership?.status == "APPROVED", value.academyClass != nil else { return items }
        let serverNow = date(value.attendance?.serverNow) ?? now
        // Only the latest teaching week is a Today candidate. Archive weeks are
        // still accessible in Academy, but cannot permanently dominate Today.
        let latest = value.weeks.sorted {
            $0.academicYear == $1.academicYear ? $0.weekNumber > $1.weekNumber : $0.academicYear > $1.academicYear
        }.prefix(1)
        for week in latest {
            guard TodayActivityPolicy.isSafeServerID(week.id), !week.assignmentTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  let due = date(week.dueAt) else { continue }
            // No assignment submission/completion state exists in this contract.
            // Never label these assignments 'unsubmitted' or invent a submit CTA.
            let closeInPresentation = due >= serverNow && due.timeIntervalSince(serverNow) <= 48 * 3600
            items.append(.init(id: "academy:" + week.id, kind: closeInPresentation ? .deadline : .assessment,
                               title: week.assignmentTitle, reason: "\(week.title)의 과제 안내와 마감을 확인하세요.",
                               action: "과제 안내 보기", minutes: nil, destination: .academyWeek(week.id),
                               source: .serverAcademy, freshness: .current, fetchedAt: now, deadline: due,
                               position: "제출 여부는 학원에서 확인"))
        }
        return items
    }
    static func arena(_ value: ServerAPI.GoatArenaSnapshot, now: Date) -> [TodayActionCandidate] {
        guard let match = value.activeMatch, let id = match.id, TodayActivityPolicy.isSafeServerID(id),
              TodayActivityPolicy.canOfferArena(matchStatus: match.status, attemptStatus: match.attempt?.status,
                                               integrity: match.integrityState, actions: match.availableActions) else { return [] }
        let actions = Set(match.availableActions ?? [])
        let evidence = actions.contains("SUBMIT_EVIDENCE") || match.attempt?.status == "EVIDENCE_REQUIRED"
        let canStart = actions.contains("START") || match.attempt?.status == "READY"
            || (match.attempt == nil && ["MATCHED", "READY"].contains(match.status))
        let defender = match.role == "DEFENDER"
        let title: String
        let reason: String
        let action: String
        let kind: TodayActionCandidate.Kind
        if evidence {
            title = "Arena 풀이 증거 제출 필요"
            reason = "경기 결과 확인에 필요한 풀이 증거가 남아 있어요. 서버가 안내한 항목과 기한을 확인하세요."
            action = "풀이 증거 제출"
            kind = .deadline
        } else if canStart && defender {
            title = "받은 Arena 공격 확인"
            reason = "대응해야 할 방어전이 있어요. 상대와 시작 기한을 확인하고 준비하세요."
            action = "방어전 확인"
            kind = .timedWork
        } else {
            title = defender ? "진행 중인 Arena 방어전" : "진행 중인 Arena 경기"
            reason = "아직 제출하지 않은 내 경기가 있어요. 경기 상태를 확인하고 이어가세요."
            action = defender ? "방어전 이어 보기" : "경기 이어 보기"
            kind = .timedWork
        }
        return [.init(id: "arena:" + id, kind: kind, title: title,
                      reason: reason, action: action, minutes: nil,
                      destination: .arena(id), source: .serverArena,
                      freshness: .current, fetchedAt: now,
                      deadline: date(match.attempt?.evidenceDeadlineAt ?? match.attempt?.endsAt ?? match.submitsBy ?? match.startsBy),
                      position: defender ? "내 역할 · 방어" : "내 역할 · 공격")]
    }
}
