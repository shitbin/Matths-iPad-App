//  Motion.swift
//  Matths
//
//  전역 모션 시스템 — 페이지 전환 · 요소 등장 · 버튼 프레스.
//
//  규칙:
//   1. 스위치는 하나다: 프로필 설정 "화면 모션" (store.motionOn).
//   2. 시스템 "동작 줄이기" 가 켜져 있으면 앱 설정과 무관하게 전부 정지한다 —
//      접근성이 앱 설정보다 항상 우선한다.
//   3. 모션은 장식이 아니라 방향 정보다. 페이지 전환은 탭 순서 기준으로
//      앞으로 갈 때 오른쪽에서, 뒤로 갈 때 왼쪽에서 들어온다.
//   4. 런타임 애니메이션은 SwiftUI + Lottie(LottieWebView) 로 구현한다.
//      Remotion 은 영상 산출(스플래시·마케팅) 전용 — 앱 안에서는 돌 수 없고,
//      스플래시 안무를 splash-video/ 와 동일하게 유지하는 것으로 연결된다.

import SwiftUI

// MARK: - 재생 허용 판정
//
// withAnimation 을 직접 부르는 곳(펼침·토글 등)은 앱 설정만 보다가 규칙 2를 어기기 쉽다.
// SwiftUI 는 동작 줄이기에서 withAnimation 을 자동으로 억제하지 않기 때문이다.
// 그래서 판정을 한 곳에 모아 둔다 — 호출부는 `store.anim(.easeOut(...), reduceMotion)`.

extension AppStore {
    /// 재생해도 되면 그 애니메이션을, 아니면 nil(=즉시 전환)을 돌려준다.
    func anim(_ animation: Animation, _ reduceMotion: Bool) -> Animation? {
        (motionOn && !reduceMotion) ? animation : nil
    }
}

// MARK: - 등장 모션 (스태거)

/// 화면의 큰 구획들이 위에서 아래 순서로 살짝 떠오르며 나타난다.
/// index 가 스태거 순번 — 같은 화면 안에서 0, 1, 2… 로 매긴다.
private struct Entrance: ViewModifier {
    @EnvironmentObject private var store: AppStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let index: Int
    @State private var shown = false

    private var active: Bool { store.motionOn && !reduceMotion }

    func body(content: Content) -> some View {
        content
            .opacity(!active || shown ? 1 : 0)
            .offset(y: !active || shown ? 0 : 14)
            .onAppear {
                guard active, !shown else { return }
                withAnimation(.spring(response: 0.45, dampingFraction: 0.85)
                    .delay(Double(index) * 0.06)) { shown = true }
            }
    }
}

extension View {
    /// 등장 모션. 모션 꺼짐/동작 줄이기에서는 아무것도 하지 않는다.
    func entrance(_ index: Int = 0) -> some View { modifier(Entrance(index: index)) }
}

// MARK: - 페이지 전환

extension AppStore.Route {
    /// 전환 방향 판정용 순서 — 하단 탭 순서와 같고, 세션 화면은 진행 방향(끝)으로 둔다.
    var navOrder: Int {
        switch self {
        case .home: return 0
        case .curriculum: return 1
        case .concept: return 2
        case .assess: return 3
        case .wrongNotes: return 4
        case .community: return 5      // 탭 순서: 오답노트 다음, GOAT Arena 앞
        case .rank, .arenaShop, .commerce: return 6
        case .pro: return 7
        case .chat: return 8
        // 알림함은 프로필과 같은 "상단 바에서 다녀오는 곳" 이라 그 옆에 둔다.
        case .notifications: return 9
        case .profile, .services, .academy, .coachSuggestions, .support, .archive, .studyHall, .storeCatalog, .faq, .hostedPortal: return 9
        // 퀵 연습은 홈에서 들어가는 짧은 세션 — 진행 방향(끝)으로 둔다
        case .quickPractice, .solve, .result, .kice, .paper, .placement, .weeklyMock: return 10
        }
    }
}

/// 라우트 전환 트랜지션. 방향(±1)은 AppStore 가 route 를 바꿀 때 계산해 둔다.
struct RouteTransition: ViewModifier {
    @EnvironmentObject private var store: AppStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let route: AppStore.Route

    private var active: Bool { store.motionOn && !reduceMotion }

    func body(content: Content) -> some View {
        Group {
            if active {
                content
                    .id(route)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .offset(x: 24 * store.navDirection)),
                        removal: .opacity))
            } else {
                content
            }
        }
    }
}

extension View {
    func routeTransition(_ route: AppStore.Route) -> some View {
        modifier(RouteTransition(route: route))
    }
}

// MARK: - 버튼 프레스

/// 응시하기·오답노트로 가기 같은 알약 버튼용 — 눌리면 살짝 가라앉는다.
/// (PrimaryButtonStyle 의 두툼 밑판과 다른, 가벼운 인라인 버튼용.)
struct PressScaleStyle: ButtonStyle {
    @EnvironmentObject private var store: AppStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let active = store.motionOn && !reduceMotion
        return configuration.label
            .scaleEffect(active && configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(active ? .spring(response: 0.25, dampingFraction: 0.7) : nil,
                       value: configuration.isPressed)
    }
}

// MARK: - 아레나 경기 인트로 모션
//
// 웹 경기 화면은 시작 순간에 3.65초짜리 커튼(READY → FIGHT! → QUESTION 1)을,
// 문항이 넘어갈 때 1.7초짜리 라운드 인트로(QUESTION N)를 재생한다.
// (Matths-Official/public/css/goat-arena.css 의 arena-fight-* / arena-question-*)
//
// 앱은 같은 안무를 쓰되 길이를 절반 아래로 줄인다. 웹은 그동안 화면 조작을 막지만
// (pointer-events:auto) 앱은 탭 한 번으로 즉시 건너뛸 수 있게 한다 — 제한 시간이
// 흐르는 화면에서 학생을 2초 붙잡아 두는 연출은 연출이 아니라 손해다.
//
// duration 을 화면 곳곳에 흩뿌리지 않으려고 이 한 곳에 모은다.
enum ArenaIntroMotion {
    /// 단어가 화면으로 들어오는 순간. 웹의 cubic-bezier(.16,1,.3,1) 대응.
    static let wordIn = Animation.spring(response: 0.32, dampingFraction: 0.68)
    /// 단어가 빠지는 순간.
    static let wordOut = Animation.easeIn(duration: 0.16)
    /// 커튼(암전 배경)이 걷히는 순간.
    static let curtain = Animation.easeOut(duration: 0.24)
    /// 잔여 60초 이하에서 남은 시간 표시가 숨 쉬는 속도.
    /// 웹 arenaTimerPulse(900ms ease-in-out infinite alternate)와 같은 값.
    static let timerPulse = Animation.easeInOut(duration: 0.9).repeatForever(autoreverses: true)

    // 경기 시작 커튼의 마디(초). 웹 타임라인(0 / 0.85 / 2.05 / 3.65)을 압축한 것이다.
    static let readyHold: Double = 0.42
    static let fightHold: Double = 0.72
    static let questionHold: Double = 0.70
    /// 모션을 끈 사용자에게 대신 보여 주는 정지 화면의 노출 시간.
    static let staticHold: Double = 0.75
    /// 문항 전환 라운드 인트로의 노출 시간.
    static let roundHold: Double = 0.60
}
