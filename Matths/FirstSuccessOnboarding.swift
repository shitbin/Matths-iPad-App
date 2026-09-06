import SwiftUI

struct SampleLessonScreen: View {
    @Environment(\.dismiss) private var dismiss
    @State private var answer: Int?
    @State private var storageKey = "matths.demo.sample.function.v1." + DataScope.slot
    var onContinue: (() -> Void)?
    var onSkip: (() -> Void)?
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Tokens.Space.s5) {
                    Text("함수는 입력을 바꾸는 규칙이에요").font(.mTitle).accessibilityAddTraits(.isHeader)
                    Text("어떤 수를 넣으면 두 배로 만든 뒤 1을 더합니다.").font(.mBody)
                    Text("3 → × 2 → + 1 → ?").font(.mTitle).accessibilityLabel("3을 두 배로 만들고 1을 더하면 얼마일까요?")
                    if let answer {
                        Text(answer == 7 ? "맞아요. 3 × 2 + 1 = 7이에요." : "먼저 3을 두 배로 만들면 6, 여기에 1을 더하면 7이에요.")
                            .font(.mBodyB).fixedSize(horizontal: false, vertical: true)
                        Text("함숫값을 구할 때는 입력한 수에 규칙을 순서대로 적용하면 돼요.")
                            .font(.mBody).foregroundStyle(Tokens.text2)
                        Button(onContinue == nil ? "로그인 화면으로" : "다음 학습 보기") {
                            if let onContinue { onContinue() } else { dismiss() }
                        }.buttonStyle(PrimaryButtonStyle())
                    } else {
                        ForEach([6, 7, 8], id: \.self) { option in
                            Button("\(option)") { answer = option }
                                .buttonStyle(SecondaryButtonStyle())
                                .accessibilityLabel("정답 \(option) 선택")
                        }
                    }
                    Text("비공식 체험입니다. 점수나 공식 진도에 반영되지 않습니다.")
                        .font(.mCaption).foregroundStyle(Tokens.text2)
                }.padding(Tokens.Space.s5).frame(maxWidth: 620).frame(maxWidth: .infinity)
            }
            .navigationTitle("30초 수학 체험").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("건너뛰기") {
                if let onSkip { onSkip() } else { dismiss() }
            } } }
        }
        .onAppear {
            if let value = UserDefaults.standard.object(forKey: storageKey) as? Int, [6, 7, 8].contains(value) { answer = value }
        }
        .onChange(of: answer) { _, value in if let value { UserDefaults.standard.set(value, forKey: storageKey) } }
    }
}

struct FirstSuccessOnboardingOverlay: View {
    @EnvironmentObject private var store: AppStore
    @State private var presented = false
    @State private var step: Step = .goal
    @State private var goal = "학교 진도 따라가기"
    @State private var mutation: Mutation = .ready
    @State private var completionTask: Task<Void, Never>?
    enum Step: String { case goal, sample, plan }
    enum Mutation { case ready, saving, failed(String) }
    private var persistenceKey: String { "matths.demo.onboarding.v1." + DataScope.slot }
    private var trigger: String {
        DataScope.slot + ":" + String(store.serverProfile?.dashboardTutorial?.shouldAutoStart == true)
    }
    var body: some View {
        Color.clear
            .allowsHitTesting(false)
            .task(id: trigger) {
                guard store.authProvider == "server", !store.isSessionMode,
                      store.serverProfile?.dashboardTutorial?.shouldAutoStart == true,
                      !presented, !store.requestedDashboardTutorial else { return }
                if UserDefaults.standard.string(forKey: persistenceKey + ".pending") == "SKIP" {
                    do {
                        _ = try await ServerAPI.updateDashboardTutorial("SKIP")
                        UserDefaults.standard.removeObject(forKey: persistenceKey + ".pending")
                        await store.refreshServerProfile()
                    } catch { /* Continue to the app; retry next authenticated launch. */ }
                    return
                }
                step = Step(rawValue: UserDefaults.standard.string(forKey: persistenceKey + ".step") ?? "") ?? .goal
                goal = UserDefaults.standard.string(forKey: persistenceKey + ".goal") ?? goal
                store.isTutorialPresentationActive = true
                presented = true
            }
            .onChange(of: step) { _, value in UserDefaults.standard.set(value.rawValue, forKey: persistenceKey + ".step") }
            .onChange(of: store.authProvider) { _, value in
                if value != "server" { completionTask?.cancel(); presented = false; store.isTutorialPresentationActive = false }
            }
            .fullScreenCover(isPresented: $presented) {
                if step == .sample {
                    SampleLessonScreen(onContinue: { step = .plan }, onSkip: { finish(skipped: true) })
                }
                else { introduction }
            }
    }
    private var introduction: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Tokens.Space.s5) {
                    if step == .goal {
                        Text("지금 가장 필요한 공부는 무엇인가요?").font(.mTitle)
                        ForEach(["학교 진도 따라가기", "틀린 문제 줄이기", "시험 대비하기", "실력 확인하기"], id: \.self) { value in
                            Button {
                                goal = value
                                UserDefaults.standard.set(goal, forKey: persistenceKey + ".goal")
                                step = .sample
                            } label: {
                                Label(value, systemImage: value == goal ? "checkmark.circle.fill" : "circle")
                                    .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                            }.buttonStyle(SecondaryButtonStyle())
                        }
                        Text("목표는 나중에 다시 바꿀 수 있어요.").font(.mCallout).foregroundStyle(Tokens.text2)
                    } else {
                        Text("첫 학습을 시작할 준비가 됐어요").font(.mTitle)
                        if let (course, _, concept) = store.nextLearningConcept {
                            Text("\(course.title) · \(concept.title)").font(.mHeading)
                            Text("개념 설명을 보고 직접 확인 문제를 풀어봐요.").font(.mBody)
                        } else { Text("공개된 과정에서 필요한 개념을 골라보세요.").font(.mBody) }
                        Button("오늘 학습 시작") { finish(skipped: false) }.buttonStyle(PrimaryButtonStyle())
                    }
                    if case .failed(let message) = mutation {
                        Text(message).font(.mCallout).foregroundStyle(Tokens.dangerInk)
                        Button("다시 저장") { finish(skipped: false) }.frame(minHeight: 44)
                    }
                    if case .saving = mutation { ProgressView("설정을 저장하고 있어요") }
                }
                .padding(Tokens.Space.s5).frame(maxWidth: 620, alignment: .leading).frame(maxWidth: .infinity)
            }
            .navigationTitle("첫 학습").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("건너뛰기") { finish(skipped: true) } }
                ToolbarItem(placement: .confirmationAction) { Button("나중에 계속") {
                    completionTask?.cancel()
                    presented = false; store.isTutorialPresentationActive = false; mutation = .ready
                } }
            }
        }
    }
    private func finish(skipped: Bool) {
        if case .saving = mutation { return }
        mutation = .saving
        let owner = store.captureAccountSessionBoundary()
        if skipped {
            UserDefaults.standard.set("SKIP", forKey: persistenceKey + ".pending")
            presented = false; store.isTutorialPresentationActive = false; store.route = .home
        }
        completionTask = Task { @MainActor in
            do {
                _ = try await ServerAPI.updateDashboardTutorial(skipped ? "SKIP" : "COMPLETE")
                guard !Task.isCancelled, store.ownsCurrentAccountSession(owner) else { return }
                await store.refreshServerProfile()
                guard !Task.isCancelled, store.ownsCurrentAccountSession(owner) else { return }
                UserDefaults.standard.removeObject(forKey: persistenceKey + ".pending")
                store.isTutorialPresentationActive = false
                presented = false; mutation = .ready
                if !skipped, let (_, _, concept) = store.nextLearningConcept { store.openConceptV2(concept.id) }
                else { store.route = .home }
            } catch {
                guard !Task.isCancelled, store.ownsCurrentAccountSession(owner) else { return }
                if skipped {
                    UserDefaults.standard.set("SKIP", forKey: persistenceKey + ".pending")
                    store.isTutorialPresentationActive = false; presented = false; mutation = .ready
                    store.route = .home
                    return
                }
                mutation = .failed("첫 설정을 저장하지 못했습니다. 연결을 확인하고 다시 시도해 주세요.")
            }
        }
    }
}
