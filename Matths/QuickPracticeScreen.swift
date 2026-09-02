//  QuickPracticeScreen.swift
//  Matths
//
//  퀵 연습 — 수능 첫 페이지 유형을 40초 안에 하나.
//  웹 quick-practice 의 앱판 (서버 API 4종: start / submit / expire / stats).
//
//  설계 두 가지만 지킨다:
//   1. 마감은 **서버가 판정한다.** 클라 타이머는 보여주기용이고, 0 이 되면
//      expire 를 쳐서 서버 판정을 받는다 (기기 시계를 믿으면 무한 연장이 된다).
//   2. 서버 계정 전용. 게스트는 진입 자체를 막는다 (기록이 갈 곳이 없다).

import SwiftUI
import PencilKit

/// 퀵 연습 통계의 화면 표시 정본.
///
/// 운영 API는 accuracy를 0...100으로 주지만, 저장된 구형 응답과 일부 fixture에는
/// 0...1 비율이 남아 있다. 더 중요한 total/correct가 함께 있으면 그 두 값을 진실원으로
/// 다시 계산하고, 둘 중 하나가 없을 때만 reported를 호환 해석한다.
enum QuickPracticeStatsDisplay {
    static func accuracyPercent(total: Int?, correct: Int?, reported: Double?) -> Int {
        let percent: Double
        if let total, total > 0, let correct {
            percent = Double(min(max(correct, 0), total)) / Double(total) * 100
        } else {
            let raw = reported ?? 0
            percent = raw >= 0 && raw <= 1 ? raw * 100 : raw
        }
        return Int(min(max(percent, 0), 100).rounded())
    }
}

struct QuickPracticeScreen: View {
    @EnvironmentObject private var store: AppStore
    // 기기 이름이 아니라 크기 클래스로 분기한다 — Split View·Stage Manager 의
    // iPad 도 compact 로 들어오고, 그때 필요한 레이아웃은 iPhone 과 같다.
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Phase { case idle, loading, solving, graded, failed }

    @State private var phase: Phase = .idle
    @State private var attempt: ServerAPI.QuickAttempt?
    @State private var result: ServerAPI.QuickResult?
    @State private var stats: ServerAPI.QuickStats.Row?
    @State private var answer = ""
    @FocusState private var answerFocused: Bool
    @State private var remaining = 40
    @State private var limitMs = 40_000
    @State private var startedAt = Date()
    @State private var pointValue = 2
    @State private var errorText: String?
    @State private var promptHeight: CGFloat = 90
    @State private var solutionHeight: CGFloat = 70
    /// 화면이 시작된 계정 슬롯과 요청 세대. 네트워크 응답을 기다리는 동안 로그아웃·
    /// 다른 계정 로그인이 일어나면 이전 학생의 문제/채점/통계를 새 화면에 붙이지 않는다.
    @State private var accountSlot = DataScope.slot
    @State private var operationID = UUID()
    @State private var statsRequestID = UUID()
    /// 앱이 내려갔다 올라오는 순간을 잡아 남은 시간을 서버 마감으로 다시 맞춘다.
    @Environment(\.scenePhase) private var scenePhase

    /// 막대를 이어 그리기 위한 표시 전용 기준 시각. remaining 이 마지막으로 바뀐
    /// 순간을 기억해 두고, 막대는 그 순간부터 흐른 만큼을 이어서 줄인다.
    /// 남은 시간을 세는 쪽(tick)과 마감 판정(서버)은 그대로 둔다.
    @State private var tickAnchor = Date()

    // 풀이 노트. 캔버스는 SolutionCanvas 를 그대로 불러 쓴다(그 파일은 건드리지 않는다).
    @State private var noteDrawing = PKDrawing()
    @State private var noteUndoStack: [PKDrawing] = []
    @State private var noteTool: SolutionCanvasTool = .pen
    /// iPhone 에는 Apple Pencil 이 없다. 손가락을 꺼둔 채 시작하면 아예 쓸 수 없다.
    @State private var noteAllowsFinger =
        UniversalLayoutPolicy.defaultsToFingerDrawing(on: QuickPracticeScreen.deviceClass)
    /// nil 이면 화면 크기가 정한 기본값을 쓰고, 학생이 한 번 접거나 펴면 그 선택이 이긴다.
    @State private var noteOpenOverride: Bool?
    /// 되돌리기·비우기가 만든 변화는 되돌릴 지점으로 다시 쌓지 않는다.
    @State private var noteSkipsHistory = false

    // MARK: 이어 풀기
    //
    // 한 문항으로 끝내지 않고 같은 배점으로 여러 문항을 이어서 푸는 흐름이다.
    // 문항을 뽑는 것도 채점하는 것도 **종전과 같은 서버 경로 그대로**다
    // (start / submit / expire). 여기서 늘어나는 것은 몇 번째 문항인지와
    // 지금까지 맞힌 개수뿐이고, 맞았는지는 서버가 돌려준 값만 센다.

    /// 이어 풀기 중이면 목표 문항 수, 아니면 nil. nil 이 종전의 한 문항 흐름이다.
    @State private var setTotal: Int?
    /// 채점까지 끝난 문항 수. 서버 채점이 돌아온 뒤에만 오른다.
    @State private var setDone = 0
    /// 그중 서버가 정답으로 판정한 문항 수.
    @State private var setCorrect = 0
    /// 시작 화면에서 고른 문항 수.
    @State private var setSize = 5

    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private static var deviceClass: MatthsDeviceClass {
        UIDevice.current.userInterfaceIdiom == .phone ? .phone : .pad
    }

    // MARK: 폭·높이 적응
    //
    // 폭이 좁으면(iPhone 세로, iPad Split View) 가로로 늘어놓던 것을 세로로 쌓고,
    // 높이가 낮으면(iPhone 가로 — 가용 390pt) 제목·여백 같은 크롬부터 줄인다.
    // 두 조건은 독립이다: iPhone 가로는 폭 compact + 높이 compact 로 동시에 온다.

    private var isNarrow: Bool { horizontalSizeClass == .compact }
    private var isShort: Bool { verticalSizeClass == .compact }

    /// iPhone 가로 풀이. 접근성 글자 크기에서는 두 칼럼보다 세로 스크롤이 읽기
    /// 순서를 더 잘 지키므로 기본 배치로 돌아간다.
    private var usesLandscapeSolvingLayout: Bool {
        isShort && phase == .solving && !dynamicTypeSize.isAccessibilitySize
    }

    /// 문제를 푸는 동안뿐 아니라 결과를 확인할 때도 긴 소개 헤더를 반복하지 않는다.
    /// 가로 결과 화면에서 소개 문단이 남으면 다음 문제 버튼이 탭바 뒤로 밀린다.
    /// AX5도 예외가 아니다. 본문·문제는 큰 글씨와 세로 읽기 순서를 유지하되, 이미
    /// 진입한 풀이 단계의 반복 소개만 탐색 크롬 크기로 줄여 문제를 첫 화면에 둔다.
    private var usesCompactExerciseHeader: Bool {
        guard isShort else { return false }
        switch phase {
        case .solving, .graded: return true
        case .idle, .loading, .failed: return false
        }
    }

    /// 시작 화면의 두 핵심 행동(문제 시작, 누적 기록)을 iPhone 가로에서 나란히 둔다.
    /// 세로 배치를 그대로 쓰면 누적 기록이 하단 내비게이션 아래로 내려가 첫 화면에서
    /// 보이지 않았다. 접근성 글자 크기에서는 칼럼 폭을 억지로 줄이지 않고 종전처럼
    /// 세로 스크롤을 허용해 읽기 순서와 글자 크기를 보존한다.
    private var usesLandscapeOverviewLayout: Bool {
        guard isShort, !dynamicTypeSize.isAccessibilitySize else { return false }
        switch phase {
        case .idle, .failed: return true
        case .loading, .solving, .graded: return false
        }
    }

    /// 카드 안쪽 여백. 좁은 폭에서 24pt 를 양쪽에 두면 본문 폭이 48pt 깎인다.
    private var cardPadding: CGFloat { isNarrow ? Tokens.Space.s4 : Tokens.Space.s6 }

    /// 섹션 사이 간격 — 낮은 화면에서 먼저 줄어드는 것은 내용이 아니라 여백이다.
    private var sectionSpacing: CGFloat { isShort ? Tokens.Space.s4 : Tokens.Space.s6 }

    /// 큰 글씨에서는 좁지 않아도 가로 나열이 깨진다 — 폭 조건과 함께 본다.
    private var stacksActions: Bool {
        dynamicTypeSize.isAccessibilitySize || (isNarrow && !isShort)
    }

    /// 노트를 처음부터 펼쳐 둘지. 세로가 짧은 화면(가로 iPhone, 가용 높이 약 390pt)에서만
    /// 접은 채로 시작한다. 거기서 노트를 펴 두면 문제와 답 칸이 화면 밖으로 밀린다.
    private var noteOpen: Bool { noteOpenOverride ?? !isShort }

    /// 노트 높이. 채점 화면의 620pt 를 그대로 가져오면 40초 안에 봐야 할 문제와
    /// 답 칸이 한 화면에서 사라진다. 여기서는 계산 두세 줄 쓸 만큼만 준다.
    private var noteHeight: CGFloat {
        if isShort { return 190 }
        return isNarrow ? 250 : 300
    }

    /// 좌우 분할 풀이에서 실제로 보이는 필기 면 높이.
    ///
    /// 76pt면 계산 두세 줄을 쓸 수 있으면서 작은 iPhone 가로에서도 답 입력·제출이
    /// 하단 탭 위에 남는다. 이전의 56pt는 화면에는 들어갔지만 실제 필기에는 너무
    /// 얕았다. 별도 제목 행을 도구막대 안으로 합쳐 되찾은 높이를 필기 면에 돌린다.
    private var landscapeNoteCanvasHeight: CGFloat {
        76
    }

    private var landscapeSolvingCardPadding: CGFloat {
        Self.deviceClass == .phone ? Tokens.Space.s2 : Tokens.Space.s3
    }

    /// iPad 는 펜슬 전용으로 시작하므로 손가락 필기를 켤 방법이 필요하다.
    /// iPhone 은 처음부터 손가락이라 토글이 할 일이 없다.
    private var showsFingerToggle: Bool { Self.deviceClass == .pad }

    /// 이어 풀기 진입점을 여는 조건. 넓은 폭에서만 연다. 40초 문항을 연달아 푸는
    /// 동안 문제·풀이 노트·진행이 한 화면에 같이 서 있어야 하는데, 좁은 폭에서는
    /// 그게 안 된다. 기기 종류도 함께 보는 이유는 큰 iPhone 의 가로 화면도
    /// 크기 클래스로는 regular 로 들어오기 때문이다.
    private var showsSetEntry: Bool {
        Self.deviceClass == .pad && horizontalSizeClass == .regular
    }

    /// 이어 풀기의 목표 문항을 다 채웠는지.
    private var setFinished: Bool {
        guard let total = setTotal else { return false }
        return setDone >= total
    }

    /// 남은 시간을 이어서 그릴지. 시스템 동작 줄이기가 우선이고, 앱의 화면 모션
    /// 스위치도 함께 본다(Motion.swift 규칙 1·2). 끄면 막대는 정확히 남은 초에 선다.
    private var smoothTimer: Bool { store.motionOn && !reduceMotion }

    private var totalSeconds: Int { max(1, limitMs / 1000) }

    var body: some View {
        VStack(alignment: .leading, spacing: sectionSpacing) {
            header

            if !ServerAPI.hasToken && !usesDebugFixture {
                guestCard
            } else if usesLandscapeOverviewLayout {
                HStack(alignment: .top, spacing: Tokens.Space.s4) {
                    primaryCard
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .accessibilityElement(children: .contain)
                    statsCard
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .accessibilityElement(children: .contain)
                }
            } else {
                primaryCard
                // 40초 풀이 중에는 누적 통계를 아래에 매달지 않는다. 통계 때문에
                // 바깥 ScrollView가 계속 스크롤 가능한 상태로 남으면 시작 버튼이
                // 풀이 카드로 바뀌는 순간 기존 위치를 보존하면서 압축 헤더가 상단
                // 바 뒤로 올라간다. 문제·메모·답·제출만 한 화면에 고정한다.
                if showsStatsBelowPrimary { statsCard }
            }
        }
        .onAppear {
            applyDebugFixtureIfPresent()
            loadStats()
            // 홈의 "바로 한 문항" 으로 들어왔으면 문항까지 바로 간다.
            // 표시는 한 번만 쓰고 지운다. 탭으로 들어온 평소 진입은 그대로
            // 시작 화면을 보여 준다 — 무엇을 풀지 고르고 싶은 사람도 있다.
            if store.quickPracticeAutoStart {
                store.quickPracticeAutoStart = false
                if phase == .idle { startSingle() }
            }
        }
        .onReceive(tick) { _ in onTick() }
        // 앱이 다시 앞으로 나오는 순간 곧바로 맞춘다. tick 을 기다리면 최대 1초 동안
        // 지난 시계를 보여 주고, 그 사이에 답을 넣으면 이미 늦은 제출이 된다.
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            onTick()
        }
        // 초가 바뀐 순간을 기억해 둔다. 막대는 이 시각부터 흐른 만큼을 이어 그린다.
        .onChange(of: remaining) { _, _ in tickAnchor = Date() }
        // 되돌리기 기록은 필기 내용 자체의 변화에서 뽑는다. 한 획이 끝날 때마다
        // 정확히 한 번 바뀌므로, 바뀌기 직전 상태를 쌓아 두면 그것이 되돌릴 지점이다.
        // (캔버스가 주는 획 완료 알림에 기대지 않는다. 아래 undoNote 주석 참조.)
        .onChange(of: noteDrawing) { old, _ in
            guard !noteSkipsHistory else { noteSkipsHistory = false; return }
            noteUndoStack.append(old)
            if noteUndoStack.count > 20 { noteUndoStack.removeFirst() }
        }
        .onReceive(NotificationCenter.default.publisher(for: DataScope.didSwitchNotification)) {
            guard let newSlot = $0.object as? String, newSlot != accountSlot else { return }
            switchAccount(to: newSlot)
        }
        .onDisappear {
            // URLSession 자체를 강제로 끊지는 않아도, 이후 도착하는 응답은 모두 폐기한다.
            operationID = UUID()
            statsRequestID = UUID()
        }
    }

    private var showsStatsBelowPrimary: Bool {
        switch phase {
        case .idle, .failed, .graded: true
        case .loading, .solving: false
        }
    }

    @ViewBuilder private var primaryCard: some View {
        switch phase {
        case .idle, .failed: idleCard
        case .loading:       loadingCard
        case .solving:       solvingCard
        case .graded:        gradedCard
        }
    }

    // MARK: 머리

    private var header: some View {
        Group {
            if usesCompactExerciseHeader {
                // 393pt 높이에서 소개 문장까지 계속 차지하면 정작 답 칸이 화면 밖으로
                // 밀린다. 풀이 중에만 현재 위치와 규칙을 한 줄로 압축한다.
                HStack(spacing: Tokens.Space.s3) {
                    Text("퀵 연습")
                        .font(.mHeading)
                        .foregroundStyle(Tokens.ink)
                        .accessibilityAddTraits(.isHeader)
                    Spacer(minLength: Tokens.Space.s2)
                    Label("40초", systemImage: "timer")
                    Label("한 문항", systemImage: "1.circle")
                }
                .font(.mCaption)
                .foregroundStyle(Tokens.text2)
                .frame(minHeight: 44)
                // 실제 문제와 답은 AX5를 그대로 따른다. 이 행은 반복 탐색 정보라
                // xxxLarge에서 멈춰 한 줄과 44pt 조작 영역을 보존한다.
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            } else {
                standardHeader
            }
        }
        .entrance(0)
    }

    private var standardHeader: some View {
        VStack(alignment: .leading, spacing: isShort ? Tokens.Space.s2 : Tokens.Space.s3) {
            // 낮은 화면에서는 제목 한 단계만 낮춘다. 지우지는 않는다 —
            // 어느 화면에 들어와 있는지가 사라지면 방향을 잃는다.
            Text("퀵 연습")
                .font(isShort ? .mHeading : .mTitle)
                .foregroundStyle(Tokens.ink)
                .accessibilityAddTraits(.isHeader)
            ExamRule()
            // 조건 요약은 카드로 쪼개지 않고 메타 행 하나로 — 세 단어면 충분하다
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Tokens.Space.s5) { metaItems }
                VStack(alignment: .leading, spacing: Tokens.Space.s2) { metaItems }
            }
            Text("수능과 모평 첫 페이지에서 나오는 계산 유형입니다. 빨리 정확하게가 전부입니다.")
                .font(isShort ? .mCallout : .mBody)
                .foregroundStyle(Tokens.text2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder private var metaItems: some View {
        metaItem("timer", "40초")
        metaItem("1.circle", "한 문항")
        metaItem("target", "취약 개념 기반")
    }

    private func metaItem(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.mMicro).foregroundStyle(Tokens.text3)
            Text(text).font(.mCaption).foregroundStyle(Tokens.text2).monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }

    /// 게스트 게이트 — "이용할 수 없습니다"로 끝내지 않는다. 가치 한 줄과
    /// 로그인 경로를 함께 준다. 트리거는 RankArena 로그인 배너와 같다
    /// (store.signOut — 게스트 슬롯을 비우고 인증 화면으로 돌려보낸다).
    private var guestCard: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s4) {
            VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                Text("기록은 로그인부터 시작됩니다").font(.mHeading).foregroundStyle(Tokens.ink)
                Text("로그인하면 40초 기록이 계정에 쌓여 정답률과 평균 속도의 변화를 확인할 수 있습니다.")
                    .font(.mCallout).foregroundStyle(Tokens.text2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            quickPracticePreview
            VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                Button("로그인하고 시작하기") { store.signOut() }
                    .buttonStyle(PrimaryButtonStyle())
                    .frame(maxWidth: 420)
                // 게이트에서 막힌 채 끝내지 않는다 — 지금 되는 길 하나를 같이 준다
                Button("커리큘럼으로 돌아가기") { store.route = .curriculum }
                    .buttonStyle(SecondaryButtonStyle())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: cardPadding)
        .entrance(1)
    }

    private var quickPracticePreview: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Tokens.Space.s2) {
                quickPracticeStep("1", "문제 받기", "취약 개념에서 한 문항", "bolt.fill")
                quickPracticeStep("2", "40초 풀이", "서버 시간으로 공정하게", "timer")
                quickPracticeStep("3", "변화 확인", "정답률과 평균 속도", "chart.line.uptrend.xyaxis")
            }
            VStack(spacing: Tokens.Space.s2) {
                quickPracticeStep("1", "문제 받기", "취약 개념에서 한 문항", "bolt.fill")
                quickPracticeStep("2", "40초 풀이", "서버 시간으로 공정하게", "timer")
                quickPracticeStep("3", "변화 확인", "정답률과 평균 속도", "chart.line.uptrend.xyaxis")
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("퀵 연습 진행, 취약 개념 문제 받기, 40초 풀이, 정답률과 평균 속도 확인")
    }

    private func quickPracticeStep(
        _ index: String,
        _ title: String,
        _ detail: String,
        _ icon: String
    ) -> some View {
        HStack(spacing: Tokens.Space.s3) {
            ZStack {
                Circle().fill(Tokens.primarySoft)
                Image(systemName: icon)
                    .font(.mCaption.weight(.bold))
                    .foregroundStyle(Tokens.primary)
            }
            .frame(width: 38, height: 38)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(index)단계").font(.mMicro).foregroundStyle(Tokens.primary)
                Text(title).font(.mBodyB).foregroundStyle(Tokens.ink)
                Text(detail).font(.mCaption).foregroundStyle(Tokens.text3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 78, alignment: .leading)
        .padding(Tokens.Space.s3)
        .background(Tokens.paper, in: RoundedRectangle(cornerRadius: Tokens.Radius.sm))
    }

    // MARK: 대기 — 배점 고르고 시작

    private var idleCard: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s4) {
            Text("배점").font(.mCaption).foregroundStyle(Tokens.text3)
            Picker("배점", selection: $pointValue) {
                // 배점은 **2·3점뿐**이다. 서버 allowedPoints=[2,3] 이고,
                // 그 밖의 값을 보내면 서버가 둘 중 하나를 무작위로 바꿔 버린다.
                // 예전엔 "4점" 탭이 있어서, 학생은 4점을 골랐다고 믿는데
                // 실제로는 2점이나 3점 문제가 나왔다.
                Text("2점").tag(2)
                Text("3점").tag(3)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 320)

            if let e = errorText {
                // 실패는 이유까지 말해야 학생이 다음 행동을 고른다.
                // 예전엔 "문제를 받지 못했습니다" 한 줄이라, 서버가 잠깐 안 되는 건지
                // 앱이 고장난 건지 알 수 없어 학생이 그 자리에서 멈췄다.
                VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                    Text(e).font(.mCaption).foregroundStyle(Tokens.dangerInk)
                        .fixedSize(horizontal: false, vertical: true)
                    // 이어 풀던 중에 끊겼다면 어디까지 갔는지는 남겨 준다.
                    // 푼 문항은 이미 서버에 기록되어 누적 기록에도 반영된다.
                    if let total = setTotal, setDone > 0 {
                        Text("이어 풀기는 \(total)문항 중 \(setDone)문항까지 진행했고 "
                             + "\(setCorrect)문항 맞혔습니다.")
                            .font(.mCaption).foregroundStyle(Tokens.text2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    // 퀵 연습은 마감 판정이 서버 몫이라 오프라인 대체가 없다(설계).
                    // 대신 기기 안에서 끝나는 길을 알려 준다.
                    Text("퀵 연습은 시간 판정을 서버가 맡아 인터넷이 필요합니다. "
                         + "지금 바로 풀고 싶다면 커리큘럼의 연습 문제나 오답노트 복습은 "
                         + "기기 안에서 그대로 됩니다.")
                        .font(.mCaption).foregroundStyle(Tokens.text3)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Button("문제 뽑기") { startSingle() }
                .buttonStyle(PrimaryButtonStyle())
                .frame(maxWidth: 420)

            if showsSetEntry { setEntry }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: cardPadding)
        .entrance(1)
    }

    /// 이어 풀기 진입점. 한 문항 흐름은 위에 그대로 있고, 이건 그 옆에 붙는 길이다.
    private var setEntry: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s3) {
            SectionRule(title: "이어 풀기")
            Text("고른 배점으로 여러 문항을 이어서 풉니다. 한 문항마다 40초는 그대로이고, "
                 + "몇 번째인지 화면에 표시됩니다. 중간에 그만둘 수 있고 끝나면 "
                 + "몇 문항 맞았는지 알려 드립니다.")
                .font(.mCaption).foregroundStyle(Tokens.text3)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
            Picker("문항 수", selection: $setSize) {
                Text("3문항").tag(3)
                Text("5문항").tag(5)
                Text("10문항").tag(10)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 320)
            // 보조 버튼은 글자 폭까지만 커진다. 바로 위 "문제 뽑기" 와 같은 폭에
            // 서야 두 길이 나란히 보이므로 라벨을 늘려 준다.
            Button { startSet() } label: {
                Text("\(setSize)문항 이어 풀기").frame(maxWidth: .infinity)
            }
            .buttonStyle(SecondaryButtonStyle())
            .frame(maxWidth: 420)
        }
    }

    private var loadingCard: some View {
        HStack(spacing: Tokens.Space.s3) {
            ProgressView().controlSize(.small)
            Text("문제를 뽑는 중…").font(.mCallout).foregroundStyle(Tokens.text2)
            Spacer()
        }
        .card(padding: cardPadding)
        .entrance(1)
    }

    // MARK: 풀이 — 타이머 + 발제문 + 답 입력

    @ViewBuilder private var solvingCard: some View {
        if let a = attempt {
            if usesLandscapeSolvingLayout {
                HStack(alignment: .top, spacing: Tokens.Space.s4) {
                    VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                        setProgress
                        topicAndTimer(a)
                        timerBar
                        KatexText(
                            text: MathText.normalizeDelimiters(a.prompt),
                            height: $promptHeight)
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)

                    Divider()

                    VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                        if !answerFocused {
                            QuickSolutionNote(
                                drawing: $noteDrawing,
                                tool: $noteTool,
                                allowsFinger: $noteAllowsFinger,
                                height: landscapeNoteCanvasHeight,
                                toolbarTitle: "풀이 메모",
                                showsToolTitles: false,
                                showsFingerToggle: false,
                                showsHelper: false,
                                canUndo: !noteUndoStack.isEmpty,
                                onUndo: undoNote)
                        }
                        HStack(spacing: Tokens.Space.s2) {
                            TextField("답", text: $answer)
                                .textFieldStyle(.roundedBorder)
                                .font(.mBody)
                                .keyboardType(.numbersAndPunctuation)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .focused($answerFocused)
                                .submitLabel(.done)
                                .onSubmit { submit() }
                            Button("제출") { submit() }
                                .buttonStyle(PrimaryButtonStyle())
                                .frame(minWidth: 96)
                                .disabled(answer.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .card(padding: landscapeSolvingCardPadding)
                .entrance(1)
            } else {
                VStack(alignment: .leading, spacing: Tokens.Space.s4) {
                    setProgress
                    topicAndTimer(a)
                    timerBar
                    KatexText(text: MathText.normalizeDelimiters(a.prompt), height: $promptHeight)
                    noteSection
                    TextField("답", text: $answer)
                        .textFieldStyle(.roundedBorder)
                        .font(.mBody)
                        .keyboardType(.numbersAndPunctuation)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($answerFocused)
                        .submitLabel(.done)
                        .onSubmit { submit() }
                    Button("제출") { submit() }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(answer.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .card(padding: cardPadding)
                .entrance(1)
            }
        }
    }

    @ViewBuilder private var setProgress: some View {
        if let total = setTotal {
            HStack(spacing: Tokens.Space.s2) {
                Image(systemName: "list.number")
                    .font(.mMicro).foregroundStyle(Tokens.text3)
                Text("이어 풀기 \(min(setDone + 1, total)) / \(total)")
                    .font(.mCaption).foregroundStyle(Tokens.text2).monospacedDigit()
                Spacer(minLength: Tokens.Space.s2)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("이어 풀기 \(total)문항 중 \(min(setDone + 1, total))번째 문항")
        }
    }

    private func topicAndTimer(_ a: ServerAPI.QuickAttempt) -> some View {
        HStack(alignment: isNarrow ? .firstTextBaseline : .center,
               spacing: Tokens.Space.s3) {
            if isNarrow {
                VStack(alignment: .leading, spacing: 2) {
                    Text(a.topicLabel ?? "").font(.mBodyB).foregroundStyle(Tokens.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    if let v = a.variantLabel {
                        Text(v).font(.mCaption).foregroundStyle(Tokens.text3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            } else {
                Text(a.topicLabel ?? "").font(.mBodyB).foregroundStyle(Tokens.ink)
                if let v = a.variantLabel {
                    Text(v).font(.mCaption).foregroundStyle(Tokens.text3)
                }
            }
            Spacer(minLength: Tokens.Space.s2)
            Text("\(remaining)초")
                .font(.mStat)
                .foregroundStyle(remaining <= 10 ? Tokens.danger : Tokens.ink)
                .monospacedDigit()
                .layoutPriority(1)
                .accessibilityLabel("남은 시간 \(remaining)초")
        }
    }

    private var timerBar: some View {
        QuickTimerBar(remaining: remaining,
                      total: totalSeconds,
                      anchor: tickAnchor,
                      smooth: smoothTimer)
    }

    // MARK: 풀이 노트
    //
    // 머리 안에서만 굴리게 두면 40초는 계산이 아니라 기억력 시험이 된다.
    // 채점 화면과 같은 캔버스(SolutionCanvas)를 그대로 부르고, 40초 안에 손이
    // 닿을 도구만 남긴다.

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
            Button { toggleNote() } label: {
                HStack(spacing: Tokens.Space.s2) {
                    Image(systemName: "square.and.pencil")
                        .font(.mCaption).foregroundStyle(Tokens.text3)
                    Text("풀이 노트").font(.mCaption).foregroundStyle(Tokens.text2)
                    Spacer(minLength: Tokens.Space.s2)
                    Image(systemName: noteOpen ? "chevron.up" : "chevron.down")
                        .font(.mMicro).foregroundStyle(Tokens.text3)
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("풀이 노트")
            .accessibilityHint(noteOpen ? "노트를 접습니다" : "노트를 펼칩니다")

            if noteOpen {
                QuickSolutionNote(
                    drawing: $noteDrawing,
                    tool: $noteTool,
                    allowsFinger: $noteAllowsFinger,
                    height: noteHeight,
                    toolbarTitle: nil,
                    showsToolTitles: !isNarrow && !dynamicTypeSize.isAccessibilitySize,
                    showsFingerToggle: showsFingerToggle,
                    showsHelper: true,
                    canUndo: !noteUndoStack.isEmpty,
                    onUndo: undoNote)
            }
        }
    }

    private func toggleNote() {
        withAnimation(store.anim(.easeInOut(duration: 0.22), reduceMotion)) {
            noteOpenOverride = !noteOpen
        }
    }

    /// 한 획 되돌리기.
    ///
    /// 캔버스에는 "획을 다 그었다" 를 알려 주는 통로(onStrokeCommitted)가 있지만,
    /// 이 화면에서는 그 알림이 오지 않는 것을 시뮬레이터에서 확인했다(획은 그려지고
    /// 필기 내용도 갱신되는데 알림만 오지 않았다). 그래서 알림 대신 필기 내용의
    /// 변화를 직접 본다. 화면이 1초마다 다시 그려지는 것과 무관하게 동작한다.
    private func undoNote() {
        guard let previous = noteUndoStack.popLast() else { return }
        noteSkipsHistory = true
        noteDrawing = previous
    }

    /// 새 문항이나 다른 계정에는 앞 문항의 필기가 남지 않는다.
    private func resetNote() {
        noteUndoStack.removeAll()
        guard !noteDrawing.strokes.isEmpty else { return }
        noteSkipsHistory = true
        noteDrawing = PKDrawing()
    }

    // MARK: 채점 결과

    private var gradedCard: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s4) {
            if let r = result {
                HStack(spacing: Tokens.Space.s3) {
                    Image(systemName: r.expired == true ? "clock.badge.exclamationmark"
                          : (r.correct == true ? "checkmark.circle.fill" : "xmark.circle.fill"))
                        .font(.system(size: 26))
                        .foregroundStyle(r.expired == true ? Tokens.warning
                                         : (r.correct == true ? Tokens.success : Tokens.danger))
                    Text(r.expired == true ? "시간 초과"
                         : (r.correct == true ? "정답" : "오답"))
                        .font(.mHeading).foregroundStyle(Tokens.ink)
                    Spacer()
                    if let ms = r.responseTimeMs {
                        Text(String(format: "%.1f초", Double(ms) / 1000))
                            .font(.mCaption).foregroundStyle(Tokens.text3).monospacedDigit()
                    }
                }

                if let sol = r.solution, !sol.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("풀이").font(.mMicro).foregroundStyle(Tokens.text3)
                        KatexText(text: MathText.normalizeDelimiters(sol), height: $solutionHeight)
                    }
                }

                if let total = setTotal { setTally(total) }

                gradedActions
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: cardPadding)
        .entrance(1)
    }

    /// 이어 풀기 집계. 진행 중에는 어디까지 왔는지, 끝나면 몇 개 맞았는지.
    private func setTally(_ total: Int) -> some View {
        let done = min(setDone, total)
        return VStack(alignment: .leading, spacing: Tokens.Space.s2) {
            HStack(spacing: Tokens.Space.s3) {
                Text("\(done) / \(total)")
                    .font(.mBodyB).foregroundStyle(Tokens.ink).monospacedDigit()
                ProgressBar(value: Double(done) / Double(max(1, total)))
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("이어 풀기 \(total)문항 중 \(done)문항 완료")
            Text(setFinished
                 ? "\(total)문항을 모두 풀었습니다. \(setCorrect)문항 맞혔습니다."
                 : "지금까지 \(setCorrect)문항 맞혔습니다.")
                .font(.mCaption).foregroundStyle(Tokens.text2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Tokens.Space.s3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tokens.paper, in: RoundedRectangle(cornerRadius: Tokens.Radius.sm))
    }

    /// 채점 화면의 두 버튼. 이어 풀기가 끝났을 때만 주 버튼이 새 세트로 바뀐다.
    /// 좁은 폭·큰 글씨에서 두 버튼을 한 줄에 두면 "그만하기" 가 잘리거나
    /// 주 버튼이 글자 폭까지 쪼그라든다. 그럴 때만 세로로 쌓는다.
    @ViewBuilder private var gradedActions: some View {
        let nextTitle = setFinished ? "한 번 더" : "다음 문제"
        if stacksActions {
            VStack(spacing: Tokens.Space.s2) {
                Button(nextTitle) { advance() }
                    .buttonStyle(PrimaryButtonStyle())
                Button("그만하기") { stopPractice() }
                    .buttonStyle(SecondaryButtonStyle())
                    .frame(maxWidth: .infinity)
            }
        } else {
            HStack(spacing: Tokens.Space.s3) {
                Button(nextTitle) { advance() }
                    .buttonStyle(PrimaryButtonStyle())
                Button("그만하기") { stopPractice() }
                    .buttonStyle(SecondaryButtonStyle())
            }
        }
    }

    // MARK: 누적 기록

    @ViewBuilder private var statsCard: some View {
        if let s = stats, (s.total ?? 0) > 0 {
            VStack(alignment: .leading, spacing: 0) {
                SectionRule(title: "누적 기록")
                    .padding(.bottom, Tokens.Space.s2)
                // 좁은 폭에 네 칸을 밀어 넣으면 한 칸이 70pt 안쪽이 되어 22pt 통계
                // 숫자가 먼저 줄어든다. 숫자를 줄이는 대신 2×2 로 접는다.
                if isNarrow {
                    VStack(spacing: Tokens.Space.s3) {
                        HStack(spacing: 0) {
                            statTile("푼 문항", "\(s.total ?? 0)", "문항")
                            Divider().frame(height: 34)
                            statTile("정답", "\(s.correct ?? 0)", "문항")
                        }
                        Divider()
                        HStack(spacing: 0) {
                            statTile("정답률", accuracyText(s), "%")
                            Divider().frame(height: 34)
                            statTile("평균",
                                     String(format: "%.1f", Double(s.averageMs ?? 0) / 1000), "초")
                        }
                    }
                } else {
                    HStack(spacing: 0) {
                        statTile("푼 문항", "\(s.total ?? 0)", "문항")
                        Divider().frame(height: 34)
                        statTile("정답", "\(s.correct ?? 0)", "문항")
                        Divider().frame(height: 34)
                        statTile("정답률", accuracyText(s), "%")
                        Divider().frame(height: 34)
                        statTile("평균", String(format: "%.1f", Double(s.averageMs ?? 0) / 1000), "초")
                    }
                }
            }
            .card(padding: cardPadding)
            .entrance(2)
        }
    }

    private func statTile(_ label: String, _ value: String, _ unit: String) -> some View {
        VStack(spacing: 3) {
            Text(label).font(.mMicro).foregroundStyle(Tokens.text3)
            (Text(value).font(.mStat) + Text(" \(unit)").font(Font.stat(13)))
                .foregroundStyle(Tokens.ink)
        }
        .frame(maxWidth: .infinity)
    }

    private func accuracyText(_ stats: ServerAPI.QuickStats.Row) -> String {
        String(QuickPracticeStatsDisplay.accuracyPercent(
            total: stats.total,
            correct: stats.correct,
            reported: stats.accuracy))
    }

    // MARK: 디자인 캡처용 고정 화면
    //
    // 이 화면의 풀이 단계는 서버 계정과 인터넷이 있어야만 열린다. 그래서 타이머와
    // 노트의 모양을 시뮬레이터에서 확인할 방법이 없었다. 다른 화면이 이미 쓰는
    // 방식(-goatMatchFixture·-commerceFixture)과 같게, DEBUG 빌드에서만 도는
    // 캡처 인자를 둔다. 채점·기록은 그대로 서버 몫이고 여기서 흉내 내지 않는다.

    /// 캡처할 단계. `-quickPracticeFixture` 뒤에 값을 붙여 고른다.
    /// 값이 없으면 종전과 같은 한 문항 풀이 화면이고,
    /// `start` 는 시작 화면(이어 풀기 진입점이 폭에 따라 어떻게 보이는지),
    /// `set` 은 이어 풀기 도중의 풀이 화면(진행 표시 확인)이다.
    /// 채점 결과 화면은 넣지 않는다. 맞았는지 틀렸는지는 서버만 정하고,
    /// 그 판정을 흉내 낸 화면은 만들지 않는다.
    private static var debugFixtureStage: String? {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-quickPracticeFixture") else { return nil }
        let next = args.indices.contains(index + 1) ? args[index + 1] : ""
        return next.isEmpty || next.hasPrefix("-") ? "solving" : next
        #else
        return nil
        #endif
    }

    private var usesDebugFixture: Bool {
        Self.debugFixtureStage != nil
    }

    private func applyDebugFixtureIfPresent() {
        #if DEBUG
        guard let stage = Self.debugFixtureStage, phase == .idle else { return }
        // 시작 화면은 그대로 두면 된다 (게스트 게이트만 지나간 상태).
        guard stage != "start" else { return }
        if stage == "set" {
            setTotal = 5
            setDone = 2
            setCorrect = 2
        }
        attempt = ServerAPI.QuickAttempt(
            instanceId: "fixture",
            pointValue: 2,
            topicKey: "log",
            topicLabel: "로그의 계산",
            variantLabel: "밑변환",
            sourceScope: nil,
            prompt: "$\\log_{2}12 - \\log_{2}3$ 의 값을 구하시오.",
            deadlineAt: nil)
        limitMs = 40_000
        remaining = 40
        startedAt = Date()
        tickAnchor = startedAt
        phase = .solving
        #endif
    }

    // MARK: 동작

    /// 문제 받기 실패 문구 — 원인을 구분해서 말한다.
    /// URLError 는 "서버가 멀쩡한데 내 인터넷이 없는" 경우라 안내가 달라야 한다.
    private static func startFailureText(_ error: Error) -> String {
        if let u = error as? URLError {
            switch u.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return "인터넷에 연결되어 있지 않습니다."
            case .timedOut:
                return "응답이 늦어지고 있습니다. 잠시 후 다시 시도해 주세요."
            case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
                return "서비스에 연결하지 못했습니다. 네트워크를 확인한 뒤 다시 시도해 주세요."
            default:
                return "네트워크 문제로 연습 문제를 받지 못했습니다. 다시 시도해 주세요."
            }
        }
        if let s = (error as? ServerAPIError)?.errorDescription { return s }
        return "문제를 받지 못했습니다."
    }

    private func loadStats() {
        guard ServerAPI.hasToken else { return }
        let ownerSlot = accountSlot
        let requestID = UUID()
        statsRequestID = requestID
        Task {
            let loaded = try? await ServerAPI.quickPracticeStats()
            guard ownerSlot == accountSlot,
                  ownerSlot == DataScope.slot,
                  statsRequestID == requestID else { return }
            stats = loaded
        }
    }

    /// 한 문항만 받는다. 이어 풀기 중이었다면 여기서 접는다.
    private func startSingle() {
        endSet()
        start()
    }

    /// 이어 풀기 시작. 문항을 받아 오는 길은 한 문항 때와 똑같다.
    private func startSet() {
        setTotal = setSize
        setDone = 0
        setCorrect = 0
        start()
    }

    /// 채점 화면의 주 버튼. 이어 풀기를 다 채웠으면 같은 문항 수로 새 세트를 연다.
    private func advance() {
        if setFinished { startSet() } else { start() }
    }

    /// 연습을 접고 시작 화면으로. 이어 풀기 중이었다면 세트도 함께 접는다.
    private func stopPractice() {
        endSet()
        phase = .idle
        attempt = nil
        result = nil
    }

    private func endSet() {
        setTotal = nil
        setDone = 0
        setCorrect = 0
    }

    /// 한 문항이 끝났다. **서버가 돌려준 판정만** 센다. 시간 초과는 정답이 아니다.
    private func recordSetResult(_ graded: ServerAPI.QuickResult) {
        guard setTotal != nil else { return }
        setDone += 1
        if graded.correct == true { setCorrect += 1 }
    }

    private func start() {
        guard ServerAPI.hasToken, accountSlot == DataScope.slot else { return }
        let ownerSlot = accountSlot
        let requestID = UUID()
        let selectedPointValue = pointValue
        operationID = requestID
        phase = .loading
        errorText = nil
        answer = ""
        result = nil
        resetNote()
        Task {
            do {
                let s = try await ServerAPI.quickPracticeStart(pointValue: selectedPointValue)
                guard ownsOperation(requestID, slot: ownerSlot) else { return }
                attempt = s.attempt
                limitMs = s.timeLimitMs ?? 40_000
                remaining = max(1, limitMs / 1000)
                startedAt = Date()
                // 앞 문항과 남은 초가 같으면 onChange 가 울리지 않는다. 여기서 직접 맞춘다.
                tickAnchor = startedAt
                phase = .solving
            } catch {
                guard ownsOperation(requestID, slot: ownerSlot) else { return }
                errorText = Self.startFailureText(error)
                phase = .failed
            }
        }
    }

    private func submit() {
        guard let a = attempt,
              phase == .solving,
              accountSlot == DataScope.slot else { return }
        let ownerSlot = accountSlot
        let requestID = UUID()
        let submittedAnswer = answer
        let elapsed = Int(Date().timeIntervalSince(startedAt) * 1000)
        operationID = requestID
        phase = .loading
        Task {
            do {
                let graded = try await ServerAPI.quickPracticeSubmit(
                    instanceId: a.instanceId, answer: submittedAnswer, elapsedMs: elapsed)
                guard ownsOperation(requestID, slot: ownerSlot) else { return }
                result = graded
                recordSetResult(graded)
                phase = .graded
                loadStats()
            } catch {
                guard ownsOperation(requestID, slot: ownerSlot) else { return }
                errorText = (error as? ServerAPIError)?.errorDescription ?? "채점에 실패했습니다"
                phase = .failed
            }
        }
    }

    /// 클라 타이머는 표시용. 0 이 되면 **서버에** 마감 판정을 받는다.
    /// 서버가 정한 마감. 이게 진짜 기준이고 화면의 숫자는 그걸 비추는 것뿐이다.
    private var serverDeadline: Date? {
        attempt?.deadlineAt.flatMap(Self.parseDeadline)
    }

    private static func parseDeadline(_ raw: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: raw) ?? ISO8601DateFormatter().date(from: raw)
    }

    /// 마감까지 실제로 남은 초. 앱이 내려가 있던 시간도 그대로 반영된다.
    private func remainingFromServer() -> Int? {
        serverDeadline.map { max(0, Int(ceil($0.timeIntervalSinceNow))) }
    }

    private func onTick() {
        guard phase == .solving else { return }
        // 전에는 1초씩 빼기만 했다. 그러면 앱이 백그라운드로 내려간 동안 tick 이 멈춰
        // 화면 시계도 같이 멈추는데, 서버 마감은 계속 흐른다. 배식 줄에서 잠깐 앱을
        // 내렸다 올리면 학생은 "아직 20초 남았다"를 보며 풀고 제출에서 시간 초과를
        // 받는다. 서버가 준 마감이 있으면 그걸 기준으로 다시 맞춘다.
        if let fromServer = remainingFromServer() {
            remaining = fromServer
        } else {
            remaining = max(0, remaining - 1)
        }
        guard remaining == 0,
              let a = attempt,
              accountSlot == DataScope.slot else { return }
        let ownerSlot = accountSlot
        let requestID = UUID()
        operationID = requestID
        phase = .loading
        Task {
            do {
                let r = try await ServerAPI.quickPracticeExpire(instanceId: a.instanceId)
                guard ownsOperation(requestID, slot: ownerSlot) else { return }
                if r.pending == true {
                    // 서버는 아직 시간이 남았다고 본다 — 클라 시계가 빨랐다. 1초 더 준다.
                    remaining = 1
                    phase = .solving
                } else {
                    result = r
                    recordSetResult(r)
                    phase = .graded
                    loadStats()
                }
            } catch {
                guard ownsOperation(requestID, slot: ownerSlot) else { return }
                errorText = (error as? ServerAPIError)?.errorDescription ?? "시간 초과 처리에 실패했습니다"
                phase = .failed
            }
        }
    }

    private func ownsOperation(_ requestID: UUID, slot: String) -> Bool {
        operationID == requestID && accountSlot == slot && DataScope.slot == slot
    }

    private func switchAccount(to newSlot: String) {
        // 먼저 기존 요청 세대를 무효화한 뒤 새 계정의 빈 화면으로 바꾼다.
        operationID = UUID()
        statsRequestID = UUID()
        accountSlot = newSlot
        phase = .idle
        attempt = nil
        result = nil
        stats = nil
        answer = ""
        remaining = 40
        limitMs = 40_000
        tickAnchor = Date()
        errorText = nil
        resetNote()
        endSet()
        loadStats()
    }
}

// MARK: - 남은 시간 막대
//
// 종전에는 1초짜리 타이머가 값을 바꿀 때마다 막대가 한 칸씩 뛰었다. 40초를
// 마흔 칸으로 나눈 셈이라, 시간이 흐르는 게 아니라 떨어지는 것처럼 보였다.
// 그래서 화면이 그려지는 주기(TimelineView(.animation))마다 "지금 초에서 얼마나
// 지났는지" 를 더해 막대를 이어 그린다.
//
// 시간 계산은 그대로다. 남은 초를 세는 것도, 마감을 판정하는 것도 종전과 같고
// 여기서는 이미 정해진 남은 초 사이를 메우기만 한다. 그래서 초가 바뀌는 순간
// 막대는 정확히 그 눈금에 서 있고, 숫자와 어긋나지 않는다.
private struct QuickTimerBar: View {
    /// 화면에 적히는 남은 초. 이 값이 막대의 기준점이다.
    let remaining: Int
    let total: Int
    /// remaining 이 마지막으로 바뀐 시각.
    let anchor: Date
    /// false 면(동작 줄이기·화면 모션 끔) 이어 그리지 않고 남은 초에 정확히 세운다.
    let smooth: Bool

    private var tint: Color { remaining <= 10 ? Tokens.danger : Tokens.primary }

    var body: some View {
        Group {
            if smooth {
                // 남은 초가 0이면 더 그릴 것이 없다. 그때는 화면 갱신을 멈춘다.
                TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: remaining <= 0)) { context in
                    bar(seconds: seconds(at: context.date))
                }
            } else {
                bar(seconds: Double(remaining))
            }
        }
        // 남은 시간은 바로 위 숫자가 이미 읽어 준다. 같은 값을 두 번 읽지 않는다.
        .accessibilityHidden(true)
    }

    /// 지금 초에서 지난 만큼을 빼되, 다음 눈금(remaining - 1) 아래로는 내려가지 않는다.
    /// 타이머가 늦게 오더라도 막대가 숫자를 앞질러 가지 않게 하는 빗장이다.
    private func seconds(at now: Date) -> Double {
        guard remaining > 0 else { return 0 }
        let intoSecond = min(1, max(0, now.timeIntervalSince(anchor)))
        return max(0, Double(remaining) - intoSecond)
    }

    private func bar(seconds: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Tokens.paper2)
                Capsule().fill(tint)
                    .frame(width: min(1, max(0, seconds / Double(max(1, total)))) * geo.size.width)
            }
        }
        .frame(height: 8)
    }
}

// MARK: - 퀵 연습 풀이 노트
//
// 캔버스와 격자는 채점 화면과 같은 것(SolutionCanvas·GraphPaper)을 부른다.
// 다만 도구는 채점 화면의 전체 도구막대(선 굵기·올가미·확대·다시 실행)를 그대로
// 가져오지 않는다. 40초 안에 실제로 쓰는 것은 펜·지우개·되돌리기·전체 지우기뿐이고,
// 나머지는 좁은 화면에서 캔버스 높이만 빼앗는다.
private struct QuickSolutionNote: View {
    @Binding var drawing: PKDrawing
    @Binding var tool: SolutionCanvasTool
    @Binding var allowsFinger: Bool
    let height: CGFloat
    /// 짧은 가로 화면에서는 별도 제목 행을 만들지 않고 도구와 같은 줄에 둔다.
    /// nil이면 일반 풀이 노트처럼 도구만 표시한다.
    let toolbarTitle: String?
    let showsToolTitles: Bool
    let showsFingerToggle: Bool
    let showsHelper: Bool
    let canUndo: Bool
    let onUndo: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
            toolbar

            ZStack {
                Rectangle().fill(Tokens.paper)
                GraphPaper()
                SolutionCanvas(
                    drawing: $drawing,
                    allowsFingerDrawing: allowsFinger,
                    selectedTool: tool,
                    inkWidth: 3)
            }
            .frame(height: height)
            .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.md))
            .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.md)
                .strokeBorder(Tokens.line, lineWidth: 1))

            // 무엇으로 쓰는지는 캔버스가 읽어 준다. 여기서는 학생이 직접 겪기 전에는
            // 알 수 없는 두 가지만 적는다.
            if showsHelper {
                Text("여기 쓴 내용은 제출되지 않습니다. 답은 아래 칸에 적어 주세요.")
                    .font(.mMicro).foregroundStyle(Tokens.text3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var toolbar: some View {
        HStack(spacing: Tokens.Space.s2) {
            if let toolbarTitle {
                Text(toolbarTitle)
                    .font(.mCaption)
                    .foregroundStyle(Tokens.text2)
                    .lineLimit(1)
            }
            noteButton("펜", icon: "pencil.tip", selected: tool == .pen) { tool = .pen }
            noteButton("지우개", icon: "eraser", selected: tool == .eraser) { tool = .eraser }
            Spacer(minLength: Tokens.Space.s2)
            noteButton("실행 취소", icon: "arrow.uturn.backward",
                       showsTitle: false, disabled: !canUndo, action: onUndo)
            noteButton("전체 지우기", icon: "trash",
                       showsTitle: false, disabled: drawing.strokes.isEmpty, action: clearDrawing)
            if showsFingerToggle {
                noteButton("손가락으로 쓰기", icon: "hand.draw",
                           showsTitle: false, selected: allowsFinger) { allowsFinger.toggle() }
            }
        }
    }

    private func noteButton(
        _ label: String,
        icon: String,
        showsTitle: Bool = true,
        selected: Bool = false,
        disabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        let titled = showsTitle && showsToolTitles
        return Button(action: action) {
            buttonLabel(label, icon: icon, titled: titled)
                .font(.mCaption)
                .frame(minWidth: 44, minHeight: 44)
                .padding(.horizontal, titled ? Tokens.Space.s2 : 0)
                .foregroundStyle(selected ? Tokens.actionPrimary : Tokens.text2)
                .background(selected ? Tokens.primarySoft : Tokens.surface,
                            in: RoundedRectangle(cornerRadius: Tokens.Radius.sm))
                .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.sm)
                    .strokeBorder(selected ? Tokens.actionPrimary : Tokens.line,
                                  lineWidth: selected ? 1.5 : 1))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.42 : 1)
        .accessibilityLabel(label)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    /// 라벨 스타일이 서로 다른 타입이라 삼항 연산자로는 고를 수 없다.
    @ViewBuilder
    private func buttonLabel(_ label: String, icon: String, titled: Bool) -> some View {
        if titled {
            Label(label, systemImage: icon).labelStyle(.titleAndIcon)
        } else {
            Label(label, systemImage: icon).labelStyle(.iconOnly)
        }
    }

    /// 비우기도 되돌릴 수 있어야 한다. 지우는 순간의 필기는 화면(부모)이 자동으로
    /// 되돌릴 지점에 쌓으므로, 여기서는 비우기만 한다.
    private func clearDrawing() {
        guard !drawing.strokes.isEmpty else { return }
        drawing = PKDrawing()
    }
}
