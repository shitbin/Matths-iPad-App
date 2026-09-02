//  EventLog.swift
//  Matths
//
//  학습 행동 이벤트 — 웹 LearningEvent 의 로컬판 (Documents/events.jsonl, append-only).
//  홈 대시보드의 주간 학습 분·정답률·전주 대비 증감이 전부 여기서 나온다.
//  서버 동기화가 붙으면 clientEventId 멱등 업로드로 이 파일을 그대로 밀어 올린다.
//
//  오늘의 학습 계획(DailyPlan)도 이 파일에 함께 둔다 — 날짜별 1문서, 체크 토글.

import Foundation

struct LearningEventV1: Codable, Sendable {
    let clientEventId: String
    let type: String            // problem-correct/problem-wrong/concept-opened/concept-closed/topic-completed/…
    let conceptId: String?
    let durationMs: Int?
    let at: Date
}

/// JSONL 인코딩과 append를 호출 actor 밖에서 한 줄로 직렬화한다.
///
/// `Task { await actor.append(...) }`를 호출마다 독립적으로 만들면 서로 다른 Task의
/// actor 도착 순서는 보장되지 않는다. 아래 submission coordinator가 슬롯별 tail을
/// 먼저 연결하고, 이 actor에는 반드시 앞 배치가 끝난 뒤 다음 배치가 들어온다.
private actor EventLogPersistence {
    static let shared = EventLogPersistence()

    /// 직전 append가 실패했으면 이벤트를 버리지 않고 다음 호출에서 앞에 붙여 재시도한다.
    /// clientEventId로 읽기 결과를 dedupe하므로, FileHandle이 일부만 쓴 뒤 실패한 경우도
    /// 대시보드에서 같은 문제를 두 번 세지 않는다.
    private var failedBatches: [String: [LearningEventV1]] = [:]
    private var invalidatedSlots: Set<String> = []

    func append(_ events: [LearningEventV1], for slot: String) -> Bool {
        guard !invalidatedSlots.contains(slot) else { return false }
        // DataScope URL 해석에는 디렉터리 검사·생성이 포함되므로 actor 안에서 한다.
        let url = DataScope.url("events.jsonl", for: slot)
        let batch = (failedBatches[slot] ?? []) + events
        guard !batch.isEmpty else { return true }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        var blob = Data()
        for event in batch {
            guard let line = try? encoder.encode(event) else {
                failedBatches[slot] = batch
                return false
            }
            blob.append(line)
            blob.append(0x0A)
        }

        let succeeded: Bool
        if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            do {
                try handle.seekToEnd()
                try handle.write(contentsOf: blob)
                succeeded = true
            } catch {
                succeeded = false
            }
        } else {
            succeeded = (try? blob.write(to: url)) != nil
        }

        if succeeded {
            failedBatches.removeValue(forKey: slot)
        } else {
            failedBatches[slot] = batch
        }
        return succeeded
    }

    func invalidate(_ slot: String) {
        invalidatedSlots.insert(slot)
        failedBatches.removeValue(forKey: slot)
    }

    func activate(_ slot: String) {
        invalidatedSlots.remove(slot)
        failedBatches.removeValue(forKey: slot)
    }
}

/// 동기 버튼 API와 비동기 writer 사이의 순서·가시성 경계.
///
/// - 호출 스레드에서는 값 배열과 URL만 붙잡고 즉시 반환한다.
/// - 슬롯별 Task tail이 모든 이벤트의 발생 순서를 보존한다(latest-wins 금지).
/// - 아직 disk ack가 오지 않은 이벤트는 `EventLog.all()`의 메모리 overlay로도 보여
///   버튼 직후 대시보드/위젯을 갱신해도 방금 기록이 사라져 보이지 않는다.
private final class EventLogSubmissionCoordinator: @unchecked Sendable {
    static let shared = EventLogSubmissionCoordinator()

    private struct Boundary {
        let id: UUID
        let task: Task<Bool, Never>
    }

    private let lock = NSLock()
    private var nextSequenceBySlot: [String: UInt64] = [:]
    private var pendingBySlot: [String: [UInt64: [LearningEventV1]]] = [:]
    private var tailsBySlot: [String: Boundary] = [:]
    private var invalidatedSlots: Set<String> = []

    func submit(_ events: [LearningEventV1], slot: String) {
        guard !events.isEmpty else { return }

        lock.lock()
        guard !invalidatedSlots.contains(slot) else {
            lock.unlock()
            return
        }
        let sequence = (nextSequenceBySlot[slot] ?? 0) &+ 1
        nextSequenceBySlot[slot] = sequence
        pendingBySlot[slot, default: [:]][sequence] = events
        let previous = tailsBySlot[slot]?.task
        let boundaryID = UUID()
        let task = Task.detached(priority: .utility) {
            _ = await previous?.value
            return await EventLogPersistence.shared.append(events, for: slot)
        }
        tailsBySlot[slot] = Boundary(id: boundaryID, task: task)
        lock.unlock()

        Task.detached(priority: .utility) { [weak self] in
            let succeeded = await task.value
            self?.complete(slot: slot, through: sequence,
                           boundaryID: boundaryID, succeeded: succeeded)
        }
    }

    func pendingEvents(for slot: String) -> [LearningEventV1] {
        lock.lock()
        defer { lock.unlock() }
        return (pendingBySlot[slot] ?? [:])
            .sorted { $0.key < $1.key }
            .flatMap(\.value)
    }

    func flush(slot: String) async -> Bool {
        while true {
            let (boundary, through) = flushBoundary(for: slot)

            guard let boundary else { return true }
            var succeeded = await boundary.task.value
            if !succeeded {
                // 실패 payload는 actor 안에 남아 있다. 빈 배치를 보내 그 payload만 재시도한다.
                succeeded = await EventLogPersistence.shared.append([], for: slot)
            }

            let isStable = finishFlush(
                slot: slot, through: through,
                boundaryID: boundary.id, succeeded: succeeded)

            if isStable { return succeeded }
        }
    }

    func invalidate(slot: String) async {
        let boundary = beginInvalidation(slot: slot)
        _ = await boundary?.task.value
        await EventLogPersistence.shared.invalidate(slot)
        finishInvalidation(slot: slot)
    }

    func activate(slot: String) async {
        await EventLogPersistence.shared.activate(slot)
        finishActivation(slot: slot)
    }

    private func finishActivation(slot: String) {
        lock.lock()
        defer { lock.unlock() }
        invalidatedSlots.remove(slot)
    }

    private func flushBoundary(for slot: String) -> (Boundary?, UInt64) {
        lock.lock()
        defer { lock.unlock() }
        return (tailsBySlot[slot], nextSequenceBySlot[slot] ?? 0)
    }

    private func beginInvalidation(slot: String) -> Boundary? {
        lock.lock()
        defer { lock.unlock() }
        invalidatedSlots.insert(slot)
        return tailsBySlot[slot]
    }

    private func finishInvalidation(slot: String) {
        lock.lock()
        defer { lock.unlock() }
        tailsBySlot.removeValue(forKey: slot)
        pendingBySlot.removeValue(forKey: slot)
    }

    private func finishFlush(slot: String, through sequence: UInt64,
                             boundaryID: UUID, succeeded: Bool) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        let isStable = tailsBySlot[slot]?.id == boundaryID
        if succeeded {
            removePendingLocked(slot: slot, through: sequence)
            if isStable { tailsBySlot.removeValue(forKey: slot) }
        }
        return isStable
    }

    private func complete(slot: String, through sequence: UInt64,
                          boundaryID: UUID, succeeded: Bool) {
        lock.lock()
        defer { lock.unlock() }
        guard succeeded else { return }
        removePendingLocked(slot: slot, through: sequence)
        if tailsBySlot[slot]?.id == boundaryID {
            tailsBySlot.removeValue(forKey: slot)
        }
    }

    private func removePendingLocked(slot: String, through sequence: UInt64) {
        guard var pending = pendingBySlot[slot] else { return }
        pending.keys.filter { $0 <= sequence }.forEach { pending.removeValue(forKey: $0) }
        if pending.isEmpty {
            pendingBySlot.removeValue(forKey: slot)
        } else {
            pendingBySlot[slot] = pending
        }
    }
}

/// 서버 `dashboardActivityService`와 같은 최근 활동 표시 계약.
///
/// 홈이 타일마다 JSONL 파일을 다시 읽지 않도록 한 번의 집계 결과에 KPI와 차트를
/// 함께 담는다. 서버 계정은 원격 스냅샷을 쓰고, 게스트·오프라인 폴백만 이 값을 쓴다.
struct EventDashboardSnapshot: Equatable {
    struct Day: Equatable {
        let dateKey: String
        let label: String
        let minutes: Int
        let isToday: Bool
    }

    let generatedAt: Date
    let weeklyStudyMinutes: Int
    let previousStudyMinutes: Int
    let weeklyStudyDetail: String
    let todayStudyMinutes: Int
    let activeStudyDays: Int
    let averageStudyMinutes: Int
    let weeklySolvedProblems: Int
    let previousSolvedProblems: Int
    let weeklySolvedDetail: String
    let correctRate: Int
    let previousCorrectRate: Int
    let correctRateDetail: String
    let days: [Day]
    let maxMinutes: Int
}

enum EventLog {
    static var fileURL: URL {
        DataScope.url("events.jsonl")
    }

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    /// append-only — 쓰기 실패는 학습 흐름을 막지 않는다 (웹과 같은 원칙)
    static func append(_ type: String, conceptId: String? = nil, durationMs: Int? = nil) {
        let event = LearningEventV1(clientEventId: UUID().uuidString, type: type,
                                    conceptId: conceptId, durationMs: durationMs, at: Date())
        submit([event])
    }

    /// 평가·기출처럼 여러 문항을 한 번에 채점할 때도 주간 풀이/정답률에 빠짐없이
    /// 넣는다. 전체 경과 시간은 문항별로 나눠 합계가 원래 값과 같게 보존한다.
    static func appendGrading(correct: Int, total: Int, durationMs: Int? = nil) {
        let safeTotal = max(0, total)
        guard safeTotal > 0 else { return }
        let safeCorrect = min(max(0, correct), safeTotal)
        let safeDuration = max(0, durationMs ?? 0)
        let perItem = safeDuration / safeTotal
        let remainder = safeDuration % safeTotal
        let now = Date()
        let events = (0..<safeTotal).map { index in
            let itemDuration = durationMs == nil ? nil : perItem + (index < remainder ? 1 : 0)
            return LearningEventV1(
                clientEventId: UUID().uuidString,
                type: index < safeCorrect ? "problem-correct" : "problem-wrong",
                conceptId: nil,
                durationMs: itemDuration,
                at: now)
        }
        // 한 평가를 한 actor 배치로 보내 문항 순서를 지키고 FileHandle open/write도 1회로 줄인다.
        submit(events)
    }

    static func all() -> [LearningEventV1] {
        let url = fileURL
        let slot = DataScope.slot
        let persisted: [LearningEventV1]
        if let data = try? Data(contentsOf: url),
           let text = String(data: data, encoding: .utf8) {
            persisted = text.split(separator: "\n").compactMap {
                try? decoder.decode(LearningEventV1.self, from: Data($0.utf8))
            }
        } else {
            persisted = []
        }

        // append 완료와 coordinator ack 사이의 짧은 경합에는 같은 id가 양쪽에 있을 수 있다.
        // 발생 순서를 유지한 채 clientEventId로 한 번만 센다.
        var seen = Set<String>()
        return (persisted + EventLogSubmissionCoordinator.shared.pendingEvents(for: slot)).filter {
            seen.insert($0.clientEventId).inserted
        }
    }

    /// background/테스트처럼 지금까지 호출된 append의 실제 disk ack가 필요한 경계.
    @discardableResult
    static func flushPendingWrites(for ownerSlot: String? = nil) async -> Bool {
        let slot = ownerSlot ?? DataScope.slot
        return await EventLogSubmissionCoordinator.shared.flush(slot: slot)
    }

    /// 탈퇴 purge 전에 owner events.jsonl의 submission gate를 먼저 닫고 tail을 drain한다.
    /// 반환 뒤에는 앞서 캡처된 append도 끝났고, 새 append는 drop되어 디렉터리를 되살리지 않는다.
    static func invalidatePendingWrites(for ownerSlot: String) async {
        await EventLogSubmissionCoordinator.shared.invalidate(slot: ownerSlot)
    }

    /// 같은 물리 슬롯을 새 계정으로 다시 쓰기로 확정한 뒤에만 호출한다.
    static func activatePendingWrites(for ownerSlot: String) async {
        await EventLogSubmissionCoordinator.shared.activate(slot: ownerSlot)
    }

    private static func submit(_ events: [LearningEventV1]) {
        let slot = DataScope.slot
        EventLogSubmissionCoordinator.shared.submit(
            events, slot: slot)
    }

    // MARK: 주간 집계 — **KST 기준 "오늘 포함 최근 7일"**
    //
    // 웹 dashboardService 는 달력 주가 아니라 최근 14일을 만들어 뒤 7일을
    // "이번 주", 앞 7일을 "지난 주"로 쓴다. 앱은 월요일 시작 달력 주를 썼다.
    // 그래서 **수요일에 웹은 최근 7일치, 앱은 월~수 3일치**를 같은 이름으로
    // 보여 줬다. 시간대도 기기 기준이라 자정 근처에서 하루가 어긋났다.
    // 여기서 KST 달력을 쓰고 창을 웹과 같게 맞춘다.

    private static var kst: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        return cal
    }

    /// 오늘(KST) 00:00 에서 `daysAgo` 일 전의 00:00
    private static func kstDayStart(daysAgo: Int, now: Date = Date()) -> Date? {
        let cal = kst
        return cal.date(byAdding: .day, value: -daysAgo, to: cal.startOfDay(for: now))
    }

    /// 웹·API와 같은 최근 14일 집계.
    ///
    /// - KST 오늘 포함 최근 7일과 그 직전 7일
    /// - 아직 오지 않은 시각의 이벤트 제외
    /// - `durationMs`를 날짜별로 합친 뒤 분 단위 반올림
    /// - 풀이 모집단은 `problem-correct`/`problem-wrong`
    ///
    /// `events` 인자는 고정 시각 회귀 테스트용이다. 생략하면 현재 슬롯의 JSONL을
    /// 정확히 한 번만 읽는다.
    static func dashboardSnapshot(
        now: Date = Date(),
        events suppliedEvents: [LearningEventV1]? = nil
    ) -> EventDashboardSnapshot {
        let calendar = kst
        let todayStart = calendar.startOfDay(for: now)
        guard let aggregateStart = calendar.date(byAdding: .day, value: -13, to: todayStart) else {
            return emptyDashboardSnapshot(now: now)
        }

        let dateKeyFormatter = DateFormatter()
        dateKeyFormatter.calendar = calendar
        dateKeyFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateKeyFormatter.timeZone = calendar.timeZone
        dateKeyFormatter.dateFormat = "yyyy-MM-dd"

        let weekdayFormatter = DateFormatter()
        weekdayFormatter.calendar = calendar
        weekdayFormatter.locale = Locale(identifier: "ko_KR")
        weekdayFormatter.timeZone = calendar.timeZone
        weekdayFormatter.dateFormat = "E"

        struct Bucket {
            var durationMs = 0
            var solvedProblems = 0
            var correctProblems = 0
        }

        var buckets: [String: Bucket] = [:]
        for event in suppliedEvents ?? all() {
            guard event.at >= aggregateStart, event.at <= now else { continue }
            let dateKey = dateKeyFormatter.string(from: event.at)
            var bucket = buckets[dateKey] ?? Bucket()
            bucket.durationMs += max(0, event.durationMs ?? 0)
            if event.type == "problem-correct" || event.type == "problem-wrong" {
                bucket.solvedProblems += 1
                if event.type == "problem-correct" {
                    bucket.correctProblems += 1
                }
            }
            buckets[dateKey] = bucket
        }

        let periods: [(date: Date, dateKey: String, minutes: Int,
                       solvedProblems: Int, correctProblems: Int)] = (0..<14).compactMap { index in
            guard let date = calendar.date(byAdding: .day, value: index, to: aggregateStart) else {
                return nil
            }
            let dateKey = dateKeyFormatter.string(from: date)
            let bucket = buckets[dateKey] ?? Bucket()
            return (
                date,
                dateKey,
                Int((Double(bucket.durationMs) / 60_000).rounded()),
                bucket.solvedProblems,
                bucket.correctProblems
            )
        }

        guard periods.count == 14 else {
            return emptyDashboardSnapshot(now: now)
        }

        let previousDays = periods.prefix(7)
        let currentDays = periods.suffix(7)
        let previousStudyMinutes = previousDays.reduce(0) { $0 + $1.minutes }
        let weeklyStudyMinutes = currentDays.reduce(0) { $0 + $1.minutes }
        let previousSolvedProblems = previousDays.reduce(0) { $0 + $1.solvedProblems }
        let weeklySolvedProblems = currentDays.reduce(0) { $0 + $1.solvedProblems }
        let previousCorrectProblems = previousDays.reduce(0) { $0 + $1.correctProblems }
        let weeklyCorrectProblems = currentDays.reduce(0) { $0 + $1.correctProblems }
        let previousCorrectRate = percentage(
            correct: previousCorrectProblems,
            total: previousSolvedProblems)
        let correctRate = percentage(
            correct: weeklyCorrectProblems,
            total: weeklySolvedProblems)
        let activeStudyDays = currentDays.filter { $0.minutes > 0 }.count
        let averageStudyMinutes = activeStudyDays == 0
            ? 0
            : Int((Double(weeklyStudyMinutes) / Double(activeStudyDays)).rounded())

        let currentArray = Array(currentDays)
        let days = currentArray.enumerated().map { index, day in
            EventDashboardSnapshot.Day(
                dateKey: day.dateKey,
                label: index == currentArray.count - 1
                    ? "오늘"
                    : weekdayFormatter.string(from: day.date),
                minutes: day.minutes,
                isToday: index == currentArray.count - 1)
        }

        return EventDashboardSnapshot(
            generatedAt: now,
            weeklyStudyMinutes: weeklyStudyMinutes,
            previousStudyMinutes: previousStudyMinutes,
            weeklyStudyDetail: deltaText(
                current: weeklyStudyMinutes, previous: previousStudyMinutes, unit: "분"),
            todayStudyMinutes: currentArray.last?.minutes ?? 0,
            activeStudyDays: activeStudyDays,
            averageStudyMinutes: averageStudyMinutes,
            weeklySolvedProblems: weeklySolvedProblems,
            previousSolvedProblems: previousSolvedProblems,
            weeklySolvedDetail: deltaText(
                current: weeklySolvedProblems, previous: previousSolvedProblems, unit: "문제"),
            correctRate: correctRate,
            previousCorrectRate: previousCorrectRate,
            correctRateDetail: deltaText(
                current: correctRate, previous: previousCorrectRate, unit: "%"),
            days: days,
            maxMinutes: max(10, days.map(\.minutes).max() ?? 0))
    }

    /// 최근 7일 각각의 학습 분. 마지막 칸이 오늘이다.
    static func minutesByWeekday(now: Date = Date()) -> [Int] {
        dashboardSnapshot(now: now).days.map(\.minutes)
    }

    /// 최근 7일 차트 라벨. 웹처럼 마지막 칸은 "오늘", 앞의 여섯 칸은 실제 요일이다.
    static func recentDayLabels(now: Date = Date()) -> [String] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = kst.timeZone
        formatter.dateFormat = "E"
        guard let start = kstDayStart(daysAgo: 6, now: now) else {
            return ["", "", "", "", "", "", "오늘"]
        }
        return (0..<7).map { index in
            guard index < 6,
                  let date = kst.date(byAdding: .day, value: index, to: start) else {
                return "오늘"
            }
            return formatter.string(from: date)
        }
    }

    /// (최근 7일, 그 직전 7일) 합계 — 분
    static func weeklyMinutes(now: Date = Date()) -> (this: Int, prev: Int) {
        let snapshot = dashboardSnapshot(now: now)
        return (snapshot.weeklyStudyMinutes, snapshot.previousStudyMinutes)
    }

    /// 오늘(KST) 학습 분 — 웹 "오늘 학습" 타일과 같은 값
    static func todayMinutes(now: Date = Date()) -> Int {
        dashboardSnapshot(now: now).todayStudyMinutes
    }

    /// 최근 7일 중 **학습한 날 수** — 웹 "학습한 날" 타일
    static func activeStudyDays(now: Date = Date()) -> Int {
        dashboardSnapshot(now: now).activeStudyDays
    }

    /// 학습한 날 기준 평균 분 — 웹 "학습일 평균" 타일
    static func averageStudyMinutes(now: Date = Date()) -> Int {
        dashboardSnapshot(now: now).averageStudyMinutes
    }

    /// "1시간 30분" 표기 — 웹 main.ejs 의 formatStudyTime 과 같은 규칙
    static func formatStudyTime(_ minutes: Int) -> String {
        let m = max(0, minutes)
        let h = m / 60, r = m % 60
        if h == 0 { return "\(r)분" }
        if r == 0 { return "\(h)시간" }
        return "\(h)시간 \(r)분"
    }

    /// (최근 7일, 그 직전 7일) 정답률 % — problem-correct / (correct+wrong). 표본 없으면 nil.
    static func weeklyAccuracy(now: Date = Date()) -> (this: Int?, prev: Int?) {
        let snapshot = dashboardSnapshot(now: now)
        return (
            snapshot.weeklySolvedProblems > 0 ? snapshot.correctRate : nil,
            snapshot.previousSolvedProblems > 0 ? snapshot.previousCorrectRate : nil
        )
    }

    /// (최근 7일, 그 직전 7일) 푼 문항 수.
    static func weeklySolved(now: Date = Date()) -> (this: Int, prev: Int) {
        let snapshot = dashboardSnapshot(now: now)
        return (snapshot.weeklySolvedProblems, snapshot.previousSolvedProblems)
    }

    private static func percentage(correct: Int, total: Int) -> Int {
        guard total > 0 else { return 0 }
        return Int((Double(max(0, correct)) / Double(total) * 100).rounded())
    }

    /// 전주 대비 증감 문구 — 부호 붙은 숫자("-3분")를 그대로 내보내지 않고
    /// 학생에게 말하듯 풀어 쓴다: 늘면 "지난주보다 3분 늘었어요",
    /// 줄면 "지난주보다 3분 적어요"(절댓값, 단위 유지).
    /// 이번 주 값이 0인데 감소를 강조하면 빈 주간에 감점부터 읽힌다 —
    /// 그 경우 빈 문자열을 돌려 줄 자체를 접는다(표시부가 빈 문구를 숨긴다).
    private static func deltaText(current: Int, previous: Int, unit: String) -> String {
        let delta = current - previous
        if delta > 0 { return "지난주보다 \(delta)\(unit) 늘었어요" }
        if delta < 0 {
            if current == 0 { return "" }
            return "지난주보다 \(abs(delta))\(unit) 적어요"
        }
        // 둘 다 0이면 "같아요" 도 빈말이다 — 줄 자체를 접는다
        if current == 0 { return "" }
        return "지난주와 같아요"
    }

    private static func emptyDashboardSnapshot(now: Date) -> EventDashboardSnapshot {
        EventDashboardSnapshot(
            generatedAt: now,
            weeklyStudyMinutes: 0,
            previousStudyMinutes: 0,
            weeklyStudyDetail: "",
            todayStudyMinutes: 0,
            activeStudyDays: 0,
            averageStudyMinutes: 0,
            weeklySolvedProblems: 0,
            previousSolvedProblems: 0,
            weeklySolvedDetail: "",
            correctRate: 0,
            previousCorrectRate: 0,
            correctRateDetail: "",
            days: [],
            maxMinutes: 10)
    }
}

// MARK: - 오늘의 학습 계획 (웹 DailyPlan)

struct DailyPlanTask: Codable, Identifiable {
    let id: String
    let kind: String        // review | concept | practice
    let title: String
    let estimatedMinutes: Int
    var done: Bool
}

struct DailyPlanV1: Codable {
    let dateKey: String
    var tasks: [DailyPlanTask]
}

enum DailyPlanStore {
    static var fileURL: URL {
        DataScope.url("dailyplan.json")
    }

    static func load(dateKey: String) -> DailyPlanV1? {
        guard let data = try? Data(contentsOf: fileURL),
              let plan = try? JSONDecoder().decode(DailyPlanV1.self, from: data),
              plan.dateKey == dateKey else { return nil }
        return plan
    }

    static func save(_ plan: DailyPlanV1) {
        if let data = try? JSONEncoder().encode(plan) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}
