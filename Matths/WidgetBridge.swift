import Foundation
import WidgetKit

// 앱 → 홈 화면 위젯.
//
// 위젯은 앱의 상태를 직접 못 본다. 앱이 "지금 위젯이 그려야 할 것" 을 스냅샷 하나로
// 요약해 앱 그룹에 적고 타임라인을 다시 그리게 하는 다리다. 판정 로직(오늘의 미션 =
// 시작 전 → 밀린 복습 → 다음 개념 → 완료)은 홈의 homeMission 과 같은 순서를 따른다 —
// 홈과 위젯이 다른 미션을 보여 주면 위젯이 거짓말하는 셈이라 순서를 맞춘다.
//
// ## 시험 D-day 는 왜 여기로 안 들어오는가
// 수능·정규 모의고사 날짜는 AppStore 가 모른다(서버 학사일정이 아직 없다).
// 그래서 일정 카탈로그(MatthsExamScheduleStore)를 스냅샷에 **그대로 실어** 보내고,
// 남은 일수 계산은 위젯이 그릴 때 한다. 반대로 주간 모의고사 응시 여부·아레나 사이클은
// 계정마다 다른 **서버 상태**라 그 값을 받는 화면이 ingest 로 넣어 준다(아래 MARK: 유입구).
@MainActor
enum WidgetBridge {
    /// 홈이 그리는 것과 같은 상태를 스냅샷으로 만들어 위젯에 넘긴다.
    /// 앱이 앞으로 나올 때·뒤로 갈 때·학습 기록이 바뀔 때 부른다. 값이 같으면 다시 안 그린다.
    static func publish(from store: AppStore) {
        let snapshot = makeSnapshot(from: store)
        if let previous = MatthsWidgetStore.load(), sameContent(previous, snapshot) { return }
        MatthsWidgetStore.save(snapshot)
        reloadAll()
    }

    /// 로그아웃·계정 전환 때 — 앞사람 이름과 미션이 위젯에 남지 않게 지운다.
    ///
    /// 시험 일정 카탈로그는 **지우지 않는다**. 그건 계정 정보가 아니라 공개 달력이고,
    /// 로그아웃한 기기에서도 수능 D-day 는 여전히 맞다. 계정에 딸린 값(주간 모의고사
    /// 응시 여부·아레나 사이클)은 스냅샷 안에 있으므로 이 clear 로 같이 사라진다.
    static func clear() {
        MatthsWidgetStore.clear()
        reloadAll()
    }

    /// 위젯 종류가 넷(오늘의 미션·연속 학습·이번 주 학습·시험 D-day)이라 하나만 깨우면
    /// 나머지는 낡은 값을 붙들고 있다. 종류 이름을 하나씩 나열하는 대신 전부 깨운다 —
    /// 새 종류를 추가할 때 여기를 고치는 것을 잊어도 조용히 낡지 않게.
    private static func reloadAll() {
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func makeSnapshot(from store: AppStore) -> MatthsWidgetSnapshot {
        let dashboard = EventLog.dashboardSnapshot()
        let studiedToday = store.activityDays.contains(ActivityLog.dayString())
        let next = store.progressV2.continueConcept()
        // 홈의 isPreStart 와 같은 조건(표시 소스 분기만 뺀다) — 위젯이 "지금 시작하기" 인데
        // 홈이 "이어서 풀기" 면 둘 중 하나는 거짓말이다.
        let preStart = dashboard.weeklyStudyMinutes == 0
            && dashboard.weeklySolvedProblems == 0
            && store.solvedTotal == 0
            && store.progressV2.byConcept.isEmpty
            && store.activityDays.isEmpty

        var kind: MatthsWidgetSnapshot.MissionKind
        var title: String, eyebrow: String, cta: String, url: String
        if preStart, let (course, _, concept) = next {
            kind = .firstConcept
            title = concept.title; eyebrow = course.title; cta = "지금 시작하기"
            url = "matths://concept/\(concept.id)"
        } else if store.dueReviewCount > 0 {
            kind = .review
            title = "오늘 복습 \(store.dueReviewCount)개"; eyebrow = "오답 복습"; cta = "복습 시작"
            url = "matths://review"
        } else if let (course, _, concept) = next {
            kind = .nextConcept
            title = concept.title; eyebrow = course.title; cta = "이어서 풀기"
            url = "matths://concept/\(concept.id)"
        } else {
            kind = .allDone
            title = "전 과목 완료"; eyebrow = "오늘의 미션"; cta = "홈 열기"
            url = "matths://home"
        }

        // 주간 모의고사·아레나 값은 앞선 ingest 가 적어 둔 것을 이어받는다.
        // 새 스냅샷을 만들 때마다 nil 로 리셋하면, 화면을 한 번 들어갔다 나온 뒤 앱을
        // 백그라운드로 보내는 것만으로 위젯의 그 칸이 사라진다.
        let carried = MatthsWidgetStore.load()

        return MatthsWidgetSnapshot(
            userName: store.userName,
            streakDays: store.streakDays,
            studiedToday: studiedToday,
            missionKind: kind,
            missionTitle: title,
            missionEyebrow: eyebrow,
            missionCTA: cta,
            missionURL: url,
            dailyMinutes: dashboard.days.map(\.minutes),
            weeklyStudyMinutes: dashboard.weeklyStudyMinutes,
            todayStudyMinutes: dashboard.todayStudyMinutes,
            arenaAttendedToday: nil,   // 아레나 출석은 서버 판정이라 화면이 받아 올 때만 안다 — 아직 안 싣는다
            examSchedule: MatthsExamScheduleStore.current(),
            weeklyMockDone: carried?.weeklyMockDone,
            weeklyMockCloseAt: carried?.weeklyMockCloseAt,
            weeklyMockNextReleaseAt: carried?.weeklyMockNextReleaseAt,
            arenaCycleDay: carried?.arenaCycleDay,
            arenaCycleLength: carried?.arenaCycleLength,
            arenaDefenseDeadline: carried?.arenaDefenseDeadline,
            updatedAt: Date()
        )
    }

    // MARK: - 유입구 (서버 상태를 받는 화면이 부른다)
    //
    // 주간 모의고사 대시보드와 아레나 스냅샷은 각 화면이 서버에서 받는다. AppStore 를
    // 거치지 않으므로 publish(from:) 만으로는 위젯에 닿지 않는다. 값을 받은 자리에서
    // 아래 두 함수를 부르면, **이미 저장된 스냅샷의 해당 칸만** 고쳐 쓰고 위젯을 깨운다.
    // (AppStore 를 새로 읽지 않는 이유 — 이 함수들은 화면의 async 응답 처리 안에서 불리고,
    //  거기서 스냅샷 전체를 다시 만들면 미션 판정이 화면 전환 도중 값으로 흔들린다.)

    /// 주간 모의고사 대시보드를 받았을 때.
    /// - Parameters:
    ///   - attemptedThisWeek: 이번 주 회차를 이미 봤는가(제출 완료 기준).
    ///   - closeAt / nextReleaseAt: 서버가 준 ISO8601 문자열 그대로. 파싱 실패는 nil 로 둔다.
    static func ingestWeeklyMock(attemptedThisWeek: Bool?,
                                 closeAt: String?,
                                 nextReleaseAt: String?) {
        patch { snapshot in
            snapshot.weeklyMockDone = attemptedThisWeek
            snapshot.weeklyMockCloseAt = parseISO8601(closeAt)
            snapshot.weeklyMockNextReleaseAt = parseISO8601(nextReleaseAt)
        }
    }

    /// GOAT Arena 스냅샷을 받았을 때.
    /// - Parameter defenseDeadline: 방어·증거 제출 마감. 걸린 마감이 없으면 nil 을 넘긴다
    ///   (지난 마감을 남겨 두면 위젯이 이미 끝난 경기를 재촉한다).
    static func ingestArena(cycleDay: Int?,
                            cycleLength: Int?,
                            defenseDeadline: String?) {
        patch { snapshot in
            snapshot.arenaCycleDay = cycleDay.flatMap { $0 > 0 ? $0 : nil }
            snapshot.arenaCycleLength = cycleLength.flatMap { $0 > 0 ? $0 : nil }
            let deadline = parseISO8601(defenseDeadline)
            snapshot.arenaDefenseDeadline = (deadline.map { $0 > Date() } ?? false) ? deadline : nil
        }
    }

    /// 서버가 시험 일정을 내려 주기 시작하면 응답 body 를 그대로 넘긴다.
    /// 저장에 성공했을 때만 위젯을 깨운다(형식이 틀리면 기본 카탈로그가 그대로 남는다).
    @discardableResult
    static func applyServerExamSchedule(_ data: Data) -> Bool {
        guard MatthsExamScheduleStore.applyServer(data) else { return false }
        patch { $0.examSchedule = MatthsExamScheduleStore.current() }
        return true
    }

    /// 저장된 스냅샷의 일부만 고쳐 쓴다. 아직 스냅샷이 없으면(첫 실행·로그아웃 직후)
    /// 아무것도 안 한다 — 여기서 반쪽짜리 스냅샷을 만들면 위젯이 이름도 미션도 없는
    /// 빈 카드를 그린다. 다음 publish 가 온전한 것을 적어 준다.
    private static func patch(_ mutate: (inout MatthsWidgetSnapshot) -> Void) {
        guard var snapshot = MatthsWidgetStore.load() else { return }
        let before = snapshot
        mutate(&snapshot)
        snapshot.updatedAt = Date()
        guard !sameContent(before, snapshot) else { return }
        MatthsWidgetStore.save(snapshot)
        reloadAll()
    }

    /// 서버가 주는 시각 문자열(소수점 초가 있을 때와 없을 때가 섞여 온다).
    /// LocalNotificationTime.parse 와 같은 규칙 — 한쪽만 고치면 알림과 위젯이 다른 시각을 말한다.
    static func parseISO8601(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: raw) ?? ISO8601DateFormatter().date(from: raw)
    }

    /// updatedAt 만 다른 스냅샷은 같은 것으로 본다 — 앱이 앞뒤로 오갈 때마다 위젯을 다시 그리지 않게.
    private static func sameContent(_ a: MatthsWidgetSnapshot, _ b: MatthsWidgetSnapshot) -> Bool {
        var a2 = a, b2 = b
        a2.updatedAt = .distantPast; b2.updatedAt = .distantPast
        return a2 == b2
    }

    /// 위젯(또는 외부)에서 온 matths:// URL 을 앱 화면으로 옮긴다.
    ///   matths://home · matths://review · matths://concept/<id> · matths://arena
    ///   matths://weekly-mock — 시험 D-day 위젯의 "주간 모의고사" 칸
    /// 모르는 경로는 홈으로 — 위젯이 낡은 URL 을 들고 있어도 앱이 멈추지 않게.
    static func handle(_ url: URL, store: AppStore) {
        guard url.scheme?.lowercased() == "matths" else { return }
        let host = (url.host ?? "").lowercased()
        let parts = url.pathComponents.filter { $0 != "/" }
        switch host {
        case "concept":
            if let id = parts.first, !id.isEmpty { store.openConceptV2(id) } else { store.route = .home }
        case "review":
            store.startReview()
        case "arena":
            store.route = .rank   // GOAT Arena 탭은 route 이름이 rank 다
        case "weekly-mock", "weeklymock":
            store.route = .weeklyMock
        default:
            store.route = .home
        }
    }
}
