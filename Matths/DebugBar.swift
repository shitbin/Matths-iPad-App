//  DebugBar.swift
//  Matths
//
//  ┌─────────────────────────── 디버그 전용 컴포넌트 ────────────────────────────┐
//  │ 전역 디버그 바 — 홈·커리큘럼·평가센터·Pro·세션 모드 등 모든 화면 위에 뜬다. │
//  │ 무당벌레 버튼을 누르면 퀵 액션이 펼쳐진다:                                  │
//  │   시험   즉석 모의고사 시작 (전 유형 · 4문항 · 시각 시드)                   │
//  │   정답   현재 문항을 정답으로 채점 (실경로: 대조→코치→결과)                 │
//  │   오답   현재 문항을 오답으로 채점                                          │
//  │   Pro    사진 분석 결과 화면 직행                                           │
//  │   데모   서버 없이 모든 화면을 채우는 데모 모드 on/off (DemoMode)           │
//  │                                                                             │
//  │ 제거 방법: MatthsApp.swift 의 "전역 디버그 바" 호출 묶음 하나만 주석 처리.  │
//  │ 릴리스 빌드에는 #if DEBUG 때문에 어차피 컴파일조차 되지 않는다.             │
//  └─────────────────────────────────────────────────────────────────────────────┘

#if DEBUG
import SwiftUI

struct DebugBar: View {
    @EnvironmentObject private var store: AppStore
    /// 리뷰용 캡처 빌드: -review 인자가 있으면 무당벌레까지 완전히 숨긴다 —
    /// 디자인 검수 산출물에 디버그 UI가 찍히면 그 자체가 오염이다.
    /// (판정은 RuntimeMode 가 전역 소유 — 화면 내부 디버그 UI 도 같은 게이트를 쓴다)
    private var reviewCapture: Bool { RuntimeMode.isReviewCapture }
    /// 항상 접힌 채로 시작한다. 폭으로 판정하던 예전 방식(hSize == .compact)은
    /// 정작 신고가 들어온 상황 — iPad 전체화면 세로 — 에서 .regular 라 한 번도 참이 아니었고,
    /// 오버레이가 RootView 위에 있어 하네스의 compact 주입도 닿지 않는 죽은 분기였다.
    /// 디버그 도구가 화면을 가리는 쪽보다 무당벌레 한 번 더 누르는 쪽이 싸다.
    @State private var open = false
    @State private var showingRankMotion = false
    /// DemoMode.isOn 은 static 이라 SwiftUI 가 관찰하지 못한다. 칩 색이 실제 상태를
    /// 따라가려면 토글할 때 뷰 상태에도 같이 적어 줘야 한다.
    @State private var demoOn = DemoMode.isOn
    /// 토글 직후 한 번 뜨는 안내.
    ///
    /// ⚠️ @State 로 두면 **한 번도 화면에 뜨지 않는다**(실측). 데모를 켜고 끄면
    /// store.authProvider 가 바뀌고 → RootView 가 인증 화면↔본 화면으로 갈아끼우면서
    /// 오버레이 부모의 정체성이 바뀌어 DebugBar 가 새로 만들어진다. 그러면 @State 는
    /// 곧바로 nil 로 되돌아간다(칩 색은 초기값이 DemoMode.isOn 이라 멀쩡해 보여서
    /// 이 증상이 오래 가려져 있었다). 그래서 뷰 밖에 사는 관찰 객체에 담는다.
    @ObservedObject private var hint = DebugBarHint.shared

    var body: some View {
        if reviewCapture { EmptyView() } else { bar }
    }

    private var bar: some View {
        VStack(alignment: .trailing, spacing: Tokens.Space.s2) {
            if let text = hint.text { hintCapsule(text) }
            chipRow
        }
        .padding(.trailing, Tokens.Space.s4)
        // 채팅에서는 탭바 위에 입력줄이 한 겹 더 있다. 84 면 접어 놓아도 전송 버튼 위에
        // 무당벌레가 앉는다 — 그 화면에서만 입력줄 높이만큼 더 띄운다.
        .padding(.bottom, store.route == .chat ? 168 : 84)     // 하단 탭바 위
        .fullScreenCover(isPresented: $showingRankMotion) {
            RankPromotionOverlay(tierCode: "CHALLENGER")
                .environmentObject(store)
        }
    }

    private var chipRow: some View {
        HStack(spacing: Tokens.Space.s2) {
            if open {
                chip("시험", enabled: true) {
                    store.startExam(types: ProblemType.allCases, count: 4)
                }
                chip("정답", enabled: store.currentProblem != nil) {
                    if let p = store.currentProblem { store.gradeCurrent(input: p.answer) }
                }
                chip("오답", enabled: store.currentProblem != nil) {
                    store.gradeCurrent(input: "DEBUG-WRONG")
                }
                chip("Pro", enabled: true) {
                    store.debugProReport = true
                    store.route = .pro
                }
                chip("휘장", enabled: true) {
                    showingRankMotion = true
                }
                demoChip
            }

            Button {
                withAnimation(.easeOut(duration: 0.15)) { open.toggle() }
            } label: {
                Image(systemName: "ladybug.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(open ? Tokens.primary : Tokens.text3)
                    .frame(width: 34, height: 34)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("디버그 바 \(open ? "접기" : "펼치기")")
        }
        .padding(.horizontal, Tokens.Space.s2)
        .padding(.vertical, 5)
        .background(Tokens.surface.opacity(0.96), in: Capsule())
        .overlay(Capsule().strokeBorder(Tokens.lineStrong,
                                        style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
        .shadow(color: Color(hex: 0x17171F).opacity(0.12), radius: 8, y: 2)  // v3 웜 잉크 잔재 제거
    }

    // MARK: 데모 모드 칩

    /// 서버 없이 전 화면을 채우는 데모 모드. 켜져 있으면 강조색으로 칠해서 지금 보고 있는
    /// 숫자가 진짜 계정 기록인지 더미인지 한눈에 구분되게 한다 — 그 구분이 없으면
    /// 감독이 데모 수치를 실제 데이터로 오해한 채 피드백을 쓴다.
    private var demoChip: some View {
        Button {
            let next = !DemoMode.isOn
            // DemoMode 가 UserDefaults·슬롯·가로채기를 한꺼번에 바꾸고 통지까지 띄운다.
            // 화면들은 이미 DataScope.didSwitchNotification 을 듣고 서버 조회를 다시 한다.
            DemoMode.setEnabled(next)
            demoOn = DemoMode.isOn
            // 슬롯이 바뀌었으니 메모리에 들고 있던 오답노트·진도·통계도 새 슬롯 파일로
            // 다시 채운다. 이걸 빼먹으면 화면 절반은 새 데이터, 절반은 앞 슬롯 잔상이 된다.
            store.reloadLocalData()
            // 로그인 표식까지 여기서 맞춘다. reloadLocalData 뒤에 와야 한다 —
            // 먼저 쓰면 슬롯 재적재가 다시 덮어쓴다.
            applyDemoIdentity(on: next)
            refillDemoSlot(on: next)
            showDemoHint(on: next)
        } label: {
            HStack(spacing: 4) {
                Text("데모")
                if demoOn, DemoMode.missingRoutes.count > 0 {
                    // 픽스처가 없어 실패시킨 경로 수 = 아직 빈 채로 남아 있을 화면 수.
                    Text("\(DemoMode.missingRoutes.count)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Tokens.onBrand)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Tokens.warningInk, in: Capsule())
                }
            }
            .font(.mCaption)
            .foregroundStyle(demoOn ? Tokens.onBrand : Tokens.ink)
            .padding(.horizontal, Tokens.Space.s3)
            .frame(minHeight: 32)
            .background(demoOn ? Tokens.actionPrimary : Tokens.paper2, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("데모 모드 \(demoOn ? "끄기" : "켜기")")
        .accessibilityHint("서버 없이 더미 데이터로 모든 화면을 채웁니다")
    }

    /// 런타임 토글로도 **로그인 게이트까지** 넘어가게 한다.
    ///
    /// 왜 필요한가(실측): 데모를 끄면 실제 서버 요청이 401 로 떨어지고 앱이 로그아웃시켜
    /// 인증 화면으로 나간다. 거기서 칩을 다시 켜면 가로채기와 슬롯은 바뀌지만 화면은
    /// 인증 화면에 그대로 멈춰 있었다 — "로그인된 것처럼" 보이게 하는 대입이
    /// AppStore.init 에만 있었기 때문이다. 감독은 재실행 말고는 빠져나올 길이 없었다.
    ///
    /// 안전한 이유: authProvider 는 didSet 이 없어 이 대입이 디스크에 남지 않고,
    /// 이름·학년·학교·스트릭의 didSet 은 **슬롯 키**(…​.demo)에 적히므로 감독의 실제
    /// 계정 값을 건드리지 않는다. 끌 때는 UserDefaults 의 진짜 로그인 표식으로 되돌린다.
    private func applyDemoIdentity(on: Bool) {
        guard on else {
            // 데모 흉내였던 "server" 를 그대로 두면 로그아웃한 사람이 로그인된 것처럼 보인다.
            store.authProvider = UserDefaults.standard.string(forKey: "matths.auth")
            return
        }
        store.authProvider = "server"
        let user = DemoMode.demoUser
        if let name = user.name, !name.isEmpty { store.userName = name }
        if let email = user.email { store.userEmail = email }
        if let grade = user.schoolGrade { store.schoolGrade = grade }
        if let region = user.school?.region, let code = user.school?.code {
            store.schoolRegion = region
            store.schoolCode = code
        }
        store.serverStreak = user.currentStreak
        store.serverLongestStreak = user.longestStreak
    }

    /// 데모 슬롯의 진도·오답노트·막힌 지점을 픽스처에서 다시 내려받는다.
    ///
    /// 왜 필요한가(실측): DemoMode.enterDemoSlot 은 설계상 데모 슬롯 파일을 **매번 비운다**
    /// (지난 실행의 데모 캐시가 이번 픽스처와 섞이지 않게). 앱 시작이면 곧바로 SyncEngine
    /// 최초 pull 이 다시 채우지만, 런타임 토글에는 그 pull 이 없어서 칩을 껐다 켜면
    /// 평가 진도가 0/4 로 돌아가고 오답노트가 빈 화면이 됐다.
    /// 가로채기가 켜져 있으므로 이 pull 은 네트워크가 아니라 픽스처에서 온다.
    ///
    /// 한계(실측): 오답노트 pull 만 SyncEngine 안에 300초 간격 제한이 있고, 그 제한은
    /// 슬롯이 "바뀐 것으로 보일 때"만 풀린다(syncSlotIfNeeded). 데모를 끈 구간에는
    /// canReachServer 가 false 라 flush 가 먼저 되돌아가서 그 갱신이 일어나지 않는다.
    /// 그래서 켠 지 5분 안에 껐다 켜면 오답노트만 비어 있을 수 있다 — 그때는 감독이
    /// 헛것을 보지 않도록 아래에서 안내 문구로 바꿔 말한다(재실행하면 복구된다).
    private func refillDemoSlot(on: Bool) {
        guard on else { return }   // 끌 때 부르면 감독의 실제 계정으로 진짜 요청이 나간다
        Task { @MainActor in
            await SyncEngine.shared.syncNow()
            store.reloadLocalData()
            if store.wrongNotes.isEmpty {
                DebugBarHint.shared.show(
                    "데모 ON · 오답노트는 5분 간격 제한에 걸렸습니다 — 앱을 다시 실행하면 채워집니다")
            }
        }
    }

    /// 토글 직후 지금 보고 있는 숫자의 출처를 한 줄로 알린다.
    private func showDemoHint(on: Bool) {
        let text: String
        if on {
            let missing = DemoMode.missingRoutes.count
            text = missing == 0
                ? "데모 ON · 지우(데모 계정) 화면으로 전환했습니다"
                : "데모 ON · 지우(데모 계정) 화면 · 픽스처 없는 경로 \(missing)개"
        } else {
            text = "데모 OFF · 지금부터 실제 서버로 요청합니다(로그인 필요할 수 있음)"
        }
        DebugBarHint.shared.show(text)
    }

    private func hintCapsule(_ text: String) -> some View {
        Text(text)
            .font(.mCaption)
            .foregroundStyle(Tokens.text2)
            .multilineTextAlignment(.trailing)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: 260, alignment: .trailing)
            .padding(.horizontal, Tokens.Space.s3)
            .padding(.vertical, 6)
            .background(Tokens.surface.opacity(0.96), in: Capsule())
            .overlay(Capsule().strokeBorder(Tokens.lineStrong,
                                            style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
            .shadow(color: Color(hex: 0x17171F).opacity(0.12), radius: 8, y: 2)
            // 등장 트랜지션을 일부러 걸지 않는다: 데모 토글은 같은 순간에 RootView 를
            // 갈아끼우므로, opacity 트랜지션을 걸면 진행 중이던 애니메이션이 뷰 재생성과
            // 함께 리셋돼 문구가 **투명한 채로 남는다**(실측 — 이것 때문에 안내가
            // 한 번도 눈에 보이지 않았다). 그냥 곧바로 그린다.
            // 5초를 못 기다렸거나 화면을 가리면 눌러서 바로 치운다.
            .contentShape(Capsule())
            .onTapGesture { dismissHint() }
    }

    private func dismissHint() { hint.clear() }

    private func chip(_ title: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(.mCaption)
            .foregroundStyle(enabled ? Tokens.ink : Tokens.text4)
            .padding(.horizontal, Tokens.Space.s3)
            .frame(minHeight: 32)
            .background(Tokens.paper2, in: Capsule())
            .disabled(!enabled)
    }
}

// MARK: - 안내 문구 보관소

/// 디버그 바의 한 줄 안내를 **뷰 밖에서** 들고 있는다.
///
/// 뷰 안(@State)에 두면 안 되는 이유는 DebugBar.hint 주석에 적었다 — 데모 토글이
/// 로그인 표식을 바꾸는 순간 RootView 가 화면을 갈아끼우면서 DebugBar 가 새로
/// 만들어지고, 그때 @State 는 통째로 초기화된다. 안내는 바로 그 순간에 떠야 하므로
/// 뷰의 수명과 분리해 둔다. 자동 소멸 타이머도 여기서 돌린다(뷰 재생성에 안 죽게).
@MainActor
final class DebugBarHint: ObservableObject {
    static let shared = DebugBarHint()

    @Published private(set) var text: String?
    private var dismissal: Task<Void, Never>?

    private init() {}

    func show(_ value: String, seconds: Double = 5) {
        dismissal?.cancel()
        text = value
        dismissal = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            self?.clear()
        }
    }

    func clear() {
        dismissal?.cancel()
        dismissal = nil
        text = nil
    }
}
#endif
