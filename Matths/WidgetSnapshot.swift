import Foundation

// 홈 화면 위젯이 읽는 스냅샷.
//
// 위젯 확장은 앱과 다른 프로세스라 AppStore·EventLog 를 못 본다. 앱이 자기 상태를
// 이 구조 하나로 요약해 앱 그룹 UserDefaults 에 적어 두면, 위젯은 그것만 읽어 그린다.
// 위젯은 서버에도 붙지 않는다 — 토큰을 확장으로 넘기지 않기 위해서고(보안 원칙),
// 위젯이 그리는 것은 "앱이 마지막으로 알던 상태"면 충분하다.
//
// 이 파일은 앱 타깃과 위젯 타깃 **양쪽에** 들어간다. 그래서 여기에는 Foundation 만 쓰고
// AppStore 같은 앱 전용 타입을 끌어오지 않는다.
struct MatthsWidgetSnapshot: Codable, Equatable {
    /// 오늘의 미션 종류 — 홈 히어로의 판정(homeMission)과 같은 축이다.
    enum MissionKind: String, Codable {
        case firstConcept   // 시작 전 — 첫 개념
        case review         // 밀린 복습이 먼저
        case nextConcept    // 다음 개념 이어서
        case allDone        // 전 과목 완료
    }

    var userName: String
    var streakDays: Int
    var studiedToday: Bool

    var missionKind: MissionKind
    /// 개념명 또는 "오늘 복습 N개" 같은 미션 제목
    var missionTitle: String
    /// 과목명("공통수학1") 또는 "오답 복습" — 히어로의 작은 윗줄
    var missionEyebrow: String
    /// 주 CTA 문구 — "이어서 풀기", "복습 시작", "지금 시작하기"
    var missionCTA: String
    /// 위젯을 눌렀을 때 앱이 열 곳. matths://concept/<id> · matths://review · matths://home
    var missionURL: String

    /// 최근 7일 학습 분(마지막 칸이 오늘) — 홈의 막대와 같은 값
    var dailyMinutes: [Int]
    var weeklyStudyMinutes: Int
    var todayStudyMinutes: Int

    /// GOAT 아레나 오늘 출석 여부. 아레나 미참여면 nil.
    var arenaAttendedToday: Bool?

    // MARK: 시험 D-day (감독 지시 — "위젯·알림센터에 항상 뜨는 것")
    //
    // 아래 필드는 전부 **옵셔널**이다. 두 가지 이유다.
    //  ① 옛 스냅샷(이 필드가 없던 버전)이 앱 그룹에 남아 있어도 decodeIfPresent 로 디코딩된다.
    //     비옵셔널로 넣으면 앱을 업데이트한 학생의 위젯이 통째로 빈 화면이 된다.
    //  ② "모르는 것"과 "0"은 다르다. 로그인 전·자격 없음·서버 미응답은 nil 이고,
    //     위젯은 nil 인 칸을 **그리지 않는다**(모르는 값을 0 으로 그리면 위젯이 거짓말한다).

    /// 수능·정규 모의고사 일정. 서버가 주면 서버 것, 없으면 앱에 들어 있는 기본 카탈로그.
    /// 날짜 자체를 실어 보내고 **D-day 계산은 위젯이 그릴 때 한다** — 스냅샷에 남은 일수를
    /// 숫자로 박아 두면 앱을 안 연 날 위젯이 어제 숫자를 붙들고 있게 된다.
    var examSchedule: MatthsExamSchedule?

    /// 이번 주 주간 모의고사를 이미 봤는가. 모르면 nil(미로그인·자격 없음).
    var weeklyMockDone: Bool?
    /// 이번 주 회차 응시 마감 시각. 모르면 nil.
    var weeklyMockCloseAt: Date?
    /// 다음 회차 공개 시각. 모르면 nil.
    var weeklyMockNextReleaseAt: Date?

    /// GOAT Arena 사이클 진행일(1일차부터). 미참여면 nil.
    var arenaCycleDay: Int?
    /// 사이클 총 일수 — 서버가 알려 준 값만 쓴다. 모르면 nil 이고 "N일차"로만 적는다.
    var arenaCycleLength: Int?
    /// 아레나 방어·증거 제출 마감 시각. 걸린 마감이 없으면 nil.
    var arenaDefenseDeadline: Date?

    var updatedAt: Date

    /// 위젯 갤러리·데이터 없을 때 보여 줄 견본. 실제 계정 정보가 아니다.
    ///
    /// 시험 일정도 **견본**이다(오늘로부터 +N일로 만든다). 갤러리 미리보기에 진짜처럼
    /// 보이는 고정 날짜를 박으면, 카탈로그가 아직 비어 있는 동안 학생이 그 날짜를
    /// 실제 시험일로 읽는다. 상대 날짜는 "이런 모양으로 나온다"만 말한다.
    static var placeholder: MatthsWidgetSnapshot {
        MatthsWidgetSnapshot(
            userName: "학생",
            streakDays: 3,
            studiedToday: false,
            missionKind: .nextConcept,
            missionTitle: "이차방정식의 판별식",
            missionEyebrow: "공통수학1",
            missionCTA: "이어서 풀기",
            missionURL: "matths://home",
            dailyMinutes: [12, 0, 25, 18, 0, 30, 6],
            weeklyStudyMinutes: 91,
            todayStudyMinutes: 6,
            arenaAttendedToday: nil,
            examSchedule: .preview,
            weeklyMockDone: false,
            weeklyMockCloseAt: Date().addingTimeInterval(2 * 24 * 3600),
            weeklyMockNextReleaseAt: nil,
            arenaCycleDay: 12,
            arenaCycleLength: 29,
            arenaDefenseDeadline: nil,
            updatedAt: Date())
    }
}

// MARK: - 시험 일정
//
// ## 왜 앱에 날짜를 박지 않는가
// 수능·정규 모의고사 날짜를 소스에 하드코딩하면 **해가 바뀔 때마다 앱 심사를 다시** 받아야
// 한다. 그래서 구조는 처음부터 "서버가 덮어쓸 수 있는 카탈로그" 하나로 만든다.
//   서버 값 있음  → 그것을 쓴다 (MatthsExamScheduleStore.applyServer)
//   서버 값 없음  → 앱에 들어 있는 기본 카탈로그(MatthsExamScheduleCatalog.bundledJSON)
// 둘은 **완전히 같은 JSON 모양**이다. 서버 API 가 생기면 응답을 그대로 applyServer 에
// 넘기면 되고, 앱 쪽은 한 줄도 바뀌지 않는다.
//
// ## 왜 Bundle 리소스(.json 파일)가 아니라 문자열 상수인가
// 위젯 확장은 앱과 **다른 번들**이다. .json 을 리소스로 넣으면 앱 타깃과 위젯 타깃 양쪽의
// Copy Bundle Resources 에 각각 넣어야 하고, 그건 project.pbxproj 변경(다른 소유자)이다.
// 소스 문자열은 두 타깃이 공유하는 이 파일에 그대로 들어가므로 프로젝트 파일을 건드리지
// 않는다. 고칠 곳은 여전히 **한 곳**(bundledJSON)이라 (a) 요구도 그대로 만족한다.

/// 시험 일정 카탈로그. 서버 응답과 앱 기본값이 공유하는 하나의 모양.
struct MatthsExamSchedule: Codable, Equatable {

    struct Event: Codable, Equatable, Hashable, Identifiable {
        /// 시험 종류. 주간 모의고사·아레나는 여기 들어오지 않는다 —
        /// 그 둘은 "달력에 박힌 날짜"가 아니라 계정마다 다른 서버 상태라 스냅샷 본문이 싣는다.
        enum Kind: String, Codable {
            /// 대학수학능력시험
            case csat
            /// 정규 모의고사(교육청 전국연합·평가원 모의평가)
            case nationalMock
        }

        var id: String
        var kind: Kind
        /// "2027학년도 대학수학능력시험" — 넓은 자리(홈 medium)에서 쓴다.
        var title: String
        /// "수능", "9월 모평" — 잠금화면 한 줄에 들어갈 짧은 이름. 없으면 title 을 쓴다.
        var shortTitle: String?
        /// 시험 당일. **KST 기준 yyyy-MM-dd**.
        ///
        /// Date 가 아니라 날짜 문자열인 이유: D-day 는 시각이 아니라 날짜의 차다.
        /// Date(즉 UTC 순간)로 실어 나르면 기기 표준시대에 따라 하루가 밀린다 —
        /// 해외 체류 중인 학생의 위젯이 "D-88"을 보여 주는 일이 실제로 생긴다.
        var dayKey: String
        /// "교육청 전국연합학력평가" 같은 부연. 없어도 된다.
        var note: String?
    }

    /// "bundled" | "server". 표시에는 안 쓰고 진단용이다.
    var source: String
    var updatedAt: Date
    var events: [Event]

    static let empty = MatthsExamSchedule(source: "bundled", updatedAt: .distantPast, events: [])

    /// 지금(포함) 이후로 가장 가까운 회차. 지난 시험은 건너뛴다.
    func next(_ kind: Event.Kind, now: Date = Date()) -> Event? {
        events
            .filter { $0.kind == kind }
            .filter { (MatthsExamClock.daysUntil($0.dayKey, from: now) ?? -1) >= 0 }
            .min { lhs, rhs in lhs.dayKey < rhs.dayKey }
    }

    func csat(now: Date = Date()) -> Event? { next(.csat, now: now) }
    func nationalMock(now: Date = Date()) -> Event? { next(.nationalMock, now: now) }

    /// 갤러리 미리보기용 견본 — 오늘로부터의 **상대** 날짜다. 실제 시험일이 아니다.
    static var preview: MatthsExamSchedule {
        MatthsExamSchedule(
            source: "preview",
            updatedAt: Date(),
            events: [
                Event(id: "preview-csat",
                      kind: .csat,
                      title: "대학수학능력시험",
                      shortTitle: "수능",
                      dayKey: MatthsExamClock.dayKey(daysFromNow: 89),
                      note: "견본"),
                Event(id: "preview-mock",
                      kind: .nationalMock,
                      title: "9월 모의평가",
                      shortTitle: "9월 모평",
                      dayKey: MatthsExamClock.dayKey(daysFromNow: 12),
                      note: "견본"),
            ])
    }
}

/// 날짜 계산은 전부 여기로 모은다.
///
/// D-day 를 각 위젯이 스스로 계산하면 한 화면 안에서 잠금화면은 D-89, 홈은 D-88 이 된다
/// (기기 표준시대·자정 경계 때문에 실제로 갈라진다). **KST 달력 하나**로 통일한다 —
/// 수능은 한국에서 치는 시험이고, 학생이 어디에 있든 남은 날은 서울 기준이다.
enum MatthsExamClock {
    static let timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current

    static var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = timeZone
        c.locale = Locale(identifier: "ko_KR")
        return c
    }

    private static var dayFormatter: DateFormatter {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")   // yyyy-MM-dd 는 로케일에 흔들리면 안 된다
        f.timeZone = timeZone
        f.dateFormat = "yyyy-MM-dd"
        return f
    }

    static func dayKey(_ date: Date) -> String { dayFormatter.string(from: date) }

    static func dayKey(daysFromNow days: Int, from now: Date = Date()) -> String {
        dayKey(calendar.date(byAdding: .day, value: days, to: now) ?? now)
    }

    static func date(fromDayKey key: String) -> Date? { dayFormatter.date(from: key) }

    /// 오늘부터 그 날까지 남은 **일수**. 오늘이면 0, 이미 지났으면 음수. 형식이 틀리면 nil.
    static func daysUntil(_ dayKey: String, from now: Date = Date()) -> Int? {
        guard let target = date(fromDayKey: dayKey) else { return nil }
        let cal = calendar
        return cal.dateComponents([.day],
                                  from: cal.startOfDay(for: now),
                                  to: cal.startOfDay(for: target)).day
    }

    /// "D-89" · 당일은 "D-DAY". 한국 표기 관례를 따른다(D+ 는 쓰지 않는다 — 지난 시험은 안 그린다).
    static func ddayText(_ days: Int) -> String { days <= 0 ? "D-DAY" : "D-\(days)" }

    /// "11월 19일 (목)" — 위젯에서 시험일을 한 줄로 적을 때.
    static func dateText(_ dayKey: String) -> String? {
        guard let date = date(fromDayKey: dayKey) else { return nil }
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "ko_KR")
        f.timeZone = timeZone
        f.dateFormat = "M월 d일 (E)"
        return f.string(from: date)
    }
}

extension MatthsExamSchedule.Event {
    var displayShortTitle: String { shortTitle?.isEmpty == false ? shortTitle! : title }

    func daysRemaining(now: Date = Date()) -> Int? {
        MatthsExamClock.daysUntil(dayKey, from: now)
    }

    func ddayText(now: Date = Date()) -> String? {
        daysRemaining(now: now).map(MatthsExamClock.ddayText)
    }
}

// MARK: - 시험 일정 카탈로그 (앱 기본값)

/// ⚠️ **시험 날짜를 고치는 곳은 여기 한 곳뿐이다.**
///
/// 서버에 시험 일정 API 가 생기기 전까지의 임시 출처다. 서버가 값을 내려 주기 시작하면
/// `MatthsExamScheduleStore.applyServer(_:)` 가 이 값을 덮고, 여기는 첫 실행(서버 응답 전)
/// 화면용으로만 남는다.
enum MatthsExamScheduleCatalog {

    /// 앱에 들어 있는 기본 일정.
    ///
    /// **지금은 비어 있다.** 2027학년도 수능(2026년 11월)과 정규 모의고사 날짜를 확인된
    /// 출처 없이 채우면, 위젯이 학생에게 **틀린 D-day** 를 매일 보여 주게 된다. 그건 이
    /// 기능이 없는 것보다 나쁘다. 카탈로그가 비면 위젯은 "시험 일정 준비 중"만 그린다.
    ///
    /// 채우는 방법 — events 배열에 아래 모양으로 넣는다(그 외에는 아무것도 고치지 않는다):
    /// ```json
    /// { "id": "csat-2027",
    ///   "kind": "csat",
    ///   "title": "2027학년도 대학수학능력시험",
    ///   "shortTitle": "수능",
    ///   "dayKey": "2026-11-19",
    ///   "note": null }
    /// ```
    /// kind 는 "csat"(수능) 또는 "nationalMock"(교육청 전국연합·평가원 모의평가).
    /// dayKey 는 **KST 기준 yyyy-MM-dd**. 지난 회차는 지워도 되고 남겨도 된다(자동으로 건너뛴다).
    static let bundledJSON = """
    {
      "source": "bundled",
      "updatedAt": "1970-01-01T00:00:00Z",
      "events": []
    }
    """

    /// 카탈로그·서버 응답 공용 디코더. 두 곳이 다른 규칙을 쓰면 서버 값만 조용히 깨진다.
    static var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    static var bundled: MatthsExamSchedule {
        guard let data = bundledJSON.data(using: .utf8),
              let value = try? decoder.decode(MatthsExamSchedule.self, from: data)
        else { return .empty }
        return value
    }
}

/// 시험 일정 저장소 — 앱이 서버에서 받은 일정을 적고, 앱·위젯이 함께 읽는다.
///
/// 스냅샷과 **다른 키**에 따로 둔다. 일정은 계정 정보가 아니라 공개 달력이라,
/// 로그아웃(WidgetBridge.clear)에 지워지면 안 된다 — 로그인 화면에서도 수능 D-day 는 맞다.
enum MatthsExamScheduleStore {
    static let key = "exam.schedule.v1"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: MatthsWidgetStore.appGroupID)
    }

    /// 지금 쓸 일정 — 서버가 준 것이 있으면 그것, 없으면 앱 기본 카탈로그.
    static func current() -> MatthsExamSchedule {
        if let data = defaults?.data(forKey: key),
           let value = try? MatthsExamScheduleCatalog.decoder.decode(
            MatthsExamSchedule.self, from: data),
           !value.events.isEmpty {
            return value
        }
        return MatthsExamScheduleCatalog.bundled
    }

    /// 서버가 내려 준 일정 JSON 을 그대로 넘긴다(응답 body 의 schedule 객체).
    /// 형식이 틀리거나 비어 있으면 **저장하지 않는다** — 잘못된 값으로 기본값을 덮으면
    /// 위젯이 조용히 빈 화면이 된다.
    @discardableResult
    static func applyServer(_ data: Data) -> Bool {
        guard var value = try? MatthsExamScheduleCatalog.decoder.decode(
            MatthsExamSchedule.self, from: data),
              !value.events.isEmpty
        else { return false }
        value.source = "server"
        guard let encoded = try? JSONEncoder.matthsISO8601.encode(value) else { return false }
        defaults?.set(encoded, forKey: key)
        return true
    }

    /// 서버 값을 버리고 앱 기본 카탈로그로 되돌린다(진단·계정 초기화용).
    static func clearServerOverride() { defaults?.removeObject(forKey: key) }
}

extension JSONEncoder {
    /// applyServer 가 다시 적을 때 쓰는 인코더. 디코더(.iso8601)와 짝을 맞춘다.
    static var matthsISO8601: JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }
}

/// 앱 ↔ 위젯 공유 저장소. 앱 그룹 하나, 키 하나.
enum MatthsWidgetStore {
    /// 앱과 위젯 확장의 entitlements 에 같은 이름으로 들어 있어야 한다.
    static let appGroupID = "group.kr.matths.app"
    static let key = "widget.snapshot.v1"
    /// 위젯 종류 식별자 — WidgetCenter.reloadTimelines(ofKind:) 와 위젯 선언이 같은 값을 쓴다.
    static let widgetKind = "MatthsTodayWidget"

    static var defaults: UserDefaults? { UserDefaults(suiteName: appGroupID) }

    static func save(_ snapshot: MatthsWidgetSnapshot) {
        guard let defaults, let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: key)
    }

    static func load() -> MatthsWidgetSnapshot? {
        guard let data = defaults?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(MatthsWidgetSnapshot.self, from: data)
    }

    static func clear() {
        defaults?.removeObject(forKey: key)
    }
}
