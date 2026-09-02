//
//  GoatArenaMatchPlayScreen.swift
//  Matths
//
//  GOAT Arena의 개인 경기 화면.
//  경기·역할·문항·제한 시간은 서버 정본만 사용하며, 정답·점수·승패를
//  클라이언트에서 계산하거나 미리 표시하지 않는다.
//

import SwiftUI
import PencilKit

private struct GoatArenaSolutionBoardDraft: Codable {
    var revision: Int
    var drawingData: Data
}

private extension PKDrawing {
    func arenaEvidencePNG() -> Data? {
        // 빈 PKDrawing의 bounds는 CGRect.null이라 maxX/maxY가 무한대다. 그 값을
        // UIGraphicsImageRenderer 크기로 넘기면 bitmap 생성이 실패해, 암산하고
        // 답만 고른 학생이 다음 문항으로 넘어갈 수 없었다. 빈 판도 유효한 원본이다.
        let drawingBounds = strokes.isEmpty ? .zero : bounds.insetBy(dx: -32, dy: -32)
        let finiteMaxX = drawingBounds.maxX.isFinite ? drawingBounds.maxX : 0
        let finiteMaxY = drawingBounds.maxY.isFinite ? drawingBounds.maxY : 0
        let width = max(1200, ceil(finiteMaxX), 1)
        let height = max(900, ceil(finiteMaxY), 1)
        let page = CGRect(x: 0, y: 0, width: width, height: height)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: page.size, format: format)
        return renderer.pngData { context in
            UIColor.white.setFill()
            context.fill(page)
            guard !strokes.isEmpty else { return }
            image(from: page, scale: 1).draw(in: page)
        }
    }
}

private enum GoatArenaSolutionBoardDraftStore {
    private static func url(matchId: String, slot: Int, accountSlot: String) -> URL {
        DataScope.url(
            "goat-arena-board-\(matchId)-\(slot).json",
            for: accountSlot)
    }

    static func load(matchId: String, slot: Int, accountSlot: String) -> GoatArenaSolutionBoardDraft? {
        guard let data = try? Data(contentsOf: url(
            matchId: matchId, slot: slot, accountSlot: accountSlot)) else { return nil }
        return try? JSONDecoder().decode(GoatArenaSolutionBoardDraft.self, from: data)
    }

    static func save(
        _ draft: GoatArenaSolutionBoardDraft,
        matchId: String,
        slot: Int,
        accountSlot: String
    ) {
        guard let data = try? JSONEncoder().encode(draft) else { return }
        try? data.write(
            to: url(matchId: matchId, slot: slot, accountSlot: accountSlot),
            options: .atomic)
    }

    static func clear(matchId: String, accountSlot: String) {
        for slot in 1...5 {
            try? FileManager.default.removeItem(at: url(
                matchId: matchId, slot: slot, accountSlot: accountSlot))
        }
    }
}

/// 경기 화면이 **서버를 다시 부르지 않고** 로비에 적을 수 있는 사실들.
///
/// WHY. 웹은 경기 페이지에 시작 전 로비가 있다(views/goat-arena-match.ejs:196-217):
/// 문항 수 · 문항당 제한 시간 · 출제 범위를 읽히고 "시작하면 내 제한 시간이 바로
/// 흐릅니다" 를 보여 준 다음, **폼 버튼을 눌러야** 타이머가 간다.
/// 앱은 커버가 뜨는 즉시 `.task` 가 POST /start 를 쳐서, 학생이 스피너를 보는 동안
/// 이미 서버 타이머가 흘렀다. 몇 분짜리인지, 무엇을 걸었는지 보기 전에 시작됐다.
///
/// 값은 전부 GOAT Arena 홈이 이미 갖고 있던 것이다 — 새 서버 호출을 만들지 않는다.
struct GoatArenaMatchBriefing: Equatable {
    /// "도전자" · "방어자" — 홈이 쓰는 같은 라벨 함수의 결과를 그대로 받는다.
    var roleLabel: String?
    /// "자리 도전, Ranked" 처럼 홈 카드의 `경기` 칸과 같은 문장.
    var matchLabel: String?
    /// "3일, 학습일수" — 홈 카드의 `맡긴 일수` 와 같은 문장.
    var stakeText: String?
    /// 서버 읽기 모델이 준 경기 제한 시간. 없으면 로비에서 그 사실을 밝힌다.
    var timeLimitSeconds: Int?
    /// 홈 카드의 `시작 마감` 과 같은 문장.
    var startsByText: String?
    /// 이미 개인 타이머가 흐르는 경기(재개)와 증거 제출 복귀는 로비를 띄우지 않는다.
    /// 이미 시작된 경기 앞에 확인 단계를 세우면 그 초는 학생 손해다.
    var skipsLobby: Bool = false
}

struct GoatArenaMatchPlayScreen: View {
    private typealias Attempt = ServerAPI.GoatArenaAttempt
    private typealias QuestionPack = ServerAPI.GoatArenaQuestionPack
    private typealias Question = ServerAPI.GoatArenaQuestionPack.Question
    private typealias Submission = ServerAPI.GoatArenaSubmission

    let matchId: String
    let briefing: GoatArenaMatchBriefing?

    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var screenshotGuard: ScreenshotGuard
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    /// 가로로 든 iPhone. 경기 화면은 제한 시간이 걸려 있어 스크롤이 곧 손해다.
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let accountSlot: String
    private let clientBuildVersion: String
    @State private var eventChannel: GoatArenaEventChannel
    @State private var startCommandId: String
    @State private var submissionId: String

    @State private var attempt: Attempt?
    @State private var questionPack: QuestionPack?
    @State private var submission: Submission?
    @State private var evidenceReceipt: ServerAPI.GoatArenaEvidenceReceipt?
    @State private var attemptEndsAt: Date?

    @State private var answers: [Int: String] = [:]
    @State private var dirtySlots: Set<Int> = []
    @State private var answerCommandIds: [Int: String] = [:]
    @State private var advanceCommandIds: [Int: String] = [:]
    @State private var currentIndex = 0
    @State private var localReviewContext: GoatArenaLocalReviewContext?

    @State private var solutionDrawing = PKDrawing()
    @State private var solutionAllowsFinger = false
    @State private var solutionZoom: CGFloat = 1
    @State private var solutionTool: SolutionCanvasTool = .pen
    @State private var solutionInkWidth: CGFloat = 3
    @State private var solutionUndoStack: [PKDrawing] = []
    @State private var solutionRedoStack: [PKDrawing] = []
    @State private var solutionBoardRevisions: [Int: Int] = [:]
    @State private var solutionBoardSavedRevisions: [Int: Int] = [:]
    @State private var solutionBoardSavedHashes: [Int: String] = [:]
    @State private var solutionBoardSaveTask: Task<Void, Never>?
    @State private var isSavingSolutionBoard = false
    @State private var solutionBoardSaveError: String?
    @State private var isInstallingSolutionDrawing = false

    @State private var isLoading = true
    @State private var didRequestStart = false
    @State private var isSavingAnswer = false
    @State private var isMovingQuestion = false
    @State private var isSubmitting = false
    @State private var didTriggerDeadlineSubmit = false

    @State private var now = Date()
    @State private var startError: String?
    @State private var actionError: String?
    @State private var connectionInterrupted = false
    @State private var connectionNotice: String?

    @State private var confirmSubmit = false
    @State private var confirmExit = false

    /// 시작 로비를 아직 지나지 않았다. 이 값이 true 인 동안 POST /start 는 나가지 않는다.
    @State private var lobbyPending: Bool
    /// 지금 재생 중인 시작·라운드 인트로. nil 이면 오버레이가 없다.
    @State private var intro: ArenaMatchIntroOverlay.Kind?
    /// 인트로를 이미 재생한 문항 번호. 같은 문항에서 두 번 재생하지 않는다.
    @State private var introducedQuestionNumber = 0
    /// 잔여 60초 이하에서 남은 시간 표시가 숨 쉬는 상태(웹 arenaTimerPulse 대응).
    @State private var timerPulsing = false
    @State private var preStartContract: ServerAPI.GoatArenaParticipantMatch.PreStartContract?
    @State private var isLoadingPreStartContract = false

    private let countdown = Timer.publish(
        every: 1,
        on: .main,
        in: .common
    ).autoconnect()

    init(matchId: String, briefing: GoatArenaMatchBriefing? = nil) {
        self.matchId = matchId
        self.briefing = briefing
        // 브리핑이 없는 호출부(디버그 픽스처 등)는 종전대로 곧바로 시작한다.
        _lobbyPending = State(initialValue: briefing.map { !$0.skipsLobby } ?? false)
        let commandKeys = GoatArenaCommandKeyStore.loadOrCreate(matchId: matchId)
        accountSlot = DataScope.slot
        clientBuildVersion = commandKeys.clientBuildVersion
        _eventChannel = State(
            initialValue: GoatArenaEventChannel(
                matchId: matchId,
                clientBuildVersion: commandKeys.clientBuildVersion,
                accountSlot: DataScope.slot
            )
        )
        _startCommandId = State(initialValue: commandKeys.startCommandId)
        _submissionId = State(initialValue: commandKeys.submissionId)
    }

    private var questions: [Question] {
        (questionPack?.questions ?? []).sorted { left, right in
            left.slot < right.slot
        }
    }

    private var currentQuestion: Question? {
        questions.first
    }

    private var currentQuestionNumber: Int {
        questionPack?.currentQuestionNumber
            ?? attempt?.currentQuestionNumber
            ?? currentQuestion?.slot
            ?? 1
    }

    private var totalQuestionCount: Int {
        max(1, attempt?.questionCount ?? questionPack?.questionCount ?? 5)
    }

    private var answeredCount: Int {
        let currentAnswered = currentQuestion.map {
            !(answers[$0.slot] ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty
        } ?? false
        return max(0, currentQuestionNumber - 1) + (currentAnswered ? 1 : 0)
    }

    private var remainingSeconds: Int? {
        guard let attemptEndsAt else { return nil }
        return max(0, Int(ceil(attemptEndsAt.timeIntervalSince(now))))
    }

    private var interactionBusy: Bool {
        isSavingAnswer || isMovingQuestion || isSubmitting
    }

    private var shortHeight: Bool { verticalSizeClass == .compact }

    private var deadlineReached: Bool {
        remainingSeconds == 0
    }

    private var answerInteractionDisabled: Bool {
        interactionBusy || deadlineReached
    }

    private var attemptIsSubmitted: Bool {
        submission != nil || (attempt.map {
            ["EVIDENCE_REQUIRED", "SUBMITTED"].contains($0.status)
        } ?? false)
    }

    /// 서버가 증거 제출을 요구한 동안에는 실수로 경기 화면을 닫지 않는다.
    /// 마감이 지난 뒤에는 사용자를 화면에 가두지 않고 Arena로 돌아갈 수 있게 한다.
    private var evidenceSubmissionOutstanding: Bool {
        guard evidenceReceipt == nil else { return false }
        let required = submission?.evidenceRequired ?? attempt?.evidenceRequired ?? false
        guard required else { return false }
        let rawDeadline = submission?.evidenceDeadlineAt ?? attempt?.evidenceDeadlineAt
        guard let rawDeadline, let deadline = ArenaServerDate.parse(rawDeadline) else {
            return true
        }
        return deadline > now
    }

    private var accountIsCurrent: Bool {
        DataScope.slot == accountSlot
    }

    private var usesDebugFixture: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-goatMatchFixture")
        #else
        false
        #endif
    }

    var body: some View {
        ZStack {
            Tokens.paper
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header

                Group {
                    if lobbyPending {
                        lobbyView
                    } else if isLoading {
                        loadingView
                    } else if let startError {
                        failedView(startError)
                    } else if let submission {
                        submittedView(submission)
                    } else if let attempt,
                              ["EVIDENCE_REQUIRED", "SUBMITTED"].contains(attempt.status) {
                        submittedAttemptView(attempt)
                    } else if attempt != nil, questionPack != nil {
                        playView
                    } else {
                        failedView("경기 정보를 확인할 수 없습니다. GOAT Arena 화면에서 다시 시도해 주세요.")
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            // 시작·라운드 인트로. 화면 맨 위에 얹고, 탭 한 번이면 즉시 걷힌다.
            if let intro {
                ArenaMatchIntroOverlay(kind: intro) { self.intro = nil }
                    .transition(.opacity)
                    .zIndex(2)
            }
        }
        .task {
            // 로비를 지나야 시작한다. 로비가 없는 경로(재개·증거 제출·픽스처)만
            // 종전처럼 화면이 뜨자마자 서버 타이머를 건다.
            guard !lobbyPending else { return }
            await beginMatchIfNeeded()
        }
        .task(id: lobbyPending) {
            guard lobbyPending, !usesDebugFixture else { return }
            await loadPreStartContract()
        }
        .task(id: attempt?.attemptId) {
            if !usesDebugFixture { await heartbeatLoop() }
        }
        .onReceive(countdown) { date in
            now = date
            updateTimerPulse()
            guard attempt != nil,
                  !attemptIsSubmitted,
                  remainingSeconds == 0,
                  !didTriggerDeadlineSubmit else { return }
            didTriggerDeadlineSubmit = true
            Task { await refreshAfterQuestionDeadline() }
        }
        .onChange(of: scenePhase) { _, phase in
            handleScenePhase(phase)
        }
        .onChange(of: solutionDrawing) { _, drawing in
            solutionDrawingChanged(drawing)
        }
        .onReceive(NotificationCenter.default.publisher(for: DataScope.didSwitchNotification)) { note in
            guard let newSlot = note.object as? String,
                  newSlot != accountSlot else { return }
            dismiss()
        }
        .confirmationDialog(
            "답안을 제출할까요?",
            isPresented: $confirmSubmit,
            titleVisibility: .visible
        ) {
            Button("최종 제출") {
                Task { await advanceCurrentQuestion() }
            }
            Button("계속 풀기", role: .cancel) {}
        } message: {
            let unanswered = max(0, totalQuestionCount - answeredCount)
            Text(
                unanswered == 0
                    ? "제출 뒤에는 답안을 바꿀 수 없습니다."
                    : "아직 답하지 않은 문항이 \(unanswered)개 있습니다. 제출 뒤에는 답안을 바꿀 수 없습니다."
            )
        }
        .confirmationDialog(
            "경기 화면을 나갈까요?",
            isPresented: $confirmExit,
            titleVisibility: .visible
        ) {
            Button("현재 답안 저장 후 나가기") {
                Task { await saveAndDismiss() }
            }
            Button("나중에 이어하기", role: .destructive) {
                persistDraft()
                dismiss()
            }
            Button("계속 풀기", role: .cancel) {}
        } message: {
            Text("화면을 나가도 개인 제한 시간은 계속 흐릅니다. 저장되지 않은 답안은 이 기기에 임시 보관됩니다.")
        }
        .alert(
            "요청을 완료하지 못했습니다",
            isPresented: Binding(
                get: { actionError != nil },
                set: { if !$0 { actionError = nil } }
            )
        ) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(actionError ?? "")
        }
        .interactiveDismissDisabled(!attemptIsSubmitted || evidenceSubmissionOutstanding)
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: 0) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Tokens.Space.s4) {
                    headerCloseButton
                    headerTitle
                    Spacer(minLength: Tokens.Space.s3)
                    headerAttemptStatus
                }

                VStack(spacing: Tokens.Space.s2) {
                    HStack(spacing: Tokens.Space.s3) {
                        headerCloseButton
                        headerTitle
                        Spacer(minLength: 0)
                    }
                    if attempt != nil, !attemptIsSubmitted {
                        HStack {
                            Spacer(minLength: 44 + Tokens.Space.s3)
                            headerAttemptStatus
                        }
                    }
                }
            }
            .padding(.horizontal, Tokens.Space.s4)
            .padding(.vertical, Tokens.Space.s2)

            if let attempt, let remainingSeconds, !attemptIsSubmitted {
                ProgressBar(
                    value: min(
                        1,
                        max(
                            0,
                            Double(remainingSeconds)
                                / Double(max(1, attempt.timeLimitSeconds))
                        )
                    ),
                    tint: remainingSeconds <= 60 ? Tokens.danger : Tokens.primary,
                    track: Tokens.paper2
                )
                .frame(height: 4)
                .accessibilityLabel("개인 경기 남은 시간")
                .accessibilityValue(timeText(remainingSeconds))
            }
        }
        .background(Tokens.surface)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Tokens.line)
                .frame(height: 1)
        }
    }

    private var headerCloseButton: some View {
        Button {
            if evidenceSubmissionOutstanding {
                actionError = "서버가 인앱 풀이판을 원본 증거로 확정하고 있습니다. 잠시 뒤 다시 확인해 주세요. 별도 사진 제출은 필요하지 않습니다."
            } else if attemptIsSubmitted || attempt == nil {
                dismiss()
            } else {
                confirmExit = true
            }
        } label: {
            Image(systemName: "xmark")
                .font(.mBodyB)
                .foregroundStyle(Tokens.text2)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("경기 화면 닫기")
    }

    private var headerTitle: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("GOAT ARENA")
                .font(.mMicro)
                .foregroundStyle(Tokens.primary)
            Text(attempt.map { roleTitle($0.participantRole) } ?? "경기 준비")
                .font(.mBodyB)
                .foregroundStyle(Tokens.ink)
                .fixedSize(horizontal: false, vertical: true)
            // 내가 무엇을 걸고 이 화면에 들어왔는지. 홈 카드에는 있었지만 정작
            // 문제를 푸는 화면에는 한 글자도 없던 값이다(웹도 마찬가지다).
            // 세로가 짧은 뷰포트에서는 헤더를 늘리지 않는다.
            if let stakeText = briefing?.stakeText, !shortHeight {
                Text("맡긴 \(stakeText)")
                    .font(.mMicro)
                    .foregroundStyle(Tokens.text3)
                    .lineLimit(1)
            }
        }
    }

    @ViewBuilder
    private var headerAttemptStatus: some View {
        if let attempt, !attemptIsSubmitted {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Tokens.Space.s3) {
                    Text("응답 \(answeredCount) / \(attempt.questionCount)")
                        .font(.mNumeric)
                        .foregroundStyle(Tokens.text2)
                        .monospacedDigit()
                    countdownLabel
                }

                countdownLabel
            }
        }
    }

    /// 잔여 60초 이하. 웹은 이 구간에서 남은 시간을 900ms 주기로 깜빡인다
    /// (goat-arena.css `arenaTimerPulse`, 클래스 토글은 goat-arena-match.js:381).
    /// 앱은 색만 바뀌고 아무 일도 일어나지 않았다.
    private var timeWarning: Bool {
        guard let remainingSeconds else { return false }
        return remainingSeconds > 0 && remainingSeconds <= 60
    }

    @ViewBuilder
    private var countdownLabel: some View {
        if let remainingSeconds {
            HStack(spacing: 6) {
                Circle()
                    .fill(timeWarning ? Tokens.danger : Tokens.primary)
                    .frame(width: 7, height: 7)
                Text(timeText(remainingSeconds))
                    .font(.mNumeric)
                    .foregroundStyle(
                        remainingSeconds <= 60 ? Tokens.danger : Tokens.ink)
                    .monospacedDigit()
            }
            .padding(.horizontal, Tokens.Space.s3)
            .frame(minHeight: 36)
            .background(
                remainingSeconds <= 60 ? Tokens.dangerSoft : Tokens.primarySoft,
                in: RoundedRectangle(cornerRadius: Tokens.Radius.md)
            )
            // 동작 줄이기·모션 끄기에서는 store.anim 이 nil 을 돌려주므로
            // 깜빡임 없이 색만 남는다(종전 동작 그대로).
            .opacity(timerPulsing ? 0.58 : 1)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("남은 시간 \(timeText(remainingSeconds))")
        }
    }

    /// 인트로를 한 번 세운다. 모션이 꺼져 있으면 오버레이가 스스로 정지 한 컷으로
    /// 대체하므로 여기서는 등장 애니메이션만 게이트에 태운다.
    @MainActor
    private func presentIntro(_ kind: ArenaMatchIntroOverlay.Kind) {
        introducedQuestionNumber = max(introducedQuestionNumber, kind.questionNumber)
        withAnimation(store.anim(ArenaIntroMotion.curtain, reduceMotion)) {
            intro = kind
        }
    }

    /// 경고 구간에 들어가면 숨쉬기를 켜고, 벗어나면 즉시 끈다.
    private func updateTimerPulse() {
        if timeWarning {
            guard !timerPulsing else { return }
            withAnimation(store.anim(ArenaIntroMotion.timerPulse, reduceMotion)) {
                timerPulsing = true
            }
        } else if timerPulsing {
            withAnimation(nil) { timerPulsing = false }
        }
    }

    // MARK: 상태 스트립
    //
    // WHY. 웹 경기 화면은 문제 위에 3칸 그리드를 **항상** 띄운다
    // (views/goat-arena-match.ejs:126-142 — 경기 상태 / 내 역할 / 상대).
    // 앱 문제 화면에는 역할 한 줄뿐이라 학생이 "지금 내 차례인지, 무엇을 걸었는지"
    // 를 화면에서 읽을 수 없었다. 감독 피드백("뭐가 어떻게 돌아가는지 모르겠다")의
    // 한 축이다.
    //
    // 상대 닉네임은 넣지 않는다. 웹의 matchData.opponentName 은 웹 전용 필드고
    // 앱용 읽기 모델(serializeParticipantMatch)에는 없다 — 없는 값을 앱이 지어내지
    // 않는다. 새 서버 호출도 만들지 않는다: 세 칸 모두 이미 화면이 들고 있는 값이다.
    private var statusStripCells: [(String, String)] {
        var cells: [(String, String)] = [("경기 상태", attemptStageText)]
        if let attempt {
            cells.append(("내 역할", shortRoleTitle(attempt.participantRole)))
        } else if let roleLabel = briefing?.roleLabel {
            cells.append(("내 역할", roleLabel))
        }
        if let stakeText = briefing?.stakeText {
            cells.append(("맡긴 일수", stakeText))
        }
        return cells
    }

    /// 서버가 준 attempt.status 를 학생의 말로 옮긴다. 상태를 새로 판정하지 않는다.
    private var attemptStageText: String {
        guard let attempt else { return "경기 준비" }
        switch attempt.status {
        case "IN_PROGRESS":
            return deadlineReached ? "문항 시간 종료" : "진행 중 · 내 차례"
        case "EVIDENCE_REQUIRED":
            return "풀이판 원본 확정 중"
        case "SUBMITTED":
            return "상대 제출 · 채점 대기"
        default:
            return "서버 상태 확인"
        }
    }

    @ViewBuilder
    private var matchStatusStrip: some View {
        let cells = statusStripCells
        if !cells.isEmpty {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: Tokens.Space.s6) {
                    ForEach(cells, id: \.0) { cell in
                        statusStripCell(cell.0, cell.1)
                    }
                    Spacer(minLength: 0)
                }

                VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                    ForEach(cells, id: \.0) { cell in
                        statusStripCell(cell.0, cell.1)
                    }
                }
            }
            .padding(Tokens.Space.s4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Tokens.surface)
            .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: Tokens.Radius.md)
                    .strokeBorder(Tokens.line, lineWidth: 1))
        }
    }

    private func statusStripCell(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.mMicro)
                .foregroundStyle(Tokens.text3)
            Text(value)
                .font(.mBodyB)
                .foregroundStyle(Tokens.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: 제출 뒤 대기 단계
    //
    // WHY. 종전 안내는 "…끝날 때까지 점수나 승패를 미리 표시하지 않습니다" 라는
    // 부정문뿐이었다. 학생은 자기가 대기 중인지 화면이 멈춘 건지 구분할 수 없었다.
    // 새 서버 값을 만들지 않고 이미 아는 사실만 순서대로 세운다 —
    // 무엇이 끝났고, 다음이 누구 차례이며, 결과가 어디에 나타나는가.
    private func waitingStages(evidenceRequired: Bool) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s4) {
            Text("다음 단계")
                .font(.mMicro)
                .foregroundStyle(Tokens.text3)

            waitingStage(
                done: true,
                title: "내 답안 제출",
                detail: "서버가 접수했습니다. 이 답안은 더 바뀌지 않습니다.")

            waitingStage(
                done: !evidenceRequired,
                title: "인앱 풀이판 원본 확정",
                detail: evidenceRequired
                    ? "서버가 다섯 문항의 풀이판을 원본 증거로 자동 확정하고 있습니다. 별도 사진 제출은 필요하지 않습니다."
                    : "다섯 문항의 풀이판이 원본 증거로 자동 제출되었습니다.")

            waitingStage(
                done: false,
                title: "상대 제출과 서버 채점",
                detail: "상대 제출이 끝나면 서버가 두 답안을 같은 기준으로 채점합니다. 내가 더 할 일은 없습니다.")

            waitingStage(
                done: false,
                title: "정산 결과 확인",
                detail: "정산이 끝나면 GOAT Arena 홈의 ‘최근 경기 결과’ 에 승패와 자리 이동이 나타납니다.")
        }
    }

    private func waitingStage(
        done: Bool,
        title: String,
        detail: String
    ) -> some View {
        HStack(alignment: .top, spacing: Tokens.Space.s3) {
            Image(systemName: done ? "checkmark.circle.fill" : "circle.dashed")
                .font(.mBodyB)
                .foregroundStyle(done ? Tokens.successInk : Tokens.text3)
                .frame(width: 24, height: 24)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.mBodyB)
                    .foregroundStyle(Tokens.ink)
                Text(detail)
                    .font(.mCaption)
                    .foregroundStyle(Tokens.text2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(done ? "완료" : "대기 중")")
        .accessibilityValue(detail)
    }

    // MARK: States

    // MARK: 시작 로비
    //
    // 웹과 같은 순서를 앱에도 세운다: **읽고 → 누르고 → 그때 타이머가 간다.**
    // 서버를 다시 부르지 않는다 — 여기 적히는 값은 전부 홈 카드가 이미 갖고 있던
    // 것을 GoatArenaMatchBriefing 으로 실어 온 것이다.

    private var lobbyView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Tokens.Space.s6) {
                VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                    Text("경기 준비")
                        .font(.mMicro)
                        .foregroundStyle(Tokens.primary)
                    Text("시작하면 내 제한 시간이 바로 흐릅니다")
                        .font(.mTitle)
                        .foregroundStyle(Tokens.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("아래 버튼을 누른 뒤에야 서버가 내 개인 타이머를 시작합니다. 화면을 닫아도 시작한 타이머는 멈추지 않습니다.")
                        .font(.mCallout)
                        .foregroundStyle(Tokens.text2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                DottedRule()

                VStack(alignment: .leading, spacing: Tokens.Space.s4) {
                    ForEach(lobbyFacts, id: \.0) { fact in
                        submittedFact(fact.0, fact.1)
                    }
                }

                if let contract = preStartContract {
                    preStartContractCard(contract)
                } else if isLoadingPreStartContract {
                    HStack(spacing: Tokens.Space.s3) {
                        ProgressView().controlSize(.small)
                        Text("경기 조건을 확인하고 있습니다")
                            .font(.mCallout)
                            .foregroundStyle(Tokens.text2)
                    }
                }

                Text("문항은 한 번에 하나씩 공개되고, 다음 문항으로 넘어가면 이전 문제와 답은 다시 열 수 없습니다. 정답·점수·승패는 서버 정산이 끝난 뒤에만 표시됩니다.")
                    .font(.mCaption)
                    .foregroundStyle(Tokens.text3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(Tokens.Space.s6)
            .frame(maxWidth: Tokens.readableWidth, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        // iPhone 가로에서 설명과 경기 조건을 읽고 나면 시작 버튼이 화면 아래로
        // 밀려 있었다. 제한 시간이 걸린 경기의 핵심 행동은 스크롤 위치와 무관하게
        // 항상 보여야 한다. safe-area inset이라 본문 마지막 줄도 버튼 뒤에 가리지 않는다.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            lobbyActions
        }
    }

    private var lobbyActions: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Tokens.Space.s3) {
                startMatchButton
                laterButton
            }
            VStack(spacing: Tokens.Space.s2) {
                startMatchButton
                laterButton
            }
        }
        .padding(.horizontal, Tokens.Space.s6)
        .padding(.vertical, Tokens.Space.s3)
        .frame(maxWidth: Tokens.readableWidth)
        .frame(maxWidth: .infinity)
        .background(Tokens.surface.opacity(0.98))
        .overlay(alignment: .top) { Divider() }
    }

    private var startMatchButton: some View {
        Button {
            lobbyPending = false
            Task { await beginMatchIfNeeded() }
        } label: {
            Label("지금 시작", systemImage: "play.fill")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(PrimaryButtonStyle())
        .frame(maxWidth: 320)
        .disabled(isLoadingPreStartContract || preStartContract == nil && !usesDebugFixture)
        .accessibilityHint("서버가 내 개인 제한 시간을 시작합니다")
    }

    private var laterButton: some View {
        Button { dismiss() } label: {
            Text("나중에 시작")
                .frame(maxWidth: .infinity)
        }
            .buttonStyle(SecondaryButtonStyle())
            .frame(maxWidth: 320)
    }

    @MainActor
    private func loadPreStartContract() async {
        isLoadingPreStartContract = true
        defer { isLoadingPreStartContract = false }
        do {
            preStartContract = try await ServerAPI.getGoatArenaMatch(
                matchId: matchId).preStartContract
            if preStartContract == nil {
                actionError = "서버가 확정한 경기 조건을 확인할 수 없습니다. GOAT Arena에서 다시 열어 주세요."
            }
        } catch {
            actionError = playErrorMessage(error, operation: .start)
        }
    }

    private func preStartContractCard(
        _ contract: ServerAPI.GoatArenaParticipantMatch.PreStartContract
    ) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s4) {
            Text(contract.title)
                .font(.mHeading)
                .foregroundStyle(Tokens.ink)
            Text(contract.description)
                .font(.mCaption)
                .foregroundStyle(Tokens.text2)
            submittedFact("예치", contract.stake)
            submittedFact("승리", contract.win)
            submittedFact("패배", contract.loss)
            submittedFact(contract.deadlineLabel, contract.deadlineNotice)
        }
        .padding(Tokens.Space.s4)
        .background(Tokens.primarySoft)
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.md)
                .strokeBorder(Tokens.primary.opacity(0.28), lineWidth: 1))
    }

    /// 로비에 세울 사실들. 서버가 준 값만 쓰고, 없는 값은 없다고 적는다 —
    /// 문항 수처럼 시작 전에는 서버 읽기 모델에 없는 값을 앱이 지어내지 않는다.
    private var lobbyFacts: [(String, String)] {
        var facts: [(String, String)] = []
        if let matchLabel = briefing?.matchLabel {
            facts.append(("경기", matchLabel))
        }
        if let roleLabel = briefing?.roleLabel {
            facts.append(("내 역할", roleLabel))
        }
        facts.append((
            "제한 시간",
            briefing?.timeLimitSeconds.map { timeText($0) } ?? "시작할 때 서버가 확정"))
        if let stakeText = briefing?.stakeText {
            facts.append(("맡긴 일수", stakeText))
        }
        if let startsByText = briefing?.startsByText {
            facts.append(("시작 마감", startsByText))
        }
        return facts
    }

    private var loadingView: some View {
        VStack(spacing: Tokens.Space.s5) {
            ProgressView()
                .controlSize(.large)
                .tint(Tokens.primary)
            Text("개인 경기와 문제를 준비하고 있습니다")
                .font(.mHeading)
                .foregroundStyle(Tokens.ink)
            Text("서버가 내 역할과 개인 제한 시간을 확정합니다.")
                .font(.mCallout)
                .foregroundStyle(Tokens.text2)
        }
        .padding(Tokens.Space.s6)
    }

    /// 경기 명령 라우트가 없는 서버에서 start 가 받는 안내. 이 값이면 heartbeat 등
    /// 후속 명령을 시작하지 않고(attempt 가 nil 이라 이미 막힘) 재시도 대신 웹 링크를 보인다.
    static let routeMissingNotice =
        "현재 경기 진행은 앱 안의 웹 GOAT Arena 화면에서 이어집니다."

    private func failedView(_ message: String) -> some View {
        VStack(spacing: Tokens.Space.s5) {
            Image(systemName: "exclamationmark.shield.fill")
                .font(.system(size: 38, weight: .semibold))
                .foregroundStyle(Tokens.warningInk)
            Text("경기를 열지 못했습니다")
                .font(.mHeading)
                .foregroundStyle(Tokens.ink)
            Text(message)
                .font(.mCallout)
                .foregroundStyle(Tokens.text2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: Tokens.Space.s3) {
                Button("GOAT Arena로 돌아가기") {
                    dismiss()
                }
                .buttonStyle(SecondaryButtonStyle())

                if message == Self.routeMissingNotice {
                    // 라우트가 없는 서버에는 "다시 시도"가 의미 없다. 로그인 세션과
                    // 경기 화면 보호를 그대로 잇는 앱 내부 웹 브리지로 보낸다.
                    Button("웹 GOAT Arena에서 진행") {
                        ArenaWebPresenter.open(
                            .match(matchId: matchId),
                            guardModel: screenshotGuard,
                            onCapture: { store.recordStuckPoint($0) })
                    }
                        .buttonStyle(PrimaryButtonStyle())
                        .frame(maxWidth: 260)
                        .accessibilityHint("앱 안에서 로그인 상태와 화면 보호를 유지한 채 현재 경기를 엽니다")
                } else {
                    Button("다시 시도") {
                        Task { await retryStart() }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .frame(maxWidth: 220)
                }
            }
        }
        .padding(Tokens.Space.s6)
        .frame(maxWidth: 620)
    }

    private func submittedView(_ submission: Submission) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Tokens.Space.s6) {
                VStack(alignment: .leading, spacing: Tokens.Space.s4) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 42, weight: .semibold))
                        .foregroundStyle(Tokens.successInk)

                    Text("답안 제출이 완료되었습니다")
                        .font(.mTitle)
                        .foregroundStyle(Tokens.ink)

                    Text(submission.evidenceRequired == true
                         ? "답안과 인앱 풀이판을 서버가 원본 증거로 자동 확정하고 있습니다. 별도 사진 제출은 필요하지 않습니다."
                         : "서버가 두 참가자의 답안과 풀이판을 같은 기준으로 검토하고 있습니다. 상대 결과와 무결성 판정이 끝나기 전에는 점수나 승패를 미리 표시하지 않습니다.")
                        .font(.mCallout)
                        .foregroundStyle(Tokens.text2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                DottedRule()

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: Tokens.Space.s8) {
                        submissionFacts(submission)
                    }

                    VStack(alignment: .leading, spacing: Tokens.Space.s4) {
                        submissionFacts(submission)
                    }
                }

                DottedRule()

                waitingStages(evidenceRequired: submission.evidenceRequired == true)

                Button("GOAT Arena에서 상태 확인") {
                    dismiss()
                }
                .buttonStyle(PrimaryButtonStyle())
                .frame(maxWidth: 320)
            }
            .padding(Tokens.Space.s6)
            .frame(maxWidth: Tokens.readableWidth, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private func submissionFacts(_ submission: Submission) -> some View {
        submittedFact("제출 답안", "\(submission.answerCount)개")
        submittedFact("마지막 기록", "#\(submission.lastAcceptedServerSequence)")
        if let submittedAt = ArenaServerDate.parse(submission.submittedAt) {
            submittedFact(
                "서버 접수",
                submittedAt.formatted(
                    Date.FormatStyle(date: .omitted, time: .shortened)
                        .locale(Locale(identifier: "ko_KR"))
                )
            )
        }
    }

    /// 시작 응답을 잃었거나 앱을 다시 연 뒤 서버가 이미 SUBMITTED 상태를 돌려준
    /// 경우의 복구 화면. 상세 제출 원장이 없어도 다시 문제를 열거나 start를 반복하지
    /// 않고 서버가 확인한 상태만 표시한다.
    private func submittedAttemptView(_ attempt: Attempt) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Tokens.Space.s6) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(Tokens.successInk)

                Text("답안 제출이 완료되었습니다")
                    .font(.mTitle)
                    .foregroundStyle(Tokens.ink)

                Text(attempt.evidenceRequired == true
                     ? "답안은 서버에 고정되어 있고 인앱 풀이판을 원본 증거로 자동 확정하고 있습니다. 별도 사진 제출은 필요하지 않습니다."
                     : "서버에 제출된 개인 경기입니다. 지금은 상대 제출과 서버 채점을 기다리는 단계이고, 점수와 승패는 정산이 끝난 뒤에 표시됩니다.")
                    .font(.mCallout)
                    .foregroundStyle(Tokens.text2)
                    .fixedSize(horizontal: false, vertical: true)

                if let submittedAt = attempt.submittedAt.flatMap(ArenaServerDate.parse) {
                    DottedRule()
                    submittedFact(
                        "서버 접수",
                        submittedAt.formatted(
                            Date.FormatStyle(date: .omitted, time: .shortened)
                                .locale(Locale(identifier: "ko_KR"))
                        )
                    )
                }


                DottedRule()

                waitingStages(evidenceRequired: attempt.evidenceRequired == true)

                Button("GOAT Arena에서 상태 확인") {
                    dismiss()
                }
                .buttonStyle(PrimaryButtonStyle())
                .frame(maxWidth: 320)
            }
            .padding(Tokens.Space.s6)
            .frame(maxWidth: Tokens.readableWidth, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }

    private func submittedFact(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.mMicro)
                .foregroundStyle(Tokens.text3)
            Text(value)
                .font(.mBodyB)
                .foregroundStyle(Tokens.ink)
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Play

    private var playView: some View {
        GeometryReader { proxy in
            if usesSplitWorkspace(proxy.size) {
                splitWorkspace(size: proxy.size)
            } else {
                scrollingPlayView
            }
        }
    }

    private func usesSplitWorkspace(_ size: CGSize) -> Bool {
        let phoneLandscape = verticalSizeClass == .compact
            && size.width >= 700
            && size.height >= 260
        let roomyWindow = size.width >= 744 && size.height >= 540
        return (phoneLandscape || roomyWindow) && !dynamicTypeSize.isAccessibilitySize
    }

    private var scrollingPlayView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Tokens.Space.s5) {
                matchStatusStrip

                if let connectionNotice {
                    connectionBanner(connectionNotice)
                }

                if deadlineReached {
                    deadlineBanner
                }

                currentQuestionProgress
                questionPanel

                Text("시간과 답안 접수 시각은 서버가 판정합니다. 제출 뒤 정답·점수·승패는 정산이 끝난 GOAT Arena 화면에서 확인할 수 있습니다.")
                    .font(.mCaption)
                    .foregroundStyle(Tokens.text3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(horizontalSizeClass == .compact ? Tokens.Space.s4 : Tokens.Space.s6)
            .frame(maxWidth: Tokens.readableWidth, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }

    /// 넓은 iPad·Stage Manager용 고정 작업대.
    /// 시험지는 왼쪽, 필기 공책은 오른쪽에 계속 보이며 바깥 스크롤을 만들지 않는다.
    private func splitWorkspace(size: CGSize) -> some View {
        let phoneLandscape = verticalSizeClass == .compact && size.height < 540
        let outerPadding: CGFloat = phoneLandscape ? 8 : (size.height < 600 ? 10 : 14)
        let statusHeight: CGFloat = phoneLandscape ? 36 : 44
        let gap: CGFloat = phoneLandscape ? 8 : (size.width < 900 ? 10 : 14)
        let availableWorkspaceHeight = size.height
            - (outerPadding * 2)
            - statusHeight
            - gap
        // iPad에서는 충분한 필기 높이를 지키되, iPhone 가로의 실제 300pt 안팎
        // 뷰포트에 360pt를 강제해 아래를 잘라 내지 않는다.
        let workspaceHeight = phoneLandscape
            ? max(220, availableWorkspaceHeight)
            : max(360, availableWorkspaceHeight)
        let problemWidth = min(
            max(340, size.width * 0.44),
            560
        )
        let boardWidth = size.width - (outerPadding * 2) - gap - problemWidth

        return VStack(spacing: gap) {
            workspaceStatusBar
                .frame(height: statusHeight)

            HStack(alignment: .top, spacing: gap) {
                workspaceQuestionColumn(height: workspaceHeight)
                    .frame(width: problemWidth, height: workspaceHeight)

                workspaceBoardColumn(
                    height: workspaceHeight,
                    usesCompactToolbar: boardWidth < 560)
                    .frame(maxWidth: .infinity, maxHeight: workspaceHeight)
            }
        }
        .padding(outerPadding)
        .background(Tokens.paper2)
    }

    private var workspaceStatusBar: some View {
        HStack(spacing: Tokens.Space.s3) {
            Label("문항 \(currentQuestionNumber) / \(totalQuestionCount)", systemImage: "doc.text.fill")
                .font(.mMicro)
                .foregroundStyle(Tokens.ink)
                .fixedSize()

            ProgressBar(
                value: Double(currentQuestionNumber) / Double(totalQuestionCount),
                tint: Tokens.primary,
                track: Tokens.paper2
            )
            .frame(maxWidth: 150)

            if deadlineReached {
                Label("시간 종료 · 서버 확인 중", systemImage: "clock.badge.exclamationmark.fill")
                    .font(.mMicro)
                    .foregroundStyle(Tokens.warningInk)
                    .lineLimit(1)
            } else if let connectionNotice {
                Label(shortHeight ? "연결 재시도" : connectionNotice,
                      systemImage: "wifi.exclamationmark")
                    .font(.mMicro)
                    .foregroundStyle(Tokens.warningInk)
                    .lineLimit(1)
                    .accessibilityLabel(connectionNotice)
            }

            if shortHeight {
                Text(attemptStageText)
                    .font(.mMicro)
                    .foregroundStyle(Tokens.text2)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            if let question = currentQuestion {
                answerSaveStatus(question)
            }
            Divider().frame(height: 20)
            solutionBoardStatus
        }
        .padding(.horizontal, Tokens.Space.s4)
        .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.md)
                .strokeBorder(Tokens.line, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func workspaceQuestionColumn(height: CGFloat) -> some View {
        if let question = currentQuestion {
            let compact = height < 650
            let phoneLandscape = shortHeight && height < 420
            VStack(alignment: .leading, spacing: phoneLandscape ? 6 : (compact ? 8 : Tokens.Space.s3)) {
                HStack(alignment: .firstTextBaseline) {
                    if phoneLandscape {
                        Text("문제 \(currentQuestionNumber)번")
                            .font(.mBodyB)
                            .foregroundStyle(Tokens.ink)
                    } else {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("문제")
                                .font(.mMicro)
                                .foregroundStyle(Tokens.primary)
                            Text("\(currentQuestionNumber)번")
                                .font(.mHeading)
                                .foregroundStyle(Tokens.ink)
                        }
                    }
                    Spacer()
                    Text("넘어가면 다시 열 수 없음")
                        .font(.mMicro)
                        .foregroundStyle(Tokens.text3)
                }

                // 짧은 가로 화면에서는 발문·도형만 자기 열 안에서 스크롤한다.
                // 답안과 다음 문항 버튼은 아래에 고정되어, 긴 문제에서도 조작을
                // 찾으려고 문제와 풀이판 전체를 위아래로 오갈 필요가 없다.
                ScrollView {
                    VStack(alignment: .leading, spacing: compact ? 7 : Tokens.Space.s3) {
                        compactIntegrityWatermark(
                            questionPack?.integrityWatermark,
                            compact: compact)

                        MathInline(
                            text: MathText.normalizeDelimiters(question.stem),
                            font: compact ? .mBodyB : .mHeading,
                            color: Tokens.ink,
                            pixelSize: compact ? 18 : 21
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)

                        if let visualizationJSON = question.visualizationJSON,
                           !visualizationJSON.isEmpty {
                            ArenaProblemVisualizationView(visualizationJSON: visualizationJSON)
                                .frame(height: compact ? 108 : min(210, height * 0.28))
                                .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.md))
                                .accessibilityLabel("문제의 그래프 또는 도형")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .scrollBounceBehavior(.basedOnSize, axes: .vertical)
                .frame(
                    minHeight: phoneLandscape ? 36 : nil,
                    maxHeight: .infinity,
                    alignment: .top)

                if let choices = question.choices, !choices.isEmpty {
                    if compact {
                        LazyVGrid(
                            columns: [GridItem(.flexible()), GridItem(.flexible())],
                            spacing: 7
                        ) {
                            ForEach(choices) { choice in
                                choiceButton(choice, question: question, compact: true)
                            }
                        }
                    } else {
                        VStack(spacing: 8) {
                            ForEach(choices) { choice in
                                choiceButton(choice, question: question, compact: true)
                            }
                        }
                    }
                } else {
                    shortAnswerField(question)
                }

                questionControls
            }
            .padding(phoneLandscape ? 10 : (compact ? Tokens.Space.s4 : Tokens.Space.s5))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Tokens.surface)
            .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: Tokens.Radius.lg)
                    .strokeBorder(Tokens.lineStrong, lineWidth: 1)
            )
        }
    }

    @ViewBuilder
    private func compactIntegrityWatermark(
        _ watermark: ServerAPI.GoatArenaQuestionPack.IntegrityWatermark?,
        compact: Bool
    ) -> some View {
        if let watermark {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Image(systemName: "shield.checkered")
                    Text(watermark.shortText)
                    Spacer(minLength: 4)
                    Text(watermark.traceCode).monospaced()
                }
                .font(.mMicro)
                Text("경기 \(watermark.matchReference) · \(watermark.role) · \(watermark.notice)")
                    .font(.mMicro)
                    .lineLimit(compact ? 1 : 2)
            }
            .foregroundStyle(Tokens.warningInk)
            .padding(.horizontal, Tokens.Space.s3)
            .padding(.vertical, 7)
            .background(Tokens.warningSoft, in: RoundedRectangle(cornerRadius: Tokens.Radius.sm))
            .accessibilityElement(children: .combine)
        }
    }

    private func workspaceBoardColumn(
        height: CGFloat,
        usesCompactToolbar: Bool
    ) -> some View {
        let compact = height < 650
        let phoneLandscape = shortHeight && height < 420
        // 헤더·안내·여백을 먼저 빼고 남은 높이만 필기판에 준다. iPhone 가로는
        // 바깥 패딩까지 포함한 실측치로 계산해 240pt 하한 때문에 잘리지 않게 한다.
        let boardPadding: CGFloat = phoneLandscape ? 8 : (compact ? Tokens.Space.s3 : Tokens.Space.s4)
        let headerAndGap: CGFloat = phoneLandscape ? 30 : (compact ? 46 : 78)
        let noteHeight = max(210, height - (boardPadding * 2) - headerAndGap)

        return VStack(alignment: .leading, spacing: compact ? 6 : 8) {
            HStack(spacing: Tokens.Space.s3) {
                Label("문항 \(currentQuestionNumber) 메모", systemImage: "pencil.and.scribble")
                    .font(.mBodyB)
                    .foregroundStyle(Tokens.ink)
                Spacer(minLength: 0)
                if UIDevice.current.userInterfaceIdiom == .pad {
                    Toggle("손가락 필기", isOn: $solutionAllowsFinger)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .fixedSize()
                        .accessibilityLabel("손가락 필기")
                }
            }

            if !compact {
                Text("문제를 보면서 바로 쓰세요. 필기는 자동 저장되고 마지막 문항에서 원본 증거로 제출됩니다.")
                    .font(.mCaption)
                    .foregroundStyle(Tokens.text2)
                    .lineLimit(1)
            }

            SolutionNote(
                drawing: $solutionDrawing,
                allowsFinger: $solutionAllowsFinger,
                zoom: $solutionZoom,
                selectedTool: $solutionTool,
                inkWidth: $solutionInkWidth,
                undoStack: $solutionUndoStack,
                redoStack: $solutionRedoStack,
                constrainedHeight: noteHeight,
                showsHeader: false,
                usesCompactToolbar: usesCompactToolbar,
                minimumConstrainedCanvasHeight: phoneLandscape ? 150 : 180
            )
        }
        .padding(boardPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(NotePalette.paper)
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.lg)
                .strokeBorder(Tokens.primary.opacity(0.28), lineWidth: 1.5)
        )
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Tokens.primary.opacity(0.65))
                .frame(width: 3)
                .padding(.vertical, Tokens.Space.s5)
        }
    }

    private var currentQuestionProgress: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s3) {
            HStack {
                Text("현재 문항")
                    .font(.mMicro)
                    .foregroundStyle(Tokens.text2)
                Spacer()
                Text("\(currentQuestionNumber) / \(totalQuestionCount)")
                    .font(.mNumeric)
                    .foregroundStyle(Tokens.ink)
                    .monospacedDigit()
            }
            ProgressBar(
                value: Double(currentQuestionNumber) / Double(totalQuestionCount),
                tint: Tokens.primary,
                track: Tokens.paper2
            )
            Text("다음 문항으로 넘어가면 이전 문제와 답은 다시 열 수 없습니다.")
                .font(.mCaption)
                .foregroundStyle(Tokens.text3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Tokens.Space.s4)
        .background(Tokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.md)
                .strokeBorder(Tokens.line, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }

    /// 문항 제한 시간이 끝난 순간. 종전에는 아무 표시 없이 refreshAfterQuestionDeadline()
    /// 이 조용히 다음 문항을 불러왔고, 학생 눈에는 문제가 그냥 바뀌었다.
    private var deadlineBanner: some View {
        HStack(alignment: .top, spacing: Tokens.Space.s3) {
            Image(systemName: "clock.badge.exclamationmark.fill")
                .foregroundStyle(Tokens.warningInk)
                .frame(width: 24, height: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(currentQuestionNumber)번 문항 시간이 끝났습니다")
                    .font(.mBodyB)
                    .foregroundStyle(Tokens.ink)
                Text(isMovingQuestion
                     ? "서버가 다음 문항을 준비하고 있습니다."
                     : "서버 시각으로 다음 단계를 확인합니다. 이 문항의 답은 더 바꿀 수 없습니다.")
                    .font(.mCaption)
                    .foregroundStyle(Tokens.text2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(Tokens.Space.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tokens.warningSoft)
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.md))
        .accessibilityElement(children: .combine)
    }

    private func connectionBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: Tokens.Space.s3) {
            Image(systemName: "wifi.exclamationmark")
                .foregroundStyle(Tokens.warningInk)
                .frame(width: 24, height: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text("연결을 다시 확인하고 있습니다")
                    .font(.mBodyB)
                    .foregroundStyle(Tokens.ink)
                Text(message)
                    .font(.mCaption)
                    .foregroundStyle(Tokens.text2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Tokens.Space.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tokens.warningSoft)
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.md))
    }

    @ViewBuilder
    private var questionPanel: some View {
        if let question = currentQuestion {
            VStack(alignment: .leading, spacing: Tokens.Space.s6) {
                HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s3) {
                    Text("문항 \(currentQuestionNumber)")
                        .font(.mMicro)
                        .foregroundStyle(Tokens.primary)
                    Text("/ \(totalQuestionCount)")
                        .font(.mMicro)
                        .foregroundStyle(Tokens.text3)
                    Spacer()
                    answerSaveStatus(question)
                }

                ExamRule()

                if let watermark = questionPack?.integrityWatermark {
                    integrityWatermarkView(watermark)
                }

                // 가로 iPhone 에서는 문제(발문·그림)를 왼쪽에, 답안과 진행 버튼을
                // 오른쪽에 둔다. 세로로만 쌓으면 발문 + 그림(240pt) + 선택지 5개가
                // 이어져, 제한 시간이 흐르는 동안 문제와 선택지를 번갈아 스크롤하게 된다.
                CompactHeightColumns(spacing: Tokens.Space.s5, stackedSpacing: Tokens.Space.s6) {
                    VStack(alignment: .leading, spacing: Tokens.Space.s6) {
                        MathInline(
                            text: MathText.normalizeDelimiters(question.stem),
                            font: .mHeading,
                            color: Tokens.ink,
                            pixelSize: 22
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)

                        if let visualizationJSON = question.visualizationJSON,
                           !visualizationJSON.isEmpty {
                            ArenaProblemVisualizationView(
                                visualizationJSON: visualizationJSON
                            )
                            .frame(
                                height: horizontalSizeClass == .compact ? 240 : 320
                            )
                            .clipShape(
                                RoundedRectangle(cornerRadius: Tokens.Radius.md)
                            )
                            .accessibilityLabel("문제의 그래프 또는 도형")
                        }
                    }
                } trailing: {
                    VStack(alignment: .leading, spacing: Tokens.Space.s6) {
                        if let choices = question.choices, !choices.isEmpty {
                            VStack(spacing: Tokens.Space.s3) {
                                ForEach(choices) { choice in
                                    choiceButton(choice, question: question)
                                }
                            }
                        } else {
                            shortAnswerField(question)
                        }

                        DottedRule()

                        questionControls
                    }
                }

                DottedRule()

                VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                    HStack {
                        Text("문항 \(question.slot) 풀이판")
                            .font(.mBodyB)
                            .foregroundStyle(Tokens.ink)
                        Spacer()
                        solutionBoardStatus
                    }
                    Text("필기는 이 기기와 서버에 자동 저장됩니다. 마지막 문항을 마치면 다섯 풀이판이 원본 증거로 자동 제출됩니다.")
                        .font(.mCaption)
                        .foregroundStyle(Tokens.text2)
                        .fixedSize(horizontal: false, vertical: true)
                    SolutionNote(
                        drawing: $solutionDrawing,
                        allowsFinger: $solutionAllowsFinger,
                        zoom: $solutionZoom,
                        selectedTool: $solutionTool,
                        inkWidth: $solutionInkWidth,
                        undoStack: $solutionUndoStack,
                        redoStack: $solutionRedoStack)
                }
            }
            .padding(horizontalSizeClass == .compact ? Tokens.Space.s5 : Tokens.Space.s6)
            // 세로가 짧을 때만 최소 높이를 풀어 준다. 470pt 를 강제하면 뷰포트가
            // 300pt 안팎인 가로 iPhone 에서는 짧은 문항도 반드시 스크롤을 만든다.
            .frame(maxWidth: .infinity,
                   minHeight: shortHeight ? 0 : 470,
                   alignment: .topLeading)
            .background(Tokens.surface)
            .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: Tokens.Radius.lg)
                    .strokeBorder(Tokens.line, lineWidth: 1)
            )
        }
    }

    private func integrityWatermarkView(
        _ watermark: ServerAPI.GoatArenaQuestionPack.IntegrityWatermark
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label(watermark.shortText, systemImage: "shield.checkered")
                    .font(.mMicro)
                    .foregroundStyle(Tokens.warningInk)
                Spacer()
                Text(watermark.traceCode)
                    .font(.mMicro)
                    .monospaced()
                    .foregroundStyle(Tokens.text2)
            }
            Text("경기 \(watermark.matchReference) · \(watermark.role)")
                .font(.mCaption)
                .foregroundStyle(Tokens.text3)
            Text(watermark.notice)
                .font(.mCaption)
                .foregroundStyle(Tokens.text2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Tokens.Space.s3)
        .background(Tokens.warningSoft)
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.sm))
        .accessibilityElement(children: .combine)
    }

    private var solutionBoardStatus: some View {
        let slot = currentQuestion?.slot ?? currentQuestionNumber
        let revision = solutionBoardRevisions[slot] ?? 0
        let saved = solutionBoardSavedRevisions[slot] ?? 0
        let hasBoardRevision = revision > 0
        return HStack(spacing: 5) {
            if isSavingSolutionBoard {
                ProgressView().controlSize(.mini)
            } else {
                Circle()
                    .fill(!hasBoardRevision ? Tokens.text4
                          : (saved >= revision ? Tokens.successInk : Tokens.warningInk))
                    .frame(width: 7, height: 7)
            }
            Text(solutionBoardSaveError != nil
                 ? "서버 저장 재시도 필요"
                 : (!hasBoardRevision ? "필기 없음"
                    : (saved >= revision ? "풀이판 저장됨" : "풀이판 저장 대기")))
                .font(.mMicro)
                .foregroundStyle(solutionBoardSaveError != nil ? Tokens.warningInk : Tokens.text2)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            !hasBoardRevision && solutionBoardSaveError == nil
                ? "필기 없음, 다음 문항으로 이동할 때 빈 풀이판을 저장합니다"
                : "풀이판 저장 상태")
    }

    private func answerSaveStatus(_ question: Question) -> some View {
        let hasAnswer = !(answers[question.slot] ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
        let isDirty = dirtySlots.contains(question.slot)

        return HStack(spacing: 5) {
            if isSavingAnswer {
                ProgressView()
                    .controlSize(.mini)
            } else {
                Circle()
                    .fill(
                        isDirty ? Tokens.warningInk
                            : (hasAnswer ? Tokens.successInk : Tokens.text4)
                    )
                    .frame(width: 7, height: 7)
            }
            Text(
                isSavingAnswer ? "답안 저장 중"
                    : (isDirty ? "저장 필요"
                        : (hasAnswer ? "서버 저장됨" : "미응답"))
            )
            .font(.mMicro)
            .foregroundStyle(
                isDirty ? Tokens.warningInk
                    : (hasAnswer ? Tokens.successInk : Tokens.text3)
            )
        }
        .accessibilityElement(children: .combine)
    }

    private func choiceButton(
        _ choice: ServerAPI.GoatArenaQuestionPack.Choice,
        question: Question,
        compact: Bool = false
    ) -> some View {
        let selected = answers[question.slot] == choice.key

        return Button {
            updateAnswer(choice.key, for: question.slot)
            Task { _ = await saveAnswer(slot: question.slot, reportFailure: true) }
        } label: {
            HStack(alignment: .center, spacing: Tokens.Space.s4) {
                Text(choice.key.uppercased())
                    .font(compact ? .mCaption : .mBodyB)
                    .foregroundStyle(selected ? Tokens.onPrimary : Tokens.primary)
                    .frame(width: compact ? 30 : 36, height: compact ? 30 : 36)
                    .background(
                        selected ? Tokens.primary : Tokens.primarySoft,
                        in: RoundedRectangle(cornerRadius: Tokens.Radius.sm)
                    )

                MathInline(
                    text: MathText.normalizeDelimiters(choice.text),
                    font: .mBody,
                    color: Tokens.ink,
                    pixelSize: compact ? 15 : 17
                )
                .allowsHitTesting(false)

                Spacer(minLength: 0)

                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? Tokens.primary : Tokens.text4)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, compact ? Tokens.Space.s3 : Tokens.Space.s4)
            .padding(.vertical, compact ? 6 : Tokens.Space.s3)
            .frame(maxWidth: .infinity, minHeight: compact ? 44 : 58, alignment: .leading)
            .background(
                selected ? Tokens.primarySoft : Tokens.paper,
                in: RoundedRectangle(cornerRadius: Tokens.Radius.md)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Tokens.Radius.md)
                    .strokeBorder(
                        selected ? Tokens.primary : Tokens.lineStrong,
                        lineWidth: selected ? 2 : 1
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(answerInteractionDisabled)
        .accessibilityLabel("\(choice.key)번, \(MathText.plain(choice.text))")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func shortAnswerField(_ question: Question) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s3) {
            Text("답")
                .font(.mCaption)
                .foregroundStyle(Tokens.text2)

            TextField(
                "답을 입력하세요",
                text: answerBinding(for: question.slot),
                axis: .vertical
            )
            .font(.mBody)
            .foregroundStyle(Tokens.ink)
            .lineLimit(2...5)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .keyboardType(.numberPad)
            .submitLabel(.done)
            .onSubmit {
                Task { _ = await saveAnswer(slot: question.slot, reportFailure: true) }
            }
            .padding(Tokens.Space.s4)
            .background(
                Tokens.paper,
                in: RoundedRectangle(cornerRadius: Tokens.Radius.md)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Tokens.Radius.md)
                    .strokeBorder(
                        dirtySlots.contains(question.slot)
                            ? Tokens.warningInk
                            : Tokens.lineStrong,
                        lineWidth: dirtySlots.contains(question.slot) ? 1.5 : 1
                    )
            )
            .disabled(answerInteractionDisabled)

            HStack {
                Text("1부터 999까지의 자연수를 입력하세요.")
                    .font(.mCaption)
                    .foregroundStyle(Tokens.text3)
                Spacer()
                Text("\((answers[question.slot] ?? "").count) / 3")
                    .font(.mMicro)
                    .foregroundStyle(Tokens.text3)
                    .monospacedDigit()
            }
        }
    }

    private var questionControls: some View {
        primaryQuestionButton
            .frame(maxWidth: .infinity, alignment: .trailing)
    }

    /// 진행 중인 명령을 **버튼 글자로** 말한다. 웹은 최소한 이 문구를 바꿔서
    /// "지금 뭘 하고 있는지" 를 알렸다(public/js/goat-arena-match.js:277-281).
    /// 앱은 문제가 그냥 바뀌어서 학생이 무슨 일이 일어났는지 알 수 없었다.
    @ViewBuilder
    private var primaryQuestionButton: some View {
        if deadlineReached {
            Button {
                Task { await refreshAfterQuestionDeadline() }
            } label: {
                Label(
                    isMovingQuestion
                        ? "\(currentQuestionNumber)번 시간 종료 · 다음 문항 준비 중"
                        : "제출 상태 다시 확인",
                    systemImage: "arrow.clockwise")
            }
            .buttonStyle(PrimaryButtonStyle())
            .frame(maxWidth: 300)
            .disabled(interactionBusy)
        } else if currentQuestionNumber < totalQuestionCount {
            Button {
                Task { await advanceCurrentQuestion() }
            } label: {
                Label(
                    isMovingQuestion ? "다음 문제 준비 중" : "다음 문항",
                    systemImage: isMovingQuestion ? "hourglass" : "chevron.right")
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(PrimaryButtonStyle())
            .frame(maxWidth: 260)
            .disabled(interactionBusy)
        } else {
            Button {
                confirmSubmit = true
            } label: {
                Label(
                    (isMovingQuestion || isSubmitting) ? "풀이 완료 처리 중" : "풀이 완료",
                    systemImage: (isMovingQuestion || isSubmitting)
                        ? "hourglass" : "paperplane.fill")
            }
            .buttonStyle(PrimaryButtonStyle())
            .frame(maxWidth: 260)
            .disabled(interactionBusy)
        }
    }

    // MARK: Start and validation

    @MainActor
    private func beginMatchIfNeeded() async {
        guard !didRequestStart, accountIsCurrent else {
            if !accountIsCurrent { dismiss() }
            return
        }
        didRequestStart = true
        isLoading = true
        startError = nil

        #if DEBUG
        if usesDebugFixture {
            let fixture = GoatArenaMatchFixture.make(matchId: matchId)
            attempt = fixture.attempt
            questionPack = fixture.questionPack
            attemptEndsAt = fixture.endsAt
            now = Date()
            currentIndex = 0
            isLoading = false
            installSolutionDrawing(for: 1)
            presentIntro(.matchStart(questionNumber: 1))
            return
        }
        #endif

        do {
            let response = try await ServerAPI.startGoatArenaMatch(
                matchId: matchId,
                commandId: startCommandId,
                clientBuildVersion: clientBuildVersion
            )
            guard accountIsCurrent else {
                dismiss()
                return
            }
            try validate(response)

            let end = try ArenaServerDate.required(
                response.attempt.endsAt,
                label: "개인 제출 마감"
            )

            attempt = response.attempt
            questionPack = response.questionPack
            attemptEndsAt = end
            now = Date()
            currentIndex = 0
            answers = Dictionary(
                uniqueKeysWithValues: response.questionPack.questions.map {
                    ($0.slot, String(($0.savedAnswer ?? "").prefix(3)))
                }
            )
            await restoreSolutionBoardsFromServer(
                currentSlot: response.questionPack.currentQuestionNumber
                    ?? response.attempt.currentQuestionNumber
                    ?? response.questionPack.questions.first?.slot
                    ?? 1)
            localReviewContext = GoatArenaLocalReviewContextStore.load(
                matchId: matchId,
                attemptId: response.attempt.attemptId
            )
            captureCurrentQuestionForLocalReview()

            if response.attempt.status == "EVIDENCE_REQUIRED" {
                try await ServerAPI.finalizeGoatArenaSolutionBoards(
                    matchId: matchId,
                    commandId: "arena-board-finalize-\(matchId)",
                    clientBuildVersion: clientBuildVersion)
                let finalized = try await ServerAPI.startGoatArenaMatch(
                    matchId: matchId,
                    commandId: startCommandId,
                    clientBuildVersion: clientBuildVersion)
                try installServerState(finalized)
                isLoading = false
                return
            }

            if ["EVIDENCE_REQUIRED", "SUBMITTED"].contains(response.attempt.status) {
                GoatArenaDraftStore.clear(
                    matchId: matchId,
                    attemptId: response.attempt.attemptId
                )
                GoatArenaCommandKeyStore.clear(matchId: matchId)
                isLoading = false
                return
            }

            if let draft = GoatArenaDraftStore.load(
                matchId: matchId,
                attemptId: response.attempt.attemptId,
                questionPackId: response.questionPack.questionPackId
            ) {
                let validSlots = Set(response.questionPack.questions.map(\.slot))
                answers = draft.answers
                    .filter { validSlots.contains($0.key) }
                    .mapValues { String($0.filter(\.isNumber).prefix(3)) }
                dirtySlots = Set(draft.dirtySlots ?? Array(draft.answers.keys))
                    .intersection(validSlots)
                answerCommandIds = (draft.answerCommandIds ?? [:])
                    .filter { dirtySlots.contains($0.key) && !$0.value.isEmpty }
                for slot in dirtySlots where answerCommandIds[slot] == nil {
                    answerCommandIds[slot] = UUID().uuidString
                }
                currentIndex = min(
                    max(0, draft.currentQuestionIndex),
                    max(0, response.questionPack.questions.count - 1)
                )
                captureCurrentQuestionForLocalReview()
                persistDraft()
            }

            isLoading = false

            // 웹의 `?started=1 && currentQuestionIndex === 0` 과 같은 조건이다 —
            // 방금 서버가 내 타이머를 시작시켰고 아직 1번 문항일 때만 1회.
            // 이미 흐르던 경기로 돌아온 재개(skipsLobby)에는 재생하지 않는다.
            let openedNumber = response.questionPack.currentQuestionNumber
                ?? response.attempt.currentQuestionNumber ?? 1
            introducedQuestionNumber = openedNumber
            if openedNumber == 1,
               response.attempt.status == "IN_PROGRESS",
               briefing?.skipsLobby != true {
                presentIntro(.matchStart(questionNumber: openedNumber))
            }

            await sendNetworkState("ONLINE")
            if let question = currentQuestion {
                await sendFocus(question.slot)
            }
        } catch {
            guard accountIsCurrent else {
                dismiss()
                return
            }
            isLoading = false
            startError = playErrorMessage(error, operation: .start)
        }
    }

    @MainActor
    private func retryStart() async {
        guard !isLoading else { return }
        didRequestStart = false
        await beginMatchIfNeeded()
    }

    private func validate(_ response: ServerAPI.GoatArenaStartResponse) throws {
        guard response.attempt.matchId == matchId,
              response.questionPack.matchId == matchId,
              response.attempt.questionPackId == response.questionPack.questionPackId,
              response.attempt.participantRole == response.questionPack.participantRole,
              ["CHALLENGER", "DEFENDER"].contains(response.attempt.participantRole),
              ["IN_PROGRESS", "EVIDENCE_REQUIRED", "SUBMITTED"].contains(response.attempt.status),
              response.attempt.questionCount == response.questionPack.questionCount,
              response.attempt.timeLimitSeconds == response.questionPack.timeLimitSeconds,
              response.attempt.questionPackVersion == response.questionPack.packVersion,
              response.attempt.scoringPolicyVersion == response.questionPack.scoringPolicyVersion
        else {
            throw GoatArenaPlayError.invalidContract
        }

        let currentNumber = response.questionPack.currentQuestionNumber
            ?? response.attempt.currentQuestionNumber
        let isInProgress = response.attempt.status == "IN_PROGRESS"
        guard (1...response.questionPack.questionCount).contains(currentNumber ?? 0),
              isInProgress
                ? (response.questionPack.questions.count == 1
                    && response.questionPack.questions.first?.slot == currentNumber)
                : response.questionPack.questions.isEmpty
        else {
            throw GoatArenaPlayError.invalidContract
        }

        let startedAt = try ArenaServerDate.required(
            response.attempt.startedAt,
            label: "개인 경기 시작"
        )
        let endsAt = try ArenaServerDate.required(
            response.attempt.endsAt,
            label: "개인 제출 마감"
        )
        let commonSubmitsBy = try ArenaServerDate.required(
            response.attempt.commonSubmitsBy,
            label: "공통 제출 마감"
        )
        guard startedAt <= endsAt, endsAt <= commonSubmitsBy else {
            throw GoatArenaPlayError.invalidContract
        }
    }

    // MARK: Answer and navigation

    @MainActor
    private func solutionDrawingChanged(_ drawing: PKDrawing) {
        guard !isInstallingSolutionDrawing,
              attempt?.status == "IN_PROGRESS",
              let slot = currentQuestion?.slot else { return }
        let revision = max(1, (solutionBoardRevisions[slot] ?? 0) + 1)
        solutionBoardRevisions[slot] = revision
        GoatArenaSolutionBoardDraftStore.save(
            GoatArenaSolutionBoardDraft(
                revision: revision,
                drawingData: drawing.dataRepresentation()),
            matchId: matchId,
            slot: slot,
            accountSlot: accountSlot)
        solutionBoardSaveError = nil
        solutionBoardSaveTask?.cancel()
        solutionBoardSaveTask = Task {
            try? await Task.sleep(for: .milliseconds(900))
            guard !Task.isCancelled else { return }
            await saveCurrentSolutionBoard(force: false)
        }
    }

    @MainActor
    private func installSolutionDrawing(for slot: Int) {
        solutionBoardSaveTask?.cancel()
        let draft = GoatArenaSolutionBoardDraftStore.load(
            matchId: matchId,
            slot: slot,
            accountSlot: accountSlot)
        isInstallingSolutionDrawing = true
        solutionDrawing = draft.flatMap { try? PKDrawing(data: $0.drawingData) } ?? PKDrawing()
        solutionBoardRevisions[slot] = draft?.revision ?? 0
        solutionUndoStack.removeAll()
        solutionRedoStack.removeAll()
        solutionZoom = 1
        DispatchQueue.main.async { isInstallingSolutionDrawing = false }
    }

    @MainActor
    private func restoreSolutionBoardsFromServer(currentSlot: Int) async {
        if let boards = try? await ServerAPI.getGoatArenaSolutionBoards(matchId: matchId) {
            for board in boards {
                guard let encoded = board.drawingDataBase64,
                      let data = Data(base64Encoded: encoded) else { continue }
                let local = GoatArenaSolutionBoardDraftStore.load(
                    matchId: matchId,
                    slot: board.questionSlot,
                    accountSlot: accountSlot)
                if local == nil || board.revision >= (local?.revision ?? 0) {
                    GoatArenaSolutionBoardDraftStore.save(
                        GoatArenaSolutionBoardDraft(
                            revision: board.revision,
                            drawingData: data),
                        matchId: matchId,
                        slot: board.questionSlot,
                        accountSlot: accountSlot)
                    solutionBoardRevisions[board.questionSlot] = board.revision
                    solutionBoardSavedRevisions[board.questionSlot] = board.revision
                    solutionBoardSavedHashes[board.questionSlot] = board.sha256
                }
            }
        }
        installSolutionDrawing(for: currentSlot)
    }

    @MainActor
    @discardableResult
    private func saveCurrentSolutionBoard(force: Bool) async -> Bool {
        guard accountIsCurrent,
              attempt?.status == "IN_PROGRESS",
              let slot = currentQuestion?.slot else { return false }
        if isSavingSolutionBoard {
            while isSavingSolutionBoard {
                try? await Task.sleep(for: .milliseconds(40))
            }
        }
        var revision = solutionBoardRevisions[slot] ?? 0
        if revision == 0 {
            guard force else { return true }
            revision = 1
            solutionBoardRevisions[slot] = revision
            GoatArenaSolutionBoardDraftStore.save(
                GoatArenaSolutionBoardDraft(
                    revision: revision,
                    drawingData: solutionDrawing.dataRepresentation()),
                matchId: matchId,
                slot: slot,
                accountSlot: accountSlot)
        }
        if !force, (solutionBoardSavedRevisions[slot] ?? 0) >= revision { return true }
        guard let png = solutionDrawing.arenaEvidencePNG() else {
            solutionBoardSaveError = "풀이판 이미지를 만들 수 없습니다."
            return false
        }
        let drawingData = solutionDrawing.dataRepresentation()
        isSavingSolutionBoard = true
        defer { isSavingSolutionBoard = false }
        do {
            let board = try await ServerAPI.saveGoatArenaSolutionBoard(
                matchId: matchId,
                questionSlot: slot,
                revision: revision,
                strokeCount: solutionDrawing.strokes.count,
                drawingData: drawingData,
                previewPNG: png,
                commandId: "arena-board-\(matchId)-\(slot)-\(revision)",
                clientBuildVersion: clientBuildVersion)
            solutionBoardSavedRevisions[slot] = max(
                solutionBoardSavedRevisions[slot] ?? 0,
                board.revision)
            solutionBoardSavedHashes[slot] = board.sha256
            solutionBoardSaveError = nil
            markConnectionRestoredIfNeeded()
            return true
        } catch {
            solutionBoardSaveError = playErrorMessage(error, operation: .answer)
            noteConnectionFailure()
            return false
        }
    }

    private func answerBinding(for slot: Int) -> Binding<String> {
        Binding(
            get: { answers[slot] ?? "" },
            set: { updateAnswer(String($0.filter(\.isNumber).prefix(3)), for: slot) }
        )
    }

    private func updateAnswer(_ value: String, for slot: Int) {
        guard answers[slot] != value else { return }
        answers[slot] = value
        dirtySlots.insert(slot)
        answerCommandIds[slot] = UUID().uuidString
        captureCurrentQuestionForLocalReview()
        persistDraft()
    }

    @MainActor
    @discardableResult
    private func saveAnswer(slot: Int, reportFailure: Bool) async -> Bool {
        guard accountIsCurrent, attempt?.status == "IN_PROGRESS",
              submission == nil else { return false }
        while isSavingAnswer {
            do {
                try await Task.sleep(for: .milliseconds(40))
            } catch {
                return false
            }
        }

        guard dirtySlots.contains(slot) else { return true }
        let value = answers[slot] ?? ""
        let commandId = answerCommandIds[slot] ?? UUID().uuidString
        answerCommandIds[slot] = commandId
        isSavingAnswer = true
        defer { isSavingAnswer = false }

        do {
            _ = try await eventChannel.saveAnswer(
                slot: slot,
                answer: value,
                commandId: commandId
            )
            guard accountIsCurrent else {
                dismiss()
                return false
            }
            if answers[slot] == value, answerCommandIds[slot] == commandId {
                dirtySlots.remove(slot)
                answerCommandIds.removeValue(forKey: slot)
            }
            markConnectionRestoredIfNeeded()
            persistDraft()
            return true
        } catch {
            guard accountIsCurrent else {
                dismiss()
                return false
            }
            noteConnectionFailure()
            if reportFailure {
                actionError = playErrorMessage(error, operation: .answer)
            }
            return false
        }
    }

    @MainActor
    private func installServerState(
        _ response: ServerAPI.GoatArenaStartResponse
    ) throws {
        captureCurrentQuestionForLocalReview()
        try validate(response)
        let end = try ArenaServerDate.required(
            response.attempt.endsAt,
            label: "현재 문항 마감"
        )
        attempt = response.attempt
        questionPack = response.questionPack
        attemptEndsAt = end
        now = Date()
        currentIndex = 0
        didTriggerDeadlineSubmit = false
        dirtySlots.removeAll()
        answerCommandIds.removeAll()
        answers = Dictionary(
            uniqueKeysWithValues: response.questionPack.questions.map {
                ($0.slot, String(($0.savedAnswer ?? "").filter(\.isNumber).prefix(3)))
            }
        )
        if let slot = response.questionPack.questions.first?.slot {
            installSolutionDrawing(for: slot)
        }
        localReviewContext = GoatArenaLocalReviewContextStore.load(
            matchId: matchId,
            attemptId: response.attempt.attemptId
        ) ?? localReviewContext
        captureCurrentQuestionForLocalReview()

        // 종전에는 여기서 questionPack 이 통째로 갈리며 0프레임에 문제가 바뀌었다.
        // 웹은 같은 자리에 1.7초짜리 QUESTION N 인트로가 있다. 앱도 새 번호를
        // 감지했을 때만 한 번 알린다(번호가 그대로면 아무 일도 하지 않는다).
        let openedNumber = response.questionPack.currentQuestionNumber
            ?? response.attempt.currentQuestionNumber
            ?? response.questionPack.questions.first?.slot
            ?? introducedQuestionNumber
        if response.attempt.status == "IN_PROGRESS",
           openedNumber > introducedQuestionNumber {
            presentIntro(.round(questionNumber: openedNumber))
        }
        introducedQuestionNumber = max(introducedQuestionNumber, openedNumber)

        if ["EVIDENCE_REQUIRED", "SUBMITTED"].contains(response.attempt.status) {
            GoatArenaDraftStore.clear(
                matchId: matchId,
                attemptId: response.attempt.attemptId
            )
            GoatArenaCommandKeyStore.clear(matchId: matchId)
            if response.attempt.status == "SUBMITTED" {
                // 서버가 다섯 풀이판을 원본 증거로 승격한 성공 경계 뒤에만 지운다.
                // EVIDENCE_REQUIRED에서 지우면 finalize 재시도 중 연결이 끊겼을 때
                // 복구할 원본 필기가 사라진다.
                GoatArenaSolutionBoardDraftStore.clear(
                    matchId: matchId,
                    accountSlot: accountSlot)
            }
        } else {
            persistDraft()
        }
    }

    /// 서버가 현재 문항의 답을 확정한 뒤에만 다음 문항을 공개한다.
    /// 이전 문항은 응답에서 제거되므로 앱에서도 다시 이동할 경로를 만들지 않는다.
    @MainActor
    private func advanceCurrentQuestion() async {
        guard accountIsCurrent,
              attempt?.status == "IN_PROGRESS",
              let question = currentQuestion,
              !isMovingQuestion else { return }
        let answer = (answers[question.slot] ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let commandId = advanceCommandIds[question.slot] ?? UUID().uuidString
        advanceCommandIds[question.slot] = commandId
        isMovingQuestion = true
        defer { isMovingQuestion = false }

        do {
            guard await saveCurrentSolutionBoard(force: true) else {
                actionError = solutionBoardSaveError
                    ?? "풀이판을 서버에 저장한 뒤 다시 시도해주세요."
                return
            }
            guard let boardRevision = solutionBoardSavedRevisions[question.slot],
                  let boardSha256 = solutionBoardSavedHashes[question.slot] else {
                actionError = "최신 풀이판 저장 정보를 확인한 뒤 다시 시도해주세요."
                return
            }
            let response = try await ServerAPI.advanceGoatArenaQuestion(
                matchId: matchId,
                questionSlot: question.slot,
                answer: answer,
                boardRevision: boardRevision,
                boardSha256: boardSha256,
                commandId: commandId,
                clientBuildVersion: clientBuildVersion
            )
            guard accountIsCurrent else {
                dismiss()
                return
            }
            try installServerState(response)
            advanceCommandIds.removeValue(forKey: question.slot)
            markConnectionRestoredIfNeeded()
            if let next = currentQuestion {
                await sendFocus(next.slot)
            }
        } catch {
            guard accountIsCurrent else {
                dismiss()
                return
            }
            noteConnectionFailure()
            actionError = playErrorMessage(error, operation: .answer)
        }
    }

    /// 문항 제한 시간이 끝나면 같은 start/read adapter를 다시 호출한다.
    /// 서버 시각으로 timeout advance를 수행하므로 클라이언트가 답이나 문항 번호를
    /// 임의 확정하지 않는다.
    @MainActor
    private func refreshAfterQuestionDeadline() async {
        guard accountIsCurrent, !isMovingQuestion else { return }
        isMovingQuestion = true
        defer { isMovingQuestion = false }
        do {
            guard await saveCurrentSolutionBoard(force: true) else {
                didTriggerDeadlineSubmit = false
                actionError = solutionBoardSaveError
                    ?? "풀이판을 서버에 저장한 뒤 제출 상태를 확인할 수 있습니다."
                return
            }
            let response = try await ServerAPI.startGoatArenaMatch(
                matchId: matchId,
                commandId: startCommandId,
                clientBuildVersion: clientBuildVersion
            )
            guard accountIsCurrent else {
                dismiss()
                return
            }
            try installServerState(response)
            if response.attempt.status == "EVIDENCE_REQUIRED" {
                try await ServerAPI.finalizeGoatArenaSolutionBoards(
                    matchId: matchId,
                    commandId: "arena-board-finalize-\(matchId)",
                    clientBuildVersion: clientBuildVersion)
                let finalized = try await ServerAPI.startGoatArenaMatch(
                    matchId: matchId,
                    commandId: startCommandId,
                    clientBuildVersion: clientBuildVersion)
                try installServerState(finalized)
            }
            markConnectionRestoredIfNeeded()
            if let next = currentQuestion {
                await sendFocus(next.slot)
            }
        } catch {
            didTriggerDeadlineSubmit = false
            guard accountIsCurrent else {
                dismiss()
                return
            }
            noteConnectionFailure()
            actionError = playErrorMessage(error, operation: .submit)
        }
    }

    // MARK: Events

    private func heartbeatLoop() async {
        guard accountIsCurrent, attempt?.status == "IN_PROGRESS",
              submission == nil else { return }

        while !Task.isCancelled {
            do {
                try await Task.sleep(for: .seconds(5))
            } catch {
                return
            }
            guard accountIsCurrent else { return }
            guard !Task.isCancelled,
                  scenePhase == .active,
                  attempt?.status == "IN_PROGRESS",
                  submission == nil else { continue }
            await sendHeartbeat()
        }
    }

    @MainActor
    private func sendHeartbeat() async {
        guard accountIsCurrent, attempt?.status == "IN_PROGRESS",
              submission == nil else { return }
        do {
            _ = try await eventChannel.heartbeat()
            guard accountIsCurrent else {
                dismiss()
                return
            }
            if connectionInterrupted {
                connectionInterrupted = false
                _ = try? await eventChannel.networkState("RECONNECTED")
            }
            connectionNotice = nil
        } catch {
            guard accountIsCurrent else {
                dismiss()
                return
            }
            noteConnectionFailure()
        }
    }

    @MainActor
    private func sendFocus(_ slot: Int) async {
        guard accountIsCurrent, attempt?.status == "IN_PROGRESS",
              submission == nil else { return }
        do {
            _ = try await eventChannel.focus(slot: slot)
            guard accountIsCurrent else {
                dismiss()
                return
            }
            markConnectionRestoredIfNeeded()
        } catch {
            guard accountIsCurrent else {
                dismiss()
                return
            }
            noteConnectionFailure()
        }
    }

    @MainActor
    private func sendNetworkState(_ state: String) async {
        guard accountIsCurrent, attempt?.status == "IN_PROGRESS",
              submission == nil else { return }
        do {
            _ = try await eventChannel.networkState(state)
            guard accountIsCurrent else {
                dismiss()
                return
            }
            if state == "FOREGROUND" || state == "ONLINE" || state == "RECONNECTED" {
                markConnectionRestoredIfNeeded()
            }
        } catch {
            guard accountIsCurrent else {
                dismiss()
                return
            }
            noteConnectionFailure()
        }
    }

    private func handleScenePhase(_ phase: ScenePhase) {
        if usesDebugFixture { return }
        guard accountIsCurrent, attempt?.status == "IN_PROGRESS",
              submission == nil else { return }

        switch phase {
        case .active:
            Task {
                await sendNetworkState(connectionInterrupted ? "RECONNECTED" : "FOREGROUND")
                await sendHeartbeat()
            }
        case .background:
            persistDraft()
            Task {
                if let currentQuestion {
                    _ = await saveCurrentSolutionBoard(force: true)
                    _ = await saveAnswer(
                        slot: currentQuestion.slot,
                        reportFailure: false
                    )
                }
                await sendNetworkState("BACKGROUND")
            }
        case .inactive:
            // background task가 실행되기 전에 앱이 정지될 수 있으므로 로컬 초안은
            // 동기적으로 먼저 확정한다.
            persistDraft()
            solutionBoardSaveTask?.cancel()
            Task { _ = await saveCurrentSolutionBoard(force: true) }
        @unknown default:
            break
        }
    }

    private func noteConnectionFailure() {
        connectionInterrupted = true
        connectionNotice = "답안은 이 기기에 임시 보관됩니다. 연결이 돌아오면 같은 경기로 다시 전송합니다."
    }

    private func markConnectionRestoredIfNeeded() {
        guard connectionInterrupted else { return }
        connectionInterrupted = false
        connectionNotice = nil
    }

    // MARK: Submit and exit

    @MainActor
    private func submitAttempt(automatic: Bool) async {
        guard accountIsCurrent,
              attempt?.status == "IN_PROGRESS",
              submission == nil,
              !isSubmitting else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        captureCurrentQuestionForLocalReview()

        var allAnswersSaved = true
        for slot in dirtySlots.sorted() {
            let saved = await saveAnswer(slot: slot, reportFailure: !automatic)
            if !saved {
                allAnswersSaved = false
                if !automatic { return }
            }
        }

        do {
            let result = try await eventChannel.submit(commandId: submissionId)
            guard accountIsCurrent else {
                dismiss()
                return
            }
            guard result.matchId == matchId,
                  result.attemptId == attempt?.attemptId else {
                throw GoatArenaPlayError.invalidContract
            }
            submission = result
            GoatArenaDraftStore.clear(
                matchId: matchId,
                attemptId: result.attemptId
            )
            GoatArenaCommandKeyStore.clear(matchId: matchId)
            connectionNotice = nil
        } catch {
            guard accountIsCurrent else {
                dismiss()
                return
            }
            noteConnectionFailure()
            actionError = automatic
                ? "개인 마감 시각이 지났지만 서버 제출 확인이 아직 끝나지 않았습니다. 연결을 확인한 뒤 답안 제출을 다시 눌러 주세요."
                : playErrorMessage(error, operation: .submit)
            if automatic, !allAnswersSaved {
                connectionNotice = "일부 답안과 최종 제출을 서버에 확인하지 못했습니다. 로컬 임시 답안은 보존되어 있습니다."
            }
        }
    }

    @MainActor
    private func saveAndDismiss() async {
        if let currentQuestion {
            let boardSaved = await saveCurrentSolutionBoard(force: true)
            guard boardSaved else { return }
            let saved = await saveAnswer(
                slot: currentQuestion.slot,
                reportFailure: true
            )
            guard saved else { return }
        }
        await sendNetworkState("BACKGROUND")
        persistDraft()
        dismiss()
    }

    private func persistDraft() {
        guard accountIsCurrent, let attempt, let questionPack,
              attempt.status == "IN_PROGRESS", submission == nil else { return }
        GoatArenaDraftStore.save(
            .init(
                matchId: matchId,
                attemptId: attempt.attemptId,
                questionPackId: questionPack.questionPackId,
                currentQuestionIndex: currentIndex,
                answers: answers,
                dirtySlots: dirtySlots.sorted(),
                answerCommandIds: answerCommandIds.filter {
                    dirtySlots.contains($0.key)
                }
            )
        )
    }

    private func captureCurrentQuestionForLocalReview() {
        guard accountIsCurrent,
              let attempt,
              let question = currentQuestion else { return }
        let value = answers[question.slot] ?? question.savedAnswer ?? ""
        localReviewContext = GoatArenaLocalReviewContextStore.merge(
            matchId: matchId,
            attemptId: attempt.attemptId,
            question: .init(
                slot: question.slot,
                questionVersionId: question.questionVersionId,
                statement: question.stem,
                inputMode: question.inputMode,
                studentAnswer: value
            )
        )
    }

    // MARK: Copy

    private enum PlayOperation {
        case start
        case answer
        case submit
    }

    private func playErrorMessage(
        _ error: Error,
        operation: PlayOperation
    ) -> String {
        if error is DecodingError || error is GoatArenaPlayError {
            return "앱과 서버의 경기 정보 형식을 확인할 수 없습니다. GOAT Arena 화면을 새로고침한 뒤 다시 시도해 주세요."
        }

        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost,
                    .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
                return "서버에 연결하지 못했습니다. Wi-Fi 연결을 확인한 뒤 다시 시도해 주세요."
            case .timedOut:
                return "서버 응답이 늦어지고 있습니다. 잠시 후 다시 시도해 주세요."
            default:
                break
            }
        }

        if let apiError = error as? ServerAPIError {
            // 라우트 자체가 없는 서버(HTTP_404, 웹 세션 전용) — 재시도해도 같은 결과이므로
            // 웹으로 안내한다. 코드 있는 404(경기 없음)는 아래 case 가 그대로 처리한다.
            if apiError.isRouteMissing {
                return Self.routeMissingNotice
            }
            switch apiError.code {
            case "MATCH_START_DEADLINE_PASSED":
                return "경기 시작 마감이 지났습니다. GOAT Arena 화면에서 서버 상태를 다시 확인해 주세요."
            case "ARENA_ATTEMPT_EXPIRED", "ARENA_ATTEMPT_DEADLINE_PASSED":
                return "개인 제한 시간이 끝났습니다. 남아 있는 답안을 최종 제출해 주세요."
            case "GOAT_ARENA_QUESTION_PACK_NOT_READY", "MATCH_QUESTION_PACK_NOT_READY":
                return "경기 문제를 준비하고 있습니다. 잠시 후 다시 시도해 주세요."
            case "GOAT_ARENA_MATCH_NOT_FOUND", "MATCH_NOT_FOUND":
                return "현재 계정에서 이 경기를 찾을 수 없습니다. GOAT Arena 화면을 새로고침해 주세요."
            case "POLICY_PENDING", "ARENA_ATTEMPT_POLICY_PENDING":
                return "경기 운영 기준을 확인하고 있습니다. 잠시 후 다시 시도해 주세요."
            default:
                if apiError.statusCode == 401 {
                    return "로그인 시간이 만료되었습니다. 다시 로그인한 뒤 경기를 이어 주세요."
                }
                if apiError.statusCode == 409 {
                    return "경기 상태가 바뀌었습니다. GOAT Arena 화면을 새로고침한 뒤 다시 시도해 주세요."
                }
            }
        }

        switch operation {
        case .start:
            return "경기를 열지 못했습니다. 잠시 후 다시 시도해 주세요."
        case .answer:
            return "답안을 서버에 저장하지 못했습니다. 로컬 임시 답안은 보존되어 있으니 다시 시도해 주세요."
        case .submit:
            return "최종 제출을 확인하지 못했습니다. 답안은 보존되어 있으니 다시 시도해 주세요."
        }
    }

    private func roleTitle(_ role: String) -> String {
        role == "CHALLENGER" ? "도전자 개인 경기" : "방어자 개인 경기"
    }

    /// 상태 스트립용 한 낱말 역할. 웹 3칸 그리드의 `내 역할` 칸과 같은 값이다.
    private func shortRoleTitle(_ role: String) -> String {
        role == "CHALLENGER" ? "도전자" : "방어자"
    }

    private func timeText(_ seconds: Int) -> String {
        let clamped = max(0, seconds)
        let hours = clamped / 3600
        let minutes = (clamped % 3600) / 60
        let remainder = clamped % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, remainder)
        }
        return String(format: "%d:%02d", minutes, remainder)
    }
}

#if DEBUG
private enum GoatArenaMatchFixture {
    static func make(
        matchId: String
    ) -> (
        attempt: ServerAPI.GoatArenaAttempt,
        questionPack: ServerAPI.GoatArenaQuestionPack,
        endsAt: Date
    ) {
        let now = Date()
        let endsAt = now.addingTimeInterval(25 * 60)
        let commonDeadline = now.addingTimeInterval(40 * 60)
        let formatter = ISO8601DateFormatter()
        let packId = "fixture-question-pack"

        let questions: [ServerAPI.GoatArenaQuestionPack.Question] = [
            .init(
                slot: 1,
                questionVersionId: "fixture-q1-v1",
                stem: "함수 \\(f(x)=x^3-3x\\)의 극댓값과 극솟값의 차를 구하세요.",
                choices: [
                    .init(key: "1", text: "2"),
                    .init(key: "2", text: "4"),
                    .init(key: "3", text: "6"),
                    .init(key: "4", text: "8")
                ],
                inputMode: "MULTIPLE_CHOICE",
                scoreWeight: 20,
                targetDifficulty: 0.58,
                calibratedDifficulty: 0.59,
                advanced: false),
            .init(
                slot: 2,
                questionVersionId: "fixture-q2-v1",
                stem: "방정식 \\(2^{x+1}=16\\)을 만족하는 \\(x\\)를 구하세요.",
                choices: nil,
                inputMode: "SHORT_ANSWER",
                scoreWeight: 20,
                targetDifficulty: 0.42,
                calibratedDifficulty: 0.41,
                advanced: false),
            .init(
                slot: 3,
                questionVersionId: "fixture-q3-v1",
                stem: "수열 \\(a_n=3n-1\\)의 첫째항부터 제10항까지의 합을 구하세요.",
                choices: nil,
                inputMode: "SHORT_ANSWER",
                scoreWeight: 20,
                targetDifficulty: 0.51,
                calibratedDifficulty: 0.52,
                advanced: false),
            .init(
                slot: 4,
                questionVersionId: "fixture-q4-v1",
                stem: "\\(\\int_0^2 (3x^2+1)\\,dx\\)의 값을 구하세요.",
                choices: [
                    .init(key: "1", text: "8"),
                    .init(key: "2", text: "10"),
                    .init(key: "3", text: "12"),
                    .init(key: "4", text: "14")
                ],
                inputMode: "MULTIPLE_CHOICE",
                scoreWeight: 20,
                targetDifficulty: 0.62,
                calibratedDifficulty: 0.63,
                advanced: false),
            .init(
                slot: 5,
                questionVersionId: "fixture-q5-v1",
                stem: "두 사건 \\(A, B\\)가 독립이고 \\(P(A)=\\frac12\\), \\(P(B)=\\frac13\\)일 때 \\(P(A\\cap B)\\)를 구하세요.",
                choices: nil,
                inputMode: "SHORT_ANSWER",
                scoreWeight: 20,
                targetDifficulty: 0.67,
                calibratedDifficulty: 0.66,
                advanced: true)
        ]

        let attempt = ServerAPI.GoatArenaAttempt(
            attemptId: "fixture-attempt",
            matchId: matchId,
            participantRole: "CHALLENGER",
            questionPackId: packId,
            questionPackVersion: "1",
            scoringPolicyVersion: "RANKED-2026-08",
            timingPolicyVersion: "RANKED-25M",
            status: "IN_PROGRESS",
            questionCount: questions.count,
            timeLimitSeconds: 25 * 60,
            startedAt: formatter.string(from: now),
            endsAt: formatter.string(from: endsAt),
            commonSubmitsBy: formatter.string(from: commonDeadline),
            networkReconnectGraceMs: 30_000,
            recognizedHeartbeatActiveMs: 92_000,
            submittedAt: nil,
            evidenceDeadlineAt: nil,
            evidenceRequired: false)

        let questionPack = ServerAPI.GoatArenaQuestionPack(
            questionPackId: packId,
            matchId: matchId,
            participantRole: "CHALLENGER",
            packVersion: "1",
            curriculumVersion: "2026-08",
            questionVersion: "1",
            scoringPolicyVersion: "RANKED-2026-08",
            questionCount: questions.count,
            timeLimitSeconds: 25 * 60,
            questions: questions,
            sealedAt: formatter.string(from: now))

        return (attempt, questionPack, endsAt)
    }
}
#endif

// MARK: - Serialized command channel

/// Swift actor는 네트워크 await 중 재진입될 수 있다. 별도 gate를 잡아
/// heartbeat·focus·answer·submit이 실제로 한 요청씩 끝난 뒤 다음 요청을 보낸다.
private actor GoatArenaEventChannel {
    let matchId: String
    let clientBuildVersion: String
    let accountSlot: String
    private var requestInFlight = false
    private var requestWaiters: [CheckedContinuation<Void, Never>] = []

    init(matchId: String, clientBuildVersion: String, accountSlot: String) {
        self.matchId = matchId
        self.clientBuildVersion = clientBuildVersion
        self.accountSlot = accountSlot
    }

    private func acquireRequestTurn() async {
        if !requestInFlight {
            requestInFlight = true
            return
        }
        await withCheckedContinuation { continuation in
            requestWaiters.append(continuation)
        }
    }

    private func releaseRequestTurn() {
        if requestWaiters.isEmpty {
            requestInFlight = false
        } else {
            requestWaiters.removeFirst().resume()
        }
    }

    private func assertAccountStillCurrent() throws {
        guard DataScope.slot == accountSlot else {
            throw GoatArenaPlayError.accountChanged
        }
    }

    func heartbeat() async throws -> ServerAPI.GoatArenaEvent {
        await acquireRequestTurn()
        defer { releaseRequestTurn() }
        try assertAccountStillCurrent()
        return try await ServerAPI.postGoatArenaHeartbeat(
            matchId: matchId,
            eventId: UUID().uuidString,
            clientBuildVersion: clientBuildVersion
        )
    }

    func focus(slot: Int) async throws -> ServerAPI.GoatArenaEvent {
        await acquireRequestTurn()
        defer { releaseRequestTurn() }
        try assertAccountStillCurrent()
        return try await ServerAPI.postGoatArenaFocus(
            matchId: matchId,
            questionSlot: slot,
            eventId: UUID().uuidString,
            clientBuildVersion: clientBuildVersion
        )
    }

    func saveAnswer(
        slot: Int,
        answer: String,
        commandId: String
    ) async throws -> ServerAPI.GoatArenaEvent {
        await acquireRequestTurn()
        defer { releaseRequestTurn() }
        try assertAccountStillCurrent()
        return try await ServerAPI.saveGoatArenaAnswer(
            matchId: matchId,
            questionSlot: slot,
            answer: answer,
            eventId: commandId,
            clientBuildVersion: clientBuildVersion
        )
    }

    func networkState(_ state: String) async throws -> ServerAPI.GoatArenaEvent {
        await acquireRequestTurn()
        defer { releaseRequestTurn() }
        try assertAccountStillCurrent()
        return try await ServerAPI.postGoatArenaNetworkState(
            matchId: matchId,
            state: state,
            eventId: UUID().uuidString,
            clientBuildVersion: clientBuildVersion
        )
    }

    func submit(commandId: String) async throws -> ServerAPI.GoatArenaSubmission {
        await acquireRequestTurn()
        defer { releaseRequestTurn() }
        try assertAccountStillCurrent()
        return try await ServerAPI.submitGoatArenaAttempt(
            matchId: matchId,
            submissionId: commandId,
            clientBuildVersion: clientBuildVersion
        )
    }
}

// MARK: - Server dates

private enum ArenaServerDate {
    static func parse(_ value: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: value) {
            return date
        }
        return ISO8601DateFormatter().date(from: value)
    }

    static func required(_ value: String, label: String) throws -> Date {
        guard let date = parse(value) else {
            throw GoatArenaPlayError.invalidDate(label)
        }
        return date
    }
}

private enum GoatArenaPlayError: LocalizedError {
    case invalidContract
    case invalidDate(String)
    case accountChanged

    var errorDescription: String? {
        switch self {
        case .invalidContract:
            return "경기 정보 계약이 일치하지 않습니다."
        case .invalidDate(let label):
            return "\(label) 형식이 올바르지 않습니다."
        case .accountChanged:
            return "로그인 계정이 변경되었습니다."
        }
    }
}

// MARK: - Account-scoped local draft

private struct GoatArenaDraft: Codable {
    let matchId: String
    let attemptId: String
    let questionPackId: String
    let currentQuestionIndex: Int
    let answers: [Int: String]
    /// nil은 구버전 초안이다. 구버전은 저장 완료 여부를 남기지 않았으므로 모든
    /// 답안을 미저장으로 간주해 한 번 안전하게 재전송한다.
    let dirtySlots: [Int]?
    /// 응답 유실 뒤에도 같은 답·같은 멱등키를 보내기 위해 초안과 함께 보존한다.
    let answerCommandIds: [Int: String]?
}

private enum GoatArenaDraftStore {
    private static let fileName = "goat-arena-match-drafts.json"

    private static var fileURL: URL {
        DataScope.url(fileName)
    }

    static func load(
        matchId: String,
        attemptId: String,
        questionPackId: String
    ) -> GoatArenaDraft? {
        guard let data = try? Data(contentsOf: fileURL),
              let drafts = try? JSONDecoder().decode([GoatArenaDraft].self, from: data)
        else {
            return nil
        }
        return drafts.first {
            $0.matchId == matchId
                && $0.attemptId == attemptId
                && $0.questionPackId == questionPackId
        }
    }

    static func save(_ draft: GoatArenaDraft) {
        var drafts = readAll().filter {
            !($0.matchId == draft.matchId && $0.attemptId == draft.attemptId)
        }
        drafts.append(draft)
        write(drafts)
    }

    static func clear(matchId: String, attemptId: String) {
        let remaining = readAll().filter {
            !($0.matchId == matchId && $0.attemptId == attemptId)
        }
        write(remaining)
    }

    private static func readAll() -> [GoatArenaDraft] {
        guard let data = try? Data(contentsOf: fileURL),
              let drafts = try? JSONDecoder().decode([GoatArenaDraft].self, from: data)
        else {
            return []
        }
        return drafts
    }

    private static func write(_ drafts: [GoatArenaDraft]) {
        guard let data = try? JSONEncoder().encode(drafts) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}

// MARK: - Stable idempotency keys

private struct GoatArenaCommandKeys: Codable {
    let matchId: String
    let startCommandId: String
    let submissionId: String
    let clientBuildVersion: String

    private enum CodingKeys: String, CodingKey {
        case matchId, startCommandId, submissionId, clientBuildVersion
    }

    init(
        matchId: String,
        startCommandId: String,
        submissionId: String,
        clientBuildVersion: String
    ) {
        self.matchId = matchId
        self.startCommandId = startCommandId
        self.submissionId = submissionId
        self.clientBuildVersion = clientBuildVersion
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        matchId = try values.decode(String.self, forKey: .matchId)
        startCommandId = try values.decode(String.self, forKey: .startCommandId)
        submissionId = try values.decode(String.self, forKey: .submissionId)
        clientBuildVersion = try values.decodeIfPresent(
            String.self,
            forKey: .clientBuildVersion
        ) ?? ServerAPI.clientBuildVersion
    }
}

private enum GoatArenaCommandKeyStore {
    private static let fileName = "goat-arena-command-keys.json"

    private static var fileURL: URL {
        DataScope.url(fileName)
    }

    static func loadOrCreate(matchId: String) -> GoatArenaCommandKeys {
        var values = readAll()
        if let existing = values.first(where: { $0.matchId == matchId }) {
            // clientBuildVersion이 없던 구버전 파일도 현재 값을 한 번 기록해 이후 앱
            // 업데이트에서 같은 명령 fingerprint가 달라지지 않게 한다.
            write(values)
            return existing
        }

        let created = GoatArenaCommandKeys(
            matchId: matchId,
            startCommandId: UUID().uuidString,
            submissionId: UUID().uuidString,
            clientBuildVersion: ServerAPI.clientBuildVersion
        )
        values.append(created)
        write(values)
        return created
    }

    static func clear(matchId: String) {
        write(readAll().filter { $0.matchId != matchId })
    }

    private static func readAll() -> [GoatArenaCommandKeys] {
        guard let data = try? Data(contentsOf: fileURL),
              let values = try? JSONDecoder().decode(
                [GoatArenaCommandKeys].self,
                from: data
              )
        else {
            return []
        }
        return values
    }

    private static func write(_ values: [GoatArenaCommandKeys]) {
        guard let data = try? JSONEncoder().encode(values) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
