//  AssessmentPaperScreen.swift
//  Matths
//
//  시험지 단위 응시 — 웹 assessment-attempt 의 앱판.
//  전 문항을 한 웹뷰(paper.html)에 렌더하고, 순서 무관하게 답한 뒤 마지막에 제출한다.
//  제출 후 같은 화면이 리뷰 모드가 되어 정오·정답·해설을 공개한다 (시험지 트랙의 계약).
//  40문항짜리 종합평가도 웹뷰 하나라 무겁지 않다 — 문항마다 웹뷰를 만들면 안 된다.

import SwiftUI
import WebKit
import PencilKit

struct AssessmentPaperScreen: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @StateObject private var timer = ExamTimer()
    @State private var paperHeight: CGFloat = 600
    @State private var confirmSubmit = false
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var scratchpad = AssessmentScratchpadModel()
    @State private var scratchTool: SolutionCanvasTool = .pen
    @State private var scratchFinger = UIDevice.current.userInterfaceIdiom == .phone
    @State private var showsScratchpad = false
    @State private var showsLegacyReview = false

    var body: some View {
        VStack(spacing: 0) {
            header

            if let attempt = store.currentAttempt {
                if attempt.hasLegacyDraftEvidence {
                    Button("보관된 기기 답안 확인") { showsLegacyReview = true }
                        .buttonStyle(SecondaryButtonStyle()).padding(Tokens.Space.s3)
                }
                GeometryReader { viewport in
                    if UniversalLayoutPolicy.usesProblemSplit(width: viewport.size.width, height: viewport.size.height, accessibilityText: typeSize.isAccessibilitySize) {
                        ResponsiveProblemWorkspace(spacing: Tokens.Space.s3) {
                            paperDocument(attempt)
                            scratchpadPanel(height: max(120, viewport.size.height - 120))
                                .padding(Tokens.Space.s3)
                        }
                    } else {
                        paperDocument(attempt)
                            .safeAreaInset(edge: .bottom) {
                                Button("풀이 메모 열기") { showsScratchpad = true }
                                    .buttonStyle(SecondaryButtonStyle()).padding(Tokens.Space.s3)
                            }
                    }
                }
            } else {
                VStack(spacing: Tokens.Space.s4) {
                    Image(systemName: "doc.questionmark")
                        .font(.system(size: 42, weight: .medium))
                        .foregroundStyle(Tokens.text4)
                        .accessibilityHidden(true)
                    Text("응시 정보를 찾을 수 없습니다")
                        .font(.mHeading)
                        .foregroundStyle(Tokens.ink)
                        .accessibilityAddTraits(.isHeader)
                    Text("다른 기기에서 종료됐거나 저장된 응시 정보가 갱신됐을 수 있습니다.")
                        .font(.mCallout)
                        .foregroundStyle(Tokens.text2)
                        .multilineTextAlignment(.center)
                    Button(returnLabel, action: closePaper)
                        .buttonStyle(PrimaryButtonStyle())
                        .frame(maxWidth: 280)
                }
                .padding(Tokens.Space.s6)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Tokens.paper)
        .onAppear { syncTimerState() }
        .task(id: store.currentAttemptID) {
            if let id = store.currentAttemptID {
                await scratchpad.open(attemptID: id, store: store)
                #if DEBUG
                scratchpad.seedIfRequested()
                #endif
            }
        }
        .onChange(of: scenePhase) { _, value in if value != .active { Task { _ = await scratchpad.flush() } } }
        .onDisappear { Task { _ = await scratchpad.flush() } }
        .sheet(isPresented: $showsLegacyReview) {
            if let id = store.currentAttemptID, let owner = AccountRequestOwner(store: store) {
                LegacyAssessmentDraftReviewScreen(attemptID: id, owner: owner)
            }
        }
        .fullScreenCover(isPresented: $showsScratchpad) {
            NavigationStack {
                GeometryReader { viewport in
                    ScrollView {
                        scratchpadPanel(height: max(140, viewport.size.height - (typeSize.isAccessibilitySize ? 260 : 130)))
                            .padding(Tokens.Space.s3)
                    }.scrollBounceBehavior(.basedOnSize)
                }
                    .navigationTitle("풀이 메모").navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("저장하고 닫기") {
                        Task { if await scratchpad.flush() { showsScratchpad = false } }
                    } } }
            }
        }
        .onChange(of: hasActiveAttempt) { _, _ in syncTimerState() }
        // 시간이 다 되면 **자동 제출**한다. 화면을 켜 둔 채 방치해도 실격 처리된다.
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            guard let a = store.currentAttempt, a.submittedAt == nil else { return }
            if a.remainingSeconds(monotonicElapsed: Double(timer.elapsedSeconds)) <= 0,
               !a.hasLegacyDraftEvidence, !a.isServerCancelled,
               store.assessmentSubmissionState.permitsAutomaticAttempt(a.id) { submit() }
        }
        .alert("아직 답하지 않은 문항이 있습니다. 제출할까요?",
               isPresented: $confirmSubmit) {
            Button("제출", role: .destructive) { submit() }
            Button("계속 풀기", role: .cancel) {}
        } message: {
            Text("답하지 않은 문항은 오답으로 처리됩니다. 제출은 한 번만 할 수 있습니다.")
        }
        .alert("평가 기록을 동기화하지 못했습니다", isPresented: Binding(
            get: { store.assessmentSyncError != nil },
            set: { if !$0 { store.assessmentSyncError = nil } }
        )) {
            if case .recovery = store.assessmentSubmissionState {
                Button("서버 상태 다시 확인") { Task { await store.pullServerAssessments() } }
            }
            Button("확인", role: .cancel) {}
        } message: {
            Text(store.assessmentSyncError ?? "")
        }
    }

    private func paperDocument(_ attempt: AssessmentAttemptV2) -> some View {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: Tokens.Space.s5) {
                            Color.clear
                                .frame(height: 0)
                                .id(Self.paperTopAnchor)
                                .accessibilityHidden(true)
                            if attempt.submittedAt != nil {
                                resultCard(attempt)
                            }
                            PaperWebView(attempt: attempt, height: $paperHeight)
                                .frame(height: paperHeight)
                                .id("\(attempt.id)-\(attempt.submittedAt != nil ? "review" : "take")")

                            if attempt.submittedAt == nil {
                                submitRow(attempt)
                            } else {
                                Button(returnLabel, action: closePaper)
                                    .buttonStyle(PrimaryButtonStyle())
                                    .frame(maxWidth: 280)
                            }
                        }
                        .padding(Tokens.Space.s6)
                        .readableWidth()
                        .frame(maxWidth: .infinity)
                    }
                    // 제출 버튼은 문서 맨 아래에 있다. 리뷰 모드로 바뀔 때 그 위치를
                    // 유지하면 학생은 점수 카드가 아니라 3~5번 해설 중간부터 보게 된다.
                    .onChange(of: attempt.submittedAt) { previous, submittedAt in
                        guard previous == nil, submittedAt != nil else { return }
                        proxy.scrollTo(Self.paperTopAnchor, anchor: .top)
                    }
                }
    }

    private func scratchpadPanel(height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
            Text("평가 메모 · 이 기기에 자동 저장").font(.mCaption).foregroundStyle(Tokens.text2)
            if let error = scratchpad.error { Text(error).font(.mCaption).foregroundStyle(Tokens.dangerInk) }
            QuickSolutionNote(drawing: $scratchpad.drawing, tool: $scratchTool, allowsFinger: $scratchFinger,
                              height: height, toolbarTitle: "풀이 메모", showsToolTitles: false,
                              showsFingerToggle: UIDevice.current.userInterfaceIdiom == .pad,
                              showsHelper: height >= 240, canUndo: !scratchpad.undoStack.isEmpty,
                              onUndo: { scratchpad.undo() },
                              helperText: "메모는 채점에 제출되지 않습니다. 문제지로 돌아가 답안을 입력해 주세요.")
        }
    }

    private var header: some View {
        HStack(spacing: Tokens.Space.s4) {
            Button(action: closePaper) {
                Image(systemName: "xmark").font(.mBodyB).foregroundStyle(Tokens.text3)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(returnLabel)

            VStack(alignment: .leading, spacing: 1) {
                Text(store.currentAttempt?.title ?? "평가").font(.mBodyB).foregroundStyle(Tokens.ink)
                if let a = store.currentAttempt {
                    Text("\(a.questions.count)문항, 균등 배점 100점, \(AssessCatalog.data.passScore)점 통과")
                        .font(.mMicro).foregroundStyle(Tokens.text3)
                }
            }
            Spacer()
            if let a = store.currentAttempt, a.submittedAt == nil {
                Text("응답 \(answeredCount(a)) / \(a.questions.count)")
                    .font(.mNumeric).foregroundStyle(Tokens.text2)
            }
            if let a = store.currentAttempt, a.submittedAt == nil {
                HStack(spacing: 2) {
                    if timer.isRunning {
                        Circle().fill(Tokens.danger).frame(width: 6, height: 6).padding(.trailing, 4)
                    }
                    // **남은 시간**을 보여 준다. 경과 시간만 보여 주면 학생은 언제
                    // 끝나는지 알 수 없고, 실격을 예고 없이 맞게 된다.
                    let left = max(0, a.remainingSeconds(monotonicElapsed: Double(timer.elapsedSeconds)))
                    Text(String(format: "%d:%02d", left / 60, left % 60))
                        .font(.mNumeric).monospacedDigit()
                        .foregroundStyle(left <= 60 ? Tokens.danger : Tokens.ink)
                }
            } else if store.currentAttempt?.submittedAt != nil {
                Label("제출 완료", systemImage: "checkmark.circle.fill")
                    .font(.mCaption)
                    .foregroundStyle(Tokens.success)
            }
            // iPhone 가로에서는 시험지가 여러 화면 높이로 이어진다. 제출 버튼을
            // 문서 맨 아래에만 두면 40문항을 푼 뒤 다시 끝까지 내려야 하므로,
            // 고정 헤더에도 같은 제출 동선을 제공한다. 세로·큰 화면은 기존 하단
            // 설명과 CTA를 유지해 헤더 밀도를 높이지 않는다.
            if verticalSizeClass == .compact,
               let a = store.currentAttempt,
               a.submittedAt == nil {
                Button(store.assessmentSubmitting ? "제출 중" : "제출") {
                    requestSubmit(a)
                }
                .font(.mCaption)
                .foregroundStyle(answeredCount(a) == 0 ? Tokens.text4 : Tokens.onBrand)
                .frame(minWidth: 64, minHeight: 44)
                .background(
                    answeredCount(a) == 0 ? Tokens.line : Tokens.actionPrimary,
                    in: RoundedRectangle(cornerRadius: Tokens.Radius.sm)
                )
                .disabled(answeredCount(a) == 0 || store.assessmentSubmitting)
                .accessibilityLabel(store.assessmentSubmitting ? "평가 제출 중" : "평가 제출")
                .accessibilityHint("현재 \(answeredCount(a))개 문항에 응답했습니다.")
            }
        }
        .padding(.horizontal, Tokens.Space.s4)
        .padding(.vertical, Tokens.Space.s2)
        .background(Tokens.surface)
        .overlay(alignment: .bottom) { Divider().overlay(Tokens.line) }
    }

    private var returnLabel: String {
        store.assessmentReturnRoute == .curriculum ? "과목 학습으로 돌아가기" : "평가센터로 돌아가기"
    }

    private func closePaper() {
        let account = store.captureAccountSessionBoundary()
        let attemptID = store.currentAttemptID
        let destination = store.assessmentReturnRoute
        Task {
            // Save before leaving, and never let a late close from the previous
            // student or previous paper navigate the current screen away.
            if attemptID != nil {
                guard await scratchpad.flush() else { return }
                guard store.ownsCurrentAccountSession(account), store.currentAttemptID == attemptID,
                      store.route == .paper else { return }
                await store.flushAssessmentDraft()
            }
            guard store.ownsCurrentAccountSession(account), store.currentAttemptID == attemptID,
                  store.route == .paper else { return }
            store.route = destination
        }
    }

    private func answeredCount(_ a: AssessmentAttemptV2) -> Int {
        a.answers.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count
    }

    private var hasActiveAttempt: Bool {
        guard let attempt = store.currentAttempt else { return false }
        return attempt.submittedAt == nil
    }

    private static let paperTopAnchor = "assessment-paper-top"

    private func syncTimerState() {
        if hasActiveAttempt {
            timer.start()
        } else {
            timer.pause()
        }
    }

    @ViewBuilder private func submitRow(_ attempt: AssessmentAttemptV2) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
            Button("제출하고 채점받기") {
                requestSubmit(attempt)
            }
            .buttonStyle(PrimaryButtonStyle())
            .frame(maxWidth: 280)
            .disabled(answeredCount(attempt) == 0 || store.assessmentSubmitting)
            Text("제출은 한 번만 됩니다. 제출 후 정답과 해설이 공개되고, 틀린 문항은 오답노트로 갑니다.")
                .font(.mCaption).foregroundStyle(Tokens.text3)
        }
    }

    private func submit() {
        timer.pause()
        // 기록은 표시용 초가 아니라 정밀 경과로 남긴다.
        store.submitPaper(monotonicElapsed: Double(timer.exactElapsedMs()) / 1000)
    }

    private func requestSubmit(_ attempt: AssessmentAttemptV2) {
        if answeredCount(attempt) < attempt.questions.count {
            confirmSubmit = true
        } else {
            submit()
        }
    }

    private func resultCard(_ a: AssessmentAttemptV2) -> some View {
        let score = a.scorePercent ?? 0
        let passed = a.passed == true
        return VStack(alignment: .leading, spacing: Tokens.Space.s3) {
            // 시간 초과 실격은 **점수가 아니라 사유**를 먼저 말한다.
            // 0점만 보여 주면 학생은 다 틀린 줄 안다.
            if a.disqualified == true {
                Label("시간 초과로 실격 처리", systemImage: "clock.badge.xmark")
                    .font(.mBodyB).foregroundStyle(Tokens.danger)
                Text("제한 시간 안에 제출하지 못해 0점으로 기록됩니다. 웹 평가와 같은 규칙입니다.")
                    .font(.mCaption).foregroundStyle(Tokens.text3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(alignment: .lastTextBaseline, spacing: Tokens.Space.s3) {
                Text("\(score)")
                    .font(.mStatLarge)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .foregroundStyle(passed ? Tokens.success : Tokens.danger)
                Text("/ 100점").font(.mCaption).foregroundStyle(Tokens.text3)
                Text(passed ? "통과" : "재응시")
                    .font(.mMicro).foregroundStyle(passed ? Tokens.success : Tokens.danger)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .overlay(Capsule().strokeBorder(passed ? Tokens.success : Tokens.danger, lineWidth: 1))
                Spacer()
                Text("\(AssessCatalog.grade(for: score))등급 구간")
                    .font(.mCaption).foregroundStyle(Tokens.text2)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                "\(score) / 100점, \(passed ? "통과" : "재응시"), "
                + "\(AssessCatalog.grade(for: score))등급 구간")
            Text(passed
                 ? "\(AssessCatalog.data.passScore)점 이상입니다. 다음 단계 평가가 열립니다."
                 : "\(AssessCatalog.data.passScore)점 미만입니다. 아래 해설을 확인하고 새 회차로 재응시하세요. 수치와 발문은 매회 바뀝니다.")
                .font(.mCallout).foregroundStyle(Tokens.text2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}

// MARK: - 시험지 웹뷰 (한 장에 전 문항)

struct PaperWebView: UIViewRepresentable {
    let attempt: AssessmentAttemptV2
    @Binding var height: CGFloat
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(WebMotion.preferenceKey) private var userMotionEnabled = true

    func makeCoordinator() -> Coordinator { Coordinator(height: $height) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.addUserScript(WKUserScript(
            source: Self.payloadJS(
                attempt: attempt,
                compactHeight: verticalSizeClass == .compact),
            injectionTime: .atDocumentStart, forMainFrameOnly: true))
        config.userContentController.addUserScript(WKUserScript(
            source: WebContentAccessibility.bootstrapScript(
                size: dynamicTypeSize,
                reduceMotion: reduceMotion,
                userMotionEnabled: userMotionEnabled),
            injectionTime: .atDocumentStart, forMainFrameOnly: true))
        config.userContentController.add(context.coordinator, name: "paperAnswer")
        config.userContentController.add(context.coordinator, name: "paperHeight")

        let web = WKWebView(frame: .zero, configuration: config)
        web.isOpaque = false
        web.backgroundColor = .clear
        WebContentAccessibility.configure(web)
        if let url = Self.htmlURL {
            web.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
        return web
    }

    func updateUIView(_ web: WKWebView, context: Context) {
        WebContentAccessibility.update(
            web,
            size: dynamicTypeSize,
            reduceMotion: reduceMotion,
            userMotionEnabled: userMotionEnabled)
        let compactHeight = verticalSizeClass == .compact ? "true" : "false"
        web.evaluateJavaScript(
            "window.MATTHS_APPLY_PAPER_LAYOUT && window.MATTHS_APPLY_PAPER_LAYOUT(\(compactHeight));")
    }

    static func dismantleUIView(_ web: WKWebView, coordinator: Coordinator) {
        web.stopLoading()
        let controller = web.configuration.userContentController
        controller.removeScriptMessageHandler(forName: "paperAnswer")
        controller.removeScriptMessageHandler(forName: "paperHeight")
    }

    static let htmlURL: URL? =
        Bundle.main.url(forResource: "paper", withExtension: "html", subdirectory: "LessonWeb")
        ?? Bundle.main.url(forResource: "paper", withExtension: "html")

    private static func payloadJS(attempt: AssessmentAttemptV2, compactHeight: Bool) -> String {
        let review = attempt.submittedAt != nil
        let verdicts = review
            ? PaperFactory.grade(questions: attempt.questions, answers: attempt.answers).verdicts
            : []
        let keys = ["a", "b", "c", "d", "e"]
        let questions: [[String: Any]] = attempt.questions.enumerated().map { i, q in
            var d: [String: Any] = ["no": q.no, "prompt": q.prompt, "points": q.points]
            if let choices = q.choices { d["choices"] = choices }
            let picked = i < attempt.answers.count ? attempt.answers[i] : ""
            if !picked.isEmpty { d["picked"] = picked }
            if review {
                d["answer"] = q.answer
                d["correct"] = verdicts.indices.contains(i) ? verdicts[i] : false
                d["solution"] = q.solution
                if q.choices != nil, let idx = keys.firstIndex(of: q.answer) {
                    d["answerText"] = "\(idx + 1)번"
                } else {
                    d["answerText"] = q.answer
                }
            }
            return d
        }
        let payload: [String: Any] = ["mode": review ? "review" : "take", "questions": questions]
        let json = (try? JSONSerialization.data(withJSONObject: payload))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        return "window.MATTHS_PAPER = \(json); window.MATTHS_PAPER_COMPACT_HEIGHT = \(compactHeight ? "true" : "false");"
    }

    final class Coordinator: NSObject, WKScriptMessageHandler {
        @Binding var height: CGFloat
        init(height: Binding<CGFloat>) { _height = height }

        func userContentController(_ controller: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            switch message.name {
            case "paperAnswer":
                if let body = message.body as? [String: Any],
                   let no = body["no"] as? Int, let value = body["value"] as? String {
                    // 스토어에 직접 반영 — 코디네이터는 뷰 계층 밖이라 알림 센터 대신
                    // 메인 큐에서 앱스토어 싱글 경로를 태운다
                    DispatchQueue.main.async {
                        AppStoreLocator.shared?.setPaperAnswer(no: no, value: value)
                    }
                }
            case "paperHeight":
                if let h = message.body as? Double {
                    let clamped = max(200, min(CGFloat(h) + 8, 60_000))
                    if abs(clamped - height) > 8 {
                        DispatchQueue.main.async { self.height = clamped }
                    }
                }
            default: break
            }
        }
    }
}

/// PaperWebView 코디네이터가 스토어에 닿기 위한 최소 로케이터.
/// (UIViewRepresentable 코디네이터에는 @EnvironmentObject 가 흐르지 않는다 —
///  DebugBar 명시 주입과 같은 계열의 함정. RootView 가 onAppear 에서 등록한다.)
@MainActor
enum AppStoreLocator {
    static weak var shared: AppStore?
}
