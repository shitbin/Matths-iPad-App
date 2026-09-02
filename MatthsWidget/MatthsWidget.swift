import SwiftUI
import WidgetKit

// Matths 홈 화면·잠금화면 위젯 묶음.
//
// 홈 화면과 같은 판정(시작 전 → 밀린 복습 → 다음 개념 → 완료)으로 앱이 적어 둔 스냅샷을
// 읽어 그린다. 위젯은 서버·앱 상태를 직접 보지 않는다(WidgetSnapshot.swift 주석).
//
// 갤러리에 서는 종류는 넷이다 — 감독이 쓰임새대로 골라 놓을 수 있게 나눴다.
//   ① 오늘의 미션 (MatthsTodayWidget)   small / medium / large
//   ② 연속 학습   (MatthsStreakWidget)  systemSmall / 잠금화면 원형·직사각형·인라인
//   ③ 이번 주 학습 (MatthsWeeklyWidget) small / medium
//   ④ 시험 D-day  (MatthsExamDDayWidget) small / medium / 잠금화면 원형·직사각형·인라인
// 여기에 Live Activity(MatthsLiveActivity.swift)가 더해져 잠금화면·다이나믹 아일랜드를 맡는다.
//
// ## 시험 D-day 를 어디에 두었나 (감독 지시: "어디에 넣을지 정해라")
// 상시 표시의 값어치는 **눈에 닿는 빈도 × 한 번에 읽히는 정도**다. 잠금화면은 하루에
// 수십 번 켜지고 홈 위젯은 앱을 열 때마다 지나친다. 그래서 이렇게 갈랐다.
//   · 잠금화면 원형    — 수능 D-day 하나. 잠금 해제 전에 0.3초 안에 읽히는 유일한 자리.
//   · 잠금화면 직사각형 — 수능 D-day + 시험일 + 다음 정규 모의고사. 가장 정보량이 큰 잠금화면 칸.
//   · 잠금화면 인라인   — 시계 밑 한 줄. "수능 D-89 · 9월 모평 D-12".
//   · 홈 small        — 수능 숫자 하나를 크게 + 시험일.
//   · 홈 medium       — 수능 + 정규 모의고사 + 주간 모의고사 + 아레나 사이클 네 줄 전부.
//   · 오늘의 미션 large — 맨 윗줄에 수능 D-day 띠 하나. (미션 위젯의 주인공은 미션이므로 띠까지만)
//   · Live Activity   — 잠금화면 배너와 다이나믹 아일랜드 expanded 에 "수능 D-89" 칩.
//     다이나믹 아일랜드 compact/minimal 에는 **넣지 않는다** — 폭이 없다
//     (MatthsLiveActivity.swift 머리말의 잘림 규칙 ①·④).
//
// 색은 CI 4색을 그대로 쓴다(DesignTokens.swift 의 brandMagenta/Violet/Blue/Cyan 와 같은 값).
// 앱 타깃의 Tokens 를 못 끌어와서(확장은 별도 모듈) 여기 값으로 둔다 — 바꾸면 양쪽을 같이.
// (private 이 아니라 internal 인 이유: MatthsLiveActivity.swift 가 같은 값을 써야 한다.
//  거기서 색을 다시 적으면 브랜드 색이 두 벌이 되고 언젠가 갈라진다.)

enum WColor {
    static let magenta = Color(red: 0xCA / 255, green: 0x44 / 255, blue: 0xE3 / 255)
    static let violet  = Color(red: 0x7B / 255, green: 0x4E / 255, blue: 0xFC / 255)
    static let blue    = Color(red: 0x32 / 255, green: 0x7F / 255, blue: 0xFA / 255)
    static let cyan    = Color(red: 0x0C / 255, green: 0xDC / 255, blue: 0xF1 / 255)
    static let navy    = Color(red: 0x09 / 255, green: 0x0C / 255, blue: 0x1B / 255)
    static let canvas  = Color(red: 0xF3 / 255, green: 0xF6 / 255, blue: 0xFF / 255)
}

struct MatthsEntry: TimelineEntry {
    let date: Date
    let snapshot: MatthsWidgetSnapshot
    /// 앱이 아직 한 번도 스냅샷을 적지 않았다(첫 설치·로그아웃 직후). 견본이 아니라 안내를 그린다.
    let isEmpty: Bool

    /// 실제로 그릴 스냅샷.
    ///
    /// isEmpty 일 때 snapshot 은 **갤러리 견본**이다(MatthsProvider.current). 견본의 시험 일정은
    /// "오늘+89일" 같은 상대 날짜라, 그대로 홈 화면에 나가면 학생이 그 날짜를 진짜 수능일로 읽는다.
    /// 그래서 견본을 쓰되 **시험 일정만 실제 카탈로그로 갈아 끼우고**(앱을 한 번도 안 열어도
    /// 수능 D-day 는 맞아야 한다 — 일정은 계정 정보가 아니다), 계정에 딸린 값(주간 모의고사·
    /// 아레나)은 모른다고 표시한다.
    var displaySnapshot: MatthsWidgetSnapshot {
        guard isEmpty else { return snapshot }
        var value = snapshot
        value.examSchedule = MatthsExamScheduleStore.current()
        value.weeklyMockDone = nil
        value.weeklyMockCloseAt = nil
        value.weeklyMockNextReleaseAt = nil
        value.arenaCycleDay = nil
        value.arenaCycleLength = nil
        value.arenaDefenseDeadline = nil
        return value
    }
}

struct MatthsProvider: TimelineProvider {
    /// 스스로 다시 그릴 간격. nil 이면 자정 직후 한 번만.
    ///
    /// 앱은 지금 `reloadTimelines(ofKind: "MatthsTodayWidget")` 하나만 부른다
    /// (WidgetBridge.swift:18 — 이 작업의 소유 밖 파일). 그래서 새로 추가한 종류들은
    /// 앱이 깨워 주지 않는다. 그동안 낡은 값을 붙들고 있지 않도록 스스로 한 시간에 한 번
    /// 다시 읽는다. WidgetBridge 가 reloadAllTimelines() 로 바뀌면 이 값은 nil 로 되돌려도 된다.
    let interval: TimeInterval?

    init(interval: TimeInterval? = nil) { self.interval = interval }

    func placeholder(in context: Context) -> MatthsEntry {
        MatthsEntry(date: Date(), snapshot: .placeholder, isEmpty: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (MatthsEntry) -> Void) {
        // 갤러리 미리보기는 견본, 실제 배치는 저장된 스냅샷
        if context.isPreview {
            completion(MatthsEntry(date: Date(), snapshot: .placeholder, isEmpty: false))
        } else {
            completion(current())
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MatthsEntry>) -> Void) {
        // 앱이 스냅샷을 새로 적을 때마다 reloadTimelines 로 다시 그린다.
        // 그래도 날짜가 바뀌면 "오늘 학습" 판정이 낡으니 자정 직후 한 번은 스스로 갱신한다.
        let entry = current()
        let cal = Calendar(identifier: .gregorian)
        let midnight = cal.startOfDay(for: Date()).addingTimeInterval(24 * 3600 + 60)
        let next = interval.map { Date().addingTimeInterval($0) } ?? midnight
        completion(Timeline(entries: [entry], policy: .after(min(next, midnight))))
    }

    private func current() -> MatthsEntry {
        if let saved = MatthsWidgetStore.load() {
            // 스냅샷은 앱이 마지막으로 연 시각의 것이다. 날짜가 넘어갔으면 "오늘 학습 완료" 는
            // 이미 어제 이야기 — 그 표시만 접는다(다른 값은 그대로 두는 편이 덜 틀린다).
            var snap = saved
            let cal = Calendar(identifier: .gregorian)
            if !cal.isDateInToday(saved.updatedAt) { snap.studiedToday = false; snap.todayStudyMinutes = 0 }
            return MatthsEntry(date: Date(), snapshot: snap, isEmpty: false)
        }
        return MatthsEntry(date: Date(), snapshot: .placeholder, isEmpty: true)
    }
}

// MARK: - 스냅샷에서 읽어 내는 파생값
//
// 여러 위젯이 같은 계산을 각자 하면 같은 화면에서 다른 숫자가 나온다. 한 곳에 모은다.
extension MatthsWidgetSnapshot {
    /// 최근 7일 학습 분(마지막 칸이 오늘). 데이터가 모자라면 0 으로 채운다.
    var lastSevenDays: [Int] {
        let tail = Array(dailyMinutes.suffix(7))
        return Array(repeating: 0, count: max(0, 7 - tail.count)) + tail
    }

    /// 이번 주 실제로 공부한 날 수 — 잠금화면 게이지와 큰 위젯 요약이 쓴다.
    var studyDaysThisWeek: Int { lastSevenDays.filter { $0 > 0 }.count }

    /// 복습 대기 수.
    ///
    /// 스냅샷에 전용 필드가 아직 없다(WidgetSnapshot.swift 는 이 작업의 소유 밖).
    /// 미션 판정이 복습일 때 제목이 "오늘 복습 N개" 라는 앱 규약(WidgetBridge.swift:47)에
    /// 기대어 숫자만 읽어 온다. 스냅샷에 dueReviewCount 가 생기면 이 계산은 지운다.
    var derivedDueReviewCount: Int {
        guard missionKind == .review else { return 0 }
        return Int(missionTitle.filter(\.isNumber)) ?? 0
    }
}

/// 최근 7일의 한 글자 요일(마지막이 오늘) — 큰 위젯의 막대 아래 라벨.
private func recentWeekdayInitials(count: Int = 7, now: Date = Date()) -> [String] {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.dateFormat = "EEEEE"
    let calendar = Calendar(identifier: .gregorian)
    return (0..<count).reversed().map { offset in
        let day = calendar.date(byAdding: .day, value: -offset, to: now) ?? now
        return formatter.string(from: day)
    }
}

private func minutesLabel(_ m: Int) -> String {
    m >= 60 ? "\(m / 60)시간 \(m % 60)분" : "\(m)분"
}

// MARK: - 오늘의 미션 (small / medium / large)

struct MatthsWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var scheme
    let entry: MatthsEntry

    var body: some View {
        Group {
            switch family {
            case .systemSmall: small
            case .systemMedium: medium
            case .systemLarge: large
            default: small
            }
        }
        .widgetURL(URL(string: entry.isEmpty ? "matths://home" : entry.snapshot.missionURL))
    }

    private var s: MatthsWidgetSnapshot { entry.snapshot }
    private var ink: Color { scheme == .dark ? .white : WColor.navy }
    private var muted: Color { ink.opacity(0.62) }

    // 불꽃 + 일수 — 홈 상단의 스트릭과 같은 표기
    private var streakRow: some View {
        HStack(spacing: 4) {
            Image(systemName: s.studiedToday ? "flame.fill" : "flame")
                .foregroundStyle(s.studiedToday ? WColor.magenta : muted)
            Text("\(s.streakDays)")
                .font(.system(.title3, design: .rounded, weight: .heavy))
                .monospacedDigit()
                .foregroundStyle(ink)
            Text("일 연속").font(.caption2).foregroundStyle(muted)
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                streakRow
                Spacer()
                Image("WidgetMark").resizable().scaledToFit().frame(width: 18, height: 18)
                    .opacity(0.9)
            }
            Spacer(minLength: 2)
            if entry.isEmpty {
                Text("앱을 한 번 열면\n오늘의 미션이 여기 뜹니다")
                    .font(.caption).foregroundStyle(muted)
            } else {
                Text(s.missionEyebrow).font(.caption2).foregroundStyle(muted).lineLimit(1)
                Text(s.missionTitle)
                    .font(.system(.subheadline, weight: .bold)).foregroundStyle(ink)
                    .lineLimit(2).minimumScaleFactor(0.85)
                Text(s.studiedToday ? "오늘 학습 완료" : s.missionCTA)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(s.studiedToday ? WColor.cyan : WColor.violet)
            }
        }
        .padding(2)
    }

    private var medium: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                streakRow
                Spacer(minLength: 2)
                if entry.isEmpty {
                    Text("앱을 한 번 열면 오늘의 미션이 여기 뜹니다")
                        .font(.caption).foregroundStyle(muted)
                } else {
                    Text("오늘의 미션 · \(s.missionEyebrow)").font(.caption2).foregroundStyle(muted).lineLimit(1)
                    Text(s.missionTitle)
                        .font(.system(.headline, weight: .bold)).foregroundStyle(ink)
                        .lineLimit(2).minimumScaleFactor(0.85)
                    Text(s.missionCTA)
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(WColor.violet, in: Capsule())
                        .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                Text("이번 주 학습").font(.caption2).foregroundStyle(muted)
                Text(minutesLabel(s.weeklyStudyMinutes))
                    .font(.system(.title3, design: .rounded, weight: .heavy)).monospacedDigit()
                    .foregroundStyle(ink)
                WeeklyBars(minutes: s.lastSevenDays, height: 34, showsLabels: false, ink: ink)
            }
            .frame(width: 118)
        }
        .padding(2)
    }

    /// 큰 위젯 — 감독 지시("주간 학습 + 오늘의 미션 + 복습 대기 수를 함께").
    /// 세 덩어리를 위에서 아래로 쌓고, 맨 아래에 숫자 세 칸을 둔다.
    /// 맨 윗줄에는 수능 D-day 띠 하나를 얹는다 — 이 위젯의 주인공은 여전히 미션이라 띠까지만.
    private var large: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image("WidgetMark").resizable().scaledToFit().frame(width: 22, height: 22)
                Text("오늘의 미션")
                    .font(.system(.subheadline, weight: .bold)).foregroundStyle(ink)
                Spacer()
                streakRow
            }

            // 일정이 아직 없으면 띠 자체를 그리지 않는다 — 빈 칸을 남겨 두면
            // "여기 뭔가 있어야 하는데 고장 났나"로 읽힌다.
            if let row = entry.displaySnapshot.csatRow(now: entry.date) {
                ExamDDayStrip(row: row, ink: ink, muted: muted)
            }

            missionCard

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text("이번 주 학습").font(.caption).foregroundStyle(muted)
                    Spacer()
                    Text(minutesLabel(s.weeklyStudyMinutes))
                        .font(.system(.title3, design: .rounded, weight: .heavy))
                        .monospacedDigit().foregroundStyle(ink)
                }
                WeeklyBars(minutes: s.lastSevenDays, height: 56, showsLabels: true, ink: ink)
            }

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                StatTile(title: "오늘 학습",
                         value: minutesLabel(s.todayStudyMinutes),
                         tint: WColor.blue, ink: ink, muted: muted)
                StatTile(title: "복습 대기",
                         value: s.derivedDueReviewCount > 0 ? "\(s.derivedDueReviewCount)개" : "없음",
                         tint: WColor.magenta, ink: ink, muted: muted)
                StatTile(title: "학습한 날",
                         value: "\(s.studyDaysThisWeek)/7",
                         tint: WColor.cyan, ink: ink, muted: muted)
            }
        }
        .padding(4)
    }

    private var missionCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            if entry.isEmpty {
                Text("앱을 한 번 열면 오늘의 미션이 여기 뜹니다")
                    .font(.subheadline).foregroundStyle(muted)
            } else {
                Text(s.missionEyebrow).font(.caption2).foregroundStyle(muted).lineLimit(1)
                Text(s.missionTitle)
                    .font(.system(.title3, weight: .heavy)).foregroundStyle(ink)
                    .lineLimit(2).minimumScaleFactor(0.8)
                Text(s.studiedToday ? "오늘 학습 완료 · \(s.missionCTA)" : s.missionCTA)
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(s.studiedToday ? WColor.cyan : WColor.violet, in: Capsule())
                    .foregroundStyle(s.studiedToday ? WColor.navy : .white)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(WColor.violet.opacity(scheme == .dark ? 0.22 : 0.10)))
    }
}

/// 최근 7일 막대 — 홈의 차트와 같은 값(마지막 칸이 오늘). 최댓값 기준 상대 높이.
private struct WeeklyBars: View {
    let minutes: [Int]
    let height: CGFloat
    let showsLabels: Bool
    let ink: Color

    var body: some View {
        let maxV = max(minutes.max() ?? 0, 1)
        let labels = showsLabels ? recentWeekdayInitials(count: minutes.count) : []
        VStack(spacing: 4) {
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(Array(minutes.enumerated()), id: \.offset) { i, m in
                    let isToday = i == minutes.count - 1
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(isToday ? WColor.blue : WColor.blue.opacity(0.35))
                        .frame(height: max(4, height * CGFloat(m) / CGFloat(maxV)))
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: height + 2, alignment: .bottom)

            if showsLabels {
                HStack(spacing: 4) {
                    ForEach(Array(labels.enumerated()), id: \.offset) { i, label in
                        Text(label)
                            .font(.system(size: 10, weight: i == labels.count - 1 ? .bold : .regular))
                            .foregroundStyle(ink.opacity(i == labels.count - 1 ? 0.9 : 0.5))
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }
}

private struct StatTile: View {
    let title: String
    let value: String
    let tint: Color
    let ink: Color
    let muted: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.system(size: 10)).foregroundStyle(muted).lineLimit(1)
            Text(value)
                .font(.system(.subheadline, design: .rounded, weight: .heavy))
                .monospacedDigit().foregroundStyle(ink)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 9).padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous).fill(tint.opacity(0.16)))
    }
}

struct MatthsTodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: MatthsWidgetStore.widgetKind, provider: MatthsProvider()) { entry in
            MatthsWidgetEntryView(entry: entry)
                // 라이트 = 앱 캔버스색, 다크 = 로고 원판의 근검정(브랜드 네이비)
                .containerBackground(for: .widget) { WidgetGround() }
        }
        .configurationDisplayName("오늘의 미션")
        .description("연속 학습과 오늘 할 것, 이번 주 학습 시간을 보여 줍니다.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - 연속 학습 (잠금화면 중심)

/// 잠금화면에서 **쓸모 있어야 한다**는 것이 이 위젯의 요구사항이다(감독 지시).
/// 그래서 잠금화면에서 답해야 하는 두 가지만 담는다 — "며칠째인가", "오늘 했는가".
struct MatthsStreakEntryView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var scheme
    let entry: MatthsEntry

    private var s: MatthsWidgetSnapshot { entry.snapshot }
    private var ink: Color { scheme == .dark ? .white : WColor.navy }
    private var muted: Color { ink.opacity(0.62) }
    private var flame: String { s.studiedToday ? "flame.fill" : "flame" }

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular: circular
            case .accessoryRectangular: rectangular
            case .accessoryInline: inline
            default: small
            }
        }
        .widgetURL(URL(string: entry.isEmpty ? "matths://home" : entry.snapshot.missionURL))
    }

    /// 원형 — 가운데 연속 일수, 링은 이번 주 학습한 날(0~7).
    /// 잠금화면 액세서리는 시스템이 단색으로 렌더한다. 색이 아니라 **모양**으로 읽히게 만든다.
    private var circular: some View {
        Gauge(value: Double(s.studyDaysThisWeek), in: 0...7) {
            Image(systemName: flame)
        } currentValueLabel: {
            Text("\(s.streakDays)")
                .font(.system(.body, design: .rounded, weight: .heavy))
                .monospacedDigit()
        }
        .gaugeStyle(.accessoryCircular)
        .accessibilityLabel("연속 학습 \(s.streakDays)일, 이번 주 \(s.studyDaysThisWeek)일 학습")
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: flame)
                Text("\(s.streakDays)일 연속").font(.headline)
            }
            Text(entry.isEmpty ? "앱을 열어 미션 받기" : s.missionTitle)
                .font(.caption).lineLimit(1)
            Text(entry.isEmpty
                 ? ""
                 : "오늘 \(minutesLabel(s.todayStudyMinutes)) · 이번 주 \(s.studyDaysThisWeek)일")
                .font(.caption2).opacity(0.8).lineLimit(1)
        }
    }

    /// 인라인은 시계 밑 한 줄이다. 한 문장만 들어간다 — 가장 중요한 것만.
    private var inline: some View {
        Label(
            s.studiedToday
                ? "\(s.streakDays)일 연속 · 오늘 \(minutesLabel(s.todayStudyMinutes))"
                : "\(s.streakDays)일 연속 · 오늘 아직",
            systemImage: flame)
    }

    /// 홈 화면 작은 크기 — 숫자 하나를 크게. 아래에 이번 주 7칸 점.
    private var small: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: flame)
                    .foregroundStyle(s.studiedToday ? WColor.magenta : muted)
                Text("연속 학습").font(.caption2).foregroundStyle(muted)
                Spacer()
            }
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(s.streakDays)")
                    .font(.system(size: 46, weight: .heavy, design: .rounded))
                    .monospacedDigit().foregroundStyle(ink)
                    .minimumScaleFactor(0.6).lineLimit(1)
                Text("일").font(.headline).foregroundStyle(muted)
            }
            Spacer(minLength: 0)
            HStack(spacing: 4) {
                ForEach(Array(s.lastSevenDays.enumerated()), id: \.offset) { i, m in
                    Circle()
                        .fill(m > 0 ? WColor.cyan : ink.opacity(0.15))
                        .frame(height: 8)
                        .overlay {
                            if i == s.lastSevenDays.count - 1 {
                                Circle().stroke(WColor.violet, lineWidth: 1.5)
                            }
                        }
                }
            }
            Text(s.studiedToday ? "오늘 학습 완료" : s.missionCTA)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(s.studiedToday ? WColor.cyan : WColor.violet)
                .lineLimit(1)
        }
        .padding(2)
    }
}

struct MatthsStreakWidget: Widget {
    static let kind = "MatthsStreakWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: Self.kind,
            provider: MatthsProvider(interval: 3600)
        ) { entry in
            MatthsStreakEntryView(entry: entry)
                .containerBackground(for: .widget) { WidgetGround() }
        }
        .configurationDisplayName("연속 학습")
        .description("며칠째 이어 왔는지와 오늘 학습 여부를 잠금화면에서 바로 봅니다.")
        .supportedFamilies([
            .systemSmall, .accessoryCircular, .accessoryRectangular, .accessoryInline,
        ])
    }
}

// MARK: - 이번 주 학습

struct MatthsWeeklyEntryView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var scheme
    let entry: MatthsEntry

    private var s: MatthsWidgetSnapshot { entry.snapshot }
    private var ink: Color { scheme == .dark ? .white : WColor.navy }
    private var muted: Color { ink.opacity(0.62) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("이번 주 학습").font(.caption2).foregroundStyle(muted)
                Spacer()
                if family != .systemSmall {
                    Text("\(s.studyDaysThisWeek)/7일")
                        .font(.caption2).foregroundStyle(muted).monospacedDigit()
                }
            }
            Text(minutesLabel(s.weeklyStudyMinutes))
                .font(.system(family == .systemSmall ? .title3 : .title2,
                              design: .rounded, weight: .heavy))
                .monospacedDigit().foregroundStyle(ink)
                .lineLimit(1).minimumScaleFactor(0.7)
            WeeklyBars(
                minutes: s.lastSevenDays,
                height: family == .systemSmall ? 40 : 52,
                showsLabels: true,
                ink: ink)
            if family != .systemSmall {
                HStack(spacing: 8) {
                    StatTile(title: "오늘", value: minutesLabel(s.todayStudyMinutes),
                             tint: WColor.blue, ink: ink, muted: muted)
                    StatTile(title: "연속 학습", value: "\(s.streakDays)일",
                             tint: WColor.magenta, ink: ink, muted: muted)
                    StatTile(
                        title: "복습 대기",
                        value: s.derivedDueReviewCount > 0 ? "\(s.derivedDueReviewCount)개" : "없음",
                        tint: WColor.cyan, ink: ink, muted: muted)
                }
            }
        }
        .padding(2)
        .widgetURL(URL(string: "matths://home"))
    }
}

struct MatthsWeeklyWidget: Widget {
    static let kind = "MatthsWeeklyWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: Self.kind,
            provider: MatthsProvider(interval: 3600)
        ) { entry in
            MatthsWeeklyEntryView(entry: entry)
                .containerBackground(for: .widget) { WidgetGround() }
        }
        .configurationDisplayName("이번 주 학습")
        .description("요일별 학습 시간과 이번 주 누적을 보여 줍니다.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - 시험 D-day
//
// 감독 지시: "위젯이랑 알림센터에 항상 뜨는 거는 아레나나 주간모의고사, 수능 D-day나
// 앞으로 남은 정규 모의고사 D-day 넣으면 좋을 듯".
//
// 네 가지는 출처가 다르다 — 수능·정규 모의고사는 **달력**(MatthsExamScheduleStore, 서버가
// 덮어쓸 수 있는 카탈로그), 주간 모의고사·아레나는 **계정별 서버 상태**(앱이 ingest 로 넣어 준다).
// 그래도 학생 눈에는 "시험까지 며칠"이라는 한 가지 질문이므로, 표시는 같은 한 줄 모양으로 맞춘다.
//
// 모르는 값은 **줄 자체를 그리지 않는다.** 로그인 전이라 주간 모의고사를 모르는데 "D-0" 이나
// "0일차"를 그리면 위젯이 아는 척 거짓말을 한다.

/// 위젯 한 줄. 네 종류가 같은 모양으로 줄 선다.
struct ExamDDayRow: Identifiable {
    enum Tone { case csat, mock, weekly, arena }

    var id: String
    /// "수능", "9월 모평", "주간 모의고사", "GOAT Arena"
    var label: String
    /// "D-89", "오늘 마감", "응시 완료", "12일차"
    var value: String
    /// "11월 19일 (목)" 같은 보조 한 줄. 없어도 된다.
    var detail: String?
    var tone: Tone
    var link: String

    var tint: Color {
        switch tone {
        case .csat: return WColor.magenta
        case .mock: return WColor.violet
        case .weekly: return WColor.blue
        case .arena: return WColor.cyan
        }
    }

    var symbol: String {
        switch tone {
        case .csat: return "flag.checkered"
        case .mock: return "calendar"
        case .weekly: return "doc.text.fill"
        case .arena: return "trophy.fill"
        }
    }
}

/// 마감 시각까지 남은 날. 오늘 안에 끝나면 "오늘 마감", 이미 지났으면 nil(그리지 않는다).
/// 시각이 아니라 **날짜의 차**로 센다 — 시험 D-day 와 같은 잣대여야 한 화면에서 말이 맞는다.
private func deadlineDDay(_ deadline: Date, now: Date) -> String? {
    let cal = MatthsExamClock.calendar
    let days = cal.dateComponents([.day],
                                  from: cal.startOfDay(for: now),
                                  to: cal.startOfDay(for: deadline)).day ?? 0
    if days < 0 { return nil }
    if days == 0 { return deadline > now ? "오늘 마감" : nil }
    return "D-\(days)"
}

extension MatthsWidgetSnapshot {

    /// 수능. 카탈로그가 비어 있으면 nil — 날짜를 지어내지 않는다(WidgetSnapshot.swift 참고).
    func csatRow(now: Date = Date()) -> ExamDDayRow? {
        guard let event = examSchedule?.csat(now: now),
              let dday = event.ddayText(now: now) else { return nil }
        return ExamDDayRow(
            id: event.id,
            label: event.displayShortTitle,
            value: dday,
            detail: MatthsExamClock.dateText(event.dayKey),
            tone: .csat,
            link: "matths://home")
    }

    /// 다음 정규 모의고사(교육청 전국연합·평가원 모의평가).
    func nationalMockRow(now: Date = Date()) -> ExamDDayRow? {
        guard let event = examSchedule?.nationalMock(now: now),
              let dday = event.ddayText(now: now) else { return nil }
        return ExamDDayRow(
            id: event.id,
            label: event.displayShortTitle,
            value: dday,
            detail: MatthsExamClock.dateText(event.dayKey),
            tone: .mock,
            link: "matths://home")
    }

    /// 이번 주 주간 모의고사 — 응시했으면 그 사실을, 아니면 마감까지 남은 날을.
    ///
    /// 우선순위가 이 순서인 이유: 이미 본 학생에게 마감을 재촉하면 소음이고,
    /// 아직 안 본 학생에게 가장 급한 정보는 "언제까지"다.
    func weeklyMockRow(now: Date = Date()) -> ExamDDayRow? {
        let link = "matths://weekly-mock"
        if weeklyMockDone == true {
            return ExamDDayRow(id: "weekly-mock", label: "주간 모의고사", value: "응시 완료",
                               detail: "이번 주", tone: .weekly, link: link)
        }
        if let closeAt = weeklyMockCloseAt, let dday = deadlineDDay(closeAt, now: now) {
            return ExamDDayRow(id: "weekly-mock", label: "주간 모의고사", value: dday,
                               detail: "응시 마감", tone: .weekly, link: link)
        }
        if let release = weeklyMockNextReleaseAt, let dday = deadlineDDay(release, now: now) {
            return ExamDDayRow(id: "weekly-mock", label: "주간 모의고사", value: dday,
                               detail: "다음 회차 공개", tone: .weekly, link: link)
        }
        // weeklyMockDone == false 인데 마감도 공개 시각도 모르는 상태 — 회차가 열려 있다는
        // 것만 안다. "미응시"까지는 말할 수 있다.
        if weeklyMockDone == false {
            return ExamDDayRow(id: "weekly-mock", label: "주간 모의고사", value: "미응시",
                               detail: "이번 주", tone: .weekly, link: link)
        }
        return nil
    }

    /// GOAT Arena — 걸린 방어 마감이 있으면 그것이 먼저다(놓치면 자리를 잃는다).
    /// 없으면 사이클 진행일.
    func arenaRow(now: Date = Date()) -> ExamDDayRow? {
        let link = "matths://arena"
        if let deadline = arenaDefenseDeadline, let dday = deadlineDDay(deadline, now: now) {
            return ExamDDayRow(id: "arena", label: "GOAT Arena", value: dday,
                               detail: "방어 마감", tone: .arena, link: link)
        }
        if let day = arenaCycleDay {
            let detail = arenaCycleLength.map { "사이클 \($0)일" } ?? "사이클 진행 중"
            return ExamDDayRow(id: "arena", label: "GOAT Arena", value: "\(day)일차",
                               detail: detail, tone: .arena, link: link)
        }
        return nil
    }

    /// 위에서부터 중요도 순. 자리가 모자라면 앞에서부터 자른다.
    func examRows(now: Date = Date()) -> [ExamDDayRow] {
        [csatRow(now: now), nationalMockRow(now: now),
         weeklyMockRow(now: now), arenaRow(now: now)].compactMap { $0 }
    }
}

/// 오늘의 미션 large 맨 윗줄에 얹는 얇은 띠.
private struct ExamDDayStrip: View {
    let row: ExamDDayRow
    let ink: Color
    let muted: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: row.symbol)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(row.tint)
            Text(row.label).font(.caption2.weight(.semibold)).foregroundStyle(muted)
            Text(row.value)
                .font(.system(.subheadline, design: .rounded, weight: .heavy))
                .monospacedDigit().foregroundStyle(ink)
            Spacer(minLength: 4)
            if let detail = row.detail {
                Text(detail).font(.caption2).foregroundStyle(muted)
            }
        }
        .lineLimit(1).minimumScaleFactor(0.75)
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(row.tint.opacity(0.14)))
    }
}

struct MatthsExamDDayEntryView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var scheme
    let entry: MatthsEntry

    /// 견본이 아니라 **실제로 그릴 값**을 쓴다(MatthsEntry.displaySnapshot 주석 참고).
    private var s: MatthsWidgetSnapshot { entry.displaySnapshot }
    private var ink: Color { scheme == .dark ? .white : WColor.navy }
    private var muted: Color { ink.opacity(0.62) }

    /// 타임라인 항목의 시각으로 센다(Date() 가 아니라). 자정 갱신 항목이 미리 만들어져도
    /// 그 항목이 뜨는 날짜 기준으로 D-day 가 맞는다.
    private var now: Date { entry.date }
    private var rows: [ExamDDayRow] { s.examRows(now: now) }
    /// 잠금화면처럼 한 칸뿐인 자리의 주인공. 수능이 없으면 그다음으로 중요한 줄이 대신 선다.
    private var lead: ExamDDayRow? { s.csatRow(now: now) ?? rows.first }

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular: circular
            case .accessoryRectangular: rectangular
            case .accessoryInline: inline
            case .systemMedium: medium
            default: small
            }
        }
        .widgetURL(URL(string: lead?.link ?? "matths://home"))
    }

    // MARK: 잠금화면

    /// 원형 — 잠금 해제 전에 읽히는 유일한 자리라 **한 값만** 넣는다.
    /// 시스템이 단색으로 렌더하므로 색이 아니라 글자 크기로 위계를 만든다.
    private var circular: some View {
        ZStack {
            AccessoryWidgetBackground()
            if let lead {
                VStack(spacing: -1) {
                    Text(lead.label)
                        .font(.system(size: 9, weight: .semibold))
                        .lineLimit(1).minimumScaleFactor(0.6)
                    Text(lead.value)
                        .font(.system(size: 17, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1).minimumScaleFactor(0.5)
                }
                .padding(3)
            } else {
                Image(systemName: "calendar.badge.clock").font(.system(size: 16, weight: .semibold))
            }
        }
        .accessibilityLabel(lead.map { "\($0.label) \($0.value)" } ?? "시험 일정 준비 중")
    }

    /// 직사각형 — 잠금화면에서 가장 정보량이 큰 칸. 세 줄까지.
    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 1) {
            if let lead {
                HStack(spacing: 4) {
                    Image(systemName: lead.symbol).font(.system(size: 11, weight: .bold))
                    Text(lead.label).font(.caption2)
                    Text(lead.value).font(.headline).monospacedDigit()
                }
                .lineLimit(1).minimumScaleFactor(0.7)
                if let detail = lead.detail {
                    Text(detail).font(.caption2).opacity(0.8).lineLimit(1)
                }
                // 두 번째 줄은 "수능 다음으로 급한 것" — 대개 정규 모의고사다.
                if let second = rows.first(where: { $0.id != lead.id }) {
                    Text("\(second.label) \(second.value)")
                        .font(.caption2).opacity(0.8).lineLimit(1).minimumScaleFactor(0.8)
                }
            } else {
                Text("시험 D-day").font(.headline)
                Text("일정이 등록되면 여기에 뜹니다").font(.caption2).opacity(0.8).lineLimit(2)
            }
        }
    }

    /// 인라인 — 시계 밑 한 줄. 두 개까지만 붙인다(길면 시스템이 잘라 버린다).
    private var inline: some View {
        Label(inlineText, systemImage: lead?.symbol ?? "calendar.badge.clock")
    }

    private var inlineText: String {
        guard let lead else { return "시험 일정 준비 중" }
        if let second = rows.first(where: { $0.id != lead.id }) {
            return "\(lead.label) \(lead.value) · \(second.label) \(second.value)"
        }
        return "\(lead.label) \(lead.value)"
    }

    // MARK: 홈 화면

    /// 작은 칸 — 숫자 하나를 크게. 아래에 시험일, 그 밑에 다음 줄 하나.
    private var small: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let lead {
                HStack(spacing: 4) {
                    Image(systemName: lead.symbol)
                        .font(.system(size: 11, weight: .bold)).foregroundStyle(lead.tint)
                    Text(lead.label).font(.caption2.weight(.semibold)).foregroundStyle(muted)
                    Spacer(minLength: 0)
                }
                Text(lead.value)
                    .font(.system(size: 42, weight: .heavy, design: .rounded))
                    .monospacedDigit().foregroundStyle(ink)
                    .lineLimit(1).minimumScaleFactor(0.45)
                if let detail = lead.detail {
                    Text(detail).font(.caption2).foregroundStyle(muted).lineLimit(1)
                }
                Spacer(minLength: 0)
                if let second = rows.first(where: { $0.id != lead.id }) {
                    HStack(spacing: 4) {
                        Image(systemName: second.symbol)
                            .font(.system(size: 9, weight: .bold)).foregroundStyle(second.tint)
                        Text("\(second.label) \(second.value)")
                            .font(.caption2.weight(.semibold)).foregroundStyle(ink.opacity(0.85))
                    }
                    .lineLimit(1).minimumScaleFactor(0.7)
                }
            } else {
                emptyState
            }
        }
        .padding(2)
    }

    /// 중간 칸 — 감독이 지목한 넷을 전부 세운다.
    private var medium: some View {
        HStack(alignment: .top, spacing: 12) {
            if let lead {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: lead.symbol)
                            .font(.system(size: 11, weight: .bold)).foregroundStyle(lead.tint)
                        Text(lead.label).font(.caption2.weight(.semibold)).foregroundStyle(muted)
                    }
                    Text(lead.value)
                        .font(.system(size: 40, weight: .heavy, design: .rounded))
                        .monospacedDigit().foregroundStyle(ink)
                        .lineLimit(1).minimumScaleFactor(0.45)
                    if let detail = lead.detail {
                        Text(detail).font(.caption2).foregroundStyle(muted)
                            .lineLimit(1).minimumScaleFactor(0.8)
                    }
                    Spacer(minLength: 0)
                }
                .frame(width: 116, alignment: .leading)

                VStack(alignment: .leading, spacing: 5) {
                    // 주인공 줄은 왼쪽에 이미 크게 있으니 오른쪽 목록에서는 뺀다.
                    ForEach(rows.filter { $0.id != lead.id }.prefix(3)) { row in
                        ExamRowLine(row: row, ink: ink, muted: muted)
                    }
                    if rows.count == 1 {
                        Text("주간 모의고사·아레나는 앱을 열면 채워집니다")
                            .font(.caption2).foregroundStyle(muted)
                            .lineLimit(2).minimumScaleFactor(0.8)
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                emptyState
            }
        }
        .padding(2)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 20, weight: .semibold)).foregroundStyle(WColor.violet)
            Text("시험 D-day").font(.system(.subheadline, weight: .bold)).foregroundStyle(ink)
            Text("일정이 등록되면\n수능·모의고사 D-day 가 여기 뜹니다")
                .font(.caption2).foregroundStyle(muted)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 중간 칸 오른쪽 목록의 한 줄.
private struct ExamRowLine: View {
    let row: ExamDDayRow
    let ink: Color
    let muted: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: row.symbol)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(row.tint)
                .frame(width: 14)
            VStack(alignment: .leading, spacing: 0) {
                Text(row.label).font(.system(size: 11, weight: .semibold)).foregroundStyle(ink)
                if let detail = row.detail {
                    Text(detail).font(.system(size: 9)).foregroundStyle(muted)
                }
            }
            Spacer(minLength: 4)
            Text(row.value)
                .font(.system(.subheadline, design: .rounded, weight: .heavy))
                .monospacedDigit().foregroundStyle(ink)
        }
        .lineLimit(1).minimumScaleFactor(0.75)
    }
}

struct MatthsExamDDayWidget: Widget {
    static let kind = "MatthsExamDDayWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: Self.kind,
            // 날짜가 바뀌면 숫자가 바뀌는 위젯이다. Provider 가 자정에 한 번 다시 그리지만,
            // 서버에서 일정이 바뀌거나 앱이 주간 모의고사·아레나 값을 넣은 것도 받아야 하므로
            // 한 시간 간격도 함께 건다(둘 중 이른 쪽이 이긴다 — MatthsProvider.getTimeline).
            provider: MatthsProvider(interval: 3600)
        ) { entry in
            MatthsExamDDayEntryView(entry: entry)
                .containerBackground(for: .widget) { WidgetGround() }
        }
        .configurationDisplayName("시험 D-day")
        .description("수능과 다음 정규 모의고사까지 남은 날, 이번 주 모의고사와 아레나 사이클을 보여 줍니다.")
        .supportedFamilies([
            .systemSmall, .systemMedium,
            .accessoryCircular, .accessoryRectangular, .accessoryInline,
        ])
    }
}

// MARK: - 바탕

/// 위젯 바탕 — 시스템 외관을 따라 캔버스색/네이비. (containerBackground 클로저에서 바로
/// colorScheme 을 읽을 수 없어 뷰로 감싼다.)
/// 잠금화면 액세서리는 바탕을 칠하지 않는다 — 시스템이 반투명 판을 이미 깔고, 그 위에
/// 네이비를 덧칠하면 잠금화면 배경과 겉돈다.
private struct WidgetGround: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.widgetFamily) private var family

    private var isAccessory: Bool {
        switch family {
        case .accessoryCircular, .accessoryRectangular, .accessoryInline: return true
        default: return false
        }
    }

    var body: some View {
        if isAccessory {
            Color.clear
        } else {
            scheme == .dark ? WColor.navy : WColor.canvas
        }
    }
}

@main
struct MatthsWidgetBundle: WidgetBundle {
    var body: some Widget {
        MatthsTodayWidget()
        MatthsExamDDayWidget()
        MatthsStreakWidget()
        MatthsWeeklyWidget()
        MatthsLiveActivityWidget()
    }
}

#Preview("small", as: .systemSmall) { MatthsTodayWidget() } timeline: {
    MatthsEntry(date: .now, snapshot: .placeholder, isEmpty: false)
}
#Preview("medium", as: .systemMedium) { MatthsTodayWidget() } timeline: {
    MatthsEntry(date: .now, snapshot: .placeholder, isEmpty: false)
}
#Preview("large", as: .systemLarge) { MatthsTodayWidget() } timeline: {
    MatthsEntry(date: .now, snapshot: .placeholder, isEmpty: false)
}
#Preview("streak", as: .systemSmall) { MatthsStreakWidget() } timeline: {
    MatthsEntry(date: .now, snapshot: .placeholder, isEmpty: false)
}
#Preview("weekly", as: .systemMedium) { MatthsWeeklyWidget() } timeline: {
    MatthsEntry(date: .now, snapshot: .placeholder, isEmpty: false)
}
#Preview("dday small", as: .systemSmall) { MatthsExamDDayWidget() } timeline: {
    MatthsEntry(date: .now, snapshot: .placeholder, isEmpty: false)
}
#Preview("dday medium", as: .systemMedium) { MatthsExamDDayWidget() } timeline: {
    MatthsEntry(date: .now, snapshot: .placeholder, isEmpty: false)
}
#Preview("dday rect", as: .accessoryRectangular) { MatthsExamDDayWidget() } timeline: {
    MatthsEntry(date: .now, snapshot: .placeholder, isEmpty: false)
}
#Preview("dday circular", as: .accessoryCircular) { MatthsExamDDayWidget() } timeline: {
    MatthsEntry(date: .now, snapshot: .placeholder, isEmpty: false)
}
