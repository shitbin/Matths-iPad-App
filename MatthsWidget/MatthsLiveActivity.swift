import ActivityKit
import SwiftUI
import WidgetKit

// Matths Live Activity 표현 — 잠금화면 배너 + 다이나믹 아일랜드 4종.
//
// 값의 정의는 Matths/LiveActivityAttributes.swift 한 곳에 있고(앱·확장 공용),
// 여기서는 **그리기만** 한다. 파생값을 여기서 다시 계산하면 잠금화면과 아일랜드가
// 서로 다른 숫자를 말하게 된다.
//
// ## 잘림을 피하는 규칙 (감독 지시: "잘리는 구간 피하기")
// 다이나믹 아일랜드는 남는 공간이 없는 UI다. 아래 네 가지를 전 표현에서 지킨다.
//  ① compact leading/trailing 은 **글자 수 상한을 코드로 건다** — lineLimit(1) +
//     minimumScaleFactor + frame(maxWidth:). 폭이 넘치면 시스템이 잘라 버리지, 줄이지 않는다.
//  ② expanded 의 leading/trailing 은 TrueDepth 카메라 좌우에 놓인다. maxWidth 를 걸어
//     가운데 센서 영역을 침범하지 않게 한다(침범하면 그 글자가 통째로 사라진다).
//  ③ 제목처럼 길이를 앱이 통제하지 못하는 문자열은 전부 lineLimit(1) + 축소 배율.
//  ④ minimal 은 지름 20pt 남짓이다. 글자를 넣지 않고 기호 + 진행 링만 그린다.
//  ⑤ 요약 칩 줄은 **개수를 코드로 막는다**(LiveChipRow). 조건마다 칩을 하나씩 늘리면
//     어느 조합에서 몇 개가 되는지 아무도 모르고, 넘치는 순간 글자가 "…"로 잘린다.
//
// ## 시험 D-day 칩 (감독 지시 — "항상 뜨는 것")
// 잠금화면 배너와 expanded 의 **첫 칩**으로 "수능 D-89" 를 넣었다. compact leading/trailing 과
// minimal 에는 넣지 않는다 — 규칙 ①·④ 그대로다. 그 두 칸에는 연속 학습일과 타이머가 이미
// 폭을 다 쓰고 있어서, 한 글자만 더 넣어도 둘 중 하나가 통째로 잘린다.
// 남은 일수는 state.examDDayText() 가 **그릴 때** 센다(LiveActivityAttributes.swift 참고) —
// 배너는 갱신 없이 자정을 넘기므로 정수로 실어 보내면 다음 날 틀린 숫자가 남는다.
//
// 색은 CI 4색(WColor — MatthsWidget.swift 와 같은 값)만 쓴다.

struct MatthsLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MatthsLiveActivityAttributes.self) { context in
            // 잠금화면 · 배너(Always-On 포함)
            LiveActivityLockScreenView(state: context.state)
                .activityBackgroundTint(WColor.navy)
                .activitySystemActionForegroundColor(WColor.cyan)
        } dynamicIsland: { context in
            let state = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    ExpandedStreakColumn(state: state)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ExpandedTimeColumn(state: state)
                }
                // .center 는 일부러 비워 둔다.
                // leading·center·trailing 은 **같은 가로줄**을 나눠 쓴다(센서 좌우가 아니라
                // 한 행이다). 가운데에 제목처럼 넓은 것을 넣으면 좌우 칸이 그만큼 눌려
                // "연속 학습"이 "…"으로, 타이머가 "경ㅗ"로 잘린다 — 시뮬레이터에서 실측한 증상이다.
                // 제목은 폭이 온전한 .bottom 으로 내렸다.
                DynamicIslandExpandedRegion(.bottom) {
                    ExpandedFooter(state: state)
                }
            } compactLeading: {
                CompactStreak(state: state)
            } compactTrailing: {
                CompactTimer(state: state)
            } minimal: {
                MinimalRing(state: state)
            }
            .keylineTint(WColor.violet)
            .widgetURL(URL(string: state.deepLink))
        }
    }
}

// MARK: - 다이나믹 아일랜드 · compact

/// 왼쪽 칸 — 연속 학습일. 감독이 콕 집은 값이라 가장 좁은 표현에도 살려 둔다.
/// 세 자리(999일)까지는 폭이 남고, 그 이상은 축소 배율이 받는다.
private struct CompactStreak: View {
    let state: MatthsLiveActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "flame.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(WColor.magenta)
            Text("\(state.streakDays)")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .frame(maxWidth: 46)
        .accessibilityLabel("연속 학습 \(state.streakDays)일")
    }
}

/// 오른쪽 칸 — 학습은 경과, 경기는 남은 시간.
///
/// 경기는 10분 미만이라 `mm:ss` 로 충분하고(showsHours: false → 폭이 항상 5글자),
/// 학습은 한 시간을 넘을 수 있어 시(hour) 칸을 허용한다. 대신 폭 상한과 축소 배율을 건다.
private struct CompactTimer: View {
    let state: MatthsLiveActivityAttributes.ContentState

    var body: some View {
        Text(
            timerInterval: state.timerRange,
            countsDown: state.countsDown,
            showsHours: !state.countsDown
        )
        .font(.system(size: 13, weight: .semibold, design: .rounded))
        .monospacedDigit()
        .multilineTextAlignment(.trailing)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .frame(maxWidth: 62)
        .foregroundStyle(state.kind == .arena ? WColor.cyan : .white)
    }
}

/// minimal — 활동이 둘 이상일 때만 나오는 지름 20pt 남짓의 칸.
/// 글자는 들어가지 않는다. 진행 링 + 종류 기호만.
private struct MinimalRing: View {
    let state: MatthsLiveActivityAttributes.ContentState

    private var symbol: String { state.kind == .arena ? "trophy.fill" : "flame.fill" }
    private var tint: Color { state.kind == .arena ? WColor.cyan : WColor.magenta }

    var body: some View {
        ZStack {
            if let progress = state.progress {
                Circle()
                    .stroke(tint.opacity(0.25), lineWidth: 2)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(tint, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(tint)
        }
        .padding(1)
        .accessibilityLabel(state.kindLabel)
    }
}

// MARK: - 다이나믹 아일랜드 · expanded

/// 위 칸 왼쪽 — 연속 학습.
///
/// **한 줄만 쓴다.** 위아래 두 줄로 쌓으면 윗줄이 아일랜드 위쪽 둥근 모서리에 걸려
/// 글자가 잘린다("연속 학습"이 "…속 학습"이 되던 증상 — 시뮬레이터 실측).
/// 한 줄을 세로 가운데에 두면 아일랜드가 가장 넓은 높이에 놓여 잘리지 않는다.
private struct ExpandedStreakColumn: View {
    let state: MatthsLiveActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "flame.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(WColor.magenta)
            Text(state.streakText)
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
            Text("연속")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.55))
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .padding(.leading, 4)
        .frame(maxWidth: 112, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("연속 학습 \(state.streakDays)일")
    }
}

/// 위 칸 오른쪽 — 경과/남은 시간. 왼쪽 칸과 같은 이유로 한 줄이다.
private struct ExpandedTimeColumn: View {
    let state: MatthsLiveActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 4) {
            Text(state.timeCaption)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.55))
            Text(
                timerInterval: state.timerRange,
                countsDown: state.countsDown,
                showsHours: !state.countsDown
            )
            .font(.system(size: 18, weight: .heavy, design: .rounded))
            .monospacedDigit()
            .multilineTextAlignment(.trailing)
            .foregroundStyle(state.kind == .arena ? WColor.cyan : .white)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .padding(.trailing, 4)
        .frame(maxWidth: 128, alignment: .trailing)
    }
}

/// 아랫칸 — 무엇을 하고 있는지 + 진행 막대 + 요약 칩.
/// 폭을 온전히 쓸 수 있는 유일한 칸이라 제목도 여기 있다. 네 줄을 넘기지 않는다.
private struct ExpandedFooter: View {
    let state: MatthsLiveActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 4) {
                Image(systemName: state.kindSymbol)
                    .font(.system(size: 9, weight: .bold))
                Text("\(state.kindLabel) · \(state.subtitle)")
                    .font(.system(size: 10, weight: .semibold))
                Spacer(minLength: 0)
            }
            .foregroundStyle(WColor.cyan)
            .lineLimit(1)
            .minimumScaleFactor(0.8)

            Text(state.title)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            if let progress = state.progress {
                ProgressBar(progress: progress)
                    .frame(height: 5)
            }
            LiveChipRow(chips: state.chips(includingStreak: false), limit: 3)
        }
        .padding(.horizontal, 4)
        .padding(.top, 2)
    }
}

// MARK: - 잠금화면 · 배너

/// 잠금화면과 (앱이 앞에 없을 때의) 배너에 쓰이는 표현.
/// 시스템이 여백을 거의 주지 않으므로 패딩을 스스로 갖는다.
private struct LiveActivityLockScreenView: View {
    let state: MatthsLiveActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                // 브랜드 표식. 앱 아이콘 PNG(WidgetMark)를 쓰지 않는 이유:
                // 그 이미지는 **검은 원판 위 흰 글자**라 네이비 배경의 잠금화면 배너에서는
                // 회색 사각형 하나로만 보인다(시뮬레이터 실측). CI 4색 그라디언트 타일에
                // 세션 종류 기호를 얹으면 어떤 배경에서도 읽히고 브랜드도 그대로 산다.
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(LinearGradient(
                            colors: [WColor.magenta, WColor.violet, WColor.blue, WColor.cyan],
                            startPoint: .topLeading, endPoint: .bottomTrailing))
                    Image(systemName: state.kindSymbol)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 24, height: 24)
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(state.kindLabel) · \(state.subtitle)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(WColor.cyan)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(state.title)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 1) {
                    Text(state.timeCaption)
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.55))
                    Text(
                        timerInterval: state.timerRange,
                        countsDown: state.countsDown,
                        showsHours: !state.countsDown
                    )
                    .font(.system(size: 19, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(state.kind == .arena ? WColor.cyan : .white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: 96, alignment: .trailing)
                }
            }

            if let progress = state.progress {
                ProgressBar(progress: progress).frame(height: 6)
            }

            LiveChipRow(chips: state.chips(includingStreak: true), limit: 4)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .widgetURL(URL(string: state.deepLink))
    }
}

// MARK: - 조각

/// 브랜드 그라디언트 진행 막대. ProgressView 로는 CI 4색 그라디언트를 못 넣는다.
private struct ProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.18))
                Capsule()
                    .fill(LinearGradient(
                        colors: [WColor.magenta, WColor.violet, WColor.blue, WColor.cyan],
                        startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(6, geo.size.width * progress))
            }
        }
        .accessibilityLabel("진행률 \(Int(progress * 100))퍼센트")
    }
}

/// 요약 칩 한 장의 내용.
struct LiveChipItem: Identifiable {
    var id: String
    var symbol: String
    var text: String
    var tint: Color
}

extension MatthsLiveActivityAttributes.ContentState {
    /// 요약 칩 목록 — **중요한 것부터**. 자리가 모자라면 뒤에서 잘린다.
    ///
    /// 순서의 근거: 시험 D-day 와 연속 학습일은 감독이 "항상 뜨는 것"으로 지목한 값이고,
    /// 문항 진행·오늘 학습·복습 대기는 앱을 열면 바로 보이는 값이다. 잠금화면에서만
    /// 볼 수 있는 것을 앞에 둔다.
    func chips(includingStreak: Bool, asOf now: Date = Date()) -> [LiveChipItem] {
        var items: [LiveChipItem] = []
        if let dday = examDDayText(asOf: now) {
            items.append(.init(id: "dday", symbol: "flag.checkered", text: dday, tint: WColor.cyan))
        }
        if includingStreak {
            items.append(.init(id: "streak", symbol: "flame.fill",
                               text: "\(streakText) 연속", tint: WColor.magenta))
        }
        if let text = progressText {
            items.append(.init(id: "progress", symbol: "checkmark.circle.fill",
                               text: text, tint: WColor.cyan))
        }
        items.append(.init(id: "today", symbol: "clock.fill",
                           text: "오늘 \(todayStudyLabel(asOf: now))", tint: WColor.blue))
        if dueReviewCount > 0 {
            items.append(.init(id: "review", symbol: "arrow.counterclockwise",
                               text: "복습 \(dueReviewCount)", tint: WColor.violet))
        }
        return items
    }
}

/// 칩 줄 — **개수를 코드로 막는다.**
///
/// 왜 개수 제한인가. 칩을 조건마다 하나씩 늘리면 어느 조합에서 몇 개가 되는지 아무도 모르고,
/// 폭이 넘치면 SwiftUI 는 줄여 주는 게 아니라 **가운데 글자를 "…"로 잘라 버린다**
/// (시험 D-day 칩을 다섯 번째로 넣었더니 "수능 D-…"가 되던 증상 — 시뮬레이터 실측).
/// minimumScaleFactor 는 글자에만 걸리고 캡슐 패딩에는 안 걸려서 이 상황을 못 막는다.
/// 그래서 그릴 수 있는 최대 개수를 정하고, 넘치는 것은 **그리지 않는다**.
/// 잘린 다섯 개보다 온전한 네 개가 더 많은 정보를 준다.
private struct LiveChipRow: View {
    let chips: [LiveChipItem]
    let limit: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(chips.prefix(limit)) { chip in
                LiveChip(symbol: chip.symbol, text: chip.text, tint: chip.tint)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.75)
    }
}

private struct LiveChip: View {
    let symbol: String
    let text: String
    let tint: Color

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: symbol).font(.system(size: 9, weight: .bold))
            Text(text).font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(tint.opacity(0.16), in: Capsule())
    }
}
