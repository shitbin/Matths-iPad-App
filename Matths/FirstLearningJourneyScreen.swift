import SwiftUI
import CryptoKit

extension Notification.Name {
    static let matthsResumeFirstLearning = Notification.Name("kr.matths.resume-first-learning")
}

struct FirstSuccessOnboardingOverlay: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ObservedObject private var model = FirstLearningJourneyStore.shared
    @State private var presented = false
    @State private var paused = false
    @State private var working = false
    @State private var message: String?
    @State private var work: Task<Void, Never>?
    @State private var pendingPractice: (problems: [GeneratedProblem], seed: UInt64, conceptID: String)?
    @State private var restartConfirmation = false
    @State private var showsGuidedStart = false
    @State private var onboardingViewport: CGSize = .zero
    private var compactHeight: Bool {
        UniversalLayoutPolicy.usesCompactOnboardingChoices(width: onboardingViewport.width,
            height: onboardingViewport.height, accessibilityText: dynamicTypeSize.isAccessibilitySize)
    }
    private var stageTitleFont: Font { compactHeight ? .mHeading : .mTitle }
    private var ownerTrigger: String {
        FirstLearningProfileReadiness.trigger(slot: DataScope.slot, authProvider: store.authProvider,
            role: store.serverProfile?.role, tutorialStatus: store.serverProfile?.dashboardTutorial?.status,
            shouldAutoStart: store.serverProfile?.dashboardTutorial?.shouldAutoStart)
    }
    private var concept: ConceptV2? { model.journey.conceptID.flatMap { CurriculumV2.concept($0)?.2 } }
    private var mayShow: Bool {
        store.authProvider == "server" && !["teacher", "admin"].contains(store.serverProfile?.role ?? "student")
            && !store.isSessionMode && !store.hasPendingAssessmentAuthentication && !store.requestedDashboardTutorial && !paused
            && store.nativeTutorialPresentationOwner == nil
    }
    var body: some View {
        Color.clear.allowsHitTesting(false)
            .task(id: ownerTrigger) {
                work?.cancel(); endOwnedPresentation()
                paused = false; message = nil; pendingPractice = nil
                recordPresentationDiagnostic("owner_task_started")
                let owner = store.captureAccountSessionBoundary()
                if FirstLearningProfileReadiness.needsHydration(authProvider: store.authProvider,
                    tutorialStatus: store.serverProfile?.dashboardTutorial?.status,
                    shouldAutoStart: store.serverProfile?.dashboardTutorial?.shouldAutoStart) {
                    // /auth/login's small user object does not include tutorial
                    // preferences. Root launch refresh may already have finished
                    // before login; hydrate the shared profile before deciding.
                    await store.refreshServerProfile()
                }
                guard !Task.isCancelled, store.ownsCurrentAccountSession(owner) else { return }
                recordPresentationDiagnostic("profile_checked")
                await model.synchronize()
                guard !Task.isCancelled, store.ownsCurrentAccountSession(owner) else { return }
                if model.journey.pendingTutorialAction != nil && model.remoteConflict == nil { saveTutorialReceipt() }
                else { presentIfNeeded() }
            }
            .onChange(of: store.route) { _, _ in presentIfNeeded() }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                Task { await model.synchronize(); presentIfNeeded() }
            }
            .onChange(of: model.remoteConflict) { _, value in
                if value == nil, model.journey.pendingTutorialAction != nil { saveTutorialReceipt() }
                else { presentIfNeeded() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .matthsResumeFirstLearning)) { _ in
                paused = false
                if model.journey.isTerminal { restartJourney() }
                presentIfNeeded(manual: true)
            }
            .fullScreenCover(isPresented: $presented, onDismiss: launchPreparedPractice) { content }
            .onDisappear {
                work?.cancel()
                // A student overlay can be removed when a just-loaded profile
                // identifies the next account as staff. It must release its own
                // presentation flag or the visible workspace stays AX-hidden.
                endOwnedPresentation()
            }
    }
    /// Profile hydration can restart this task while a native tour has just
    /// acquired the shared presentation lease. A non-presented first-learning
    /// view owns nothing and must not clear another overlay's flag.
    private func endOwnedPresentation() {
        let ownedPresentation = presented
        presented = false
        if ownedPresentation, store.nativeTutorialPresentationOwner == nil {
            store.isTutorialPresentationActive = false
        }
    }
    private var content: some View {
        NavigationStack {
            GeometryReader { viewport in
            ScrollView {
                VStack(alignment: .leading, spacing: compactHeight ? Tokens.Space.s2 : Tokens.Space.s5) {
                    Text(stageCaption).font(.mCaption).foregroundStyle(Tokens.actionPrimary)
                    if let conflict = model.remoteConflict {
                        Text("어느 기록에서 이어갈까요?").font(.mTitle)
                        Text("다른 기기에서 첫 학습이 변경됐습니다. 선택 전에는 서로 덮어쓰지 않습니다. 이 기기의 원본도 별도로 보관합니다.")
                            .font(.mBody).foregroundStyle(Tokens.text2)
                        Text(conflict.state == nil ? "계정에서는 첫 학습 안내가 종료되거나 다시 시작되었습니다." : "계정의 저장 단계: \(remoteStageTitle(conflict.state?.stage))")
                            .font(.mCallout)
                        Button("계정의 최신 기록 사용") { model.useRemoteJourney() }
                            .buttonStyle(PrimaryButtonStyle()).disabled(working || model.isSyncing)
                        Button("이 기기의 진행으로 계속") { work = Task { await model.keepLocalJourney() } }
                            .buttonStyle(SecondaryButtonStyle()).disabled(working || model.isSyncing)
                    } else { stageContent }
                    if let text = model.error ?? message {
                        Text(text).font(.mCallout).foregroundStyle(Tokens.dangerInk).fixedSize(horizontal: false, vertical: true)
                    }
                    if let text = model.syncMessage, model.remoteConflict == nil {
                        Text(text).font(.mCaption).foregroundStyle(Tokens.text2)
                        if model.remoteCacheBlocked {
                            Button("기존 기록 보관 후 이어하기 복구") { Task { await model.recoverRemoteCache() } }.disabled(model.isSyncing)
                        } else if model.remoteSyncNeedsRetry {
                            Button("이어하기 동기화 다시 확인") { Task { await model.synchronize() } }.disabled(model.isSyncing)
                        }
                    }
                    if working { ProgressView("학습 기록을 확인하고 있어요") }
                }
                .padding(.horizontal, Tokens.Space.s5)
                .padding(.vertical, compactHeight ? Tokens.Space.s2 : Tokens.Space.s5)
                .frame(maxWidth: 680, alignment: .leading).frame(maxWidth: .infinity)
            }
            .onAppear { onboardingViewport = viewport.size }
            .onChange(of: viewport.size) { _, size in onboardingViewport = size }
            }
            .navigationTitle("첫 학습").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("나중에 계속") { deferJourney() } }
                ToolbarItem(placement: .confirmationAction) {
                    Menu {
                        Button("처음부터 다시") { restartConfirmation = true }
                        Button("첫 학습 건너뛰기") { skip() }
                    } label: { Image(systemName: "ellipsis").frame(width: 44, height: 44) }.disabled(working || model.remoteConflict != nil)
                }
            }
            .confirmationDialog("첫 학습을 처음부터 시작할까요?", isPresented: $restartConfirmation) {
                Button("처음부터 시작") { restartJourney(); message = nil }
            } message: { Text("기존 학습 진도와 오답은 그대로 유지됩니다. 첫 학습 안내의 진행 단계만 다시 시작합니다.") }
            .interactiveDismissDisabled()
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if !model.journey.isTerminal && model.journey.stage != .result && model.remoteConflict == nil {
                    HStack {
                        Button("건너뛰기") { skip() }.font(.mCallout).frame(minHeight: 44)
                        Spacer()
                        Text("학습 기록은 유지됩니다").font(.mCaption).foregroundStyle(Tokens.text2)
                    }.padding(.horizontal, Tokens.Space.s5).background(Tokens.surface)
                }
            }
        }
        .onAppear { recordPresentationDiagnostic("content_appeared") }
        .task(id: model.journey.stage) {
            guard model.remoteConflict == nil else { return }
            if model.journey.stage == .lesson, model.journey.conceptID == nil { await prepareLesson() }
            if model.journey.stage == .awaitingSync { await confirmLearningReceipt() }
        }
    }
    private func remoteStageTitle(_ stage: String?) -> String {
        switch stage {
        case "goal": "공부 목표"
        case "diagnosis": "현재 위치 확인"
        case "lesson": "개념 학습"
        case "checks": "확인 문제"
        case "awaitingSync", "result", "completed": "풀이 결과 확인"
        case "skipped": "안내 건너뛰기"
        default: "첫 학습"
        }
    }
    private var stageCaption: String {
        switch model.journey.stage {
        case .goal: "시작 방법 선택"
        case .diagnosis: "2 / 4 · 가볍게 현재 위치 확인"
        case .lesson: "3 / 4 · 개념 하나 이해하기"
        case .checks: "4 / 4 · 확인 문제 3개"
        case .awaitingSync, .result, .completed: "첫 학습 결과"
        case .skipped: "첫 학습"
        }
    }
    @ViewBuilder private var stageContent: some View {
        switch model.journey.stage {
        case .goal:
            Text("원하는 과목부터 골라볼까요?").font(stageTitleFont)
            Text("과목과 단원을 고르면 개념 설명을 보고 바로 문제를 풀 수 있어요.")
                .font(.mBody).foregroundStyle(Tokens.text2)
            Button("과목 고르고 시작하기") { browseCoursesWithoutGuide() }
                .buttonStyle(PrimaryButtonStyle()).disabled(working || model.isSyncing)
                .accessibilityIdentifier("first-learning-browse-courses")
            Text("앱 사용 안내는 프로필과 설정에서 언제든 다시 볼 수 있어요.")
                .font(.mCaption).foregroundStyle(Tokens.text2)
            DisclosureGroup("안내를 따라 첫 학습 해보기", isExpanded: $showsGuidedStart) {
                Text("목표를 고르고, 개념 하나와 확인 문제 3개로 사용법을 익힙니다.")
                    .font(.mCallout).foregroundStyle(Tokens.text2)
                    .padding(.vertical, Tokens.Space.s2)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Tokens.Space.s2), count: compactHeight ? 2 : 1), spacing: Tokens.Space.s2) {
                    ForEach(LearningGoal.allCases) { goal in
                        Button {
                            if model.update({ $0.selectGoal(goal) }) { model.setGoal(goal) }
                        } label: { Text(goal.title).frame(maxWidth: .infinity, minHeight: 24) }
                        .buttonStyle(SecondaryButtonStyle())
                    }
                }
            }.font(.mBodyB)
        case .diagnosis:
            let first = model.journey.diagnosticAnswers.isEmpty
            Text(first ? "규칙을 적용해 볼까요?" : "거꾸로 생각해 볼까요?").font(stageTitleFont)
            Text(first ? "f(x) = 2x + 1일 때, f(3)은 얼마인가요?" : "2x + 1 = 7일 때, x는 얼마인가요?").font(.mBodyB)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Tokens.Space.s2), count: compactHeight ? 3 : 1), spacing: Tokens.Space.s2) {
                ForEach(first ? [6, 7, 8] : [2, 3, 4], id: \.self) { value in
                    Button { model.update { $0.answerDiagnosis(value) } } label: {
                        Text("\(value)").frame(maxWidth: .infinity, minHeight: 24)
                    }.buttonStyle(SecondaryButtonStyle())
                }
            }
            Text("이 두 문항은 설명의 자세함을 고르는 용도예요. 공식 점수·진도·배치에는 반영하지 않습니다.").font(.mCaption).foregroundStyle(Tokens.text2)
        case .lesson:
            lessonContent
        case .checks:
            Text("확인 문제를 이어 풀어요").font(.mTitle)
            Text("\(model.journey.answeredCount) / 3문항을 풀었어요. 이미 제출한 문항은 다시 제출하지 않습니다.").font(.mBody)
            Button("남은 문제 이어 풀기") { beginChecks() }.buttonStyle(PrimaryButtonStyle()).disabled(working)
        case .awaitingSync:
            Text("3문제 풀이를 마쳤어요").font(.mTitle)
            Text("정답 \(model.journey.correctCount)개 · 풀이 기록을 저장했습니다.").font(.mBodyB)
            Text("계정의 학습 기록과 진도를 확인 중입니다. 연결이 복구되면 이 단계에서 이어갑니다.").font(.mCallout).foregroundStyle(Tokens.text2)
            Button("기록 다시 확인") { work = Task { await confirmLearningReceipt() } }.buttonStyle(PrimaryButtonStyle()).disabled(working)
        case .result:
            Text("첫 학습을 마쳤어요").font(.mTitle)
            Text("개념 1개를 읽고 3문제를 풀었어요. 정답은 \(model.journey.correctCount)개예요.").font(.mBodyB)
            if let progress = model.journey.confirmedProgress { Text("계정에서 확인한 이 개념의 진도: \(progress)%").font(.mCallout) }
            Text(model.journey.correctCount < 3 ? "틀린 문제는 오답에 보관했어요. 오늘의 복습에서 다시 풀어볼 수 있습니다." : "이제 오늘 화면에서 다음 학습을 이어가세요.").font(.mBody).foregroundStyle(Tokens.text2)
            Button("오늘의 다음 학습 보기") { complete() }.buttonStyle(PrimaryButtonStyle()).disabled(working)
        case .completed, .skipped:
            Text(model.journey.pendingTutorialAction == nil ? "첫 학습 안내를 마쳤습니다" : "학습 안내를 저장하고 있어요").font(.mTitle)
            Button("오늘로 가기") { deferJourney() }.buttonStyle(PrimaryButtonStyle())
        }
    }
    @ViewBuilder private var lessonContent: some View {
        if let concept {
            MathInline(text: concept.title, font: .mTitle, pixelSize: 28)
            MathInline(text: concept.lesson?.summary ?? concept.achievementStandard ?? concept.title, font: .mBody)
            if model.journey.diagnosticCorrectCount < 2 {
                Text("풀이 순서를 하나씩 확인하며 시작해요. 설명을 펼쳐보고, 문제를 틀리면 해설을 확인할 수 있어요.").font(.mCallout).foregroundStyle(Tokens.text2)
                if let lesson = concept.lesson {
                    ForEach(Array(lesson.steps.enumerated()), id: \.offset) { _, step in
                        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                            MathInline(text: step.title, font: .mBodyB)
                            MathInline(text: step.description, font: .mBody)
                        }
                    }
                }
            } else if let lesson = concept.lesson {
                ForEach(Array(lesson.steps.enumerated()), id: \.offset) { _, step in
                    DisclosureGroup {
                        MathInline(text: step.description, font: .mBody).padding(.top, Tokens.Space.s2)
                    } label: { MathInline(text: step.title, font: .mBodyB) }
                }
            }
            if let lesson = concept.lesson { MathInline(text: lesson.keyTakeaway, font: .mBodyB).padding(Tokens.Space.s4).background(Tokens.surface) }
            if !concept.topics.isEmpty {
                Text("확인할 핵심").font(.mBodyB)
                ForEach(Array(concept.topics.enumerated()), id: \.offset) { _, topic in MathInline(text: "· " + topic) }
            }
            Button("개념을 읽었어요 · 3문제 풀기") { beginChecks() }.buttonStyle(PrimaryButtonStyle()).disabled(working)
            Text("실제 과정의 문제입니다. 풀이 기록은 계정에 저장되지만, 3문제를 풀었다고 개념 완료나 평가 합격으로 처리하지는 않아요.").font(.mCaption).foregroundStyle(Tokens.text2)
        } else {
            Text("첫 수업을 준비하고 있어요").font(.mTitle)
            Button("다시 확인") { work = Task { await prepareLesson() } }.buttonStyle(PrimaryButtonStyle()).disabled(working)
            Text("연결이 어렵다면 나중에 계속을 누르고, 학습의 오프라인 연습을 이용할 수 있어요.").font(.mCallout).foregroundStyle(Tokens.text2)
        }
    }
    private func presentIfNeeded(manual: Bool = false) {
        recordPresentationDiagnostic("presentation_checked")
        let fixture: Bool
        #if DEBUG
        fixture = DemoMode.isOn && ProcessInfo.processInfo.arguments.contains("-firstLearningJourneyFixture")
        #else
        fixture = false
        #endif
        guard mayShow, !presented, !model.journey.isTerminal || model.remoteConflict != nil,
              manual || fixture || model.remoteConflict != nil || store.serverProfile?.dashboardTutorial?.shouldAutoStart == true || model.journey.learningStartedAt != nil else { return }
        store.isTutorialPresentationActive = true; presented = true
        recordPresentationDiagnostic("presentation_requested")
    }
    private func recordPresentationDiagnostic(_ checkpoint: String) {
        #if DEBUG
        guard ProcessInfo.processInfo.arguments.contains("-firstLearningJourneyFixture"), model.journey.slot == DataScope.slot else { return }
        let value: [String: Any] = ["checkpoint": checkpoint, "authenticated": store.authProvider == "server",
            "profileHasTutorial": store.serverProfile?.dashboardTutorial != nil,
            "serverShouldAutoStart": store.serverProfile?.dashboardTutorial?.shouldAutoStart == true,
            "staff": ["teacher", "admin"].contains(store.serverProfile?.role ?? "student"),
            "sessionMode": store.isSessionMode, "explicitDashboardTour": store.requestedDashboardTutorial,
            "paused": paused, "presented": presented, "stage": model.journey.stage.rawValue,
            "hasConflict": model.remoteConflict != nil]
        if let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]) {
            try? data.write(to: DataScope.url("first-learning-presentation-diagnostic.json"), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        }
        #endif
    }
    private func deferJourney() {
        work?.cancel(); working = false; paused = true; pendingPractice = nil
        endOwnedPresentation(); store.route = .home
    }
    private func prepareLesson() async {
        guard !working, let authorization = ServerAPI.captureAuthorization() else { return }
        working = true; defer { working = false }
        let owner = store.captureAccountSessionBoundary()
        do {
            await CurriculumAvailabilityStore.shared.refresh(force: true)
            let snapshot = try await ServerAPI.getCanonicalLearning(authorization: authorization)
            guard !Task.isCancelled, store.ownsCurrentAccountSession(owner), snapshot.isValid else { return }
            guard let id = snapshot.projection(using: CurriculumPolicy.snapshot).nextConceptID,
                  let (course, unit, concept) = CurriculumV2.concept(id), CurriculumV2.canStudy(id) else {
                message = "지금 시작할 새 개념이 없습니다. 학습에서 원하는 공개 과정을 골라 주세요."; return
            }
            let seed = UInt64.random(in: 1...UInt64.max / 2)
            let problems = WebGen.practiceProblems(courseId: course.id, unitId: unit.id, conceptId: id, count: 3, seed: seed, includeCurriculumChecks: true)
            guard problems.count == 3 else { message = "확인 문제 3개를 준비하지 못했습니다. 다시 시도하거나 다른 학습을 먼저 이용해 주세요."; return }
            let progress = snapshot.courses.flatMap(\.units).flatMap(\.concepts).first { $0.id == id }?.progress
            model.update { _ = $0.prepare(conceptID: concept.id, seed: seed, problemIDs: problems.map(\.id), baselineProgress: progress, contentFingerprint: fingerprint(problems),
                                         deadLetters: SyncEngine.shared.deadLettered, quarantined: SyncEngine.shared.quarantinedLines, now: Date()) }
        } catch { if store.ownsCurrentAccountSession(owner) { message = "학습 정보를 확인하지 못했습니다. 연결을 확인하고 다시 시도해 주세요." } }
    }
    private func beginChecks() {
        guard let concept, let (course, unit, _) = CurriculumV2.concept(concept.id),
              CurriculumV2.canStudy(concept.id), let seed = model.journey.seed else { message = "이 수업은 현재 열 수 없습니다. 처음부터 다시 시작하면 공개된 수업을 확인합니다."; return }
        let problems = WebGen.practiceProblems(courseId: course.id, unitId: unit.id, conceptId: concept.id, count: 3, seed: seed, includeCurriculumChecks: true)
        guard problems.map(\.id) == model.journey.expectedProblemIDs,
              model.journey.problemContentFingerprint == fingerprint(problems) else { message = "수업 콘텐츠가 바뀌었습니다. 기존 학습 기록은 유지됩니다. 첫 학습을 처음부터 다시 시작해 주세요."; return }
        if model.journey.stage == .lesson {
            guard model.update({ _ = $0.beginChecks() }) else { return }
            for index in concept.topics.indices where store.progressV2.byConcept[concept.id]?.completedTopicIndexes.contains(index) != true {
                store.toggleConceptTopic(index, concept: concept)
            }
        }
        let remaining = problems.filter { model.journey.checkedAnswers[$0.id] == nil }
        guard !remaining.isEmpty else { return }
        pendingPractice = (remaining, seed, concept.id)
        endOwnedPresentation()
    }
    private func launchPreparedPractice() {
        guard let pending = pendingPractice, model.journey.slot == DataScope.slot, store.authProvider == "server" else { pendingPractice = nil; return }
        pendingPractice = nil
        store.selectedConceptV2ID = pending.conceptID
        store.startExam(problems: pending.problems, seed: pending.seed)
        store.examSourceConceptV2ID = pending.conceptID
    }
    private func fingerprint(_ problems: [GeneratedProblem]) -> String {
        let fields = problems.map { [$0.id, $0.typeKey, $0.statement, $0.answer] + ($0.choices ?? []) + $0.steps }
        guard let data = try? JSONEncoder().encode(fields) else { return "" }
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
    private func confirmLearningReceipt() async {
        guard !working, model.journey.stage == .awaitingSync, let authorization = ServerAPI.captureAuthorization() else { return }
        working = true; defer { working = false }
        let owner = store.captureAccountSessionBoundary()
        recordReceiptDiagnostic("start")
        guard model.retryPendingSave() else { recordReceiptDiagnostic("journey_save_failed"); return }
        guard await SyncEngine.shared.flushLocalQueuePersistence() else { recordReceiptDiagnostic("queue_save_failed"); message = "학습 기록을 아직 기기에 저장하지 못했습니다. 저장 공간을 확인해 주세요."; return }
        let learningQueueDrained = await SyncEngine.shared.flushForLearningReceipt()
        guard !Task.isCancelled, store.ownsCurrentAccountSession(owner) else { return }
        recordReceiptDiagnostic("sync_returned")
        guard learningQueueDrained, SyncEngine.shared.pending == 0,
              SyncEngine.shared.deadLettered == model.journey.deadLetterBaseline,
              SyncEngine.shared.quarantinedLines == model.journey.quarantineBaseline else {
            recordReceiptDiagnostic("learning_queue_guard")
            message = "학습 기록을 계정에 아직 확인하지 못했습니다. 기록은 보관되어 있으며 다시 확인할 수 있어요."; return
        }
        do {
            let snapshot = try await ServerAPI.getCanonicalLearning(authorization: authorization)
            recordReceiptDiagnostic("canonical_returned", valid: snapshot.isValid,
                progress: snapshot.courses.flatMap(\.units).flatMap(\.concepts).first(where: { $0.id == model.journey.conceptID })?.progress)
            guard !Task.isCancelled, store.ownsCurrentAccountSession(owner), snapshot.isValid,
                  let id = model.journey.conceptID, CurriculumV2.canStudy(id),
                  let progress = snapshot.courses.flatMap(\.units).flatMap(\.concepts).first(where: { $0.id == id })?.progress else { return }
            model.update { _ = $0.confirmServer(progress: progress, now: Date()) }
            recordReceiptDiagnostic("confirmation_finished", valid: snapshot.isValid, progress: progress)
        } catch { if store.ownsCurrentAccountSession(owner) { recordReceiptDiagnostic("canonical_failed"); message = "진도를 확인하지 못했습니다. 연결 후 다시 확인해 주세요." } }
    }
    private func recordReceiptDiagnostic(_ checkpoint: String, valid: Bool? = nil, progress: Int? = nil) {
        #if DEBUG
        guard ProcessInfo.processInfo.arguments.contains("-firstLearningJourneyFixture"), model.journey.slot == DataScope.slot else { return }
        // Diagnostic enums/counts only: no error body, token, email, account slot,
        // problem/answer content or production credential can enter this file.
        var value: [String: Any] = ["checkpoint": checkpoint, "stage": model.journey.stage.rawValue,
            "checkedCount": model.journey.answeredCount, "pending": SyncEngine.shared.pending,
            "deadLettered": SyncEngine.shared.deadLettered, "deadLetterBaseline": model.journey.deadLetterBaseline,
            "quarantined": SyncEngine.shared.quarantinedLines, "quarantineBaseline": model.journey.quarantineBaseline,
            "hasLastError": SyncEngine.shared.lastError != nil, "topicRead": model.journey.topicRead]
        if let valid { value["canonicalValid"] = valid }
        if let progress { value["canonicalProgress"] = progress }
        if let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]) {
            try? data.write(to: DataScope.url("first-learning-receipt-diagnostic.json"), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        }
        #endif
    }
    private func complete() {
        guard model.remoteConflict == nil, model.journey.canCompleteTutorial, model.update({ _ = $0.finish(now: Date()) }) else { return }
        paused = true; endOwnedPresentation(); store.route = .home
        saveTutorialReceipt()
    }
    private func skip() {
        guard model.remoteConflict == nil, model.update({ $0.skip() }) else { return }
        deferJourney(); saveTutorialReceipt()
    }
    private func browseCoursesWithoutGuide() {
        guard model.journey.slot == DataScope.slot, model.journey.stage == .goal,
              model.remoteConflict == nil, model.update({ $0.skip() }) else { return }
        // This is an explicit skip of the guide, not a completed lesson or a
        // fabricated PASS. Reuse its durable SKIP receipt and existing retry.
        deferJourney()
        saveTutorialReceipt()
        store.route = .curriculum
    }
    private func restartJourney() {
        guard model.remoteConflict == nil else { return }
        model.willSendTutorialAction()
        model.restart()
        if model.update({ $0.pendingTutorialAction = "RESTART" }) { saveTutorialReceipt() }
    }
    private func saveTutorialReceipt() {
        guard model.remoteConflict == nil, let action = model.journey.pendingTutorialAction, let authorization = ServerAPI.captureAuthorization() else { return }
        model.willSendTutorialAction()
        let owner = store.captureAccountSessionBoundary()
        work = Task { @MainActor in
            struct Envelope: Decodable { let tutorial: ServerTutorialStatus }
            do {
                let _: Envelope = try await ServerAPI.request("PATCH", "/api/v1/me/tutorials/dashboard", body: ["action": action], authed: true, authorization: authorization)
                guard !Task.isCancelled, store.ownsCurrentAccountSession(owner) else { return }
                model.didSaveTutorialAction(action)
                await store.refreshServerProfile(force: true)
            } catch { /* Durable receipt retries on the next authenticated launch. */ }
        }
    }
}
