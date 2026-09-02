import ActivityKit
import Foundation

// 앱 → Live Activity (잠금화면 배너 · 다이나믹 아일랜드).
//
// 위젯(WidgetBridge)과 역할이 다르다. 위젯은 "앱이 마지막으로 알던 상태"를 항상 보여 주는
// 정적인 창이고, Live Activity 는 **지금 진행 중인 한 가지 일**만 살아 있는 동안 띄운다.
// 그래서 이 컨트롤러의 불변식은 하나다: **동시에 하나만 떠 있다.**
//   - 학습하다 아레나 경기에 들어가면 학습 배너를 끝내고 경기 배너로 바꾼다.
//   - 세션이 끝나면 반드시 end 한다. 안 끝내면 잠금화면에 "학습 중"이 몇 시간 남는다.
//   - 앱을 강제 종료해도 시스템이 배너를 지우지 않는다 — 다음 실행에서 adoptOnLaunch()
//     가 남은 것을 회수해 끝낸다(그러지 않으면 어제 세션이 오늘도 떠 있다).
//
// 시작/갱신/종료는 전부 여기로만 부른다. 화면이 Activity.request 를 직접 부르면
// 두 개가 동시에 뜨고, 다이나믹 아일랜드가 minimal 두 칸으로 쪼개져 아무것도 못 읽는다.
//
// iOS 16.1+ 필요. 배포 타깃이 17.0 이라 가용성 분기는 없지만, **기기·사용자 설정으로 꺼져
// 있을 수 있다**(설정 > Matths > 실시간 현황). areActivitiesEnabled 로 매번 확인한다.
@MainActor
enum LiveActivityController {

    // MARK: 상태

    private static var activity: Activity<MatthsLiveActivityAttributes>?
    /// 마지막으로 밀어 넣은 상태. 부분 갱신(문항 진행만 바꾸기)의 기준이 된다.
    private static var lastState: MatthsLiveActivityAttributes.ContentState?

    /// 기기·사용자 설정이 Live Activity 를 허용하는가. 꺼져 있으면 조용히 아무것도 안 한다 —
    /// 학습 흐름이 이것 때문에 막히면 안 된다.
    static var isAvailable: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }

    /// 지금 배너가 떠 있는가(디버그 바·자가진단이 본다).
    static var isRunning: Bool { activity != nil }

    // MARK: 시작

    /// 학습 세션 배너를 띄운다.
    /// - Parameters:
    ///   - title: 개념명 또는 "오늘 복습 4개"
    ///   - subtitle: 과목명 또는 "오답 복습"
    ///   - streakDays: 연속 학습일 (AppStore.streakDays — 서버 계정이면 서버 값)
    ///   - todayStudyMinutes: 세션 **시작 전까지** 오늘 학습한 분 (EventLog.todayStudyMinutes)
    ///   - totalCount: 세트 문항 수. 모르면 0 — 진행 막대를 감춘다.
    @discardableResult
    static func startStudySession(
        title: String,
        subtitle: String,
        streakDays: Int,
        todayStudyMinutes: Int,
        solvedCount: Int = 0,
        totalCount: Int = 0,
        dueReviewCount: Int = 0,
        deepLink: String = "matths://home",
        startedAt: Date = Date()
    ) -> Bool {
        let exam = currentExam()
        return start(.init(
            kind: .study,
            title: title,
            subtitle: subtitle,
            startedAt: startedAt,
            endsAt: nil,
            streakDays: streakDays,
            studiedMinutesBeforeSession: max(0, todayStudyMinutes),
            solvedCount: solvedCount,
            totalCount: totalCount,
            dueReviewCount: dueReviewCount,
            deepLink: deepLink,
            examLabel: exam?.label,
            examDayKey: exam?.dayKey))
    }

    /// 아레나 경기 배너를 띄운다. endsAt 은 서버가 준 마감 시각 그대로 넘긴다 —
    /// 남은 초를 계산해 넘기면 잠금화면에서 시계가 멈춘 것처럼 보인다.
    @discardableResult
    static func startArenaMatch(
        title: String,
        subtitle: String = "GOAT Arena",
        endsAt: Date,
        streakDays: Int,
        todayStudyMinutes: Int = 0,
        solvedCount: Int = 0,
        totalCount: Int = 0,
        deepLink: String = "matths://arena",
        startedAt: Date = Date()
    ) -> Bool {
        let exam = currentExam()
        return start(.init(
            kind: .arena,
            title: title,
            subtitle: subtitle,
            startedAt: startedAt,
            endsAt: endsAt,
            streakDays: streakDays,
            studiedMinutesBeforeSession: max(0, todayStudyMinutes),
            solvedCount: solvedCount,
            totalCount: totalCount,
            dueReviewCount: 0,
            deepLink: deepLink,
            examLabel: exam?.label,
            examDayKey: exam?.dayKey))
    }

    /// 배너에 얹을 시험 D-day. 호출부(학습·경기 화면)가 일정을 몰라도 되게 여기서 붙인다 —
    /// 화면마다 카탈로그를 읽게 하면 어떤 화면은 붙이고 어떤 화면은 빠뜨린다.
    /// 수능이 카탈로그에 없으면 가장 가까운 정규 모의고사로 대신하고, 그것도 없으면 nil.
    private static func currentExam() -> (label: String, dayKey: String)? {
        let schedule = MatthsExamScheduleStore.current()
        guard let event = schedule.csat() ?? schedule.nationalMock() else { return nil }
        return (event.displayShortTitle, event.dayKey)
    }

    /// 공통 진입. 이미 떠 있으면 새로 만들지 않고 갱신한다 —
    /// request 를 겹쳐 부르면 시스템 상한(앱당 동시 개수)에 걸려 두 번째부터 조용히 실패하고,
    /// 성공해도 배너가 두 장 쌓인다.
    @discardableResult
    static func start(_ state: MatthsLiveActivityAttributes.ContentState) -> Bool {
        guard isAvailable else {
            NSLog("LIVE-ACTIVITY 사용 불가(설정에서 꺼짐) — 배너를 띄우지 않는다")
            return false
        }
        adoptRunningActivity()
        if activity != nil {
            update(state)
            return true
        }
        do {
            activity = try Activity.request(
                attributes: MatthsLiveActivityAttributes(sessionID: UUID().uuidString),
                content: ActivityContent(state: state, staleDate: staleDate(for: state)),
                pushType: nil)
            lastState = state
            NSLog("LIVE-ACTIVITY 시작 · %@ · %@", state.kind.rawValue, state.title)
            return true
        } catch {
            // 실패 이유는 대체로 "설정에서 꺼짐" 또는 "앱이 포그라운드가 아님"이다.
            // 학습을 막지 않고 로그만 남긴다.
            NSLog("LIVE-ACTIVITY 시작 실패: %@", String(describing: error))
            return false
        }
    }

    // MARK: 갱신

    /// 상태 전체 교체.
    static func update(_ state: MatthsLiveActivityAttributes.ContentState) {
        adoptRunningActivity()
        guard let activity else { return }
        lastState = state
        Task {
            await activity.update(
                ActivityContent(state: state, staleDate: staleDate(for: state)))
        }
    }

    /// 부분 갱신 — 떠 있는 배너가 없으면 아무 일도 안 한다.
    /// (호출부가 "지금 배너가 있나"를 매번 따지지 않아도 되게 한다)
    static func update(_ mutate: (inout MatthsLiveActivityAttributes.ContentState) -> Void) {
        adoptRunningActivity()
        guard activity != nil, var state = lastState else { return }
        mutate(&state)
        update(state)
    }

    /// 문항을 하나 풀었다. 진행 막대와 다이나믹 아일랜드 숫자가 같이 움직인다.
    static func advanceProgress(solvedCount: Int, totalCount: Int? = nil) {
        update { state in
            state.solvedCount = max(0, solvedCount)
            if let totalCount { state.totalCount = max(0, totalCount) }
        }
    }

    /// 연속 학습일이 올라갔다(오늘 첫 학습이 기록된 순간). 감독이 지목한 값이라
    /// 세션 도중에도 즉시 반영한다.
    static func updateStreak(_ days: Int, dueReviewCount: Int? = nil) {
        update { state in
            state.streakDays = max(0, days)
            if let dueReviewCount { state.dueReviewCount = max(0, dueReviewCount) }
        }
    }

    // MARK: 종료

    /// 세션 종료. 기본은 즉시 사라진다 — 끝난 세션이 잠금화면에 남아 있으면
    /// 학생은 아직 공부 중이라고 오해한다.
    /// `linger` 를 주면 그만큼 남겨 결과를 읽을 시간을 준다(경기 종료 직후 등).
    static func end(linger: TimeInterval = 0) {
        guard let activity else { return }
        let finalState = lastState
        self.activity = nil
        self.lastState = nil
        let policy: ActivityUIDismissalPolicy =
            linger > 0 ? .after(Date().addingTimeInterval(linger)) : .immediate
        Task {
            let content = finalState.map {
                ActivityContent(state: $0, staleDate: nil)
            }
            await activity.end(content, dismissalPolicy: policy)
        }
        NSLog("LIVE-ACTIVITY 종료")
    }

    /// 이 앱이 띄운 모든 배너를 끝낸다. 로그아웃·계정 전환처럼 "앞사람 화면이 남으면
    /// 안 되는" 순간에 쓴다(WidgetBridge.clear 와 같은 자리).
    static func endAll() {
        activity = nil
        lastState = nil
        // 목록을 **지금** 찍어 둔다. Task 안에서 다시 조회하면, 그 사이에 시작된
        // 새 배너까지 같이 끝내 버린다(로그아웃 직후 다시 로그인하는 흐름에서 실제로 겹친다).
        let running = Activity<MatthsLiveActivityAttributes>.activities
        Task {
            for one in running { await one.end(nil, dismissalPolicy: .immediate) }
        }
    }

    /// 앱 시작 직후 한 번 부른다.
    ///
    /// 지난 실행이 세션 도중에 죽었으면 배너가 그대로 살아 있다. 그 배너의 시작 시각이
    /// 오늘이 아니거나 아레나 마감이 이미 지났으면 회수해 끝낸다 — 남겨 두면 잠금화면이
    /// 어제 일을 지금 하고 있다고 말한다. 오늘 것이면 손잡이만 다시 쥔다(회수).
    static func adoptOnLaunch() {
        adoptRunningActivity()
        guard let activity, let state = lastState else { return }
        let calendar = Calendar(identifier: .gregorian)
        let expiredArena = state.endsAt.map { $0 < Date() } ?? false
        let staleStudy = !calendar.isDateInToday(state.startedAt)
        // 6시간 넘게 켜져 있는 학습 세션은 세션이 아니라 잊고 둔 것이다(timerRange 상한과 같은 값).
        let abandoned = Date().timeIntervalSince(state.startedAt) > 6 * 3600
        guard expiredArena || staleStudy || abandoned else { return }
        self.activity = nil
        self.lastState = nil
        Task { await activity.end(nil, dismissalPolicy: .immediate) }
        NSLog("LIVE-ACTIVITY 지난 실행의 배너를 회수해 종료")
    }

    // MARK: 내부

    /// 프로세스가 다시 뜬 뒤에도 시스템에는 배너가 남아 있다. 손잡이를 다시 쥔다.
    private static func adoptRunningActivity() {
        guard activity == nil,
              let running = Activity<MatthsLiveActivityAttributes>.activities.first
        else { return }
        activity = running
        lastState = running.content.state
    }

    /// 이 시각이 지나면 시스템이 내용을 "낡음"으로 표시한다(흐리게 그린다).
    /// 학습은 30분마다 갱신이 오리라 보고, 경기는 마감 시각을 그대로 쓴다.
    private static func staleDate(
        for state: MatthsLiveActivityAttributes.ContentState
    ) -> Date {
        if let endsAt = state.endsAt { return endsAt }
        return Date().addingTimeInterval(30 * 60)
    }
}
