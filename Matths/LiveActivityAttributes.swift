import ActivityKit
import Foundation

// Matths Live Activity 계약 — 잠금화면 배너와 다이나믹 아일랜드가 그리는 값의 정의.
//
// 이 파일은 **앱 타깃과 위젯 확장 타깃 양쪽에** 들어간다(WidgetSnapshot.swift 와 같은 방식).
// 그래서 여기에는 Foundation/ActivityKit 만 쓰고 AppStore·Tokens 같은 앱 전용 타입을
// 끌어오지 않는다. 한쪽에만 있는 타입을 쓰면 위젯 타깃이 통째로 컴파일되지 않는다.
//
// ## 왜 ContentState 에 "숫자"가 아니라 "시각"이 들어 있는가
// Live Activity 는 앱이 갱신을 밀어 줄 때만 다시 그려진다. 경과·잔여 시간을 정수 초로
// 실어 보내면 1초마다 갱신을 밀어야 하고, 그건 시스템 예산상 불가능하다.
// 대신 startedAt/endsAt 을 넘기고 SwiftUI 의 `Text(timerInterval:)` 이 스스로 세게 한다 —
// 앱이 죽어 있어도(잠금화면) 시계는 계속 돈다.
//
// ## 왜 하나의 Attributes 로 학습·아레나를 겸하는가
// 학생은 "공부 중"이거나 "경기 중"이지 둘 다는 아니다. 종류를 나눠 두 개의 Attributes 를
// 만들면 동시에 두 개가 뜨는 상태를 코드가 허용하게 되고, 다이나믹 아일랜드가 minimal 두
// 개로 쪼개져 정보가 사라진다. 종류는 상태의 한 필드로 두고, 표현만 갈라 그린다.
struct MatthsLiveActivityAttributes: ActivityAttributes {

    /// 지금 진행 중인 것이 학습 세션인지 아레나 경기인지.
    enum Kind: String, Codable, Hashable {
        /// 개념 학습·복습·연습 세트 — 경과 시간이 올라간다.
        case study
        /// GOAT Arena 경기 — 마감 시각까지 내려간다.
        case arena
    }

    struct ContentState: Codable, Hashable {
        var kind: Kind
        /// 개념명 또는 경기 이름. 한 줄로 잘리지 않을 만큼 짧게 넣는다.
        var title: String
        /// 과목명·상대 등 윗줄 보조 문구.
        var subtitle: String
        /// 세션 시작 시각. 경과 타이머의 기준.
        var startedAt: Date
        /// 아레나 제한 시각. nil 이면 카운트업(학습), 값이 있으면 카운트다운(경기).
        var endsAt: Date?
        /// 연속 학습일 — 감독이 콕 집은 값이라 모든 표현(minimal 포함)에 살아 있어야 한다.
        var streakDays: Int
        /// 이 세션을 열기 **전까지** 오늘 학습한 분. 화면에는 여기에 경과가 더해진 값을 쓴다.
        var studiedMinutesBeforeSession: Int
        /// 이 세션에서 푼 문항 수 / 전체 문항 수. total 이 0 이면 진행 막대를 감춘다.
        var solvedCount: Int
        var totalCount: Int
        /// 오늘 남은 복습 개수. 0 이면 표시하지 않는다.
        var dueReviewCount: Int
        /// 배너를 눌렀을 때 앱이 열 곳 (matths://concept/<id> · matths://review · matths://arena).
        var deepLink: String

        // MARK: 시험 D-day (감독 지시 — 잠금화면에 항상 보이는 값)
        //
        // **날짜 문자열을 넘기고 남은 일수는 그릴 때 센다.** 배너는 몇 시간씩 갱신 없이 떠
        // 있고 그 사이 자정을 넘는다. 여기에 정수 "89"를 실어 보내면 다음 날 아침에도
        // 89 라고 말한다 — 시간 표시를 Text(timerInterval:) 에 맡기는 것과 같은 이유다.

        /// "수능" 같은 짧은 이름. nil 이면 칩을 그리지 않는다(일정 미등록).
        var examLabel: String?
        /// 시험 당일 **KST yyyy-MM-dd** (MatthsExamSchedule.Event.dayKey 와 같은 값).
        var examDayKey: String?

        init(
            kind: Kind,
            title: String,
            subtitle: String,
            startedAt: Date,
            endsAt: Date? = nil,
            streakDays: Int,
            studiedMinutesBeforeSession: Int = 0,
            solvedCount: Int = 0,
            totalCount: Int = 0,
            dueReviewCount: Int = 0,
            deepLink: String = "matths://home",
            examLabel: String? = nil,
            examDayKey: String? = nil
        ) {
            self.kind = kind
            self.title = title
            self.subtitle = subtitle
            self.startedAt = startedAt
            self.endsAt = endsAt
            self.streakDays = streakDays
            self.studiedMinutesBeforeSession = studiedMinutesBeforeSession
            self.solvedCount = solvedCount
            self.totalCount = totalCount
            self.dueReviewCount = dueReviewCount
            self.deepLink = deepLink
            self.examLabel = examLabel
            self.examDayKey = examDayKey
        }
    }

    /// 세션 식별자 — 같은 세션을 두 번 띄우지 않기 위한 값(표시하지는 않는다).
    var sessionID: String
}

// MARK: - 표현이 공유하는 계산값
//
// 잠금화면·compact·expanded·minimal 이 각자 계산하면 네 곳이 서로 다른 숫자를 말하게 된다.
// 표시에 쓰는 파생값은 전부 여기 한 곳에서 만든다.
extension MatthsLiveActivityAttributes.ContentState {

    /// 타이머가 셀 구간. `Text(timerInterval:)` 은 닫힌 구간을 요구한다.
    /// 학습은 상한이 없으므로 6시간으로 자른다 — 그보다 오래 켜 두면 그건 세션이 아니라
    /// 잊고 둔 것이고, 상한 없는 구간을 넘기면 표시가 깨진다.
    var timerRange: ClosedRange<Date> {
        if let endsAt, endsAt > startedAt { return startedAt...endsAt }
        return startedAt...startedAt.addingTimeInterval(6 * 3600)
    }

    /// 경기는 남은 시간을 내려 세고, 학습은 경과를 올려 센다.
    var countsDown: Bool { endsAt != nil }

    /// 시간 칸의 제목. compact 에는 안 들어가고 expanded/잠금화면에만 붙인다.
    var timeCaption: String { countsDown ? "남은 시간" : "경과" }

    /// 문항 진행률 0...1. 문항 수를 모르는 세션(개념 읽기 등)은 nil — 막대를 감춘다.
    var progress: Double? {
        guard totalCount > 0 else { return nil }
        return min(1, max(0, Double(solvedCount) / Double(totalCount)))
    }

    var progressText: String? {
        guard totalCount > 0 else { return nil }
        return "\(min(solvedCount, totalCount))/\(totalCount) 문항"
    }

    /// 상단 눈썹 문구. 종류를 한눈에 구분하는 유일한 글자라 짧게 유지한다.
    var kindLabel: String { kind == .arena ? "경기 중" : "학습 중" }

    /// SF Symbol 이름. 아레나는 트로피, 학습은 펜.
    var kindSymbol: String { kind == .arena ? "trophy.fill" : "pencil.and.outline" }

    /// "12일" — 연속 학습 표기는 앱 홈·위젯과 같은 말로 쓴다.
    var streakText: String { "\(streakDays)일" }

    /// "수능 D-89" — 잠금화면 배너와 다이나믹 아일랜드 expanded 의 칩 문구.
    /// 일정이 없거나 이미 지난 날짜면 nil 이고, 그때는 칩 자체를 그리지 않는다.
    /// 계산은 위젯과 **같은 KST 달력**(MatthsExamClock)을 쓴다 — 잠금화면 위젯이 D-89 인데
    /// 그 아래 배너가 D-88 이면 둘 중 하나는 틀린 것이고, 학생은 둘 다 못 믿는다.
    func examDDayText(asOf now: Date = Date()) -> String? {
        guard let examLabel, !examLabel.isEmpty,
              let examDayKey,
              let days = MatthsExamClock.daysUntil(examDayKey, from: now),
              days >= 0
        else { return nil }
        return "\(examLabel) \(MatthsExamClock.ddayText(days))"
    }

    /// 오늘 학습 시간(분) — 세션 전 누계 + 지금까지 경과. 잠금화면 요약에 쓴다.
    /// 값이 1분마다 저절로 늘지는 않는다(갱신 시점의 값이다). 초 단위로 살아 움직이는 것은
    /// 타이머 칸이 맡고, 이 줄은 "오늘 얼마나 했나"의 눈금 역할만 한다.
    func todayStudyMinutes(asOf now: Date = Date()) -> Int {
        let elapsed = max(0, now.timeIntervalSince(startedAt))
        return studiedMinutesBeforeSession + Int(elapsed / 60)
    }

    func todayStudyLabel(asOf now: Date = Date()) -> String {
        let m = todayStudyMinutes(asOf: now)
        return m >= 60 ? "\(m / 60)시간 \(m % 60)분" : "\(m)분"
    }

    /// 갤러리·미리보기·자가진단이 함께 쓰는 견본. 실제 학생 기록이 아니다.
    static var studyPreview: Self {
        .init(
            kind: .study,
            title: "이차방정식의 판별식",
            subtitle: "공통수학1",
            startedAt: Date().addingTimeInterval(-12 * 60),
            streakDays: 12,
            studiedMinutesBeforeSession: 14,
            solvedCount: 3,
            totalCount: 8,
            dueReviewCount: 4,
            deepLink: "matths://home",
            // 견본의 시험일은 **오늘 기준 상대 날짜**다. 고정 날짜를 박으면 자가진단 화면이
            // 실제 수능일처럼 읽힌다(WidgetSnapshot.placeholder 와 같은 이유).
            examLabel: "수능",
            examDayKey: MatthsExamClock.dayKey(daysFromNow: 89))
    }

    static var arenaPreview: Self {
        .init(
            kind: .arena,
            title: "본선 3라운드",
            subtitle: "GOAT Arena",
            startedAt: Date().addingTimeInterval(-90),
            endsAt: Date().addingTimeInterval(7 * 60),
            streakDays: 12,
            studiedMinutesBeforeSession: 26,
            solvedCount: 2,
            totalCount: 5,
            dueReviewCount: 0,
            deepLink: "matths://arena",
            examLabel: "수능",
            examDayKey: MatthsExamClock.dayKey(daysFromNow: 89))
    }
}

extension MatthsLiveActivityAttributes {
    static var preview: Self { .init(sessionID: "preview") }
}
