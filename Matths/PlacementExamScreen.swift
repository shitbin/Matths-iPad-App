//  PlacementExamScreen.swift
//  Matths
//
//  웹 placementExamService를 그대로 사용하는 네이티브 iPad 배치고사.
//  제한 시간·채점·티어 판정은 서버가 유일한 진실원이며 앱은 답안 작성과 표시만 담당한다.

import SwiftUI

struct PlacementExamScreen: View {
    private typealias Attempt = ServerAPI.PlacementAttempt
    private typealias Question = ServerAPI.PlacementQuestion
    private typealias Result = ServerAPI.PlacementResult

    @EnvironmentObject private var store: AppStore
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    /// 가로로 든 iPhone. horizontalSizeClass 만으로는 세로 iPhone 과 구분되지 않아
    /// 같은 한 줄짜리 레이아웃을 뷰포트 300pt 문맥에도 그대로 씌우게 된다.
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private enum LoadState {
        case loading
        case intro(ServerAPI.PlacementStatus)
        case unavailable(ServerAPI.PlacementStatus)
        case taking
        case result(Result)
        case failed(String)
    }

    @State private var state: LoadState = .loading
    @State private var attempt: Attempt?
    @State private var answers: [String: String] = [:]
    @State private var currentIndex = 0
    @State private var now = Date()
    @State private var saveRevision = 0
    @State private var isStarting = false
    @State private var isSaving = false
    @State private var isSubmitting = false
    @State private var didExpire = false
    @State private var confirmSubmit = false
    @State private var confirmExit = false
    @State private var actionError: String?
    @State private var reviewFixtureActive = false
    /// 화면을 연 학생에게 네트워크 응답과 로컬 초안을 귀속한다. 계정 전환 뒤
    /// 늦게 도착한 배치 결과가 새 학생 화면/초안에 섞이지 않게 하는 경계다.
    @State private var accountSlot = DataScope.slot

    private let clock = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var questions: [Question] { attempt?.questions ?? [] }
    private var currentQuestion: Question? {
        guard questions.indices.contains(currentIndex) else { return nil }
        return questions[currentIndex]
    }
    private var activeQuestionId: String { currentQuestion?.id ?? "" }
    private var answeredCount: Int {
        questions.reduce(into: 0) { count, question in
            if !(answers[question.id] ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { count += 1 }
        }
    }
    private var deadline: Date? { attempt?.deadlineAt.flatMap(Self.parseDate) }
    private var remainingSeconds: Int? {
        deadline.map { max(0, Int(ceil($0.timeIntervalSince(now)))) }
    }
    private var interactionDisabled: Bool {
        isSaving || isSubmitting || remainingSeconds == 0
    }
    private var compact: Bool { horizontalSizeClass == .compact }
    private var shortHeight: Bool { verticalSizeClass == .compact }
    private var usesLandscapeChoiceGrid: Bool {
        shortHeight && !dynamicTypeSize.isAccessibilitySize
    }

    var body: some View {
        ZStack {
            Tokens.paper.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                Group {
                    switch state {
                    case .loading:
                        loadingView
                    case .intro(let status):
                        introView(status)
                    case .unavailable(let status):
                        unavailableView(status)
                    case .taking:
                        examView
                    case .result(let result):
                        resultView(result)
                    case .failed(let message):
                        failureView(message)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task { await load() }
        .task(id: saveRevision) {
            guard saveRevision > 0 else { return }
            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled else { return }
            await saveDraft(reportFailure: false)
        }
        .onReceive(clock) { value in
            now = value
            guard case .taking = state,
                  remainingSeconds == 0,
                  !didExpire else { return }
            didExpire = true
            Task { await expireAttempt() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await refreshAfterBackground() }
            } else if case .taking = state {
                saveLocalDraft()
                Task { await saveDraft(reportFailure: false, closeTiming: true) }
            }
        }
        .confirmationDialog(
            "배치고사 답안을 제출할까요?",
            isPresented: $confirmSubmit,
            titleVisibility: .visible
        ) {
            Button("최종 제출") { Task { await submitAttempt() } }
            Button("계속 풀기", role: .cancel) {}
        } message: {
            let left = max(0, questions.count - answeredCount)
            Text(left == 0
                 ? "제출 뒤에는 답안을 바꿀 수 없습니다."
                 : "미응답 문항이 \(left)개 있습니다. 제출 뒤에는 답안을 바꿀 수 없습니다.")
        }
        .confirmationDialog(
            "Arena로 돌아갈까요?",
            isPresented: $confirmExit,
            titleVisibility: .visible
        ) {
            Button("저장하고 나가기") {
                Task {
                    await saveDraft(reportFailure: false, closeTiming: true)
                    store.route = .rank
                }
            }
            Button("계속 풀기", role: .cancel) {}
        } message: {
            Text("화면을 나가거나 다른 앱을 사용해도 서버 제한 시간은 계속 흐릅니다. 작성한 답안은 이 기기와 서버에 저장합니다.")
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
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: 0) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Tokens.Space.s4) {
                    closeButton
                    titleBlock
                    Spacer(minLength: Tokens.Space.s3)
                    if case .taking = state { timerPill }
                }

                VStack(spacing: Tokens.Space.s2) {
                    HStack(spacing: Tokens.Space.s3) {
                        closeButton
                        titleBlock
                        Spacer(minLength: Tokens.Space.s2)
                    }
                    if case .taking = state { timerPill }
                }
            }
            .padding(.horizontal, compact ? Tokens.Space.s4 : Tokens.Space.s6)
            .padding(.vertical, Tokens.Space.s3)

            if case .taking = state {
                ProgressView(value: Double(answeredCount), total: Double(max(questions.count, 1)))
                    .tint(Tokens.primary)
                    .accessibilityLabel("배치고사 응답 진행률")
                    .accessibilityValue("\(questions.count)문항 중 \(answeredCount)문항 응답")
            }
            Rectangle().fill(Tokens.line).frame(height: 1)
        }
        .background(.bar)
    }

    private var closeButton: some View {
        Button {
            if case .taking = state { confirmExit = true }
            else { store.route = .rank }
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 16, weight: .bold))
                .frame(width: 44, height: 44)
                .background(Tokens.paper2, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Arena로 돌아가기")
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(attempt?.phase == "verification" ? "추가 확인" : "배치고사")
                .font(.mMicro)
                .foregroundStyle(Tokens.primary)
            Text(attempt?.title ?? "GOAT Arena 배치고사")
                .font(.mBodyB)
                .foregroundStyle(Tokens.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
    }

    private var timerPill: some View {
        HStack(spacing: 7) {
            Image(systemName: "timer")
            Text(Self.clockText(remainingSeconds ?? 0))
                .monospacedDigit()
            Text("답안 \(answeredCount)/\(questions.count)")
                .foregroundStyle(Tokens.text2)
        }
        .font(.mNumeric)
        .foregroundStyle((remainingSeconds ?? 0) <= 300 ? Tokens.danger : Tokens.ink)
        .padding(.horizontal, Tokens.Space.s4)
        .frame(minHeight: 40)
        .background(
            (remainingSeconds ?? 0) <= 300 ? Tokens.dangerSoft : Tokens.paper2,
            in: Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("남은 시간 \(Self.clockAccessibility(remainingSeconds ?? 0)), \(questions.count)문항 중 \(answeredCount)문항 응답")
    }

    // MARK: Intro / loading / failure

    private var loadingView: some View {
        VStack(spacing: Tokens.Space.s4) {
            ProgressView().controlSize(.large)
            Text("배치고사 상태를 확인하고 있습니다")
                .font(.mBodyB).foregroundStyle(Tokens.ink)
        }
    }

    private func introView(_ status: ServerAPI.PlacementStatus) -> some View {
        ScrollView {
            // 가로 iPhone 에서는 "무슨 시험인가"(왼쪽)와 "어떻게 진행되나 · 시작"(오른쪽)을
            // 나눠 시작 버튼을 첫 화면 안에 둔다. 세로로 쌓으면 안내 네 덩어리 뒤에
            // 버튼이 붙어, 시작하려면 매번 끝까지 스크롤해야 한다.
            CompactHeightColumns(spacing: Tokens.Space.s6, stackedSpacing: Tokens.Space.s6) {
                VStack(alignment: .leading, spacing: Tokens.Space.s6) {
                    VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                        Text("GOAT Arena 배치")
                            .font(.mMicro).foregroundStyle(Tokens.primary)
                        Text("실력에 맞는 첫 티어를 찾습니다")
                            .font(.mDisplay).foregroundStyle(Tokens.ink)
                        Text("30문항을 100분 동안 풉니다. 앱을 벗어나도 시간은 멈추지 않으며, 답안과 채점, 첫 MMR은 서버가 동일한 규칙으로 처리합니다.")
                            .font(.mCallout).foregroundStyle(Tokens.text2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: Tokens.Space.s4) { introMetric("30", "문항"); introMetric("100", "분"); introMetric("9", "티어") }
                        VStack(spacing: Tokens.Space.s3) { introMetric("30", "문항"); introMetric("100", "분"); introMetric("9", "티어") }
                    }
                }
                .accessibilityElement(children: .contain)
            } trailing: {
                VStack(alignment: .leading, spacing: Tokens.Space.s6) {
                    VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                        Label("중간 저장 후 다시 이어서 풀 수 있습니다.", systemImage: "checkmark.circle.fill")
                        Label("추가 확인이 필요한 경우 4문항이 이어집니다.", systemImage: "checkmark.circle.fill")
                        Label("최종 결과가 확정되면 해당 티어 휘장 모션이 재생됩니다.", systemImage: "checkmark.circle.fill")
                    }
                    .font(.mBody)
                    .foregroundStyle(Tokens.text2)

                    Button {
                        Task { await start() }
                    } label: {
                        if isStarting { ProgressView().tint(Tokens.onPrimary) }
                        else { Label(status.ctaLabel.isEmpty ? "입단 배치고사 시작" : status.ctaLabel, systemImage: "arrow.right") }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(isStarting)
                    .frame(maxWidth: 360)
                }
                .accessibilityElement(children: .contain)
            }
            .readableWidth(840)
            .adaptiveHPadding()
            .padding(.vertical, shortHeight ? Tokens.Space.s5 : Tokens.Space.s8)
        }
    }

    private func introMetric(_ value: String, _ label: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            // iPhone 가로의 2열 intro 안에서는 카드 하나가 약 110pt다. 100을
            // mStatLarge로 두면 마지막 0이 다음 줄로 떨어져 시험 시간이 10/0처럼
            // 보인다. 세로가 짧을 때 한 단계 줄이고 숫자·단위를 한 줄로 고정한다.
            Text(value)
                .font(shortHeight ? .mStat : .mStatLarge)
                .foregroundStyle(Tokens.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.68)
            Text(label)
                .font(.mCaption)
                .foregroundStyle(Tokens.text2)
                .lineLimit(1)
        }
        .padding(shortHeight ? Tokens.Space.s4 : Tokens.Space.s5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.Radius.lg))
        .accessibilityElement(children: .combine)
    }

    private func failureView(_ message: String) -> some View {
        VStack(spacing: Tokens.Space.s5) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 36)).foregroundStyle(Tokens.warningInk)
            Text("배치고사를 불러오지 못했습니다").font(.mHeading).foregroundStyle(Tokens.ink)
            Text(message).font(.mCallout).foregroundStyle(Tokens.text2).multilineTextAlignment(.center)
            Button("다시 확인") { Task { await load() } }
                .buttonStyle(PrimaryButtonStyle())
        }
        .padding(Tokens.Space.s6)
    }

    private func unavailableView(_ status: ServerAPI.PlacementStatus) -> some View {
        VStack(spacing: Tokens.Space.s5) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 40)).foregroundStyle(Tokens.text2)
            Text("이번 배치고사 응시가 종료되었습니다")
                .font(.mHeading).foregroundStyle(Tokens.ink)
            Text(status.ctaLabel.isEmpty ? "같은 배치 구간에서는 다시 시작할 수 없습니다." : status.ctaLabel)
                .font(.mCallout).foregroundStyle(Tokens.text2)
                .multilineTextAlignment(.center)
            Button("GOAT Arena로 돌아가기") { store.route = .rank }
                .buttonStyle(PrimaryButtonStyle())
        }
        .padding(Tokens.Space.s6)
    }

    // MARK: Exam

    private var examView: some View {
        Group {
            if compact {
                ScrollView {
                    VStack(spacing: shortHeight ? Tokens.Space.s3 : Tokens.Space.s4) {
                        compactNavigator
                        questionPanel
                    }
                    // 가로 iPhone 은 뷰포트 높이가 300pt 안팎이다. 상하 16pt 를 그대로
                    // 두면 문항 하나 볼 자리에서 32pt 를 여백으로 쓴다.
                    .padding(.horizontal, Tokens.Space.s4)
                    .padding(.vertical, shortHeight ? Tokens.Space.s2 : Tokens.Space.s4)
                }
            } else {
                HStack(alignment: .top, spacing: Tokens.Space.s5) {
                    ScrollView { navigator.padding(.bottom, Tokens.Space.s5) }
                        .frame(width: 250)
                    ScrollView { questionPanel.padding(.bottom, Tokens.Space.s6) }
                }
                .padding(.horizontal, Tokens.Space.s6)
                .padding(.top, Tokens.Space.s5)
            }
        }
    }

    private var navigator: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s4) {
            Text("문항 이동").font(.mHeading).foregroundStyle(Tokens.ink)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 44, maximum: 52), spacing: Tokens.Space.s2)], spacing: Tokens.Space.s2) {
                ForEach(Array(questions.enumerated()), id: \.element.id) { index, question in
                    questionNumberButton(index, question)
                }
            }
            DottedRule()
            Label(isSaving ? "서버 저장 중" : "답안 자동 저장", systemImage: isSaving ? "arrow.triangle.2.circlepath" : "checkmark.circle")
                .font(.mCaption)
                .foregroundStyle(isSaving ? Tokens.primary : Tokens.text2)
            Text("다른 앱을 사용해도 서버 제한 시간은 계속 흐릅니다.")
                .font(.mCaption).foregroundStyle(Tokens.text3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Tokens.Space.s5)
        .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.Radius.lg))
    }

    private var compactNavigator: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Tokens.Space.s2) {
                ForEach(Array(questions.enumerated()), id: \.element.id) { index, question in
                    questionNumberButton(index, question)
                }
            }
        }
        .accessibilityLabel("배치고사 문항 이동")
    }

    private func questionNumberButton(_ index: Int, _ question: Question) -> some View {
        let selected = index == currentIndex
        let answered = !(answers[question.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return Button { move(to: index) } label: {
            ZStack(alignment: .topTrailing) {
                Text("\(question.number)")
                    .font(.mNumeric)
                    // 칩은 44pt 조작 표준을 지키는 고정 도구다. 접근성 최대 글씨를
                    // 그대로 넣으면 두 자리 문항이 전부 "…"가 되어 눈으로 이동할 수
                    // 없다. 번호 칩만 XXXL로 제한하고 전체 번호는 VoiceOver가 읽는다.
                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                    .foregroundStyle(selected ? Tokens.onPrimary : Tokens.ink)
                    .frame(width: 44, height: 44)
                    .background(selected ? Tokens.primary : Tokens.paper2,
                                in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
                    .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.md)
                        .strokeBorder(selected ? Tokens.primary : Tokens.line, lineWidth: 1))
                if answered {
                    Circle().fill(selected ? Tokens.onPrimary : Tokens.successInk)
                        .frame(width: 8, height: 8).padding(5)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(interactionDisabled)
        .accessibilityLabel("\(question.number)번 문항")
        .accessibilityValue(answered ? "응답함" : "미응답")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    @ViewBuilder private var questionPanel: some View {
        if let question = currentQuestion {
            VStack(alignment: .leading,
                   spacing: shortHeight ? Tokens.Space.s3 : Tokens.Space.s6) {
                HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s2) {
                    Text("문항 \(question.number)").font(.mMicro).foregroundStyle(Tokens.primary)
                    Text("/ \(questions.count)").font(.mMicro).foregroundStyle(Tokens.text3)
                    Spacer()
                    Text((answers[question.id] ?? "").isEmpty ? "미응답" : "응답함")
                        .font(.mMicro)
                        .foregroundStyle((answers[question.id] ?? "").isEmpty ? Tokens.text3 : Tokens.successInk)
                }

                ExamRule()

                // 가로 iPhone 에서는 발문과 답안을 좌우로 나눈다. 세로로 쌓으면
                // 발문 + 선택지 5개(각 58pt) + 이동 버튼이 400pt 를 넘어, 문제를 읽는
                // 동안 선택지가 화면 밖에 있고 고르는 동안 발문이 화면 밖에 있다.
                // 나란히 두면 읽기와 고르기가 한 화면에서 끝난다.
                CompactHeightColumns(spacing: Tokens.Space.s5, stackedSpacing: Tokens.Space.s6) {
                    VStack(alignment: .leading, spacing: Tokens.Space.s5) {
                        MathInline(
                            text: MathText.normalizeDelimiters(question.prompt),
                            font: .mHeading,
                            color: Tokens.ink,
                            pixelSize: compact ? 19 : 22)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            // MathInline의 렌더링 표면은 네이티브 접근성 트리에 발문을
                            // 자동으로 내놓지 않는다. 문제를 눈으로만 읽을 수 있게 두지 않는다.
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(MathText.plain(question.prompt))

                        // 발문이 짧으면 왼쪽 열 아래가 통째로 빈다. 이동 버튼을 그리로
                        // 옮기면 그만큼 오른쪽 선택지가 위로 올라와 한 번에 더 보인다.
                        // 세로 방향에서는 종전대로 답안 아래에 남는다(아래 trailing).
                        if shortHeight {
                            DottedRule()
                            controls
                        }
                    }
                } trailing: {
                    VStack(alignment: .leading, spacing: shortHeight ? Tokens.Space.s4 : Tokens.Space.s6) {
                        if !question.choices.isEmpty {
                            if usesLandscapeChoiceGrid {
                                // iPhone 가로의 오른쪽 열은 높이보다 폭이 남는다. 다섯
                                // 선택지를 한 줄씩 쌓으면 4·5번이 첫 화면 아래로 밀리므로
                                // 두 열, 최대 세 행으로 접어 발문·전체 답·이동 버튼을 함께 둔다.
                                LazyVGrid(
                                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                                    spacing: Tokens.Space.s2
                                ) {
                                    ForEach(question.choices) { choice in
                                        choiceButton(choice, question: question)
                                    }
                                }
                            } else {
                                VStack(spacing: Tokens.Space.s3) {
                                    ForEach(question.choices) { choice in
                                        choiceButton(choice, question: question)
                                    }
                                }
                            }
                        } else {
                            shortAnswerField(question)
                        }

                        if !shortHeight {
                            DottedRule()
                            controls
                        }
                    }
                }
            }
            // iPhone 가로는 위의 44pt 문항 탐색 줄까지 같은 뷰포트에 있다. 기본
            // 20pt 안쪽 여백을 그대로 두면 2열 선택지의 마지막 행이 화면 끝에서
            // 잘려 매 문항마다 스크롤해야 한다. 짧은 높이에서만 12pt로 줄여
            // 발문·선택지 1~5·이동 버튼을 첫 화면에 모두 남긴다.
            .padding(shortHeight ? Tokens.Space.s3
                     : (compact ? Tokens.Space.s5 : Tokens.Space.s6))
            // 가로 iPhone 의 최소 높이는 뷰포트보다 낮게 잡는다. 500pt 를 강제하면
            // 짧은 문항에서도 카드가 화면 밖으로 넘쳐 매번 스크롤이 생긴다.
            .frame(maxWidth: .infinity,
                   minHeight: shortHeight ? 0 : (compact ? 500 : 620),
                   alignment: .topLeading)
            .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.Radius.lg))
            .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.lg).strokeBorder(Tokens.line, lineWidth: 1))
        }
    }

    private func choiceButton(_ choice: Question.Choice, question: Question) -> some View {
        let selected = answers[question.id] == choice.key
        return Button {
            setAnswer(choice.key, for: question.id)
            Task { await saveDraft(reportFailure: true) }
        } label: {
            HStack(spacing: Tokens.Space.s4) {
                Text(choice.key.uppercased())
                    .font(.mBodyB)
                    .foregroundStyle(selected ? Tokens.onPrimary : Tokens.primary)
                    .frame(width: 36, height: 36)
                    .background(selected ? Tokens.primary : Tokens.primarySoft,
                                in: RoundedRectangle(cornerRadius: Tokens.Radius.sm))
                MathInline(text: MathText.normalizeDelimiters(choice.text), font: .mBody,
                           color: Tokens.ink, pixelSize: 17)
                    .allowsHitTesting(false)
                Spacer(minLength: 0)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? Tokens.primary : Tokens.text4)
            }
            .padding(.horizontal, Tokens.Space.s4)
            .padding(.vertical, shortHeight ? Tokens.Space.s2 : Tokens.Space.s3)
            // 가로 iPhone 에서만 48pt 로 줄인다. 선택지 5개가 세로 290pt 를 먹으면
            // 좌우로 나눠도 답을 고르려면 또 스크롤해야 한다. 44pt 조작 영역은 지킨다.
            .frame(maxWidth: .infinity, minHeight: shortHeight ? 48 : 58, alignment: .leading)
            .background(selected ? Tokens.primarySoft : Tokens.paper,
                        in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
            .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.md)
                .strokeBorder(selected ? Tokens.primary : Tokens.lineStrong,
                              lineWidth: selected ? 2 : 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(interactionDisabled)
        .accessibilityLabel("\(choice.key)번, \(MathText.plain(choice.text))")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func shortAnswerField(_ question: Question) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s3) {
            Text("답").font(.mCaption).foregroundStyle(Tokens.text2)
            TextField("답을 입력하세요", text: answerBinding(question.id), axis: .vertical)
                .font(.mBody)
                .lineLimit(2...5)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .onSubmit { Task { await saveDraft(reportFailure: true) } }
                .padding(Tokens.Space.s4)
                .background(Tokens.paper, in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
                .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.md).strokeBorder(Tokens.lineStrong, lineWidth: 1))
                .disabled(interactionDisabled)
            Text("수식과 기호를 포함해 답을 입력할 수 있습니다.")
                .font(.mCaption).foregroundStyle(Tokens.text3)
        }
    }

    private var controls: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Tokens.Space.s3) { previousButton; Spacer(); primaryButton }
            VStack(spacing: Tokens.Space.s3) { primaryButton; previousButton }
        }
    }

    private var previousButton: some View {
        Button { move(to: currentIndex - 1) } label: {
            Label("이전 문항", systemImage: "chevron.left")
        }
        .buttonStyle(SecondaryButtonStyle())
        .disabled(currentIndex == 0 || interactionDisabled)
    }

    @ViewBuilder private var primaryButton: some View {
        if currentIndex < questions.count - 1 {
            Button { move(to: currentIndex + 1) } label: {
                Label("다음 문항", systemImage: "chevron.right")
            }
            .buttonStyle(PrimaryButtonStyle())
            .frame(maxWidth: 260)
            .disabled(interactionDisabled)
        } else {
            Button { confirmSubmit = true } label: {
                if isSubmitting { ProgressView().tint(Tokens.onPrimary) }
                else { Label("답안 제출", systemImage: "paperplane.fill") }
            }
            .buttonStyle(PrimaryButtonStyle())
            .frame(maxWidth: 260)
            .disabled(interactionDisabled)
        }
    }

    // MARK: Result

    private func resultView(_ result: Result) -> some View {
        ScrollView {
            // 휘장은 크고(가로에서도 150pt) 그 뒤로 지표·안내·이동 버튼이 이어진다.
            // 가로 iPhone 에서는 휘장·티어를 왼쪽에 세우고 숫자와 다음 행동을
            // 오른쪽에 모아, 결과를 보는 순간 다음 버튼도 같이 보이게 한다.
            CompactHeightColumns(spacing: Tokens.Space.s6,
                                 stackedSpacing: Tokens.Space.s6,
                                 alignment: .center) {
                VStack(spacing: shortHeight ? Tokens.Space.s3 : Tokens.Space.s6) {
                    // 150pt 휘장과 결과 텍스트를 그대로 쌓으면 iPhone 가로에서
                    // 마지막 티어명이 카드 아래에 걸린다. 짧은 높이에서만 줄인다.
                    RankBadgeView(
                        tierCode: result.tierCode,
                        size: shortHeight ? 112 : (compact ? 150 : 210),
                        animated: true)
                    VStack(spacing: Tokens.Space.s2) {
                        Text("배치 완료").font(.mMicro).foregroundStyle(Tokens.primary)
                        Text(result.tierLabel).font(.mDisplay).foregroundStyle(Tokens.ink)
                        Text("첫 MMR \(result.initialMmr.map(String.init) ?? "확인 중")")
                            .font(.mHeading).foregroundStyle(Tokens.text2)
                    }
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .contain)
            } trailing: {
                VStack(spacing: Tokens.Space.s6) {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: Tokens.Space.s4) {
                            resultMetric("\(result.totalCorrect)", "정답")
                            resultMetric(Self.scoreText(result.placementScore), "배치 점수")
                            resultMetric(result.rankPoint.map(String.init) ?? "확인 중", "RP")
                        }
                        VStack(spacing: Tokens.Space.s3) {
                            resultMetric("\(result.totalCorrect)", "정답")
                            resultMetric(Self.scoreText(result.placementScore), "배치 점수")
                            resultMetric(result.rankPoint.map(String.init) ?? "확인 중", "RP")
                        }
                    }

                    Text(result.verificationRequired
                         ? "추가 실력 확인이 필요합니다. 이어서 4문항을 완료해 주세요."
                         : "이 결과는 서버의 동일한 배치 규칙으로 확정되었습니다. 이후 MMR과 Arena Position은 서로 다른 기준으로 갱신됩니다.")
                        .font(.mCallout).foregroundStyle(Tokens.text2)
                        .multilineTextAlignment(.center)

                    Button("GOAT Arena로 이동") { store.route = .rank }
                        .buttonStyle(PrimaryButtonStyle())
                        .frame(maxWidth: 360)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .contain)
            }
            .readableWidth(820)
            .adaptiveHPadding()
            .padding(.vertical, shortHeight ? Tokens.Space.s3 : Tokens.Space.s8)
        }
    }

    private func resultMetric(_ value: String, _ label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(shortHeight ? .mStat : .mStatLarge)
                .foregroundStyle(Tokens.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.68)
            Text(label)
                .font(.mCaption)
                .foregroundStyle(Tokens.text2)
                .lineLimit(1)
        }
        .padding(shortHeight ? Tokens.Space.s4 : Tokens.Space.s5)
        .frame(maxWidth: .infinity)
        .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.Radius.lg))
        .accessibilityElement(children: .combine)
    }

    // MARK: Networking and persistence

    @MainActor private func load() async {
        guard accountSlot == DataScope.slot else { return }
        #if DEBUG
        if applyDebugFixtureIfPresent() { return }
        #endif
        state = .loading
        do {
            let status = try await ServerAPI.getPlacementStatus()
            guard accountSlot == DataScope.slot else { return }
            if status.status == "submitted", let result = status.result {
                showResult(result, presentation: status.presentation)
            } else if let id = status.attemptId,
                      ["in-progress", "verification-required"].contains(status.status) {
                applyAttempt(try await ServerAPI.getPlacementAttempt(id))
            } else if LearningEntryStatePolicy.canStartPlacement(status.status) {
                state = .intro(status)
            } else {
                // `attempt-used`는 서버가 같은 배치 구간의 재응시를 거절하는
                // 종결 상태다. intro로 보내면 시작 버튼이 다시 POST를 쏴 매번
                // 409를 만든다.
                state = .unavailable(status)
            }
        } catch {
            guard accountSlot == DataScope.slot else { return }
            state = .failed(Self.message(for: error))
        }
    }


    #if DEBUG
    /// 디자인 검수는 운영 계정·배치 기록을 만들지 않는다. 정상 intro/taking/result를
    /// 동일한 화면 모델로만 렌더하고 모든 쓰기 버튼은 기존 네트워크 경계를 유지한다.
    /// `-route placement -placementFixture intro|taking|result`
    @MainActor private func applyDebugFixtureIfPresent() -> Bool {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-placementFixture"),
              arguments.indices.contains(index + 1) else { return false }
        reviewFixtureActive = true
        switch arguments[index + 1].lowercased() {
        case "intro":
            state = .intro(ServerAPI.PlacementStatus(
                status: "available", attemptId: nil, answeredCount: 0,
                ctaLabel: "입단 배치고사 시작", result: nil, presentation: nil))
        case "taking":
            applyAttempt(Self.debugAttempt())
        case "result":
            showResult(Self.debugResult(), presentation: nil)
        default:
            reviewFixtureActive = false
            return false
        }
        return true
    }

    private static func debugAttempt() -> Attempt {
        let choices = [
            Question.Choice(key: "1", text: "\\(1\\)"),
            Question.Choice(key: "2", text: "\\(2\\)"),
            Question.Choice(key: "3", text: "\\(3\\)"),
            Question.Choice(key: "4", text: "\\(4\\)"),
            Question.Choice(key: "5", text: "\\(5\\)"),
        ]
        let questions = (1...30).map { number in
            Question(
                id: "placement-review-\(number)", number: number,
                prompt: number == 1
                    ? "\\(x^2-5x+6=0\\)의 두 근의 합을 구하세요."
                    : "\(number)번 배치 문항",
                inputMode: number <= 21 ? "choice" : "short",
                choices: number <= 21 ? choices : [], points: number <= 21 ? 3 : 4,
                submittedAnswer: "", responseTimeMs: 0, visitCount: number == 1 ? 1 : 0)
        }
        return Attempt(
            id: "placement-review-attempt", phase: "placement", status: "in-progress",
            purpose: "initial-placement", title: "GOAT Arena 배치고사",
            subtitle: "30문항, 100분", timeLimitMs: 6_000_000,
            startedAt: ISO8601DateFormatter().string(from: Date()),
            deadlineAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(5_700)),
            submittedAt: nil, elapsedTimeMs: 300_000, currentQuestionIndex: 0,
            answeredCount: 0, questionCount: questions.count, questions: questions,
            result: nil, presentation: nil)
    }

    private static func debugResult() -> Result {
        Result(
            attemptId: "placement-review-attempt", status: "completed",
            totalCorrect: 24, placementScore: 82.5, initialMmr: 1_320,
            tierCode: "DIAMOND", tierLabel: "다이아몬드 II", rankPoint: 48,
            rankingStatus: "CONFIRMED", percentile: 0.88,
            verificationRequired: false, presentationId: nil)
    }
    #endif

    @MainActor private func start() async {
        guard accountSlot == DataScope.slot, !isStarting else { return }
        #if DEBUG
        if reviewFixtureActive {
            applyAttempt(Self.debugAttempt())
            return
        }
        #endif
        isStarting = true
        defer { isStarting = false }
        do {
            let value = try await ServerAPI.startPlacementExam()
            guard accountSlot == DataScope.slot else { return }
            applyAttempt(value)
        } catch {
            guard accountSlot == DataScope.slot else { return }
            actionError = Self.message(for: error)
        }
    }

    @MainActor private func applyAttempt(_ value: Attempt) {
        guard accountSlot == DataScope.slot else { return }
        attempt = value
        currentIndex = min(max(value.currentQuestionIndex, 0), max(value.questions.count - 1, 0))
        var merged = Dictionary(uniqueKeysWithValues: value.questions.map { ($0.id, $0.submittedAnswer) })
        for (key, answer) in loadLocalDraft(attemptId: value.id) where !answer.isEmpty {
            if (merged[key] ?? "").isEmpty { merged[key] = answer }
        }
        answers = merged
        didExpire = false
        if value.phase == "completed", let result = value.result {
            showResult(result, presentation: value.presentation)
        } else {
            state = .taking
            now = Date()
            saveLocalDraft()
        }
    }

    @MainActor private func refreshAfterBackground() async {
        guard !reviewFixtureActive else { return }
        guard accountSlot == DataScope.slot,
              case .taking = state, let id = attempt?.id else { return }
        do {
            let value = try await ServerAPI.getPlacementAttempt(id)
            guard accountSlot == DataScope.slot else { return }
            applyAttempt(value)
        } catch {
            guard accountSlot == DataScope.slot else { return }
            actionError = "연결을 다시 확인하고 있습니다. 로컬에 저장된 답안은 유지됩니다."
        }
    }

    @MainActor private func saveDraft(reportFailure: Bool, closeTiming: Bool = false) async {
        guard !reviewFixtureActive else { return }
        guard accountSlot == DataScope.slot,
              case .taking = state, let attempt, !isSubmitting else { return }
        saveLocalDraft()
        isSaving = true
        defer { isSaving = false }
        do {
            let draft = try await ServerAPI.savePlacementDraft(
                attemptId: attempt.id,
                answers: answers,
                activeQuestionId: activeQuestionId,
                currentQuestionIndex: currentIndex,
                closeQuestionTiming: closeTiming)
            guard accountSlot == DataScope.slot else { return }
            if draft.expired == true { await expireAttempt() }
        } catch {
            guard accountSlot == DataScope.slot else { return }
            if reportFailure { actionError = "서버 저장이 늦어지고 있습니다. 답안은 이 기기에 보관했으며 연결되면 다시 저장합니다." }
        }
    }

    @MainActor private func submitAttempt() async {
        guard accountSlot == DataScope.slot, let attempt, !isSubmitting else { return }
        #if DEBUG
        if reviewFixtureActive {
            showResult(Self.debugResult(), presentation: nil)
            return
        }
        #endif
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            let response = try await ServerAPI.submitPlacementExam(
                attemptId: attempt.id, answers: answers,
                activeQuestionId: activeQuestionId, currentQuestionIndex: currentIndex)
            guard accountSlot == DataScope.slot else { return }
            clearLocalDraft(attemptId: attempt.id)
            if response.attempt.phase == "verification" {
                applyAttempt(response.attempt)
            } else if let result = response.result ?? response.attempt.result {
                showResult(result, presentation: response.presentation ?? response.attempt.presentation)
            } else {
                applyAttempt(response.attempt)
            }
        } catch {
            guard accountSlot == DataScope.slot else { return }
            actionError = Self.message(for: error)
        }
    }

    @MainActor private func expireAttempt() async {
        guard !reviewFixtureActive else { return }
        guard accountSlot == DataScope.slot, let attempt, !isSubmitting else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            let response = try await ServerAPI.expirePlacementExam(
                attemptId: attempt.id, answers: answers,
                activeQuestionId: activeQuestionId, currentQuestionIndex: currentIndex)
            guard accountSlot == DataScope.slot else { return }
            clearLocalDraft(attemptId: attempt.id)
            if let result = response.result ?? response.attempt.result {
                showResult(result, presentation: response.presentation ?? response.attempt.presentation)
            } else {
                state = .failed("제한 시간이 종료되었습니다. Arena에서 배치 상태를 다시 확인해 주세요.")
            }
        } catch {
            guard accountSlot == DataScope.slot else { return }
            state = .failed("제한 시간이 종료되었습니다. 연결 후 제출 상태를 다시 확인해 주세요.")
        }
    }

    @MainActor private func showResult(_ result: Result, presentation: ServerAPI.PlacementPresentation?) {
        guard accountSlot == DataScope.slot else { return }
        state = .result(result)
        attempt = nil
        if let presentation {
            store.presentRankPromotion(
                tierCode: presentation.tierCode,
                presentationId: presentation.id)
        }
    }

    private func move(to index: Int) {
        guard questions.indices.contains(index), index != currentIndex else { return }
        currentIndex = index
        saveLocalDraft()
        Task { await saveDraft(reportFailure: false) }
    }

    private func setAnswer(_ answer: String, for id: String) {
        answers[id] = String(answer.prefix(256))
        saveLocalDraft()
        saveRevision += 1
    }

    private func answerBinding(_ id: String) -> Binding<String> {
        Binding(
            get: { answers[id] ?? "" },
            set: { setAnswer($0, for: id) })
    }

    private func draftKey(_ attemptId: String) -> String {
        DataScope.defaultsKey("matths.placement.draft.\(attemptId)", for: accountSlot)
    }

    private func saveLocalDraft() {
        guard let id = attempt?.id,
              let data = try? JSONEncoder().encode(answers) else { return }
        UserDefaults.standard.set(data, forKey: draftKey(id))
    }

    private func loadLocalDraft(attemptId: String) -> [String: String] {
        guard let data = UserDefaults.standard.data(forKey: draftKey(attemptId)),
              let value = try? JSONDecoder().decode([String: String].self, from: data) else { return [:] }
        return value
    }

    private func clearLocalDraft(attemptId: String) {
        UserDefaults.standard.removeObject(forKey: draftKey(attemptId))
    }

    private static func parseDate(_ raw: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: raw) ?? ISO8601DateFormatter().date(from: raw)
    }

    private static func clockText(_ seconds: Int) -> String {
        let value = max(0, seconds)
        return String(format: "%02d:%02d:%02d", value / 3600, (value % 3600) / 60, value % 60)
    }

    private static func clockAccessibility(_ seconds: Int) -> String {
        let value = max(0, seconds)
        return "\(value / 3600)시간 \((value % 3600) / 60)분 \(value % 60)초"
    }

    private static func scoreText(_ value: Double) -> String {
        value.rounded() == value ? String(Int(value)) : String(format: "%.1f", value)
    }

    private static func message(for error: Error) -> String {
        if let api = error as? ServerAPIError { return api.errorDescription ?? "서버 요청을 확인해 주세요." }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return "인터넷 연결이 끊겼습니다. 답안은 이 기기에 보관됩니다."
            case .timedOut:
                return "서버 응답이 늦어지고 있습니다. 잠시 후 다시 시도해 주세요."
            default: break
            }
        }
        return "서버와 연결하지 못했습니다. 잠시 후 다시 시도해 주세요."
    }
}
