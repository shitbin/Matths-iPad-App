//  Screens.swift
//  Matths
//
//  문제풀이 / 채점결과 / 평가센터 / 오답노트
//  ipad-demo(PWA)에서 검증한 화면 구성을 SwiftUI 로 옮긴 것.
//
//  구 CurriculumScreen·CurriculumMapScreen은 13과목 CurriculumV2MapScreen으로,
//  구 RankScreen은 RankArenaScreen / GoatArenaScreen으로 교체했다.

import SwiftUI
import PencilKit

// MARK: - 문제 풀이 (세션 모드)

/// hint-core.js 가 이 시각화를 그릴 수 있는가.
///
/// `swift-*` kind 는 **풀이 안무(solution-scenes.js) 전용**이다. hint-core 에는
/// 대응 렌더러가 없어 renderSVG 가 null 을 돌려주고, 힌트 카드는 40pt 빈 상자가 된다.
/// 27차가 네이티브 17유형 전부에 그 kind 를 붙이면서 조건이 무의미해졌다(감사 적발).
func hintCoreCanDraw(_ json: String?) -> Bool {
    guard let json, !json.isEmpty else { return false }
    return !json.contains("\"swift-")
}

struct SolveScreen: View {
    /// 좌우 분할이 가능한 폭인지. 답 입력 위치를 이걸로 가른다.
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var screenshotGuard: ScreenshotGuard
    @State private var drawing = PKDrawing()
    @State private var answer = ""
    @State private var problemHeight: CGFloat = 120
    @State private var pickedKey: String?          // 뱅크 5지선다 선택
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showHint = false            // 복습 시각 힌트 펼침
    @State private var showReplay = false          // 복습 풀이 애니메이션 다시 보기
    @State private var replayHeight: CGFloat = 320
    @State private var hintHeight: CGFloat = 120
    @State private var showInputHelp = false       // 수식 입력 문법 팝오버
    @FocusState private var answerFocused: Bool
    @State private var noteAllowsFinger = UniversalLayoutPolicy.defaultsToFingerDrawing(
        on: UIDevice.current.userInterfaceIdiom == .phone ? .phone : .pad)
    @State private var noteZoom: CGFloat = 1
    @State private var noteTool: SolutionCanvasTool = .pen
    @State private var noteInkWidth: CGFloat = 3
    @State private var noteUndoStack: [PKDrawing] = []
    @State private var noteRedoStack: [PKDrawing] = []
    #if DEBUG
    /// `-solveKeyboardFixture`는 SizeHarness의 낮은 높이와 함께 소프트웨어 키보드가
    /// 열린 iPhone 가로 잔여 공간을 반복 캡처하기 위한 비배포 진입점이다.
    @State private var keyboardVisible = ProcessInfo.processInfo.arguments.contains(
        "-solveKeyboardFixture")
    #else
    @State private var keyboardVisible = false
    #endif

    /// 진행 표시 — 동적 모의고사 중이면 실제 문항 위치
    private var progressInfo: (value: Double, label: String) {
        if !store.exam.isEmpty {
            return (Double(store.examIndex + 1) / Double(store.exam.count),
                    "\(store.examIndex + 1) / \(store.exam.count)")
        }
        return (1, "1 / 1")
    }

    @ViewBuilder var body: some View {
        if store.currentProblem != nil {
            solveContent
        } else {
            LearningDataRecoveryView(
                title: "문제 정보를 불러오지 못했습니다",
                detail: "임시 예시 문제를 대신 보여주지 않았습니다. 학습 목록으로 돌아가 문제를 다시 선택해 주세요.",
                primaryTitle: "학습 목록으로",
                primaryRoute: .curriculum)
        }
    }

    private var solveContent: some View {
        VStack(spacing: 0) {
            SessionBar(progress: progressInfo.value, label: progressInfo.label) {
                // 진행 상태 정리는 스토어가 한 곳에서 한다 (exam 만 비우면
                // 개념 소스 id 가 남아 다음 세션 결과가 엉뚱한 개념에 적립된다)
                store.abandonExam()
            }

            if usesPhoneLandscapeWorkspace {
                phoneLandscapeWorkspace
            } else {
                standardScrollableWorkspace
            }
        }
        .background(Tokens.paper)
        // 문항이 바뀌면 답과 필기를 비운다
        .onChange(of: store.examIndex) {
            answer = ""
            pickedKey = nil
            drawing = PKDrawing()
            noteZoom = 1
            noteUndoStack.removeAll()
            noteRedoStack.removeAll()
            showHint = false
        }
        .onReceive(NotificationCenter.default.publisher(
            for: UIResponder.keyboardWillShowNotification)) { _ in
                keyboardVisible = true
            }
        .onReceive(NotificationCenter.default.publisher(
            for: UIResponder.keyboardWillHideNotification)) { _ in
                keyboardVisible = false
            }
        .onDisappear { keyboardVisible = false }
        // 문제 푸는 중에만 스크린샷 감지가 반응한다.
        // 개념 페이지 캡처는 정상 학습 행동이므로 건드리지 않는다.
    }

    /// iPhone 가로는 폭은 넓지만 세로가 390pt 안팎이다. `ViewThatFits`에 맡기면
    /// 각 칸의 이상적인 너비 때문에 세로 적층으로 물러나고, 학생이 문제와 노트를
    /// 오가며 스크롤해야 했다. 이 문맥은 책을 펼친 것처럼 좌우 고정 작업대를 쓴다.
    private var usesPhoneLandscapeWorkspace: Bool {
        UIDevice.current.userInterfaceIdiom == .phone && verticalSizeClass == .compact
    }

    private var standardScrollableWorkspace: some View {
        ScrollView {
            // 왼손잡이 모드: 노트가 왼쪽 — 쓰는 손이 문제를 가리지 않는 방향으로
            ViewThatFits(in: .horizontal) {
                // 좌우로 나뉘는 폭에서는 답 입력을 **문제 바로 아래**에 둔다.
                // 화면 맨 아래 고정하면 iPad 가로에서 문제와 입력창 사이에
                // 빈 공간이 크게 남고, 학생 시선이 위아래로 길게 왕복한다
                // (사용자가 "위로 이동" 이라고 표시한 그 거리다).
                if store.leftHandedOn {
                    HStack(alignment: .top, spacing: Tokens.Space.s6) {
                        right
                        VStack(alignment: .leading, spacing: Tokens.Space.s4) { left; gradeBar }
                    }
                } else {
                    HStack(alignment: .top, spacing: Tokens.Space.s6) {
                        VStack(alignment: .leading, spacing: Tokens.Space.s4) { left; gradeBar }
                        right
                    }
                }
                // 좁은 폭(아이폰 세로)에서는 세로로 쌓이므로 입력창이 자연히
                // 문제 아래에 온다. 여기서는 하단 고정이 맞다 — 아래 inset 이 그 역할.
                VStack(spacing: Tokens.Space.s6) { left; right }
            }
            .padding(Tokens.Space.s6)
        }
        // 좁은 폭에서만 하단에 고정한다. 손풀이 캔버스에 필기한 뒤 답을 적으러
        // 위로 스크롤해 돌아가는 왕복을 없앤다.
        // safeAreaInset 이라 키보드가 올라오면 바도 함께 올라온다.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if horizontalSizeClass == .compact { gradeBar }
        }
    }

    /// iPhone 가로 전용 한 화면 작업대.
    /// 왼쪽은 문제와 답, 오른쪽은 필기 노트를 맡고 바깥 ScrollView를 두지 않는다.
    /// 44:56 비율은 긴 수학 발문을 읽을 최소 폭과 손가락 필기 폭의 타협점이다.
    private var phoneLandscapeWorkspace: some View {
        GeometryReader { proxy in
            let outer: CGFloat = Tokens.Space.s3
            let gutter: CGFloat = Tokens.Space.s3
            let usableWidth = max(1, proxy.size.width - outer * 2 - gutter)
            let problemWidth = min(390, max(300, usableWidth * 0.44))
            let paneHeight = max(1, proxy.size.height - outer * 2)

            Group {
                if keyboardVisible {
                    // iPhone 가로 소프트웨어 키보드는 화면 절반 이상을 차지한다.
                    // 노트 도구까지 남기면 답 입력은 보여도 발문이 0에 가깝게 접힌다.
                    // 입력 중에는 문제·답 판만 전체 폭으로 열고, 키보드를 닫으면 같은
                    // PKDrawing을 가진 좌우 작업대로 즉시 돌아간다.
                    landscapeKeyboardProblemPane
                        .frame(width: usableWidth, height: paneHeight)
                } else if store.leftHandedOn {
                    HStack(spacing: gutter) {
                        landscapeNotePane(height: paneHeight)
                        landscapeProblemPane
                            .frame(width: problemWidth, height: paneHeight)
                    }
                } else {
                    HStack(spacing: gutter) {
                        landscapeProblemPane
                            .frame(width: problemWidth, height: paneHeight)
                        landscapeNotePane(height: paneHeight)
                    }
                }
            }
            // 접근성 최대 단계는 393pt 높이에서 도구 아이콘과 글자가 서로
            // 겹쳐 조작 자체가 불가능해진다. iPhone 가로 작업대만 표준 최대
            // 단계까지 제한하고, 세로 화면과 iPad의 큰 글자 지원은 건드리지 않는다.
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .padding(outer)
        }
    }

    private var landscapeProblemPane: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
            // 짧은 문항은 그대로 한 화면에 머물고, Dynamic Type·장문 발문처럼
            // 물리적으로 높이를 넘는 경우에만 문제 쪽이 독립적으로 스크롤된다.
            // 문제 높이가 커져도 채점 바를 아래로 밀어내면 5지선다를 골라도
            // 제출할 수 없으므로, 채점 바는 반드시 이 ScrollView 밖에 둔다.
            ScrollView(.vertical) {
                left
            }
            .scrollBounceBehavior(.basedOnSize, axes: .vertical)
            .frame(maxHeight: .infinity, alignment: .top)
            landscapeGradeBar
        }
        .background(Tokens.paper2, in: RoundedRectangle(cornerRadius: Tokens.Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.lg)
                .strokeBorder(Tokens.line, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.lg))
    }

    /// 소프트웨어 키보드가 열린 iPhone 가로의 초저높이 문제 판.
    /// 일반 `left` 카드는 단원 메타+카드 패딩만으로 약 50pt를 써서 180pt 잔여
    /// 화면에서 발문이 사라진다. 이 상태에서만 발문을 직접 그려 그 공간을 돌려준다.
    private var landscapeKeyboardProblemPane: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s1) {
            ScrollView(.vertical) {
                if let problem = store.currentProblem, problem.needsMathTypesetting {
                    ProblemWebView(
                        problem: problem,
                        height: $problemHeight,
                        pickedKey: $pickedKey,
                        usesCompactLandscapeLayout: true)
                        .frame(height: problemHeight)
                        .id("keyboard-\(problem.id)")
                } else if let problem = store.currentProblem {
                    Text(problem.statement)
                        .font(.mCallout).foregroundStyle(Tokens.ink)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, Tokens.Space.s3)
                        .padding(.vertical, Tokens.Space.s1)
                }
            }
            .scrollBounceBehavior(.basedOnSize, axes: .vertical)
            .frame(maxHeight: .infinity, alignment: .top)
            landscapeGradeBar
        }
        .background(Tokens.paper2, in: RoundedRectangle(cornerRadius: Tokens.Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.lg)
                .strokeBorder(Tokens.line, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.lg))
    }

    private func landscapeNotePane(height: CGFloat) -> some View {
        SolutionNote(
            drawing: $drawing,
            allowsFinger: $noteAllowsFinger,
            zoom: $noteZoom,
            selectedTool: $noteTool,
            inkWidth: $noteInkWidth,
            undoStack: $noteUndoStack,
            redoStack: $noteRedoStack,
            constrainedHeight: height,
            showsHeader: true,
            usesCompactToolbar: true)
            .frame(maxWidth: .infinity, maxHeight: height, alignment: .top)
    }

    private var left: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s4) {
            VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                // 동적 생성 문항이면 유형·단원이 함께 나온다.
                // 발제문의 수치·정답은 생성기(네이티브/뱅크)가 회차 시드로 뽑은 것.
                Text(store.currentProblem.map { "\($0.unit) · 예상 \($0.minutes)분" }
                     ?? "응용 · 예상 5분")
                    .font(.mMicro).foregroundStyle(Tokens.text3)
                if let p = store.currentProblem, p.needsMathTypesetting {
                    // 뱅크 문항 — KaTeX 발제문 + 5지선다를 웹뷰로
                    ProblemWebView(
                        problem: p,
                        height: $problemHeight,
                        pickedKey: $pickedKey,
                        usesCompactLandscapeLayout: usesPhoneLandscapeWorkspace)
                        .frame(height: problemHeight)
                        .id(p.id)
                } else if let problem = store.currentProblem {
                    Text(problem.statement)
                        .font(.mBody).foregroundStyle(Tokens.ink)
                        .lineSpacing(6)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .card(padding: usesPhoneLandscapeWorkspace ? Tokens.Space.s3 : Tokens.Space.s6)

            // 답안 입력·채점 버튼은 하단 고정 바(gradeBar)로 갔다 —
            // 캔버스 아래로 스크롤해도 항상 손 닿는 자리에 있어야 한다.

            // 복습 트랙 전용 시각 힌트 — 웹 wrong-note-review 의 힌트 버튼 이식.
            // 첫 풀이에는 노출하지 않는다 (그래프가 답을 반쯤 알려준다).
            // hint-core 가 **그릴 수 있는** 것만 버튼을 띄운다.
            //
            // 27차가 네이티브 17유형 전부에 visualizationJSON(kind: "swift-…")을 붙였는데,
            // 그건 풀이 안무(solution-scenes.js)용이라 hint-core.js 는 그 kind 를 모른다
            // (renderSVG → null). 조건이 visualizationJSON != nil 이었던 탓에 버튼은 뜨고,
            // 누르면 그래프도 문장도 없는 40pt 빈 상자만 열렸다(감사 적발).
            if store.reviewingNoteIDs != nil, let p = store.currentProblem,
               p.hintText != nil || hintCoreCanDraw(p.visualizationJSON) {
                VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                    Button {
                        withAnimation(store.anim(.easeOut(duration: 0.2), reduceMotion)) {
                            showHint.toggle()
                        }
                    } label: {
                        Label(showHint ? "힌트 접기" : "힌트 보기 (그래프)",
                              systemImage: showHint ? "lightbulb.fill" : "lightbulb")
                            .font(.mCaption).foregroundStyle(Tokens.primary)
                    }
                    .buttonStyle(.plain)
                    if showHint {
                        HintWebView(hintText: p.hintText,
                                    visualizationJSON: p.visualizationJSON,
                                    height: $hintHeight)
                            .frame(height: hintHeight)
                            .id("hint-\(p.id)")
                    }
                }
            }

            // 복습 트랙 — 지난번 짚었던 갈라진 단계부터 풀이 애니메이션을 다시 볼 수 있다.
            // ("짚은 단계부터 복습이 시작됩니다" 요청의 복습쪽 반영 — 결과 화면에만 있던 것)
            // 같은 problemID 로 노트가 둘 생길 수 있다 — 졸업한 옛 노트와 다시 틀려 만든
            // 새 노트. 앱의 다른 조회 4곳처럼 졸업분을 걸러야 이 문제의 "지금" 갈라진
            // 단계가 잡힌다(원격 병합으로 순서가 뒤집히면 옛 단계가 재생된다).
            if store.reviewingNoteIDs != nil, let p = store.currentProblem,
               let note = store.wrongNotes.first(where: { $0.problemID == p.id && !$0.isMastered }),
               note.steps.count >= 2 {
                VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                    Button {
                        withAnimation(store.anim(.easeOut(duration: 0.2), reduceMotion)) {
                            showReplay.toggle()
                        }
                    } label: {
                        Label(showReplay ? "풀이 애니메이션 접기"
                              : (note.divergenceStep.map { $0 > 0 ? "\($0)단계(갈라진 곳)부터 풀이 다시 보기"
                                                                  : "풀이 애니메이션 다시 보기" }
                                 ?? "풀이 애니메이션 다시 보기"),
                              systemImage: showReplay ? "pause.circle" : "play.circle")
                            .font(.mCaption).foregroundStyle(Tokens.primary)
                    }
                    .buttonStyle(.plain)
                    if showReplay {
                        // 짚은 단계가 있으면 그 단계부터 시작할 수 있는 쪽(식 변형)으로 간다.
                        // 그림 안무(solution-scene)는 네이티브 계약에 시작 단계가 없어 늘
                        // 1단계부터 재생되므로, 버튼이 약속한 "N단계(갈라진 곳)부터" 를
                        // 지킬 수 없다. 짚은 단계가 없을 때만 생성 파라미터로 그림을 그린다.
                        if let from = note.divergenceStep, from > 0 {
                            SolutionPlayerView(steps: note.steps,
                                               startStep: from,
                                               height: $replayHeight)
                                .frame(height: replayHeight)
                                .id("replay-\(note.id)-\(from)")
                        } else if note.visualizationJSON?.isEmpty == false {
                            SolutionScenePlayerView(
                                visualizationJSON: note.visualizationJSON,
                                steps: note.steps, answer: note.answer,
                                statement: note.statement, height: $replayHeight)
                                .frame(height: replayHeight)
                                .id("replay-scene-\(note.id)")
                        } else {
                            SolutionPlayerView(steps: note.steps,
                                               startStep: 1,
                                               height: $replayHeight)
                                .frame(height: replayHeight)
                                .id("replay-\(note.id)")
                        }
                    }
                }
            }

            // 2026-08-17: 문제 화면의 DEBUG 채점 줄을 없앴다.
            //
            // 우측하단 전역 디버그 바(DebugBar)에 같은 "정답/오답" 칩이 이미 있다.
            // 같은 기능이 두 곳에 있으면서, 문제 화면 쪽은 발문 바로 아래 자리를
            // 차지해 학생이 볼 영역을 밀어냈다. 디버그 도구는 한 곳에 모은다.
            // 필요하면 무당벌레를 눌러 쓴다 — 화면을 상시 점유하지 않는다.
        }
    }

    private var right: some View {
        SolutionNote(
            drawing: $drawing,
            allowsFinger: $noteAllowsFinger,
            zoom: $noteZoom,
            selectedTool: $noteTool,
            inkWidth: $noteInkWidth,
            undoStack: $noteUndoStack,
            redoStack: $noteRedoStack)
    }

    /// 하단 고정 답안 바 — 답 입력 + 채점. 채점 버튼은 전폭이 아니라 220pt 로
    /// 제한한다: 좌우로 긴 iPad 화면에서 전폭 CTA 는 시선 이동 거리만 늘린다.
    private var gradeBar: some View {
        HStack(spacing: Tokens.Space.s3) {
            if store.currentProblem?.isMultipleChoice == true {
                // 뱅크 5지선다 — 보기는 발문 웹뷰 안에서 고른다
                Text("보기를 고른 뒤 채점하세요.")
                    .font(.mCaption).foregroundStyle(Tokens.text3)
                Spacer(minLength: 0)
            } else {
                HStack(spacing: 0) {
                    TextField("답을 입력하세요", text: $answer)
                        .font(.mBody)
                        .textFieldStyle(.plain)
                        .padding(.leading, Tokens.Space.s4)
                        .focused($answerFocused)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        // Return = 채점. submitLabel 만 있고 onSubmit 이 없으면 Return 이
                        // 무언가 할 것처럼 보이는데 키보드만 닫힌다 (감사 1651·1660)
                        .submitLabel(.done)
                        .onSubmit {
                            // 채점 버튼의 disabled 조건과 같은 가드 — 빈 답은 채점하지 않는다
                            guard !answer.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                            grade()
                        }
                    // 7/25 팀 질문 "문제풀때 답이 루트면 어떻게 적어야해?" 의 답 —
                    // 상시 노출 문구는 매 문항 같은 말을 반복하므로 도움말 팝오버로 옮겼다.
                    Button { showInputHelp = true } label: {
                        Image(systemName: "questionmark.circle")
                            .font(.mBody).foregroundStyle(Tokens.text3)
                            .frame(width: 44, height: 52)   // 최소 터치 타깃 44pt
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("답 입력 방법 도움말")
                    .popover(isPresented: $showInputHelp, arrowEdge: .top) {
                        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                            Text("답 입력 방법").font(.mCaption).foregroundStyle(Tokens.text3)
                            Text("정수는 그대로, 분수는 a/b 로 쓰세요.")
                                .font(.mCallout).foregroundStyle(Tokens.text1)
                            Text("루트는 √2, sqrt(2), 2^(1/2) 중 아무거나 쓰셔도 됩니다.")
                                .font(.mCallout).foregroundStyle(Tokens.text1)
                        }
                        .padding(Tokens.Space.s5)
                        .frame(maxWidth: 360, alignment: .leading)
                        .presentationCompactAdaptation(.popover)
                    }
                }
                .frame(minHeight: 52)
                .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
                .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.md)
                    .strokeBorder(answerFocused ? Tokens.primary : Tokens.line, lineWidth: 1.5))
            }

            Button("채점하기", action: grade)
                .buttonStyle(PrimaryButtonStyle())
                .frame(maxWidth: 220)
                .disabled(store.currentProblem?.isMultipleChoice == true
                          ? pickedKey == nil
                          : answer.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, Tokens.Space.s6)
        .padding(.vertical, Tokens.Space.s3)
        .frame(maxWidth: .infinity)
        .background(Tokens.surface)
        .overlay(alignment: .top) { Divider().overlay(Tokens.line) }
    }

    /// iPhone 가로의 300~390pt 문제 칸에 맞춘 제출 바.
    /// 5지선다는 안내문을 선지 바로 아래에서 다시 반복하지 않고 CTA만 남긴다.
    /// 주관식은 버튼 폭을 고정해 답 입력칸이 0으로 눌리지 않게 한다.
    private var landscapeGradeBar: some View {
        HStack(spacing: Tokens.Space.s2) {
            if store.currentProblem?.isMultipleChoice != true {
                HStack(spacing: 0) {
                    TextField("답 입력", text: $answer)
                        .font(.mCallout)
                        .textFieldStyle(.plain)
                        .padding(.leading, Tokens.Space.s3)
                        .focused($answerFocused)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .submitLabel(.done)
                        .onSubmit {
                            guard !answer.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                            grade()
                        }
                    Button { showInputHelp = true } label: {
                        Image(systemName: "questionmark.circle")
                            .font(.mCallout).foregroundStyle(Tokens.text3)
                            .frame(width: 44, height: 48)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("답 입력 방법 도움말")
                    .popover(isPresented: $showInputHelp, arrowEdge: .top) {
                        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                            Text("답 입력 방법").font(.mCaption).foregroundStyle(Tokens.text3)
                            Text("정수는 그대로, 분수는 a/b 로 쓰세요.")
                                .font(.mCallout).foregroundStyle(Tokens.text1)
                            Text("루트는 √2, sqrt(2), 2^(1/2) 중 아무거나 쓰셔도 됩니다.")
                                .font(.mCallout).foregroundStyle(Tokens.text1)
                        }
                        .padding(Tokens.Space.s5)
                        .frame(maxWidth: 360, alignment: .leading)
                        .presentationCompactAdaptation(.popover)
                    }
                }
                .frame(minHeight: 48)
                .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
                .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.md)
                    .strokeBorder(answerFocused ? Tokens.primary : Tokens.line, lineWidth: 1.5))
            }

            Button(store.currentProblem?.isMultipleChoice == true ? "선택한 보기 채점" : "채점",
                   action: grade)
                .buttonStyle(PrimaryButtonStyle())
                .frame(maxWidth: store.currentProblem?.isMultipleChoice == true ? .infinity : 96)
                .disabled(store.currentProblem?.isMultipleChoice == true
                          ? pickedKey == nil
                          : answer.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, Tokens.Space.s3)
        .padding(.vertical, Tokens.Space.s1)
        .frame(maxWidth: .infinity)
        .background(Tokens.surface)
        .overlay(alignment: .top) { Divider().overlay(Tokens.line) }
    }

    /// 채점 — 버튼 탭과 답 입력 필드의 Return 이 같은 액션을 공유한다 (감사 1651·1660)
    private func grade() {
        answerFocused = false
        if let p = store.currentProblem {
            // 동적 문항 — 정답 대조 + 필기 스냅샷(틀리면 오답노트에 저장)
            store.gradeCurrent(input: p.isMultipleChoice ? (pickedKey ?? "") : answer,
                               drawingPNG: drawing.pngForGrading(scale: 1))
        }
    }
}

#if DEBUG
// 2026-08-17: DebugGradeShortcut 을 지웠다.
// 우측하단 전역 디버그 바(DebugBar.swift)가 같은 "정답/오답" 칩을 이미 갖고 있어
// 기능이 두 곳에 있었고, 이쪽은 발문 아래 자리를 상시 점유했다.
// 디버그 도구는 무당벌레 한 곳에 모은다.
#endif

struct SessionBar: View {
    let progress: Double
    let label: String
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: Tokens.Space.s4) {
            Button(action: onClose) {
                Image(systemName: "xmark").font(.mBodyB).foregroundStyle(Tokens.text3)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("나가기")

            ProgressBar(value: progress)
            Text(label).font(.mNumeric).foregroundStyle(Tokens.text3)
        }
        // 세션 모드는 앱 셸의 safeAreaInset을 사용하지 않는다. iPhone 가로에서
        // 좌우 둥근 모서리/센서 영역을 직접 피하지 않으면 닫기와 진행 라벨이 화면
        // 밖으로 반쯤 잘린다. 세로·iPad에서는 기존 16pt 여백만 그대로 남는다.
        .safeAreaPadding(.horizontal, Tokens.Space.s4)
        .padding(.vertical, Tokens.Space.s2)
        .background(Tokens.surface)
        .overlay(alignment: .bottom) { Divider().overlay(Tokens.line) }
    }
}

// MARK: - 채점 결과

struct ResultScreen: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @State private var showPlayer = false          // 짚지 않았을 때의 수동 재생
    @State private var playerHeight: CGFloat = 320
    @State private var playerMode = 0              // 0 = 그림 안무, 1 = 식 변형
    @State private var scenePlayerHeight: CGFloat = 360

    private var usesPhoneLandscapeStickyActions: Bool {
        UIDevice.current.userInterfaceIdiom == .phone && verticalSizeClass == .compact
    }

    @ViewBuilder var body: some View {
        if let grading = store.lastGrading, store.currentProblem != nil {
            // 채점 결과를 값으로 캡처해 이번 렌더 패스 전체가 같은 스냅샷을 쓴다.
            // 계정 전환이나 비동기 복구가 lastGrading을 지우더라도 이미 시작된
            // 하위 뷰 평가가 강제 종료되지 않고, 다음 패스에서 복구 화면으로 간다.
            resultContent(grading: grading)
        } else {
            LearningDataRecoveryView(
                title: "채점 결과를 불러오지 못했습니다",
                detail: "저장되지 않은 예시 결과로 화면을 채우지 않았습니다. 학습 목록에서 문제를 다시 열어 주세요.",
                primaryTitle: "학습 목록으로",
                primaryRoute: .curriculum)
        }
    }

    private func resultContent(grading: GradingResult) -> some View {
        VStack(spacing: 0) {
            SessionBar(progress: 1, label: "채점 결과") { store.route = .home }

            ScrollView {
                VStack(alignment: .leading, spacing: Tokens.Space.s6) {
                    verdictHeader(grading: grading)
                    if let guidance = store.coachGuidance {
                        CoachBubble(guidance: guidance)
                    } else if let line = store.coachLine, !line.isEmpty {
                        CoachBubble(guidance: CoachGuidance(
                            observation: line,
                            reason: "디버그 화면에서 선택한 코치 상태입니다.",
                            nextAction: "실제 문항을 채점하면 문제 맥락에 맞는 안내로 바뀝니다."
                        ))
                    }
                    stepList(grading: grading)
                    feedbackCard(grading: grading)
                    // 검수 캡처 모드에서는 디버그 빌드라도 그리지 않는다 (R-01)
                    #if DEBUG
                    if !RuntimeMode.isReviewCapture,
                       let p = store.currentProblem,
                       let review = store.latestCheatingReview(problemID: p.id,
                                                               source: .practiceDrawing) {
                        CheatingReviewDebugCard(record: review)
                    }
                    #endif
                    // 완답이면 짚을 갈림길이 없다. 해설이 한 덩어리(뱅크)면 짚을 단계도 없다.
                    if grading.overall != .correct && stepCount >= 2 {
                        reasonTagCard
                    }
                    // 틀린 이유 7종 (웹 errorType) — 오답노트 필터의 축이 된다
                    if grading.overall != .correct {
                        errorTypeCard
                    }
                    // 풀이 애니메이션 — 짚은 단계부터 수치 그대로 재생.
                    // 단계를 짚는 순간 자동으로 등장한다 (그냥 복습으로 떠넘기지 않는다).
                    if grading.overall != .correct && stepCount >= 2 {
                        solutionPlayerCard
                    }
                    // 복습 문항을 맞혔다 — 같은 유형 새 수치로 확인 (웹 변형 재출제)
                    if grading.overall == .correct, store.reviewingNoteIDs != nil,
                       let p = store.currentProblem, ProblemType(rawValue: p.typeKey) != nil {
                        variationCard(typeKey: p.typeKey)
                    }

                    // 온디바이스 AI — 모의고사 진행 중에는 흐름을 끊지 않도록 숨긴다
                    if store.exam.isEmpty, let p = store.currentProblem {
                        Button {
                            store.openChatAbout(problem: p.statement,
                                                myAnswer: store.lastStudentInput,
                                                correct: p.answer)
                        } label: {
                            Label("AI 튜터에게 이 문제 물어보기", systemImage: "sparkles")
                                .font(.mCaption).foregroundStyle(Tokens.primary)
                                .padding(.horizontal, Tokens.Space.s3).padding(.vertical, 6)
                                .overlay(Capsule().strokeBorder(Tokens.primary, lineWidth: 1.2))
                        }
                        .buttonStyle(.plain)
                    }

                    if !usesPhoneLandscapeStickyActions {
                        resultActionRow(grading: grading)
                            .padding(.top, Tokens.Space.s2)
                    }
                }
                .padding(Tokens.Space.s6)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if usesPhoneLandscapeStickyActions {
                resultActionRow(grading: grading)
                    // 접근성 최대 글자 크기를 그대로 쓰면 두 버튼만으로 화면 높이의
                    // 절반 가까이를 덮는다. 세션 진행 바는 xxxLarge까지 보장하고,
                    // 원문 크기의 상세 설명은 위 ScrollView에서 그대로 제공한다.
                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                    .safeAreaPadding(.horizontal, Tokens.Space.s4)
                    .padding(.vertical, Tokens.Space.s2)
                    .background(Tokens.surface)
                    .overlay(alignment: .top) { Divider().overlay(Tokens.line) }
            }
        }
        .background(Tokens.paper)
        // 오답 직후 비전 검토가 끝날 때까지, 방금 쓴 풀이를 결과 위에 보존한다.
        // 완료 판정이나 채점에는 관여하지 않고 pending 기록이 끝나면 자동으로 사라진다.
        .overlay {
            GeometryReader { proxy in
                if grading.overall != .correct,
                   let problem = store.currentProblem,
                   let review = store.latestCheatingReview(
                        problemID: problem.id,
                        source: .practiceDrawing),
                   review.state == .pending,
                   review.imageFile != nil {
                    StudentSolutionAnalysisFloatingCard(record: review)
                        .frame(width: min(300, max(220, proxy.size.width - 32)))
                        .padding(.top, 68)
                        .padding(.trailing, 16)
                        .frame(
                            maxWidth: .infinity,
                            maxHeight: .infinity,
                            alignment: .topTrailing)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                        .zIndex(20)
                }
            }
        }
        .animation(
            store.anim(.easeOut(duration: 0.24), reduceMotion),
            value: store.cheatingReviews)
    }

    /// 세션을 진행하는 버튼은 결과 설명의 길이와 무관하게 손에 닿아야 한다.
    /// 일반 화면에서는 문서 끝에 놓고, iPhone 가로에서는 위 safeAreaInset이 같은
    /// 행을 하단에 고정한다.
    private func resultActionRow(grading: GradingResult) -> some View {
        HStack(spacing: Tokens.Space.s3) {
            if !store.exam.isEmpty {
                Button(store.examIndex + 1 < store.exam.count
                       ? "다음 문항 (\(store.examIndex + 2)/\(store.exam.count))"
                       : "평가 끝내기") { store.advanceExam() }
                    .buttonStyle(PrimaryButtonStyle()).frame(maxWidth: 240)
                Button("다시 풀기") { store.route = .solve }
                    .buttonStyle(SecondaryButtonStyle())
            } else {
                Button("다시 풀기") { store.route = .solve }
                    .buttonStyle(PrimaryButtonStyle()).frame(maxWidth: 200)
                Button("개념 다시 보기") {
                    store.openRelevantConceptV2(typeKey: store.currentProblem?.typeKey)
                }
                .buttonStyle(SecondaryButtonStyle())
            }
            Spacer(minLength: Tokens.Space.s2)
            if !usesPhoneLandscapeStickyActions {
                // 실제 상태를 말한다 — 정답이면 오답노트에 넣지 않고(gradeCurrent 의
                // `else if !ok` 가드), 최초 복습은 3일이 아니라 **당일**이다.
                Text(grading.overall != .correct
                     ? "오답노트에 저장됨 · 오늘 다시 복습"
                     : "정답 · 오답노트에 담지 않습니다")
                    .font(.mCaption).foregroundStyle(Tokens.text3)
                    .lineLimit(1).minimumScaleFactor(0.8)
            }
        }
    }

    // 성적표 머리 — 색 상자도, 색 테두리 바도 없다.
    // (카드 왼쪽의 색 막대는 "AI 로 만든 화면" 을 알아보는 가장 확실한 단서로 꼽힌다.)
    // 판정은 글자와 세리프 점수로 말하고, 밑에 이중 괘선을 긋는다.
    private func verdictHeader(grading: GradingResult) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s3) {
            HStack(alignment: .lastTextBaseline, spacing: Tokens.Space.s4) {
                // 판정 Lottie (체크 드로우 / X + 흔들림) — 모션 켬일 때만. 라벨은 항상 있다.
                if store.motionOn && !reduceMotion,
                   grading.overall == .correct || grading.overall == .incorrect {
                    LottieWebView(name: grading.overall == .correct
                                  ? "lottie-correct" : "lottie-wrong")
                        .frame(width: 52, height: 52)
                        .alignmentGuide(.lastTextBaseline) { $0[VerticalAlignment.center] + 22 }
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(grading.overall.koreanLabel).font(.mTitle).foregroundStyle(Tokens.ink)
                    Text(subtitle(for: grading)).font(.mCallout).foregroundStyle(Tokens.text2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                if let pts = grading.awardedPoints {
                    VStack(alignment: .trailing, spacing: 0) {
                        Text("부분점수").font(.mMicro).foregroundStyle(Tokens.text3)
                        (Text("\(Int(pts))").font(.mStatLarge).foregroundStyle(accent(for: grading))
                         + Text(" / 4").font(Font.stat(18)).foregroundStyle(Tokens.text3))
                    }
                }
            }
            ExamRule()
        }
    }

    private func stepList(grading: GradingResult) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionRule(title: store.currentProblem?.needsMathTypesetting == true ? "해설" : "단계별 채점")
                .padding(.bottom, Tokens.Space.s2)
            if let p = store.currentProblem, p.needsMathTypesetting {
                // isTex 는 "수식 조판이 필요하다"는 뜻이지 "해설이 한 덩어리"라는
                // 뜻이 아니다. WebGen 은 한 문단을 의미 단계로 나눈 뒤에도 isTex=true라,
                // steps.first 만 넘기면 두 번째 단계부터 조용히 사라진다. 각 단계를 같은
                // KaTeX 인라인 렌더러로 그려 수식은 살리고 단계는 하나도 버리지 않는다.
                ForEach(Array(p.steps.enumerated()), id: \.offset) { index, text in
                    if index > 0 { DottedRule() }
                    HStack(alignment: .top, spacing: Tokens.Space.s4) {
                        CircledNumber(n: index + 1, color: Tokens.text3)
                        MathInline(
                            text: text,
                            font: .system(.callout, design: .serif),
                            color: Tokens.ink,
                            pixelSize: 17
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.vertical, Tokens.Space.s3)
                }
            } else {
            ForEach(Array(grading.stepResults.enumerated()), id: \.element.id) { i, step in
                if i > 0 { DottedRule() }
                HStack(alignment: .top, spacing: Tokens.Space.s4) {
                    // 수능 원문자 — 단계 번호가 곧 상태색을 입는다
                    CircledNumber(n: step.step, color: stepColor(step.verdict))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(stepText(step.step))
                            .font(.system(.callout, design: .serif))
                            .foregroundStyle(Tokens.ink)
                        Text(step.comment).font(.mCaption).foregroundStyle(Tokens.text3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Image(systemName: stepIcon(step.verdict))
                        .font(.mCaption).foregroundStyle(stepColor(step.verdict))
                }
                .padding(.vertical, Tokens.Space.s4)
                .opacity(step.verdict == .unverifiable ? 0.6 : 1)
            }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func feedbackCard(grading: GradingResult) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s3) {
            SectionRule(title: "피드백")
            Text(grading.feedback).font(.mBody).foregroundStyle(Tokens.text1)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // 어느 단계에서 갈라졌는지 — 추상적인 사유 태그("계산 실수" 등) 대신
    // 풀이 단계 자체를 버튼으로 짚게 한다. 학생이 짚은 단계가
    // firstErrorStep 후보가 되고, 복습이 그 단계부터 다시 시작된다.
    private var reasonTagCard: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s3) {
            SectionRule(title: "어느 단계에서 갈라졌나요? · 짚은 단계부터 복습이 시작됩니다")

            VStack(spacing: Tokens.Space.s2) {
                ForEach(1...stepCount, id: \.self) { i in
                    stepPickRow(i)
                }
                // 어디서 갈라졌는지 자체를 모르는 것도 정보다 —
                // 이 경우 복습은 1단계(개념)부터 시작한다.
                Button {
                    store.setDivergence(0)
                } label: {
                    HStack {
                        Text("어디서 갈라졌는지 모르겠어요")
                            .font(.mCallout)
                            .foregroundStyle(store.divergenceStep == 0 ? Tokens.primary : Tokens.text3)
                        Spacer()
                        if store.divergenceStep == 0 {
                            Image(systemName: "checkmark").font(.mCaption).foregroundStyle(Tokens.primary)
                        }
                    }
                    .padding(Tokens.Space.s3)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background(store.divergenceStep == 0 ? Tokens.primarySoft : Tokens.surface,
                            in: RoundedRectangle(cornerRadius: Tokens.Radius.sm))
                .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.sm)
                    .strokeBorder(store.divergenceStep == 0 ? Tokens.primary : Tokens.line, lineWidth: 1.2))
            }

            if let picked = store.divergenceStep {
                Text(picked == 0
                     ? "1단계 개념부터 차근차근 복습으로 잡았습니다."
                     : "\(picked)단계부터 다시 짚는 복습으로 잡았습니다. 오답노트에 함께 저장됩니다.")
                    .font(.mCaption).foregroundStyle(Tokens.successInk)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 풀이 애니메이션 — 갈라진 단계를 짚으면 그 단계부터, 안 짚었으면 버튼으로 1단계부터.
    /// 수치는 이 회차 생성 값 그대로 (시드가 바뀌면 숫자만 바뀐 같은 안무).
    @ViewBuilder private var solutionPlayerCard: some View {
        // 폴백을 stepCount·stepText 와 같은 소스로 맞춘다 (데모 채점 화면에서
        // 단계는 4개 보이는데 무대만 비어 재생이 즉사하던 불일치)
        let steps = store.currentProblem?.steps ?? []
        VStack(alignment: .leading, spacing: Tokens.Space.s3) {
            SectionRule(title: "풀이 다시 보기 · 이 회차 수치 그대로")
            if store.divergenceStep != nil || showPlayer {
                // 그림 안무(유형별)와 식 변형(항 단위) 중 고른다.
                // 그림 쪽은 이 회차의 생성 파라미터로 그려지므로 시드가 바뀌면
                // 같은 안무에 수치만 달라진다.
                Picker("풀이 보기 방식", selection: $playerMode) {
                    Text("그림으로").tag(0)
                    Text("식으로").tag(1)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 260)

                if playerMode == 0 {
                    SolutionScenePlayerView(
                        visualizationJSON: store.currentProblem?.visualizationJSON,
                        steps: steps,
                        answer: store.currentProblem?.answer,
                        statement: store.currentProblem?.statement,
                        height: $scenePlayerHeight)
                        .frame(height: scenePlayerHeight)
                        .id("scene-\(store.currentProblem?.id ?? "")")
                } else {
                SolutionPlayerView(steps: steps,
                                   startStep: max(1, store.divergenceStep ?? 1),
                                   height: $playerHeight)
                    .frame(height: playerHeight)
                    .id("player-\(store.currentProblem?.id ?? "")-\(store.divergenceStep ?? 0)")
                }
                Text(playerCaption)
                    .font(.mCaption).foregroundStyle(Tokens.text3)
            } else {
                Button {
                    withAnimation(store.anim(.easeOut(duration: 0.2), reduceMotion)) {
                        showPlayer = true
                    }
                } label: {
                    Label("풀이 애니메이션 재생", systemImage: "play.circle")
                        .font(.mBodyB)
                }
                .buttonStyle(SecondaryButtonStyle())
                Text("위에서 갈라진 단계를 짚으면 그 단계부터 자동으로 재생됩니다.")
                    .font(.mCaption).foregroundStyle(Tokens.text3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // 단계를 짚는 순간 "그 단계부터" 를 지킬 수 있는 쪽으로 무대를 연다
        .onAppear { syncPlayerMode() }
        .onChange(of: store.divergenceStep) { syncPlayerMode() }
    }

    /// 짚은 단계가 있으면 식 변형(1)으로 연다.
    /// 그림 안무는 solution-scene 네이티브 계약({kind, viz, steps, answer, statement})에
    /// 시작 단계가 아예 없어 언제나 1단계부터 재생된다 — 그림을 기본으로 두면
    /// "짚는 순간 그 단계부터" 라는 약속이 기본 진입 경로에서 조용히 무효가 된다.
    private func syncPlayerMode() {
        if let picked = store.divergenceStep, picked > 0 { playerMode = 1 }
    }

    /// 안내문은 지금 실제로 재생되는 위치만 말한다 —
    /// 그림 쪽을 고른 사용자에게 "N단계부터 재생 중" 이라고 하면 거짓 표시가 된다.
    private var playerCaption: String {
        guard let picked = store.divergenceStep else { return "1단계부터 전체 재생 중입니다." }
        if picked == 0 { return "1단계 개념부터 전체 재생 중입니다." }
        return playerMode == 1
            ? "\(picked)단계부터 재생 중 — 이전 단계는 흐리게 보입니다."
            : "그림 안무는 1단계부터 재생됩니다 — \(picked)단계부터 보려면 ‘식으로’ 를 고르세요."
    }

    /// 틀린 이유 선택 — 갈라진 단계(어디서)와 별개로 "왜" 를 남긴다
    @ViewBuilder private var errorTypeCard: some View {
        let current = store.currentProblem.flatMap { p in
            store.wrongNotes.first { $0.problemID == p.id && !$0.isMastered }?.errorType
        }
        VStack(alignment: .leading, spacing: Tokens.Space.s3) {
            SectionRule(title: "왜 틀렸다고 생각하나요? · 오답노트에서 이유별로 모아 봅니다")
            FlowChips(items: WrongErrorType.allCases.map { ($0.rawValue, $0.label) },
                      selected: current) { raw in
                if let t = WrongErrorType(rawValue: raw) { store.setErrorType(t) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func variationCard(typeKey: String) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
            SectionRule(title: "확인 한 번 더")
            Text("복습을 통과했습니다. 같은 유형을 새 수치로 한 번 더 풀어 정말 잡혔는지 확인해 보세요.")
                .font(.mCallout).foregroundStyle(Tokens.text2)
                .fixedSize(horizontal: false, vertical: true)
            Button("같은 유형 새 수치로 풀기") { store.startVariationCheck(typeKey: typeKey) }
                .buttonStyle(SecondaryButtonStyle())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var stepCount: Int {
        store.currentProblem?.steps.count ?? 0
    }

    private func stepPickRow(_ i: Int) -> some View {
        let picked = store.divergenceStep == i
        return Button {
            store.setDivergence(i)      // 오답노트 항목에도 기록된다
        } label: {
            HStack(alignment: .top, spacing: Tokens.Space.s3) {
                CircledNumber(n: i, color: picked ? Tokens.primary : Tokens.text3)
                // 같은 화면 위쪽 "단계별 채점/해설" 이 이 단계 문장을 이미 전문으로
                // 보여줬다. 여기는 **고르는 자리**라 문장이 식별만 되면 된다 —
                // 전문을 두 번 깔면 같은 글을 두 번 읽히는 화면이 된다.
                // 그래서 여기는 요약(최대 두 줄), 전문은 위 목록 한 곳으로 둔다.
                // 잘라낸 뒷부분은 보이스오버 라벨에 되살린다(KiceExamRow 와 같은 규칙).
                Text(stepText(i))
                    .font(.system(.callout, design: .serif))
                    .foregroundStyle(Tokens.ink)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if picked {
                    Text("여기서부터").font(.mMicro).foregroundStyle(Tokens.primary)
                        .padding(.top, 4)
                }
            }
            .padding(Tokens.Space.s3)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(picked ? Tokens.primarySoft : Tokens.surface,
                    in: RoundedRectangle(cornerRadius: Tokens.Radius.sm))
        .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.sm)
            .strokeBorder(picked ? Tokens.primary : Tokens.line, lineWidth: 1.2))
        .accessibilityLabel("\(i)단계 \(stepText(i)), 여기서 갈라짐\(picked ? ", 선택됨" : "")")
    }

    // 표시 헬퍼
    private func accent(for grading: GradingResult) -> Color {
        switch grading.overall {
        case .correct: return Tokens.success
        case .answerOnly, .partiallyCorrect: return Tokens.warning
        default: return Tokens.text4
        }
    }
    private func subtitle(for grading: GradingResult) -> String {
        switch grading.overall {
        case .answerOnly: return "최종 답은 정답과 같지만, 중간에 성립하지 않는 식이 있습니다."
        case .correct:    return "풀이 흐름이 일관되게 성립합니다."
        default:          return "풀이를 다시 확인해 보세요."
        }
    }
    private func stepText(_ i: Int) -> String {
        // 동적 문항이면 생성기가 계산한 모범 풀이 단계를 쓴다.
        //
        // MathText.plain 을 거치는 이유: 이 행은 SwiftUI Text 라 KaTeX 를 못 쓴다.
        // 원문을 그대로 두면 "$f(1)$와 무관하게 극한값은 $-3$입니다" 처럼 달러 기호가
        // 그대로 노출된다 — 바로 위 해설은 웹뷰로 조판되는데 여기만 소스가 보였다
        // (2026-07-29 시뮬 확인). 근사 조판이라도 읽을 수 있는 꼴로 맞춘다.
        if let p = store.currentProblem {
            return i - 1 < p.steps.count ? MathText.plain(p.steps[i - 1]) : "·"
        }
        return "풀이 단계 정보를 불러오지 못했습니다."
    }
    private func stepIcon(_ v: StepVerdict) -> String {
        switch v {
        case .correct: return "checkmark"
        case .incorrect: return "exclamationmark"
        case .unverifiable: return "minus"
        case .irrelevant: return "questionmark"
        }
    }
    private func stepColor(_ v: StepVerdict) -> Color {
        switch v {
        case .correct: return Tokens.success
        case .incorrect: return Tokens.warning
        default: return Tokens.text4
        }
    }
}

/// 실제 학습/채점 데이터가 유실된 경우의 명시적 복구 화면.
/// 릴리스에서 SampleData를 조용히 노출하면 학생의 실제 기록처럼 보이므로,
/// 안전한 목적지로 돌아갈 수 있게 하고 원인을 숨기지 않는다.
private struct LearningDataRecoveryView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let title: String
    let detail: String
    let primaryTitle: String
    let primaryRoute: AppStore.Route

    var body: some View {
        GeometryReader { viewport in
            let compactLandscape = viewport.size.width > viewport.size.height
                && viewport.size.height < 500

            VStack(spacing: 0) {
                SessionBar(progress: 0, label: "학습 복구") { store.route = .home }
                recoveryCard(isCompactLandscape: compactLandscape)
                    .frame(maxWidth: 620, alignment: .leading)
                    .card()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(compactLandscape ? Tokens.Space.s3 : Tokens.Space.s6)
            }
            // 자식의 최소 높이가 순간적으로 뷰포트를 넘어도 VStack의 중심 정렬이
            // 닫기 바를 위로 밀어내지 못하게 세션 루트를 물리 뷰포트에 고정한다.
            .frame(
                width: viewport.size.width,
                height: viewport.size.height,
                alignment: .top)
        }
        .background(Tokens.paper)
    }

    /// 복구 화면은 실패 상태라서 가장 먼저 '빠져나갈 수 있어야' 한다. iPhone 가로의
    /// 짧은 높이에서 세로 카드의 최소 높이가 화면보다 커지면 VStack이 상단 바까지
    /// 화면 밖으로 밀어 냈다. 보통 글자 크기에서는 설명과 행동을 좌우로 놓아 스크롤
    /// 없이 끝낸다. 접근성 글자 크기에서도 행동은 우측에 고정하고 긴 설명만 좌측에서
    /// 스크롤해, 복구 버튼을 찾으려고 먼저 화면을 밀어야 하는 막다른 상태를 없앤다.
    @ViewBuilder private func recoveryCard(isCompactLandscape: Bool) -> some View {
        if isCompactLandscape {
            HStack(alignment: .center, spacing: Tokens.Space.s5) {
                Group {
                    if dynamicTypeSize.isAccessibilitySize {
                        ScrollView {
                            recoveryMessage(isCompactLandscape: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    } else {
                        recoveryMessage(isCompactLandscape: true)
                    }
                }
                Spacer(minLength: Tokens.Space.s3)
                recoveryActions
                    .frame(width: dynamicTypeSize.isAccessibilitySize ? 232 : 184)
            }
            .padding(dynamicTypeSize.isAccessibilitySize ? Tokens.Space.s3 : Tokens.Space.s5)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: Tokens.Space.s5) {
                    recoveryMessage(isCompactLandscape: isCompactLandscape)
                    recoveryActions
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Tokens.Space.s6)
            }
        }
    }

    private func recoveryMessage(isCompactLandscape: Bool) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s3) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: isCompactLandscape ? 28 : 34, weight: .semibold))
                .foregroundStyle(Tokens.primary)
                .accessibilityHidden(true)
            Text(title)
                .font(.mHeading)
                .foregroundStyle(Tokens.ink)
                .accessibilityAddTraits(.isHeader)
            Text(detail)
                .font(.mBody)
                .foregroundStyle(Tokens.text2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var recoveryActions: some View {
        VStack(spacing: Tokens.Space.s3) {
            Button { store.route = primaryRoute } label: {
                Text(primaryTitle)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
            }
                .buttonStyle(PrimaryButtonStyle())
            Button { store.route = .home } label: {
                Text("홈으로")
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
            }
                .buttonStyle(SecondaryButtonStyle())
        }
    }

}

// MARK: - 코치 말풍선
//
// 채점 직후 관찰 → 점검 이유 → 다음 행동만 보여 준다.
// 수위는 정보의 직설성만 바꾸며, 랜덤 조롱 문구를 결과의 중심에 놓지 않는다.

struct CoachBubble: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let guidance: CoachGuidance
    @State private var revealedTurnCount = 0
    /// 흐르는 글자를 건너뛰고 전문을 바로 보기(말풍선 탭). 채점이 바뀌면 초기화된다.
    /// 스트리밍은 연출이지 관문이 아니다 — 급한 학생이 기다리게 두지 않는다.
    @State private var skipStreaming = false

    private var turns: [CoachPresentationTurn] {
        CoachPresentationTurn.make(from: guidance)
    }

    /// 글자 흐름 연출을 켤지. 동작 줄이기(시스템)·모션 스위치(앱)·건너뛰기 탭이 각각 끈다.
    private var streams: Bool { !reduceMotion && store.motionOn && !skipStreaming }

    /// 한 턴에 허용하는 흐름 시간(초).
    ///
    /// WHY 턴마다 고정값이 아닌가 — 코치 대사는 문장 수가 들쭉날쭉하다(관찰·점검·다음이
    /// 각각 1~3문장으로 쪼개진다). 턴당 고정 0.9초를 주면 6턴짜리 대사는 5.4초 동안
    /// 학생을 붙잡는다. 그래서 **전체 예산을 턴 수로 나눠** 대사가 길수록 빨리 흐르게 한다.
    /// 상한을 두는 이유는 반대쪽 — 한 턴짜리 짧은 대사가 3.2초를 다 쓰면 늘어진다.
    private var streamBudget: Double {
        min(1.0, 3.2 / Double(max(1, turns.count)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
            HStack {
                Text("맵쓰 코치").font(.mCaption).foregroundStyle(Tokens.text3)
                Spacer()
                // 웹·서버와 같은 순한맛 / 매운맛 / 무음
                Menu {
                    Picker("코치 수위", selection: $store.coach.level) {
                        ForEach(SpiceLevel.allCases) { lv in
                            Text(lv.name).tag(lv)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(store.coach.level.name).font(.mCaption)
                        Image(systemName: "chevron.down").font(.mMicro)
                    }
                    .foregroundStyle(Tokens.primary)
                }
            }

            CoachCharacterView(level: store.coach.level)

            VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                ForEach(Array(turns.enumerated()), id: \.element.id) { index, turn in
                    if index < revealedTurnCount {
                        CoachMessageBubble(
                            turn: turn,
                            streams: streams,
                            budget: streamBudget,
                            onFinished: { revealNextTurn(after: index) })
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
            }
            // 말풍선 어디를 눌러도 전문으로 건너뛴다. 수위 메뉴는 위쪽 헤더에 있어
            // 이 제스처와 겹치지 않는다.
            .contentShape(Rectangle())
            .onTapGesture {
                guard streams else { return }
                skipStreaming = true
                revealedTurnCount = turns.count
            }
            .accessibilityAddTraits(.isStaticText)

            // 학습 온도 — 오답이 쌓이면 설명을 더 직접적으로 바꾼다
            HStack(spacing: Tokens.Space.s3) {
                ProgressBar(value: store.coach.shuProgress,
                            tint: Tokens.primary, track: Tokens.paper2)
                    .frame(maxWidth: 130)
                Text(store.coach.shuLabel).font(.mMicro).foregroundStyle(Tokens.text3)
                if store.coach.softened {
                    Text("완화 모드").font(.mMicro).foregroundStyle(Tokens.successInk)
                }
            }
        }
        .card()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("맵쓰 코치. \(guidance.accessibilityText)")
        .task(id: guidance) {
            skipStreaming = false
            let count = turns.count
            guard count > 0 else {
                revealedTurnCount = 0
                return
            }
            if reduceMotion || !store.motionOn {
                revealedTurnCount = count
                return
            }
            // 종전에는 여기서 **턴 전체를 90ms 간격으로 통째로** 띄웠다. 감독 피드백:
            // "텍스트가 한번에 딱 나오는거 말고, 마치 실시간으로 토큰이 출력되는것처럼
            // 애니메이팅 해두셈." 그래서 이 루프는 첫 턴만 열고, 그다음부터는 **글자가
            // 다 흐른 턴이 스스로 다음 턴을 연다**(onFinished → revealNextTurn).
            // 타이머가 아니라 실제 출력 진행이 리듬을 정해야 스트리밍처럼 읽힌다.
            revealedTurnCount = 0
            do {
                try await Task.sleep(nanoseconds: 90_000_000)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.18)) {
                revealedTurnCount = 1
            }
        }
    }

    /// 방금 글자가 다 흐른 턴 다음 턴을 연다.
    ///
    /// 가드가 두 개인 이유: ① 건너뛰기로 전 턴이 한꺼번에 열리면 모든 말풍선이
    /// 동시에 끝났다고 알려 온다 — 지금 **맨 끝** 턴만 다음을 열 자격이 있다.
    /// ② 이미 다 열렸으면 아무 일도 하지 않는다.
    private func revealNextTurn(after index: Int) {
        guard index + 1 == revealedTurnCount, revealedTurnCount < turns.count else { return }
        withAnimation(.easeOut(duration: 0.18)) {
            revealedTurnCount += 1
        }
    }
}

private struct CoachCharacterView: View {
    let level: SpiceLevel
    @EnvironmentObject private var store: AppStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var species = "goat"
    @State private var frame = 1

    private var sourceURL: URL? {
        guard level != .silent else { return nil }
        return URL(
            string: "/images/coach-characters/\(level.rawValue)-\(species)-\(frame).webp",
            relativeTo: ServerAPI.baseURL)?.absoluteURL
    }

    var body: some View {
        Group {
            if let sourceURL {
                AsyncImage(url: sourceURL) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFit()
                    } else {
                        Color.clear
                    }
                }
                .frame(width: 88, height: 88)
                .accessibilityHidden(true)
            }
        }
        .task(id: "\(level.rawValue)|\(reduceMotion)|\(store.motionOn)") {
            guard level != .silent else { return }
            species = ["goat", "pigeon", "llama"].randomElement() ?? "goat"
            frame = 1
            guard !reduceMotion, store.motionOn else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled else { return }
                frame = frame % 3 + 1
            }
        }
    }
}

private struct CoachPresentationTurn: Identifiable {
    let id: String
    let phase: String?
    let text: String

    static func make(from guidance: CoachGuidance) -> [CoachPresentationTurn] {
        let phases = [
            ("관찰", stripOwnedPrefix(guidance.observation,
                                    prefixes: ["관찰:", "관찰 ·"])),
            ("점검", stripOwnedPrefix(guidance.reason,
                                    prefixes: ["점검 순서:", "점검 순서 ·", "점검:", "점검 ·"])),
            ("다음", stripOwnedPrefix(guidance.nextAction,
                                    prefixes: ["다음 행동:", "다음 행동 ·", "다음:", "다음 ·"])),
        ]
        return phases.flatMap { phase in
            let (label, text) = phase
            return chunks(text).enumerated().map { index, chunk in
                CoachPresentationTurn(
                    id: "\(label)-\(index)",
                    phase: index == 0 ? label : nil,
                    text: chunk)
            }
        }
    }

    /// 과거 디버그 값이나 복원 데이터에 접두사가 남아 있어도 UI 단계명과 두 번
    /// 읽히지 않게 경계에서 한 번만 걷는다. 일반 단어 `관찰값`은 건드리지 않는다.
    private static func stripOwnedPrefix(_ source: String, prefixes: [String]) -> String {
        let text = source.trimmingCharacters(in: .whitespacesAndNewlines)
        for prefix in prefixes where text.hasPrefix(prefix) {
            return String(text.dropFirst(prefix.count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return text
    }

    /// 정보는 버리지 않고 문장 및 ①·② 경계만 대화 턴으로 바꾼다. 임의 글자 수로
    /// 자르면 조사나 수식이 떨어져 나가므로 길이 기반 절단은 하지 않는다.
    private static func chunks(_ source: String) -> [String] {
        let normalized = source
            .replacingOccurrences(of: "①", with: "\n①")
            .replacingOccurrences(of: "②", with: "\n②")
            .replacingOccurrences(of: "③", with: "\n③")
            .split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let markerChunks = normalized.isEmpty ? [source] : normalized
        let sentences = markerChunks.flatMap(splitSentences)
        return sentences.isEmpty ? [source] : sentences
    }

    private static func splitSentences(_ source: String) -> [String] {
        let characters = Array(source)
        var output: [String] = []
        var buffer = ""
        for (index, character) in characters.enumerated() {
            buffer.append(character)
            let decimalPoint = character == "."
                && index > 0 && index + 1 < characters.count
                && characters[index - 1].isNumber && characters[index + 1].isNumber
            if !decimalPoint && (character == "." || character == "?" || character == "!") {
                let sentence = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
                if !sentence.isEmpty { output.append(sentence) }
                buffer = ""
            }
        }
        let tail = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
        if !tail.isEmpty { output.append(tail) }
        return output
    }
}

private struct CoachMessageBubble: View {
    let turn: CoachPresentationTurn
    /// false 면 전문을 즉시 그린다(동작 줄이기·모션 끔·건너뛰기).
    var streams: Bool = false
    /// 이 말풍선 하나가 다 흐르는 데 쓸 시간(초).
    var budget: Double = 0.9
    /// 글자가 다 흐른 순간. 부모가 다음 말풍선을 여는 신호로 쓴다.
    var onFinished: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s1) {
            if let phase = turn.phase {
                Text(phase)
                    .font(.mMicro.weight(.bold))
                    .foregroundStyle(Tokens.primaryDark)
                    .padding(.horizontal, Tokens.Space.s2)
                    .padding(.vertical, 4)
                    .background(Tokens.primarySoft, in: Capsule())
            }
            StreamingCoachText(
                text: turn.text,
                streams: streams,
                budget: budget,
                onFinished: onFinished)
                .font(.mCallout)
                .foregroundStyle(Tokens.ink)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Tokens.Space.s3)
                .padding(.vertical, Tokens.Space.s2)
                .background(Tokens.paper2, in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
        }
        .frame(maxWidth: 640, alignment: .leading)
    }
}

/// 코치 대사 한 덩어리를 **토큰이 실시간으로 출력되듯** 흘려 그린다.
///
/// 왜 있나 — 감독 피드백: "마치 실시간으로 토큰이 출력되는것처럼 애니메이팅 해두셈."
/// 코치 대사는 LLM 이 만들지 않는다(CoachEngine 은 스크립트 풀에서 뽑는다). 즉
/// 흘릴 진짜 스트림이 없으므로, 완성된 문자열을 **토큰처럼 잘라** 같은 리듬으로 낸다.
///
/// 접근성: 부모(CoachBubble)가 `.accessibilityElement(children: .combine)` 과 전문
/// 라벨을 이미 걸어 뒀다. 그래서 VoiceOver 는 흐름 진행과 무관하게 전문을 한 번에
/// 읽는다 — 낭독이 글자 수만큼 끊기지 않는다. 여기서 라벨을 또 만들지 않는 이유다.
private struct StreamingCoachText: View {
    let text: String
    let streams: Bool
    let budget: Double
    let onFinished: () -> Void

    @State private var shown = ""

    var body: some View {
        // 빈 문자열은 줄 높이가 0 으로 접혀 말풍선이 한 번 튄다 — 최소 한 칸을 남긴다.
        Text(shown.isEmpty ? " " : shown)
            // id 에 streams 를 함께 넣는다: 건너뛰기 탭으로 streams 가 false 가 되면
            // 이 작업이 다시 시작돼 그 자리에서 전문으로 바뀐다.
            .task(id: "\(streams)\u{1F} \(text)") { await stream() }
    }

    private func stream() async {
        guard streams else {
            shown = text
            onFinished()
            return
        }
        let tokens = CoachStreamTokenizer.tokens(text, budget: budget)
        guard !tokens.isEmpty else {
            shown = text
            onFinished()
            return
        }
        shown = ""
        for token in tokens {
            guard !Task.isCancelled else { return }
            shown += token.text
            do {
                try await Task.sleep(nanoseconds: token.delayNanos)
            } catch {
                return                      // 취소 — 화면이 사라졌거나 새 채점이 왔다
            }
        }
        guard !Task.isCancelled else { return }
        shown = text                        // 반올림 오차 없이 원문과 정확히 일치시킨다
        onFinished()
    }
}

/// 완성된 문장을 **LLM 토큰처럼** 자른다.
///
/// 글자 단위로 찍으면 타자기(옛날 게임 대사)가 되고, 어절 통째로 내보내면 툭툭
/// 끊겨 스트리밍으로 안 읽힌다. 실제 토크나이저의 결과 모양에 맞춰
///   · 라틴 글자·숫자는 **단어 통째로**(대개 한 토큰이다)
///   · 한글·한자는 **두 글자씩**
///   · 뒤따르는 공백·구두점은 **앞 토큰에 붙여서**(다음 토큰 앞에 붙이면 줄바꿈
///     자리가 한 박자 늦게 잡혀 문장이 흔들린다)
///   · 여는 따옴표·괄호는 **뒤 토큰에 붙여서**
/// 낸다. 문장부호 뒤에는 숨을 더 준다 — 사람이 읽는 리듬이 거기서 끊긴다.
enum CoachStreamTokenizer {
    struct Token {
        let text: String
        let delayNanos: UInt64
    }

    /// - Parameter budget: 이 문장 전체를 흘리는 데 쓸 시간(초). 합이 넘치면
    ///   전체를 비례 축소한다 — 긴 대사가 학생을 붙잡지 않게 하는 유일한 안전장치다.
    static func tokens(_ source: String, budget: Double) -> [Token] {
        let pieces = split(source)
        guard !pieces.isEmpty else { return [] }

        let raw = pieces.map(pause(after:))
        let total = raw.reduce(0, +)
        let scale = total > budget && total > 0 ? budget / total : 1
        return zip(pieces, raw).map { piece, seconds in
            Token(text: piece,
                  delayNanos: UInt64(max(0.008, seconds * scale) * 1_000_000_000))
        }
    }

    private static func split(_ source: String) -> [String] {
        let characters = Array(source)
        var pieces: [String] = []
        var index = 0

        while index < characters.count {
            var piece = ""
            // 여는 따옴표·괄호는 뒤 글자와 함께 나간다.
            while index < characters.count, isLeader(characters[index]) {
                piece.append(characters[index])
                index += 1
            }
            guard index < characters.count else {
                if !piece.isEmpty { pieces.append(piece) }
                break
            }

            let head = characters[index]
            piece.append(head)
            index += 1

            if isWordCharacter(head) {
                while index < characters.count, isWordCharacter(characters[index]) {
                    piece.append(characters[index])
                    index += 1
                }
            } else if isSyllable(head), index < characters.count, isSyllable(characters[index]) {
                piece.append(characters[index])
                index += 1
            }

            while index < characters.count, isTrailer(characters[index]) {
                piece.append(characters[index])
                index += 1
            }
            pieces.append(piece)
        }
        return pieces
    }

    /// 라틴 글자·숫자 — 한 단어가 한 토큰이다.
    private static func isWordCharacter(_ character: Character) -> Bool {
        guard let scalar = character.unicodeScalars.first, scalar.isASCII else { return false }
        return character.isLetter || character.isNumber
    }

    /// 한글·한자처럼 글자 하나가 뜻을 갖는 문자.
    private static func isSyllable(_ character: Character) -> Bool {
        guard let scalar = character.unicodeScalars.first else { return false }
        return !scalar.isASCII && (character.isLetter || character.isNumber)
    }

    private static func isLeader(_ character: Character) -> Bool {
        "\u{201C}\u{2018}([{<\u{300C}\u{300E}".contains(character)
    }

    private static func isTrailer(_ character: Character) -> Bool {
        if character.isWhitespace { return true }
        return "\u{201D}\u{2019})]}>\u{300D}\u{300F}.,?!:;\u{00B7}\u{2026}~%".contains(character)
    }

    /// 이 토큰을 내보낸 뒤 쉬는 시간(초). 문장 끝에서 가장 길게 쉰다.
    private static func pause(after piece: String) -> Double {
        let trimmed = piece.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let last = trimmed.last else { return 0.030 }
        if ".?!\u{2026}".contains(last) { return 0.200 }
        if ",:;\u{00B7}".contains(last) { return 0.100 }
        return 0.034
    }
}

/// 대사가 타자기처럼 찍힌다. 동작 줄이기가 켜져 있으면 즉시 전체 표시.
struct TypewriterText: View {
    let text: String
    @State private var shown = ""

    var body: some View {
        Text(shown.isEmpty ? " " : shown)
            .task(id: text) {
                if UIAccessibility.isReduceMotionEnabled {
                    shown = text
                    return
                }
                shown = ""
                for ch in text {
                    shown.append(ch)
                    try? await Task.sleep(nanoseconds: 16_000_000)
                }
            }
    }
}

// MARK: - 평가센터
//
// 위계 (외부 디자인 리뷰 + 55차 우선순위 재배열) — 같은 무게의 블록 반복이
// "지금 뭘 해야 하는지" 를 지운다.
//   ⓪ 지금 할 수 있어요 — 열린 단계 평가 하나. 있을 때만 서는 최상단 카드.
//   ① 주간 공식 모의고사 — 이번 주의 할 일. 유일한 네이비 히어로.
//   ② 시험 목록(단계 평가·기출) — 기록/아카이브. 카드 반복 대신 구분선 리스트.
//   ③ 채점 Pro — 도구 진입. 하단 보조 행.

struct AssessmentScreen: View {
    @StateObject private var timer = ExamTimer()
    @EnvironmentObject private var store: AppStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// 카탈로그 과목 선택 — 웹 정본의 5개 단계 평가 과목을 그대로 지원한다.
    @State private var courseID = AssessCatalog.data.courses.first?.courseId ?? "algebra"
    /// 평가 체계 상세(중간 10 → 기말 20 → 종합 40 등) — 본문에 상시 노출하지 않고
    /// 정보 버튼으로 연다
    @State private var showSystemInfo = false
    /// 잠긴 행을 탭하면 남은 개념을 보여주는 시트
    @State private var lockDetail: ChainExam?
    /// 유닛 접기 — 기본값(포커스 유닛만 펼침)에서 사용자가 뒤집은 유닛만 기록한다.
    /// 화면 상태일 뿐 저장하지 않는다. 키는 "과목/유닛" 이라 과목을 오가도 안 섞인다.
    @State private var toggledGroups: Set<String> = []
    /// 펼친 유닛 안에서 "나머지 평가 보기" 를 연 유닛 — 기본은 접힘
    @State private var innerExpanded: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s7) {
            VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .lastTextBaseline) {
                        assessmentTitle
                        Spacer(minLength: Tokens.Space.s4)
                        timerReadout.fixedSize(horizontal: true, vertical: false)
                    }
                    VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                        assessmentTitle
                        timerReadout
                    }
                }
                ExamRule()
            }
            .entrance(0)

            // ── 1. 지금 할 수 있어요 — 응시 가능한 단계 평가가 있으면 그 하나가
            //       최상단이다. "지금 뭘 해야 하는지" 의 첫 답은 열린 시험이다.
            if let course = AssessCatalog.course(courseID), let now = nextOpenExam(course) {
                nowCard(now)
                    .entrance(1)
            }

            // ── 2. 주간 공식 모의고사 — 이번 주의 할 일
            WeeklyMockEntryCard { store.route = .weeklyMock }
                .entrance(2)

            // ── 3. 단계 평가 — 통과 사슬 전체가 대단원별 구분선 리스트로 선다
            if let catalogError = AssessCatalog.loadError {
                Label(catalogError, systemImage: "exclamationmark.triangle.fill")
                    .font(.mCallout)
                    .foregroundStyle(Tokens.warningInk)
                    .padding(Tokens.Space.s5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Tokens.warningSoft, in: RoundedRectangle(cornerRadius: Tokens.Radius.lg))
                    .entrance(3)
            } else if let course = AssessCatalog.course(courseID) {
                chainSection(course)
                    .entrance(3)
            }

            // ── 4. 빠른 연습·채점 도구 — 정식 시험과 다른 보조 행동은 하단에 둔다.
            // 기출 아카이브의 긴 연도별 목록은 평가센터에서 제거했다. KICE 리소스와
            // 기존 응시 route는 내부 검증·기록 복원을 위해 그대로 보존한다.
            //       퀵 연습은 구현된 네이티브 화면으로 가는 명시적 진입점이다.
            supportingEntries
                .entrance(4)
        }
        .compactHeightSheet(isPresented: $showSystemInfo) { systemInfoSheet }
        .compactHeightSheet(item: $lockDetail) { lockDetailSheet($0) }
    }

    private var assessmentTitle: some View {
        Text("평가센터").font(.mTitle).foregroundStyle(Tokens.ink)
    }

    /// 경과 시간 — 시험이 도는 동안에만 그린다. 평시의 '00:00.000' 상시 노출은
    /// 0 측정값처럼 읽히고, 보이는 레이블이 없어 정체도 알 수 없었다 (감사 0278·1380).
    /// 밀리초 자리는 화면에서 뺀다 — 동점자 판정 기록은 정지 시점에 계산되고,
    /// 흐르는 ms 는 사용자가 판단에 쓸 수 없는 숫자다 (감사 1787).
    @ViewBuilder
    private var timerReadout: some View {
        if timer.isRunning {
            HStack(spacing: Tokens.Space.s2) {
                Circle().fill(Tokens.danger).frame(width: 6, height: 6)
                Text("경과 시간").font(.mCaption).foregroundStyle(Tokens.text3)
                Text(timer.display).font(.mStat).foregroundStyle(Tokens.ink).monospacedDigit()
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("경과 시간 \(timer.display)")
        }
    }

    /// 정식 평가보다 가벼운 행동을 한 섹션에 모은다. 퀵 연습은 40초 한 문항,
    /// 채점 Pro는 촬영 도구라 열린 시험·주간 모의고사와 같은 위계로 올리지 않는다.
    private var supportingEntries: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionRule(title: "빠른 연습과 도구")

            supportingEntry(
                title: "퀵 연습",
                detail: "취약 개념 한 문항을 40초 안에 풀고 변화를 확인합니다.",
                icon: "bolt.fill"
            ) {
                store.route = .quickPractice
            }

            Divider().foregroundStyle(Tokens.line)

            supportingEntry(
                title: "채점 Pro",
                detail: "시험지 사진을 올리면 풀이 과정까지 짚어 채점합니다.",
                icon: "camera.viewfinder"
            ) {
                store.route = .pro
            }
        }
    }

    private func supportingEntry(
        title: String,
        detail: String,
        icon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: Tokens.Space.s3) {
                Image(systemName: icon)
                    .font(.mBody).foregroundStyle(Tokens.text2)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.mBodyB).foregroundStyle(Tokens.ink)
                    Text(detail)
                        .font(.mCaption).foregroundStyle(Tokens.text3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: Tokens.Space.s4)
                Image(systemName: "chevron.right")
                    .font(.mCaption).foregroundStyle(Tokens.text3)
            }
            .padding(.vertical, Tokens.Space.s3)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(detail)")
    }
}

/// 주간 공식 모의고사 입구 — **화면에 하나뿐인 네이비 히어로 면.**
/// 네이비 안의 층위는 navyElevated 로만 올리고, 포인트는 시안 하나만 쓴다
/// (네이비 위 마젠타·바이올렛 금지 규칙).
private struct WeeklyMockEntryCard: View {
    let open: () -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Tokens.Space.s6) {
                copy
                Spacer(minLength: Tokens.Space.s4)
                action.frame(width: 220)
            }
            VStack(alignment: .leading, spacing: Tokens.Space.s4) {
                copy
                action
            }
        }
        .padding(Tokens.Space.s6)
        .background(Tokens.brandNavy, in: RoundedRectangle(cornerRadius: Tokens.Radius.xl))
    }

    private var copy: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
            // 눈썹줄("주간 공식 모의고사")을 지웠다 — 바로 아래 제목이 같은 말을
            // 통째로 품고 있어("Matths 주간 공식 모의고사") 카드를 열면 같은 문장이
            // 두 줄 연속으로 읽혔다. 정보가 하나도 늘지 않는 반복이다.
            // 덤으로 네이비 위 시안 포인트도 CTA 하나로 정리된다(이 카드의 규칙).
            Text("Matths 주간 공식 모의고사")
                .font(.mHeading).foregroundStyle(Tokens.onNavy)
            // 섹션 역할 한 줄 — "지금 뭘 해야 하는지" 의 답이 화면 최상단에 선다
            Text("이번 주 대표 성적은 이 시험에서 만들어집니다.")
                .font(.mCallout).foregroundStyle(Tokens.onNavy)
                .fixedSize(horizontal: false, vertical: true)
            // 칩은 시험의 형태(문항·시간) 둘만 — 다섯 덩어리 나열은 히어로를
            // 게시판으로 만든다. 승격 레이어에 얹는 이유는 종전과 같다
            // (네이비 위 회색 글자만으로는 층이 안 생긴다).
            Text("30문항 · 100분")
                .font(.mCaption).foregroundStyle(Tokens.onNavy.opacity(0.72))
                .monospacedDigit()
                .padding(.horizontal, Tokens.Space.s3)
                .padding(.vertical, Tokens.Space.s2)
                .background(Tokens.navyElevated, in: RoundedRectangle(cornerRadius: Tokens.Radius.sm))
            // 주기는 서브 캡션 한 줄로
            Text("매주 일요일")
                .font(.mCaption).foregroundStyle(Tokens.onNavy.opacity(0.72))
            // 회차·대표 성적 규칙은 상세 톤(마이크로)으로 캡션 하단에 내린다
            Text("A·B·C 최대 3회까지 응시하고, 대표 성적으로 남길 회차를 직접 고릅니다.")
                .font(.mMicro).foregroundStyle(Tokens.onNavy.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var action: some View {
        // 종전에는 navyElevated 캡슐로 강등했었다(감사 0703·0263) — 단계 평가의
        // 바이올렛 히어로 CTA 가 화면의 주 버튼이던 때의 판정이다. 위계 개편으로
        // 그 버튼이 목록 행으로 내려갔으니, 화면의 유일한 채움 CTA 자리는 여기다.
        // 채움은 여전히 화면에 하나뿐이고, 네이비 위 액센트도 시안 하나뿐이다.
        Button(action: open) {
            HStack(spacing: Tokens.Space.s2) {
                Text("시험장 입장하기").font(.mBodyB)
                Image(systemName: "chevron.right").font(.mCaption)
            }
            .foregroundStyle(Tokens.brandNavy)
            .padding(.horizontal, Tokens.Space.s5)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(Tokens.brandCyan, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(PressScaleStyle())
    }
}

// MARK: - 평가 v2 통과 사슬 (웹 assessment-center)
//
// 화면 문법: 히어로 카드를 두지 않는다. 같은 무게의 블록 반복이 위계를 지운다는
// 리뷰 지적에 따라, 사슬 전체가 대단원별 구분선 리스트 하나로 선다 — 이 목록의
// 역할은 "오늘의 할 일" 이 아니라 단계 기록이고, 할 일 자리는 최상단의
// "지금 할 수 있어요" 카드와 주간 공식 모의고사가 가져갔다. 잠금·응시 판정
// 근거는 전부 종전과 같은 AssessCatalog · attemptsV2 · progressV2 조회다.

/// 사슬 한 칸의 화면 상태 — 상태 어휘는 이 4개가 전부다.
private enum ChainExamState { case available, inProgress, done, locked }

/// 통과 사슬 평면 모델. 데이터가 아니라 화면 계산용이다 — 새 저장소를 만들지 않는다.
private struct ChainExam: Identifiable {
    let id: String              // scopeKey
    let title: String
    let meta: String            // 문항수 · 제한시간
    let lockReason: String
    let lockProgress: String    // "개념 2/3 완료" — 잠긴 행의 진행 수치
    let remaining: [String]     // 잠금을 풀기 위해 남은 항목 이름 (시트에서 보여준다)
    let state: ChainExamState
    let best: Int?
    let count: Int
    let start: () -> Void
}

/// 대단원 하나의 리스트 구획. 제목 패턴(소단원 중간 → 대단원 기말 → 종합)이
/// 곧 카탈로그 구조라서, 문자열을 파싱하지 않고 구조로 묶는다.
private struct ChainGroup: Identifiable {
    let id: String
    let title: String           // "Ⅰ. 다항식" / "과목 종합"
    let exams: [ChainExam]
}

/// 상태 칩 — 행에서는 진행 중만 쓴다. 응시 가능은 행 오른쪽의 파란 응시 레이블이,
/// 완료는 최고점 메타가 이미 말하므로 칩을 겹치지 않는다. 잠김은 칩이 없다 —
/// 가라앉은 행 자체가 상태다.
private struct AssessStateChip: View {
    let state: ChainExamState

    var body: some View {
        switch state {
        case .available:  chip("응시 가능", fg: Tokens.brandViolet, bg: Tokens.brandViolet.opacity(0.12))
        case .inProgress: chip("진행 중", fg: Tokens.brandCyanInk, bg: Tokens.brandCyanInk.opacity(0.12))
        case .done:       chip("완료", fg: Tokens.text2, bg: Tokens.paper2)
        case .locked:     EmptyView()
        }
    }

    private func chip(_ label: String, fg: Color, bg: Color) -> some View {
        Text(label).font(.mMicro).foregroundStyle(fg)
            .padding(.horizontal, Tokens.Space.s2)
            .padding(.vertical, 4)
            .background(bg, in: Capsule())
    }
}

extension AssessmentScreen {

    // MARK: 상태 계산 — 근거는 전부 기존 조회 (새 서버 호출 없음)

    fileprivate func chainGroups(_ course: AssessCourse) -> [ChainGroup] {
        var out: [ChainGroup] = []
        for unit in course.units {
            var exams: [ChainExam] = []
            for sub in unit.subunits {
                // 메타는 문항수·제한시간만 — 연결 개념 수·구성은 시트로 갔다
                let doneCount = sub.conceptIds.filter(conceptDone).count
                exams.append(makeExam(
                    key: "subunit/\(course.courseId)/\(unit.unitId)/\(sub.id)",
                    title: "\(sub.title) 중간평가",
                    meta: "10문항 · 제한 10분",
                    unlocked: doneCount == sub.conceptIds.count,
                    lockReason: "이 소단원에 연결된 개념을 모두 완료하면 열립니다.",
                    lockProgress: "개념 \(doneCount)/\(sub.conceptIds.count) 완료",
                    remaining: remainingConceptTitles(sub.conceptIds)) {
                    store.startPaper(scope: .subunit, course: course, unit: unit, subunit: sub)
                })
            }
            // 기말은 잠금이 2단(개념 완료 → 중간평가 통과)이라 진행 수치도 단계를 따른다
            let unitConceptIds = unit.subunits.flatMap(\.conceptIds)
            let conceptsAllDone = conceptsDone(unitConceptIds)
            let passedSubIDs = Set(unit.subunits.filter {
                store.attemptsV2.passed(scopeKey: "subunit/\(course.courseId)/\(unit.unitId)/\($0.id)")
            }.map(\.id))
            exams.append(makeExam(
                key: "unit/\(course.courseId)/\(unit.unitId)/-",
                title: "\(unit.title) 기말평가",
                meta: "20문항 · 제한 30분",
                unlocked: unitFinalUnlocked(unit, course: course),
                lockReason: conceptsAllDone
                    ? "소단원 중간평가를 모두 통과해야 합니다."
                    : "이 대단원의 개념을 모두 완료하면 열립니다.",
                lockProgress: conceptsAllDone
                    ? "중간평가 \(passedSubIDs.count)/\(unit.subunits.count) 통과"
                    : "개념 \(unitConceptIds.filter(conceptDone).count)/\(unitConceptIds.count) 완료",
                remaining: conceptsAllDone
                    ? unit.subunits.filter { !passedSubIDs.contains($0.id) }
                        .map { "\($0.title) 중간평가" }
                    : remainingConceptTitles(unitConceptIds)) {
                store.startPaper(scope: .unit, course: course, unit: unit)
            })
            out.append(ChainGroup(id: unit.unitId, title: "\(unit.numeral). \(unit.title)", exams: exams))
        }
        let passedUnitIDs = Set(course.units.filter {
            store.attemptsV2.passed(scopeKey: "unit/\(course.courseId)/\($0.unitId)/-")
        }.map(\.unitId))
        out.append(ChainGroup(id: "course/\(course.courseId)", title: "과목 종합", exams: [
            makeExam(
                key: "course/\(course.courseId)/-/-",
                title: "\(course.title) 과목 종합평가",
                meta: "40문항 · 제한 60분",
                unlocked: courseFinalUnlocked(course),
                lockReason: "모든 대단원 기말평가를 통과해야 합니다.",
                lockProgress: "기말평가 \(passedUnitIDs.count)/\(course.units.count) 통과",
                remaining: course.units.filter { !passedUnitIDs.contains($0.unitId) }
                    .map { "\($0.title) 기말평가" }) {
                store.startPaper(scope: .course, course: course)
            }
        ]))
        return out
    }

    private func makeExam(key: String, title: String, meta: String, unlocked: Bool,
                          lockReason: String, lockProgress: String, remaining: [String],
                          start: @escaping () -> Void) -> ChainExam {
        let passed = store.attemptsV2.passed(scopeKey: key)
        // 제출 전 기록이 남아 있으면 진행 중 — "시험 중 나가도 저장됩니다" 와 같은 근거
        let open = store.attemptsV2.openAttempt(scopeKey: key) != nil
        let state: ChainExamState = passed ? .done : !unlocked ? .locked : open ? .inProgress : .available
        return ChainExam(id: key, title: title, meta: meta, lockReason: lockReason,
                         lockProgress: lockProgress, remaining: remaining, state: state,
                         best: store.attemptsV2.bestScore(scopeKey: key),
                         count: store.attemptsV2.submitted(scopeKey: key).count,
                         start: start)
    }

    private func conceptDone(_ id: String) -> Bool {
        guard let (_, _, con) = CurriculumV2.concept(id) else { return false }
        if store.progressV2.percent(for: con) >= 100 { return true }
        // 업데이트 전 앱이 남긴 legacy.appId 완료 기록도 같은 개념으로 인정한다.
        // v2 마이그레이션이 끝나기 전에도 기존 학생의 평가 잠금이 되살아나지 않는다.
        if let appId = con.legacy?.appId {
            return store.completedConceptIDs.contains(appId)
        }
        return false
    }

    private func conceptsDone(_ ids: [String]) -> Bool { ids.allSatisfy(conceptDone) }

    /// 아직 완료하지 않은 개념의 이름 — 잠긴 행 시트의 재료
    private func remainingConceptTitles(_ ids: [String]) -> [String] {
        ids.filter { !conceptDone($0) }.map { CurriculumV2.concept($0)?.2.title ?? $0 }
    }

    private func unitFinalUnlocked(_ unit: AssessUnit, course: AssessCourse) -> Bool {
        conceptsDone(unit.subunits.flatMap(\.conceptIds))
            && unit.subunits.allSatisfy {
                store.attemptsV2.passed(scopeKey: "subunit/\(course.courseId)/\(unit.unitId)/\($0.id)")
            }
    }

    private func courseFinalUnlocked(_ course: AssessCourse) -> Bool {
        course.units.allSatisfy {
            store.attemptsV2.passed(scopeKey: "unit/\(course.courseId)/\($0.unitId)/-")
        }
    }

    // MARK: [단계 평가] — 대단원별 구분선 리스트 (카드 0장)

    @ViewBuilder
    fileprivate func chainSection(_ course: AssessCourse) -> some View {
        let groups = chainGroups(course)
        let all = groups.flatMap(\.exams)
        let openCount = all.filter { $0.state == .available || $0.state == .inProgress }.count
        let allDone = !all.isEmpty && all.allSatisfy { $0.state == .done }
        // 포커스 유닛 — 열린 시험이 있는 첫 유닛, 없으면 첫 잠긴 시험이 속한 유닛.
        // 이 하나만 기본으로 펼치고 나머지 유닛은 같은 문법의 접힌 행으로 선다 (RG-08)
        let focusGroupID = groups.first { g in
            g.exams.contains { $0.state == .available || $0.state == .inProgress }
        }?.id ?? groups.first { g in g.exams.contains { $0.state == .locked } }?.id

        VStack(alignment: .leading, spacing: Tokens.Space.s5) {
            VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                SectionRule(title: "단계 평가")
                // 해제 규칙은 여기 한 번만 말한다 — 행마다 반복하지 않는다.
                // 문항 구성·통과 점수 같은 체계 상세는 정보 버튼의 시트로.
                HStack(spacing: 0) {
                    Text(allDone
                         ? "모든 단계를 통과했습니다. 새 회차로 기록을 갱신하세요."
                         : "개념을 완료할수록 다음 평가가 열립니다.")
                        .font(.mCaption).foregroundStyle(Tokens.text3)
                        .fixedSize(horizontal: false, vertical: true)
                    Button { showSystemInfo = true } label: {
                        Image(systemName: "info.circle")
                            .font(.mCaption).foregroundStyle(Tokens.text3)
                            .frame(width: 44, height: 44)   // 최소 터치 타깃 44pt
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("평가 체계 자세히 보기")
                }

                coursePicker
                // 커리큘럼 5과목 중 평가 미지원 과목 안내는 상시 문구에서 빼고
                // 정보 시트의 "지원 과목" 항목으로 옮겼다 (RG-10)

                // 잠금을 푸는 유일한 길은 커리큘럼이다 — 열린 시험이 없으면 그 길을
                // 그 자리에서 연다 (감사 0263). 버튼이 할 일의 크기(남은 개념 수)를
                // 직접 말하고, 탭하면 이 과목이 열린 커리큘럼으로 간다 (RG-09).
                if openCount == 0 && !allDone,
                   let firstLocked = all.first(where: { $0.state == .locked }) {
                    Button("남은 개념 \(firstLocked.remaining.count)개 학습하기") {
                        // 평가 카탈로그의 과목 제목("대수" 등)이 곧 구 커리큘럼 과목 id 다
                        store.selectedCourseV2ID = course.courseId
                        store.route = .curriculum
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
            }

            ForEach(groups) { group in
                chainGroupList(group, courseKey: course.courseId,
                               isFocus: group.id == focusGroupID)
            }

            // 밀리초 기록 규정은 정보 시트로 — 여기서는 이탈 불안만 푼다 (RG-11)
            Label("시험 중 나가도 진행 상황은 저장됩니다.", systemImage: "info.circle")
                .font(.mCaption).foregroundStyle(Tokens.text3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var coursePicker: some View {
        if horizontalSizeClass == .compact || dynamicTypeSize.isAccessibilitySize {
            Picker("평가 과목", selection: $courseID) {
                ForEach(AssessCatalog.data.courses) { Text($0.title).tag($0.courseId) }
            }
            .pickerStyle(.menu)
            .accessibilityHint("평가할 과목을 선택합니다.")
        } else {
            Picker("평가 과목", selection: $courseID) {
                ForEach(AssessCatalog.data.courses) { Text($0.title).tag($0.courseId) }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 680)
        }
    }

    /// 대단원 하나 = DisclosureGroup 하나 — 접기 문법은 전 유닛이 동일하다 (RG-08).
    ///   · 기본으로 펼쳐지는 유닛은 포커스 유닛 하나뿐이다(열린 시험이 있는 유닛,
    ///     없으면 첫 잠긴 시험이 속한 유닛). 나머지는 요약 행으로 접힌다.
    ///   · 펼친 유닛 안에서도 기본 노출은 열린 시험 + 첫 잠긴 시험뿐 — 나머지는
    ///     "나머지 평가 보기" 안쪽 접기로 들어간다.
    ///   · 접힌 행을 펼치고 잠긴 행을 탭하면 남은 개념 시트 — 종전 그대로.
    @ViewBuilder
    private func chainGroupList(_ group: ChainGroup, courseKey: String, isFocus: Bool) -> some View {
        let passed = group.exams.filter { $0.state == .done }.count
        let key = "\(courseKey)/\(group.id)"
        // 기본값에서 뒤집힌 유닛만 기록한다 — 과목을 바꾸거나 진도가 바뀌어
        // 포커스가 이동해도 손대지 않은 유닛은 새 기본값을 따라온다.
        let expanded = Binding<Bool>(
            get: { isFocus != toggledGroups.contains(key) },
            set: { open in
                if open == isFocus { toggledGroups.remove(key) }
                else { toggledGroups.insert(key) }
            })
        // 펼쳤을 때의 기본 노출 — 열린 시험 + 이 유닛의 첫 잠긴 시험
        let firstLockedID = group.exams.first { $0.state == .locked }?.id
        let visible = group.exams.filter {
            $0.state == .available || $0.state == .inProgress || $0.id == firstLockedID
        }
        let folded = group.exams.filter { exam in !visible.contains { $0.id == exam.id } }

        DisclosureGroup(isExpanded: expanded) {
            VStack(alignment: .leading, spacing: 0) {
                if visible.isEmpty {
                    // 전부 완료된 유닛 — 펼치면 기록 전체가 바로 나온다. 겹접기 없음.
                    ForEach(Array(group.exams.enumerated()), id: \.element.id) { i, exam in
                        if i > 0 { DottedRule() }
                        chainRow(exam)
                    }
                } else {
                    ForEach(Array(visible.enumerated()), id: \.element.id) { i, exam in
                        if i > 0 { DottedRule() }
                        chainRow(exam)
                    }
                    if !folded.isEmpty {
                        DottedRule()
                        DisclosureGroup(isExpanded: innerFold(key)) {
                            ForEach(Array(folded.enumerated()), id: \.element.id) { i, exam in
                                if i > 0 { DottedRule() }
                                chainRow(exam)
                            }
                        } label: {
                            Text("나머지 평가 \(folded.count)개 보기")
                                .font(.mCaption).foregroundStyle(Tokens.text3)
                                .monospacedDigit()
                                .frame(minHeight: 44, alignment: .leading)   // 최소 터치 타깃 44pt
                        }
                        .tint(Tokens.text3)
                    }
                }
            }
        } label: {
            // 완료 수는 제목 **옆**에 붙인다 — 양끝 정렬은 900pt 폭에서 제목과
            // 수치 사이 시선이 끊긴다 (RG-14). 셰브런은 접기 문법의 자리(오른끝) 유지.
            HStack(alignment: .lastTextBaseline, spacing: Tokens.Space.s3) {
                Text(group.title).font(.mCaption).foregroundStyle(Tokens.text2)
                Text("완료 \(passed)/\(group.exams.count)")
                    .font(.mMicro).foregroundStyle(Tokens.text3).monospacedDigit()
                Spacer(minLength: 0)
            }
            .frame(minHeight: 44, alignment: .leading)   // 최소 터치 타깃 44pt
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(group.title), 완료 \(passed)/\(group.exams.count)")
        }
        .tint(Tokens.text3)
    }

    /// 안쪽 "나머지 평가 보기" 접기의 바인딩 — 기본은 접힘
    private func innerFold(_ key: String) -> Binding<Bool> {
        Binding(get: { innerExpanded.contains(key) },
                set: { open in
                    if open { innerExpanded.insert(key) } else { innerExpanded.remove(key) }
                })
    }

    // 행 문법: 제목 + 메타 + 셰브런, 행 전체가 버튼이다 (최소 44pt).
    // 잠긴 행도 탭할 수 있다 — 응시 대신 남은 개념 시트가 열린다. 해제 규칙
    // 문장은 목록 상단에 한 번만 있으므로 행에는 진행 수치와 자물쇠 하나만 남긴다.
    // 문항수·제한시간은 못 푸는 시험에는 지금 필요 없는 정보다 — 잠긴 행에서는
    // 빼고 상세 시트에서 보여준다 (RG-07).
    // opacity 이중 감쇠 금지 — 톤은 텍스트 토큰으로만 낮춘다 (감사 0410·1259).

    @ViewBuilder
    private func chainRow(_ exam: ChainExam) -> some View {
        switch exam.state {
        case .locked:
            Button { lockDetail = exam } label: {
                HStack(alignment: .center, spacing: Tokens.Space.s4) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(exam.title).font(.mBodyB).foregroundStyle(Tokens.text3)
                        Text(exam.lockProgress)
                            .font(.mMicro).foregroundStyle(Tokens.text3)
                            .monospacedDigit()
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: Tokens.Space.s4)
                    Image(systemName: "lock.fill")
                        .font(.mMicro).foregroundStyle(Tokens.text4)
                }
                .padding(.vertical, Tokens.Space.s3)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(exam.title), 잠김, \(exam.lockProgress). 남은 개념 보기")
        default:
            Button(action: exam.start) {
                HStack(alignment: .center, spacing: Tokens.Space.s4) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: Tokens.Space.s2) {
                            Text(exam.title).font(.mBodyB).foregroundStyle(Tokens.ink)
                                .fixedSize(horizontal: false, vertical: true)
                            if exam.state == .inProgress {
                                AssessStateChip(state: .inProgress)
                            }
                        }
                        Text(chainRowMeta(exam))
                            .font(.mCaption).foregroundStyle(Tokens.text3)
                            .monospacedDigit()
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: Tokens.Space.s4)
                    HStack(spacing: 2) {
                        Text(exam.state == .done || exam.count > 0 ? "새 회차" : "응시하기")
                        Image(systemName: "chevron.right").font(.mMicro)
                    }
                    .font(.mCaption).foregroundStyle(Tokens.primary)
                }
                .padding(.vertical, Tokens.Space.s3)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
        }
    }

    /// 응시 기록이 생기면 문항 구성 메타 대신 기록이 선다 — 이 목록의 톤은 기록이다.
    private func chainRowMeta(_ exam: ChainExam) -> String {
        if let best = exam.best {
            return "최고 \(best)점 · \(exam.count)회 응시 · \(AssessCatalog.grade(for: best))등급 구간"
        }
        return exam.meta
    }

    // MARK: [지금 할 수 있어요] — 열린 단계 평가 하나를 최상단 카드로

    /// 응시 가능(또는 진행 중)한 단계 평가 중 첫 번째. 진행 중이 있으면
    /// 이어서 하는 쪽이 먼저다 — 시작한 시험을 끝내는 것이 첫 할 일이다.
    fileprivate func nextOpenExam(_ course: AssessCourse) -> ChainExam? {
        let all = chainGroups(course).flatMap(\.exams)
        return all.first { $0.state == .inProgress } ?? all.first { $0.state == .available }
    }

    /// 행 문법(제목 + 메타 + 셰브런)을 카드로 승격한 것 — 채움 CTA 는 여전히
    /// 주간 모의고사 히어로 하나뿐이다. 카드 전체가 버튼이다.
    fileprivate func nowCard(_ exam: ChainExam) -> some View {
        Button(action: exam.start) {
            HStack(alignment: .center, spacing: Tokens.Space.s4) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("지금 할 수 있어요").font(.mMicro).foregroundStyle(Tokens.primary)
                    Text(exam.title).font(.mBodyB).foregroundStyle(Tokens.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(exam.meta).font(.mCaption).foregroundStyle(Tokens.text3)
                        .monospacedDigit()
                }
                Spacer(minLength: Tokens.Space.s4)
                HStack(spacing: 2) {
                    Text(exam.state == .inProgress ? "이어서 응시" : "응시하기")
                    Image(systemName: "chevron.right").font(.mMicro)
                }
                .font(.mCaption).foregroundStyle(Tokens.primary)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .card()
        .accessibilityElement(children: .combine)
    }

    // MARK: 시트 — 평가 체계 상세 · 잠긴 시험의 남은 개념

    /// 정보 버튼이 여는 평가 체계 상세 — 본문에서 뺀 문항 구성·통과 규칙이 여기 있다.
    fileprivate var systemInfoSheet: some View {
        VStack(spacing: 0) {
            assessmentSheetHeader(title: "평가 체계", systemImage: "list.number") {
                showSystemInfo = false
            }

            Divider()

            ScrollView {
                CompactHeightColumns(
                    spacing: Tokens.Space.s7,
                    stackedSpacing: Tokens.Space.s5
                ) {
                    VStack(alignment: .leading, spacing: Tokens.Space.s4) {
                        systemInfoRow(1, "소단원 중간평가",
                                      "10문항 · 제한 10분. 소단원에 연결된 개념을 모두 완료하면 열립니다.")
                        systemInfoRow(2, "대단원 기말평가",
                                      "20문항(중상 7 · 응용 8 · 심화 5) · 제한 30분. 소단원 중간평가를 모두 통과하면 열립니다.")
                        systemInfoRow(3, "과목 종합평가",
                                      "40문항(중상 14 · 응용 16 · 심화 10) · 제한 60분. 모든 기말평가를 통과하면 열립니다.")
                    }
                } trailing: {
                    VStack(alignment: .leading, spacing: Tokens.Space.s5) {
                        Text("\(AssessCatalog.data.passScore)점 이상이면 통과입니다. 재응시는 제한이 없고, 한번 통과한 시험은 계속 열려 있습니다.")
                            .font(.mCaption).foregroundStyle(Tokens.text3)
                            .monospacedDigit()
                            .fixedSize(horizontal: false, vertical: true)
                        // 목록 상시 문구에서 옮겨 온 규정들 — 지원 과목(RG-10) · 밀리초 기록(RG-11)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("지원 과목").font(.mBodyB).foregroundStyle(Tokens.ink)
                            Text("\(AssessCatalog.data.courses.map(\.title).joined(separator: " · "))의 정식 단계 평가를 지원합니다. 목록에 없는 과목은 13과목 학습 지도의 개념 연습으로 학습 결과를 확인하세요.")
                                .font(.mCaption).foregroundStyle(Tokens.text3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Text("시험 시간은 밀리초 단위까지 기록되어 GOAT Arena 동점자 판정에 쓰입니다.")
                            .font(.mCaption).foregroundStyle(Tokens.text3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(Tokens.Space.s6)
            }
        }
        .background(Tokens.paper)
        .presentationDetents([.medium, .large])
    }

    private func systemInfoRow(_ n: Int, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: Tokens.Space.s3) {
            CircledNumber(n: n)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.mBodyB).foregroundStyle(Tokens.ink)
                Text(detail).font(.mCaption).foregroundStyle(Tokens.text3)
                    .monospacedDigit()
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// 잠긴 행을 탭하면 열리는 시트 — 무엇이 남았는지 이름으로 보여준다.
    fileprivate func lockDetailSheet(_ exam: ChainExam) -> some View {
        VStack(spacing: 0) {
            assessmentSheetHeader(title: exam.title, systemImage: "lock.fill") {
                lockDetail = nil
            }

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: Tokens.Space.s4) {
                    // 잠긴 행에서 뺀 문항수·제한시간은 여기(상세)가 자리다 (RG-07)
                    Text(exam.meta)
                        .font(.mCaption).foregroundStyle(Tokens.text3)
                        .monospacedDigit()
                    Text("\(exam.lockReason) 지금 \(exam.lockProgress)입니다.")
                        .font(.mCallout).foregroundStyle(Tokens.text2)
                        .monospacedDigit()
                        .fixedSize(horizontal: false, vertical: true)
                    if !exam.remaining.isEmpty {
                        SectionRule(title: "남은 항목 \(exam.remaining.count)개")
                    }
                    VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                        ForEach(exam.remaining, id: \.self) { name in
                            HStack(alignment: .top, spacing: Tokens.Space.s2) {
                                Text("·").font(.mCallout).foregroundStyle(Tokens.text3)
                                Text(name).font(.mCallout).foregroundStyle(Tokens.text1)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    // 개념이 남은 잠금이면 푸는 길은 커리큘럼뿐이다 — 그 길을 여기서 연다.
                    // (중간·기말 통과가 남은 잠금은 위 목록의 해당 시험이 곧 다음 행동이다)
                    // 버튼이 남은 개념 수를 직접 말하고, 커리큘럼도 이 과목으로 연다 (RG-09)
                    if exam.lockProgress.hasPrefix("개념") {
                        Button("남은 개념 \(exam.remaining.count)개 학습하기") {
                            lockDetail = nil
                            // 평가 카탈로그의 과목 제목("대수" 등)이 곧 구 커리큘럼 과목 id 다
                            store.selectedCourseV2ID = courseID
                            store.route = .curriculum
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    }
                }
                .padding(Tokens.Space.s6)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(Tokens.paper)
        .presentationDetents([.medium])
    }

    private func assessmentSheetHeader(
        title: String,
        systemImage: String,
        close: @escaping () -> Void
    ) -> some View {
        HStack(spacing: Tokens.Space.s3) {
            Image(systemName: systemImage)
                .font(.mCaption)
                .foregroundStyle(Tokens.text3)
                .accessibilityHidden(true)
            Text(title)
                .font(.mHeading)
                .foregroundStyle(Tokens.ink)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: Tokens.Space.s3)
            Button("닫기", action: close)
                .font(.mCaption)
                .foregroundStyle(Tokens.primary)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .padding(.horizontal, Tokens.Space.s6)
        .padding(.vertical, Tokens.Space.s2)
        .accessibilityElement(children: .contain)
    }

    // MARK: [기출 아카이브] — 학년도별 구분선 리스트

    fileprivate var kiceSection: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s5) {
            VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                SectionRule(title: "기출 아카이브")
                // 섹션 역할 한 줄 — 채점·오답노트 흐름 설명은 응시하면 바로 겪는
                // 것이라 지웠다 (RG-22)
                Text("평가원 실제 문제지를 그대로 풀고, 실제 정답표로 채점됩니다.")
                    .font(.mCaption).foregroundStyle(Tokens.text3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ForEach(kiceYearGroups) { group in
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(group.year)학년도")
                        .font(.mCaption).foregroundStyle(Tokens.text2)
                        .monospacedDigit()
                        .accessibilityAddTraits(.isHeader)
                        .padding(.bottom, Tokens.Space.s2)
                    ForEach(Array(group.exams.enumerated()), id: \.element.id) { i, exam in
                        if i > 0 { DottedRule() }
                        KiceExamRow(exam: exam)
                    }
                }
            }

            // 이 섹션은 KICE 리소스를 명시적으로 복사한 내부 Debug에서만 존재한다.
            // 학습·연구 목적을 사용 허락으로 오인하지 않게 권리 경계를 그대로 말한다.
            Text("기출 문항 저작권은 한국교육과정평가원에 있습니다. 사용 허락 확인 전 내부 검증 빌드에만 포함됩니다.")
                .font(.mMicro).foregroundStyle(Tokens.text4)
        }
    }

    /// 학년도(제목 패턴 "YYYY 수능/모평" 의 앞 네 자리)로 묶는다 — 번들 순서 유지.
    private var kiceYearGroups: [KiceYearGroup] {
        var out: [KiceYearGroup] = []
        for exam in KiceBank.exams {
            let year = String(exam.short.prefix(4))
            if let idx = out.firstIndex(where: { $0.year == year }) {
                out[idx].exams.append(exam)
            } else {
                out.append(KiceYearGroup(year: year, exams: [exam]))
            }
        }
        return out
    }
}

/// 기출 리스트의 학년도 구획 — 화면 계산용.
private struct KiceYearGroup: Identifiable {
    let year: String
    var exams: [KiceExam]
    var id: String { year }
}

/// 기출 아카이브 한 행 — 제목 + 메타 + 셰브런. 행 전체가 응시 버튼이다.
struct KiceExamRow: View {
    let exam: KiceExam
    @EnvironmentObject private var store: AppStore

    /// 학년도 헤더가 연도를 이미 말했으니 행 제목에서는 뗀다 — "수능 수학 (홀수형)"
    private var rowTitle: String {
        var name = exam.short
        if let range = name.range(of: "^\\d{4} ", options: .regularExpression) {
            name = String(name[range.upperBound...])
        }
        return exam.displayForm.map { "\(name) 수학 (\($0))" } ?? "\(name) 수학"
    }

    var body: some View {
        Button { store.startKice(exam) } label: {
            HStack(alignment: .center, spacing: Tokens.Space.s4) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(rowTitle).font(.mBodyB).foregroundStyle(Tokens.ink)
                    Text("\(exam.heldOn) 시행 · 공통 22 + 선택 8문항 · 100점")
                        .font(.mCaption).foregroundStyle(Tokens.text3)
                        .monospacedDigit()
                    if let best = KiceBank.bestScore(exam.id) {
                        // 실제 채점 기록 — 전시물이 아니다.
                        // 상태 원색(success)은 면 채움용 — 문구는 4.5:1 확보된 잉크로 (감사 0410)
                        Text("최고 \(best)점").font(.mCaption).foregroundStyle(Tokens.successInk)
                            .monospacedDigit()
                    }
                }
                Spacer(minLength: Tokens.Space.s4)
                HStack(spacing: 2) {
                    Text("응시하기")
                    Image(systemName: "chevron.right").font(.mMicro)
                }
                .font(.mCaption).foregroundStyle(Tokens.primary)
            }
            .padding(.vertical, Tokens.Space.s3)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(kiceAccessibilityLabel)
    }

    /// 행 제목에서 뗀 연도를 보이스오버에는 되살린다 — 헤더 문맥이 없는 낭독 대비.
    private var kiceAccessibilityLabel: String {
        let title = exam.displayForm.map { "\(exam.short) 수학 (\($0))" } ?? "\(exam.short) 수학"
        if let best = KiceBank.bestScore(exam.id) {
            return "\(title), \(exam.heldOn) 시행, 최고 \(best)점, 응시하기"
        }
        return "\(title), \(exam.heldOn) 시행, 응시하기"
    }
}

/// 감싸며 흐르는 선택 칩 — 틀린 이유·필터용 (알약, 선택 시 브랜드 소프트)
struct FlowChips: View {
    let items: [(id: String, label: String)]
    let selected: String?
    let onPick: (String) -> Void

    var body: some View {
        FlexWrap(spacing: 8) {
            ForEach(items, id: \.id) { item in
                Button(item.label) { onPick(item.id) }
                    .font(.mCaption)
                    .foregroundStyle(selected == item.id ? Tokens.primary : Tokens.text2)
                    .padding(.horizontal, Tokens.Space.s3)
                    .frame(minHeight: 34)
                    .background(selected == item.id ? Tokens.primarySoft : Tokens.surface,
                                in: Capsule())
                    .overlay(Capsule().strokeBorder(
                        selected == item.id ? Tokens.primary : Tokens.line, lineWidth: 1.1))
                    // 시각 높이(34pt 알약)는 유지하고 터치 영역만 44pt 로 확장 (감사 1202)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                    .buttonStyle(.plain)
            }
        }
    }
}

/// 최소 줄바꿈 래핑 레이아웃 (iOS 16+ Layout)
struct FlexWrap: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 600
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > width && x > 0 { x = 0; y += rowH + spacing; rowH = 0 }
            x += s.width + spacing
            rowH = max(rowH, s.height)
        }
        return CGSize(width: width, height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > bounds.maxX && x > bounds.minX {
                x = bounds.minX; y += rowH + spacing; rowH = 0
            }
            v.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing
            rowH = max(rowH, s.height)
        }
    }
}

// MARK: - 오답노트

/// 정렬 축 — 웹 wrongNoteService sortItems(latest/oldest/difficulty/priority) 이식.
/// 웹의 difficulty 값은 앱 오답 항목에 없으므로 그 자리를 실제로 가진 값인
/// 틀린 횟수로 대신한다 (없는 값을 있는 척 정렬하지 않는다).
enum WrongNoteSort: String, CaseIterable, Identifiable {
    case latest, oldest, wrongCount, dueSoon

    var id: String { rawValue }
    var label: String {
        switch self {
        case .latest: return "최신순"
        case .oldest: return "오래된순"
        case .wrongCount: return "많이 틀린 순"
        case .dueSoon: return "복습 임박순"
        }
    }
}

struct WrongNotesScreen: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    // 저장 계층 사고(파일 손상·저장 실패) 알림 — AppStore 프로퍼티가 아니라
    // 저장 계층의 싱글턴을 직접 구독한다 (WrongNoteStore.swift 의 통로 설계 주석 참조)
    @ObservedObject private var storageAlert = WrongNoteStorageAlertCenter.shared
    private func applyFilters(_ list: [WrongNoteEntry]) -> [WrongNoteEntry] {
        applySort(list.filter { e in
            (store.wrongNoteFilterUnit == nil || e.unit == store.wrongNoteFilterUnit)
            && (store.wrongNoteFilterError == nil || e.errorType == store.wrongNoteFilterError)
            && (store.wrongNoteQuery.isEmpty
                || e.statement.localizedCaseInsensitiveContains(store.wrongNoteQuery)
                || e.typeName.localizedCaseInsensitiveContains(store.wrongNoteQuery)
                || e.unit.localizedCaseInsensitiveContains(store.wrongNoteQuery))
        })
    }

    /// 같은 값이면 최신 적재를 앞에 둔다 — 순서가 흔들리지 않게 항상 2차 기준을 준다.
    private func applySort(_ list: [WrongNoteEntry]) -> [WrongNoteEntry] {
        switch store.wrongNoteSortKey {
        case .latest:
            return list.sorted { $0.createdAt > $1.createdAt }
        case .oldest:
            return list.sorted { $0.createdAt < $1.createdAt }
        case .wrongCount:
            return list.sorted { ($0.wrongCount, $0.createdAt) > ($1.wrongCount, $1.createdAt) }
        case .dueSoon:
            return list.sorted { a, b in
                switch (a.nextReviewAt, b.nextReviewAt) {
                case let (l?, r?):  return l == r ? a.createdAt > b.createdAt : l < r
                case (_?, nil):     return true      // 졸업(nil)은 급할 일이 없으니 뒤로
                case (nil, _?):     return false
                case (nil, nil):    return a.createdAt > b.createdAt
                }
            }
        }
    }

    private var due: [WrongNoteEntry] { applyFilters(store.wrongNotes.filter(\.isDue)) }
    private var waiting: [WrongNoteEntry] { applyFilters(store.wrongNotes.filter { !$0.isDue && !$0.isMastered }) }
    private var mastered: [WrongNoteEntry] { applyFilters(store.wrongNotes.filter(\.isMastered)) }
    private var compactHeight: Bool { verticalSizeClass == .compact }

    var body: some View {
        VStack(alignment: .leading, spacing: compactHeight ? Tokens.Space.s4 : Tokens.Space.s7) {
            // 저장 사고 배너 — 파일 손상·저장 실패는 조용히 넘기지 않는다 (감사 F-04).
            // 닫기 전까지 남는다: 학생이 "오답이 왜 비었지"를 추측하게 두지 않기 위해.
            // 통로(싱글턴)와 스토어 미러 어느 쪽에 세팅돼도 보이게 coalesce 로 읽는다.
            if let alertText = storageAlert.message ?? store.wrongNoteStorageAlert {
                HStack(alignment: .center, spacing: Tokens.Space.s2) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.mCaption).foregroundStyle(Tokens.warningInk)
                    Text(alertText).font(.mCaption).foregroundStyle(Tokens.text1)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Button { storageAlert.dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.mMicro).foregroundStyle(Tokens.text3)
                            .frame(width: 44, height: 44)   // 최소 터치 타깃 44pt
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("저장 경고 닫기")
                }
                .padding(.leading, Tokens.Space.s3)
                .background(Tokens.warningSoft, in: RoundedRectangle(cornerRadius: Tokens.Radius.sm))
            }

            VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                wrongNotesTitle
                ExamRule()
                // 오늘의 분량(건수·예상 시간)은 바로 아래 HERO 한 곳에서만 말한다 —
                // 제목 밑 캡션이 같은 수량을 한 줄 먼저 반복하면 HERO 가 재방송이 된다.

                // 필터 — 과목 · 틀린 이유 · 검색 (웹 오답노트의 3축)
                if !store.wrongNotes.isEmpty {
                    // 필터 3개 + 검색창은 320/375pt에서 한 줄로 설 수 없다.
                    // 좁으면 메뉴 한 줄, 검색창 한 줄로 나눠 모든 조작점을 보존한다.
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: Tokens.Space.s3) {
                            filterMenus
                            filterSearch.frame(maxWidth: 260)
                            Spacer(minLength: 0)
                        }
                        .frame(minWidth: 560)

                        VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                            filterMenus
                            filterSearch.frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .entrance(0)

            // 오늘 복습 HERO — 이 화면의 유일한 주 CTA. 노트가 하나도 없으면
            // 아래 고스트 빈 상태가 대신 선다.
            if !store.wrongNotes.isEmpty {
                reviewHero.entrance(1)
            }

            if store.wrongNotes.isEmpty {
                emptyGhost
            } else if due.isEmpty && waiting.isEmpty && mastered.isEmpty {
                // 필터·검색이 전 항목을 걸러낸 상태 — 목록만 조용히 사라지면
                // 오답이 없어진 건지 가려진 건지 구분할 수 없다. 진짜 빈 상태
                // (emptyGhost)와 문구를 다르게 유지한다 (감사 1107·0839)
                filteredEmpty
            } else {
                // 이름은 **웹 wrong-notes.ejs 의 어휘를 따른다.**
                // 웹 정의: 복습 대기 = 새 오답(지금 바로 풀 수 있음),
                //          복습 예정 = 재도전에서 또 틀려 다음 날로 예약된 것,
                //          복습 완료 = 끝난 것.
                // 앱은 이 두 단어를 서로 **바꿔** 쓰고 있었다(due 에 "복습 예정",
                // 아직 예정일이 안 온 것에 "복습 대기"). 같은 학생이 웹과 앱에서
                // 정반대 뜻으로 읽게 된다.
                if !due.isEmpty { section("지금 복습할 문제", items: due) }
                if !waiting.isEmpty { section("복습 예정", items: waiting) }
                if !mastered.isEmpty { section("복습 완료", items: mastered) }
            }

            // 스크린샷 가드에서 적은 "막힌 지점" — 잔소리로 끝내지 않고 여기로 온다
            if !store.stuckPoints.isEmpty {
                VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                    SectionRule(title: "내가 적은 막힌 지점")
                    ForEach(store.stuckPoints) { point in
                        HStack(alignment: .top, spacing: Tokens.Space.s2) {
                            Text("·").font(.mCallout).foregroundStyle(Tokens.text3)
                            Text(point.text).font(.mCallout).foregroundStyle(Tokens.text1)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var wrongNotesTitle: some View {
        Text("오답노트").font(.mTitle).foregroundStyle(Tokens.ink)
    }

    /// HERO 는 필터와 무관한 전체 기준으로 말한다 — 화면 상태의 진실.
    /// (필터·검색은 아래 목록에만 건다. 필터가 다 가려도 "복습 완료" 라고 거짓말하지 않게.)
    private var dueAll: [WrongNoteEntry] { store.wrongNotes.filter(\.isDue) }
    private var waitingAll: [WrongNoteEntry] { store.wrongNotes.filter { !$0.isDue && !$0.isMastered } }

    /// 가장 이른 다음 복습 예정일 — 졸업(nil)은 제외
    private var nextReviewDate: Date? {
        store.wrongNotes.compactMap(\.nextReviewAt).min()
    }

    private func shortDate(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "M/d"
        return f.string(from: d)
    }

    /// 오늘 복습 HERO — due 가 있으면 큰 건수 + 주 CTA, 0건이면 축하 상태.
    @ViewBuilder private var reviewHero: some View {
        if !dueAll.isEmpty {
            CompactHeightColumns(spacing: Tokens.Space.s5, stackedSpacing: Tokens.Space.s3) {
                VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                    HStack(alignment: .lastTextBaseline, spacing: Tokens.Space.s1) {
                        Text("오늘 복습").font(.mHeading).foregroundStyle(Tokens.ink)
                        Text("\(dueAll.count)").font(.mStatLarge).monospacedDigit()
                            .foregroundStyle(Tokens.ink)
                        Text("건").font(.mHeading).foregroundStyle(Tokens.ink)
                    }
                    Text("틀렸던 바로 그 문제를 그대로 다시 풉니다.")
                        .font(.mCaption).foregroundStyle(Tokens.text3)
                }
                .accessibilityElement(children: .combine)
            } trailing: {
                VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                // 예상 시간 한 줄 — 시작 전에 얼마나 걸릴지 보인다. 문항당 4분은
                // 복습 문항 복원(WrongNoteEntry.asProblem)의 minutes 와 같은 값이다.
                // (entry.unit 은 과목이 아니라 출처 문자열이라 과목 분류 줄은 뺐다 — R-07)
                    Text("예상 시간 약 \(dueAll.count * 4)분")
                        .font(.mCaption).foregroundStyle(Tokens.text2)
                        .monospacedDigit()
                // 복습 시작 세트 = 위의 전체 due. **화면이 정렬한 순서 그대로** 넘긴다 —
                // 정렬 칩("최신순/많이 틀린 순/기한 임박순")을 바꿔 놓고 시작했는데 큐가
                // 늘 같은 순서로 나오던 것이 감독이 말한 "코스 마냥 주어진 순서" 였다.
                // (필터는 여기에 걸지 않는다 — HERO 는 전체 기준으로 말한다는 위 규약 유지.
                //  정렬은 무엇도 숨기지 않으므로 걸어도 그 규약을 깨지 않는다.)
                    Button("복습 시작") { store.startReview(ids: applySort(dueAll).map(\.id)) }
                        .buttonStyle(PrimaryButtonStyle())
                        .frame(maxWidth: 280)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
        } else {
            // due = 0 — 축하 상태. 색·아이콘·문구 삼중으로 말한다 (색만으로 말하지 않기).
            CompactHeightColumns(spacing: Tokens.Space.s5, stackedSpacing: Tokens.Space.s3) {
                HStack(spacing: Tokens.Space.s2) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.mHeading).foregroundStyle(Tokens.correctGreen)
                    Text("오늘 복습 완료").font(.mHeading).foregroundStyle(Tokens.correctGreen)
                }
                .accessibilityElement(children: .combine)
            } trailing: {
                VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                    if let next = nextReviewDate {
                        Text("다음 복습 \(shortDate(next)) 예정 · \(waitingAll.count)문항이 기다립니다")
                            .font(.mCallout).foregroundStyle(Tokens.text2)
                    }
                    if !waitingAll.isEmpty {
                    // 예정일 전에 당겨 풀 길 — 같은 startReview 를 예정 목록으로 부른다.
                    // 파랑 글자만으로는 눌린다는 단서가 없다 — 셰브론 문법으로 통일 (감사 0430)
                        Button { store.startReview(ids: applySort(waitingAll).map(\.id)) } label: {
                            HStack(spacing: 2) {
                                Text("미리 복습")
                                Image(systemName: "chevron.right").font(.mMicro)
                            }
                        }
                        .buttonStyle(.plain)
                        .font(.mCaption).foregroundStyle(Tokens.primary)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
        }
    }

    /// 빈 상태 — "기록 없음" 죽은 문구 대신 채워진 미래의 고스트 + 탈출구 하나
    private var emptyGhost: some View {
        VStack(spacing: compactHeight ? Tokens.Space.s2 : Tokens.Space.s4) {
            VStack(spacing: compactHeight ? Tokens.Space.s2 : Tokens.Space.s3) {
                GhostNoteCard(statement: "이차함수 y = x² − 4x + 3 의 최솟값을 구하시오.",
                              tag: "공통수학1 · 이차방정식과 이차함수")
                // iPhone 가로에서는 두 번째 장식 카드가 실제 설명과 탈출 CTA를
                // 하단 탭 뒤로 밀었다. 채워질 목록의 형태는 한 장으로도 충분히
                // 전달되므로 세로가 짧을 때만 한 장으로 압축한다.
                if !compactHeight {
                    GhostNoteCard(statement: "두 집합 A, B 에 대하여 n(A∪B) 를 구하시오.",
                                  tag: "공통수학1 · 집합과 명제")
                }
            }
            .opacity(0.4)
            .allowsHitTesting(false)
            .accessibilityHidden(true)

            Text("틀린 문제가 여기에 쌓입니다").font(.mBodyB).foregroundStyle(Tokens.text1)
            Text("문제를 틀리면 당시 풀이 메모와 함께 저장되고, 예정일에 맞춰 복습으로 돌아옵니다.")
                .font(.mCaption).foregroundStyle(Tokens.text3)
                .multilineTextAlignment(.center)

            Button("연습 문제 풀러 가기") { store.route = .curriculum }
                .buttonStyle(.plain)
                .font(.mBodyB).foregroundStyle(Tokens.primary)
                .frame(minHeight: 44)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, compactHeight ? Tokens.Space.s2 : Tokens.Space.s8)
    }

    /// 필터 빈 상태 — 오답은 있는데 조건이 전부 걸러낸 경우.
    /// 문구가 진짜 빈 상태와 달라야 하고, 복구는 메뉴 3개를 되짚지 않는
    /// 한 번의 행동이어야 한다 (감사 1107·0839)
    private var filteredEmpty: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s3) {
            Text("조건에 맞는 오답이 없습니다").font(.mBodyB).foregroundStyle(Tokens.ink)
            Text("과목·이유 필터나 검색어를 바꾸면 목록이 다시 나타납니다.")
                .font(.mCaption).foregroundStyle(Tokens.text3)
                .fixedSize(horizontal: false, vertical: true)
            Button("필터 초기화") {
                store.wrongNoteFilterUnit = nil
                store.wrongNoteFilterError = nil
                store.wrongNoteQuery = ""
            }
            .buttonStyle(.plain)
            .font(.mBodyB).foregroundStyle(Tokens.primary)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private var filterMenus: some View {
        HStack(spacing: Tokens.Space.s2) {
            // Menu 안은 Button 이 아니라 Picker — 열었을 때 현재 선택에
            // 시스템 체크마크가 붙어야 같은 항목을 다시 고르는 확인 행동이 없다 (감사 1030)
            Menu {
                Picker("과목", selection: $store.wrongNoteFilterUnit) {
                    Text("전체 과목").tag(String?.none)
                    ForEach(Array(Set(store.wrongNotes.map(\.unit))).sorted(), id: \.self) { unit in
                        Text(unit).tag(String?.some(unit))
                    }
                }
            } label: {
                Label(store.wrongNoteFilterUnit ?? "전체 과목", systemImage: "line.3.horizontal.decrease")
                    .lineLimit(1).minimumScaleFactor(0.75)
                    .frame(maxWidth: .infinity, minHeight: 44)   // 최소 터치 타깃 44pt (감사 1261)
                    .contentShape(Rectangle())
            }

            Menu {
                Picker("틀린 이유", selection: $store.wrongNoteFilterError) {
                    Text("모든 이유").tag(String?.none)
                    ForEach(WrongErrorType.allCases) { type in
                        Text(type.label).tag(String?.some(type.rawValue))
                    }
                }
            } label: {
                Label(store.wrongNoteFilterError.flatMap { WrongErrorType(rawValue: $0)?.label } ?? "모든 이유",
                      systemImage: "questionmark.circle")
                    .lineLimit(1).minimumScaleFactor(0.75)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
            }

            Menu {
                Picker("정렬", selection: $store.wrongNoteSortKey) {
                    ForEach(WrongNoteSort.allCases) { sort in
                        Text(sort.label).tag(sort)
                    }
                }
            } label: {
                Label(store.wrongNoteSortKey.label, systemImage: "arrow.up.arrow.down")
                    .lineLimit(1).minimumScaleFactor(0.75)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
            }
        }
        .font(.mCaption)
        .foregroundStyle(Tokens.text2)
    }

    private var filterSearch: some View {
        HStack(spacing: 0) {
            TextField("발문·유형·과목 검색", text: $store.wrongNoteQuery)
                .font(.mCaption)
                .textFieldStyle(.plain)
                .padding(.leading, Tokens.Space.s3)
                .padding(.trailing, store.wrongNoteQuery.isEmpty ? Tokens.Space.s3 : 0)
            if !store.wrongNoteQuery.isEmpty {
                // 검색이 목록을 즉시 거르는 구조라 지우기 빈도가 높다 —
                // 전부 백스페이스 대신 한 탭 지우기 (감사 0957)
                Button { store.wrongNoteQuery = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.mCaption).foregroundStyle(Tokens.text4)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("검색어 지우기")
            }
        }
        .frame(minHeight: 44)   // 최소 터치 타깃 44pt (감사 1261)
        .background(Tokens.surface, in: Capsule())
        .overlay(Capsule().strokeBorder(Tokens.line, lineWidth: 1))
    }

    private func section(_ title: String, items: [WrongNoteEntry]) -> some View {
        // 괘선 목록이 아니라 덱 — 카드 사이는 여백으로만 나눈다.
        // LazyVStack: 오답은 무한히 쌓이는 목록이라 진입 시 전량 렌더
        // (행마다 MathText.plain 파싱 포함)를 피한다 (감사 1766)
        LazyVStack(alignment: .leading, spacing: Tokens.Space.s3) {
            SectionRule(title: "\(title) · \(items.count)")
            ForEach(items) { note in
                WrongNoteRow(note: note, isOpen: store.wrongNoteExpanded.contains(note.id)) {
                    // store.anim 을 거친다 — 생 withAnimation 이라 화면 모션을 꺼도,
                    // 시스템 '동작 줄이기' 를 켜도 이 행만 계속 움직였다(감사 적발).
                    withAnimation(store.anim(.easeOut(duration: 0.18), reduceMotion)) {
                        if store.wrongNoteExpanded.contains(note.id) {
                            store.wrongNoteExpanded.remove(note.id)
                        } else {
                            store.wrongNoteExpanded.insert(note.id)
                        }
                    }
                }
            }
        }
    }
}

struct WrongNoteRow: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let note: WrongNoteEntry
    let isOpen: Bool
    let toggle: () -> Void
    // mathHeight 는 지웠다 — 발문을 펼침에서 다시 조판하던 KatexText 전용
    // 높이 상태였고, 그 중복 렌더가 사라지면서 쓰는 곳이 없어졌다.
    @State private var showPlayer = false          // 갈라진 단계부터 풀이 애니메이션
    @State private var notePlayerMode = 0          // 0 = 그림 안무, 1 = 식 변형
    @State private var notePlayerHeight: CGFloat = 360
    @State private var playerHeight: CGFloat = 320

    private var stateBadge: (String, ReviewBadge.State) {
        // 웹 어휘와 1:1 (wrong-notes.ejs). 여기서 단어를 바꾸면 화면 소제목과도 어긋난다.
        if note.isMastered { return ("복습 완료", .mastered) }
        if note.isDue { return ("복습 대기", .due) }
        let f = DateFormatter(); f.dateFormat = "M/d"
        let when = note.nextReviewAt.map { f.string(from: $0) } ?? ""
        return ("복습 예정 · \(when)", .pending)
    }

    /// 학생 입력 없이 바로 답이 오는 쪽. 문제·내 답·모범 풀이를 실어 보낸다.
    private var diagnoseButton: some View {
        Button {
            store.route = .chat
            AITutor.shared.discoverAndLoad()
            AITutor.shared.analyze(
                statement: note.statement,
                myAnswer: note.myAnswer,
                correctAnswer: note.answer,
                steps: note.steps,
                errorType: note.errorType,
                divergenceStep: note.divergenceStep,
                coachLevel: store.coach.level)
        } label: {
            Label("왜 틀렸는지 알려주기", systemImage: "magnifyingglass")
                .font(.mCaption).foregroundStyle(Tokens.primary)
                .padding(.horizontal, Tokens.Space.s3).padding(.vertical, 6)
                .overlay(Capsule().strokeBorder(Tokens.primary, lineWidth: 1.2))
                // 캡슐 모양은 그대로 두고 누를 수 있는 범위만 44pt (감사 1202)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("이 문제와 내가 낸 답을 넘겨 어디서 틀렸는지 바로 설명을 받습니다")
    }

    /// 무엇을 물을지 학생이 직접 쓰는 쪽. 문제 맥락만 채팅에 깔아 둔다.
    private var askButton: some View {
        Button {
            store.openChatAbout(problem: note.statement, myAnswer: note.myAnswer,
                                correct: note.answer)
        } label: {
            Label("이 문제 직접 질문하기", systemImage: "text.bubble")
                .font(.mCaption).foregroundStyle(Tokens.text2)
                .padding(.horizontal, Tokens.Space.s3).padding(.vertical, 6)
                .overlay(Capsule().strokeBorder(Tokens.line, lineWidth: 1.2))
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("이 문제를 띄워 둔 채로 궁금한 점을 직접 적어 물어봅니다")
    }

    /// 이 문제 **하나만** 바로 다시 풀기.
    ///
    /// WHY — 감독 피드백: "코스 마냥 주어진 순서로 복습하는게 맘에 안들어.
    /// 지금 복습할 문제 옆에 이 문제 다시 풀기 가능토록."
    /// 종전에는 오답노트에서 문제를 푸는 길이 **덩어리 세트뿐**이었다("복습 시작"이
    /// due 전체를 열고, 행에는 설명·질문·풀이재생만 있었다). 지금 눈에 보이는 이
    /// 문제를 풀고 싶으면 관심 없는 문제들을 순서대로 통과해야 했다.
    ///
    /// includingMastered: true 인 이유 — 이 버튼은 학생이 **한 문제를 지목한** 요청이다.
    /// 졸업한 오답을 덩어리 복습에서 되살리지 않는 규칙(startReview 기본값)은
    /// 그대로 두되, 지목한 경우까지 조용히 무시하면 "복습 완료" 행에서 버튼이
    /// 아무 반응도 없는 죽은 버튼이 된다.
    private var replayButton: some View {
        Button {
            store.startReview(ids: [note.id], includingMastered: true)
        } label: {
            Label("다시 풀기", systemImage: "arrow.counterclockwise")
                .font(.mCaption).foregroundStyle(Tokens.primary)
                .padding(.horizontal, Tokens.Space.s3).padding(.vertical, 6)
                .overlay(Capsule().strokeBorder(Tokens.primary, lineWidth: 1.2))
                // 캡슐 모양은 그대로 두고 누를 수 있는 범위만 44pt (감사 1202)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("이 문제 다시 풀기")
        .accessibilityHint("이 문제 한 개만 지금 바로 다시 풉니다")
    }

    /// 메타 한 줄 — 알약은 상태(ReviewBadge) 하나만. 과목·틀린 횟수는
    /// 일반 메타 텍스트다. 카드마다 알약이 늘어서면 상태가 안 읽힌다.
    private var metaLine: some View {
        HStack(spacing: Tokens.Space.s3) {
            Text(note.unit).font(.mMicro).foregroundStyle(Tokens.text3)
            ReviewBadge(state: stateBadge.1, text: stateBadge.0)
            if note.wrongCount > 1 {
                Label("\(note.wrongCount)회 틀림", systemImage: "xmark.circle")
                    .font(.mMicro).foregroundStyle(Tokens.incorrectRed)
            }
            Spacer(minLength: 0)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
            VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                // 발문이 카드의 주인공. 수식이 들어오면 목록에서도 KaTeX로
                // 조판한다. 수학 앱의 첫 인상이 ASCII 근사식이어서는 안 된다.
                //
                // 펼침 토글은 **발문 줄만** 감싼다. 메타 줄이 토글 버튼 안에 있으면
                // 그 안에 "다시 풀기" 버튼을 넣을 수 없다(버튼 안의 버튼은 어느
                // 쪽이 눌렸는지 SwiftUI 가 보장하지 않는다). 발문 줄은 카드에서
                // 가장 큰 영역이라 펼침 타깃으로 충분하다.
                Button(action: toggle) {
                    HStack(alignment: .top, spacing: Tokens.Space.s2) {
                        MathInline(
                            text: MathText.normalizeDelimiters(note.statement),
                            font: .mBodyB,
                            color: Tokens.ink,
                            pixelSize: 17)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Spacer(minLength: Tokens.Space.s2)
                        Image(systemName: "chevron.down")
                            .font(.mMicro).foregroundStyle(Tokens.text4)
                            .rotationEffect(.degrees(isOpen ? 180 : 0))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                // 메타 + 재풀이. 390pt 아이폰에서 한 줄에 안 들어가면 두 줄로 접는다 —
                // 접히지 않으면 "다시 풀기" 가 화면 밖으로 밀려 눌리지 않는다.
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: Tokens.Space.s3) {
                        metaLine
                        replayButton
                    }
                    VStack(alignment: .leading, spacing: Tokens.Space.s1) {
                        metaLine
                        replayButton
                    }
                }
            }

            if isOpen {
                VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                    // 발문은 여기서 다시 그리지 않는다.
                    //
                    // 바로 위 헤더의 MathInline 이 이미 **전문**을 렌더한다 —
                    // lineLimit 도 truncation 도 없고(MathLabel.swift), KaTeX 쪽
                    // mathline.html 은 줄바꿈 후 실제 높이를 스스로 보고한다.
                    // 즉 헤더는 요약이 아니라 완본이므로, 펼침에서 같은 문장을
                    // KatexText 로 한 번 더 조판하면 같은 발문이 위아래로 두 번
                    // 보인다("이미 나온 텍스트를 왜 또 보여주는가", 2026-08-17 리포트).
                    // 펼침의 자리는 헤더에 없는 것 — 갈라진 단계·풀이·힌트·필기다.
                    if let step = note.divergenceStep {
                        Text(step == 0 ? "갈라진 곳: 스스로 못 짚음 — 1단계 개념부터"
                             : "갈라진 곳: \(step)단계부터 다시")
                            .font(.mCaption).foregroundStyle(Tokens.primary)
                    }
                    // 복습 요청 반영 — 저장된 갈라진 단계부터 풀이 애니메이션을 여기서도 재생
                    if note.steps.count >= 2 {
                        Button {
                            withAnimation(store.anim(.easeOut(duration: 0.2), reduceMotion)) {
                                showPlayer.toggle()
                            }
                        } label: {
                            Label(showPlayer ? "풀이 애니메이션 접기" : "풀이 애니메이션 보기",
                                  systemImage: showPlayer ? "pause.circle" : "play.circle")
                                .font(.mCaption).foregroundStyle(Tokens.primary)
                                // 같은 파일의 다른 글자 버튼처럼 최소 터치 타깃 44pt (감사 1202)
                                .frame(minHeight: 44, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        if showPlayer {
                            Picker("풀이 보기 방식", selection: $notePlayerMode) {
                                Text("그림으로").tag(0)
                                Text("식으로").tag(1)
                            }
                            .pickerStyle(.segmented)
                            .frame(maxWidth: 240)
                            // 갈라진 단계를 짚어 둔 노트는 **식 모드로 연다.**
                            // 그림 안무는 1단계부터 통째로 다시 도는데, 바로 위 줄이
                            // "갈라진 곳: N단계부터 다시" 라고 말해 놓고 1단계부터
                            // 재생하면 말과 화면이 어긋난다. 식 모드는 startStep 을
                            // 받으므로 그 단계부터 시작한다(결과 화면과 같은 규칙).
                            .onAppear {
                                if let d = note.divergenceStep, d > 0 { notePlayerMode = 1 }
                            }

                            if notePlayerMode == 0 {
                                SolutionScenePlayerView(
                                    visualizationJSON: note.visualizationJSON,
                                    steps: note.steps, answer: note.answer,
                                    statement: note.statement, height: $notePlayerHeight)
                                    .frame(height: notePlayerHeight)
                                    .id("note-scene-\(note.id)")
                            } else {
                                SolutionPlayerView(steps: note.steps,
                                                   startStep: max(1, note.divergenceStep ?? 1),
                                                   height: $playerHeight)
                                    .frame(height: playerHeight)
                                    .id("note-player-\(note.id)")
                            }
                        }
                    }
                    // 힌트 = 모범 풀이의 첫 단계까지만. 정답은 끝까지 안 보여준다.
                    // 힌트에도 \( \)·$ 수식이 섞여 온다 — 목록과 같은 평문 근사로 정리
                    if let first = note.steps.first {
                        HStack(alignment: .top, spacing: Tokens.Space.s2) {
                            Image(systemName: "lightbulb").font(.mCaption).foregroundStyle(Tokens.warningInk)
                            Text("힌트: \(MathText.plain(first))").font(.mCallout).foregroundStyle(Tokens.text2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    // 온디바이스 AI 진입 두 개 — 하는 일이 실제로 다르다.
                    //  · 위: 저장된 문제·내 답·모범 풀이·갈라진 단계를 그대로 실어
                    //    보내 답을 바로 받아 온다. 학생이 아무것도 입력하지 않는다.
                    //  · 아래: 같은 문제 맥락만 채팅에 깔아 두고(chatSeedContext),
                    //    무엇을 물을지는 학생이 직접 쓴다.
                    // 예전 이름("AI 진단" / "AI에게 묻기")은 둘 다 같은 말로 읽혀
                    // 차이가 안 보였다. 이름만 보고 고를 수 있게 바꾼다.
                    // 모델이 아직 없으면 채팅 화면이 안내 카드를 띄운다.
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: Tokens.Space.s3) {
                            diagnoseButton
                            askButton
                        }
                        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                            diagnoseButton
                            askButton
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // 그때 내 풀이 — 틀린 순간의 필기 스냅샷
                    if let b64 = note.drawingPNGBase64,
                       let data = Data(base64Encoded: b64),
                       let ui = UIImage(data: data) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("그때 내 풀이").font(.mMicro).foregroundStyle(Tokens.text3)
                            Image(uiImage: ui)
                                .resizable().scaledToFit()
                                .frame(maxHeight: 180)
                                .background(Tokens.surface)
                                .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.sm))
                                .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.sm)
                                    .strokeBorder(Tokens.line, lineWidth: 1))
                        }
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(Tokens.Space.s5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.Radius.lg))
        .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.lg)
            .strokeBorder(Tokens.line, lineWidth: 1))
        .background {
            // 덱 뒷장 2장 — paper2 모서리가 3pt·6pt 아래로 비치는 순수 장식
            RoundedRectangle(cornerRadius: Tokens.Radius.lg).fill(Tokens.paper2)
                .padding(.horizontal, Tokens.Space.s3).offset(y: 6)
            RoundedRectangle(cornerRadius: Tokens.Radius.lg).fill(Tokens.paper2)
                .padding(.horizontal, 6).offset(y: 3)
        }
        .padding(.bottom, 6)
    }
}

/// 빈 상태 고스트 카드 — 채워진 상태의 미리보기. 순수 장식, 상호작용 없음.
private struct GhostNoteCard: View {
    let statement: String
    let tag: String

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s3) {
            Text(statement).font(.mBodyB).foregroundStyle(Tokens.ink)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            HStack(spacing: Tokens.Space.s3) {
                // 실 카드와 같은 문법 — 알약은 상태 하나, 과목은 일반 메타 텍스트
                Text(tag).font(.mMicro).foregroundStyle(Tokens.text3)
                ReviewBadge(state: .due)
            }
        }
        .padding(Tokens.Space.s5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.Radius.lg))
        .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.lg)
            .strokeBorder(Tokens.line, lineWidth: 1))
    }
}
