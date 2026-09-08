import SwiftUI

struct LearningFlowTopBar: View {
    @EnvironmentObject private var store: AppStore
    var body: some View {
        HStack(spacing: Tokens.Space.s3) {
            if !store.route.isTab && store.route != .academy {
                Button {
                    if let previous = store.previousBrowseRoute {
                        store.route = previous
                        return
                    }
                    switch store.route {
                    case .commerce: store.route = store.commerceOrigin
                    case .notifications: store.route = store.notificationOrigin
                    case .hostedPortal: store.route = store.serviceOrigin
                    case .concept: store.route = .curriculum
                    default: store.route = StudentDestination.containing(store.route).route
                    }
                } label: {
                    Image(systemName: "chevron.left").frame(width: 44, height: 44)
                }.accessibilityLabel("이전 화면으로")
            }
            // Keep the original identity in the shell. Page titles belong to
            // their content, not a second competing navigation heading.
            PrimaryBrandIdentity()
                .frame(width: 116, height: 36)
                .accessibilityHidden(false)
                .accessibilityLabel("Matths")
                .accessibilityIdentifier("navigation-brand")
            Spacer()
            if store.workspace != .student {
                WorkspacePicker(compact: true, showsAccountActions: true)
            }
            Button {
                guard store.route != .notifications else { return }
                store.route = .notifications
            } label: {
                Image(systemName: "bell").frame(width: 44, height: 44)
            }.accessibilityLabel("알림 열기")
                .tutorialTarget(.topNotifications)
        }
        .foregroundStyle(Tokens.ink).padding(.horizontal, Tokens.Space.s3)
        .frame(minHeight: 48).background(Tokens.surface)
    }
}

/// The same destinations drive compact navigation, the sidebar and legacy routes.
struct LearningFlowSidebar: View {
    @EnvironmentObject private var store: AppStore
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                if store.workspace == .student {
                    ForEach(StudentDestination.allCases) { destination in
                        destinationButton(destination.title, icon: destination.icon, route: destination.route)
                    }
                } else {
                    destinationButton(store.workspace.title, icon: "building.2", route: .academy)
                    destinationButton("알림", icon: "bell", route: .notifications)
                    destinationButton("지원", icon: "questionmark.circle", route: .support)
                    destinationButton("내 계정", icon: "person.crop.circle", route: .me)
                }
                Divider().padding(.vertical, Tokens.Space.s4)
                WorkspacePicker()
            }
            .padding(Tokens.Space.s4)
        }
        .tutorialViewport()
        .frame(width: 204)
        .background(Tokens.surface)
        .overlay(alignment: .trailing) { Divider() }
    }
    private func destinationButton(_ title: String, icon: String, route: AppStore.Route) -> some View {
        Button { store.route = route } label: {
            Label(title, systemImage: icon)
                .font(.mBodyB)
                .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                .padding(.horizontal, Tokens.Space.s3)
                .foregroundStyle(store.selectedTab == route ? Tokens.actionPrimary : Tokens.ink)
                .background(store.selectedTab == route ? Tokens.actionPrimary.opacity(0.10) : .clear,
                            in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(store.selectedTab == route ? [.isSelected] : [])
        .modifier(TutorialNavigationAnchor(route: route))
    }
}

struct WorkspacePicker: View {
    @EnvironmentObject private var store: AppStore
    var compact = false
    var showsAccountActions = false
    var body: some View {
        if store.allowedWorkspaces.count > 1 {
            Menu {
                ForEach(store.allowedWorkspaces, id: \.self) { workspace in
                    Button { store.selectWorkspace(workspace) } label: {
                        if store.workspace == workspace { Label(workspace.title, systemImage: "checkmark") }
                        else { Text(workspace.title) }
                    }
                }
                if showsAccountActions {
                    Divider()
                    Button("내 계정과 설정", systemImage: "person.crop.circle") { store.route = .me }
                    Button("도움말과 문의", systemImage: "questionmark.circle") { store.route = .support }
                }
            } label: {
                if compact {
                    Image(systemName: "person.crop.circle").frame(width: 44, height: 44)
                } else {
                    Label(store.workspace.title, systemImage: "arrow.left.arrow.right")
                        .font(.mCallout).frame(minHeight: 44)
                }
            }
            .accessibilityLabel(showsAccountActions ? "계정과 작업공간, 현재 \(store.workspace.title)" : "작업공간 변경, 현재 \(store.workspace.title)")
        }
    }
}

struct TodayLearningScreen: View {
    @EnvironmentObject private var store: AppStore
    @ObservedObject private var availability = CurriculumAvailabilityStore.shared
    @ObservedObject private var activities = TodayActivityStore.shared
    @ObservedObject private var journey = FirstLearningJourneyStore.shared
    @State private var selectedActivity: TodayActionCandidate?
    @State private var navigationID = UUID()
    @State private var actionBusy = false
    @Environment(\.scenePhase) private var scenePhase

    @Environment(\.matthsBrowseViewportSize) private var viewport
    @Environment(\.dynamicTypeSize) private var typeSize

    private var compact: Bool { viewport.height < 460 && viewport.width >= 620 && !typeSize.isAccessibilitySize }
    private var usesColumns: Bool { viewport.width >= 760 && !typeSize.isAccessibilitySize }
    private var agenda: [TodayActionCandidate] {
        TodayDashboardPolicy.agenda(store.todayActionCandidates, primary: store.resolvedTodayAction)
    }
    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { _ in todayContent }
            .task { await activities.refresh(store: store) }
            .onChange(of: scenePhase) { _, value in
                if value == .active { Task { await activities.refresh(store: store) } }
            }
            .onChange(of: store.route) { _, _ in
                selectedActivity = nil
                navigationID = UUID()
                actionBusy = false
            }
            .fullScreenCover(item: $selectedActivity) { action in
                TodayActivityDestination(action: action) { selectedActivity = nil }
                    .onDisappear { Task { await activities.refresh(store: store, force: true) } }
            }
    }
    private var todayContent: some View {
        VStack(alignment: .leading, spacing: compact ? Tokens.Space.s3 : Tokens.Space.s5) {
            heading
            if usesColumns || compact {
                HStack(alignment: .top, spacing: Tokens.Space.s5) {
                    if let action = store.resolvedTodayAction {
                        actionCard(action).frame(maxWidth: .infinity, alignment: .leading)
                    }
                    TodayLearningOverview(compact: compact)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                if let action = store.resolvedTodayAction { actionCard(action) }
                TodayLearningOverview()
            }
            agendaSection
            connectionNotice
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private var heading: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
            HStack(alignment: .firstTextBaseline) {
                Text("오늘의 수학").font(.mTitle).accessibilityAddTraits(.isHeader)
                Spacer(minLength: Tokens.Space.s2)
                Label("\(store.streakDays)일 연속", systemImage: "flame")
                    .font(.mCaption).foregroundStyle(Tokens.text2)
            }
            Text("\(store.userName.isEmpty ? "나" : store.userName)님의 목표 · \(journey.goal.title)")
                .font(.mCallout).foregroundStyle(Tokens.text2)
            if !journey.journey.isTerminal, journey.journey.stage != .goal {
                Button("첫 학습 이어서 마치기") {
                    NotificationCenter.default.post(name: .matthsResumeFirstLearning, object: nil)
                }.font(.mCallout).frame(minHeight: 44)
            }
        }
    }
    private func actionCard(_ action: TodayActionCandidate) -> some View {
        VStack(alignment: .leading, spacing: compact ? Tokens.Space.s3 : Tokens.Space.s4) {
            if !compact {
                Label(action.kind == .timedWork ? "이어서 할 일" : "지금 할 학습", systemImage: "arrow.right.circle")
                    .font(.mCaption).foregroundStyle(Tokens.actionPrimary)
            }
            Text(action.title).font(compact ? .mHeading : .mTitle).fixedSize(horizontal: false, vertical: true)
            Text(action.visibleReason).font(.mCallout).foregroundStyle(Tokens.text2).fixedSize(horizontal: false, vertical: true)
            if let position = action.position { Text(position).font(.mCaption).foregroundStyle(Tokens.text2) }
            if let minutes = action.minutes {
                Label("약 \(minutes)분", systemImage: "clock").font(.mCaption).foregroundStyle(Tokens.text2)
            }
            if let deadline = action.deadline {
                Text("마감 안내: " + deadline.formatted(date: .abbreviated, time: .shortened))
                    .font(.mCaption).foregroundStyle(Tokens.text2)
            }
            Button(actionBusy ? "기록 확인 중…" : action.visibleAction) { perform(action) }
                .buttonStyle(PrimaryButtonStyle()).disabled(actionBusy)
                .accessibilityIdentifier("today-primary-action")
                .tutorialTarget(.todayPrimaryAction)
        }
        .padding(compact ? Tokens.Space.s3 : Tokens.Space.s5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.Radius.lg))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2).fill(Tokens.actionPrimary)
                .frame(width: 3).padding(.vertical, Tokens.Space.s5)
                .accessibilityHidden(true)
        }
    }
    @ViewBuilder private var agendaSection: some View {
        if !agenda.isEmpty {
            VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                Text("함께 확인할 일").font(.mHeading)
                ForEach(agenda) { action in
                    FlowDestinationRow(action.title,
                                       detail: action.freshness == .cached ? action.visibleReason : action.position ?? action.visibleReason,
                                       icon: action.kind == .review ? "arrow.counterclockwise" : "calendar.badge.clock") {
                        perform(action)
                    }
                    if action.id != agenda.last?.id { Divider() }
                }
            }
        }
    }
    @ViewBuilder private var connectionNotice: some View {
        if availability.state == .offline || availability.state == .failed || !activities.failedSources.isEmpty {
            VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                Text("마지막으로 확인한 학습 정보를 보여드리고 있어요.").font(.mCaption).foregroundStyle(Tokens.text2)
                Button("다시 연결") { Task {
                    await SyncEngine.shared.syncNow()
                    await activities.refresh(store: store, force: true)
                } }.frame(minHeight: 44)
            }
        }
    }
    private func perform(_ action: TodayActionCandidate) {
        // A sheet keeps route == .home, so route changes alone cannot retire
        // the preceding asynchronous assessment lookup.
        navigationID = UUID()
        actionBusy = false
        switch action.destination {
        case .officialAssessment(let id):
            let owner = store.captureAccountSessionBoundary()
            let requestedNavigation = navigationID
            actionBusy = true
            Task {
                defer { if navigationID == requestedNavigation { actionBusy = false } }
                await store.pullServerAssessments()
                guard store.ownsCurrentAccountSession(owner), navigationID == requestedNavigation,
                      store.route == .home else { return }
                store.assessmentReturnRoute = .assess
                guard store.attemptsV2.attempts.contains(where: {
                    $0.id == id && $0.serverBacked == true && !$0.isServerCancelled && $0.submittedAt == nil
                }) else { store.route = .assess; return }
                store.currentAttemptID = id; store.route = .paper
            }
        case .academyAttendance: store.route = .academy
        case .review: store.startReview(ids: Array(store.todayReviewIDs.prefix(5)))
        case .concept(let id): store.openConceptV2(id)
        case .assessments: store.route = .assess
        case .learn: store.route = .learn
        case .weeklyMock, .arena, .academyWeek: selectedActivity = action
        }
    }
}

struct LearningHubScreen: View {
    @EnvironmentObject private var store: AppStore
    @State private var showsPractice = false
    @State private var showsTools = false
    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s5) {
            Text("학습").font(.mHeading).accessibilityAddTraits(.isHeader)
            if CurriculumPolicy.snapshot.orderedCourseIDs.contains(where: {
                CurriculumPolicy.isAvailable($0) && CurriculumV2.course($0) == nil
            }) {
                Text("새로 공개된 과목이 있어요. 이 기기에서 열려면 앱을 업데이트해 주세요.")
                    .font(.mCallout).foregroundStyle(Tokens.text2)
                if let url = URL(string: "https://apps.apple.com/app/id6803569629") {
                    Link("업데이트 확인", destination: url).frame(minHeight: 44)
                }
            }
            if let (course, unit, concept) = store.nextLearningConcept {
                VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                    Text("이어서 학습 · \(course.title)").font(.mCaption).foregroundStyle(Tokens.text2)
                    Text(concept.title).font(.mTitle)
                    Text(unit.title).font(.mCallout).foregroundStyle(Tokens.text2)
                    if let summary = concept.lesson?.summary { MathInline(text: summary, font: .mBody, color: Tokens.text2) }
                    Button("수업 이어가기") { store.openConceptV2(concept.id) }.buttonStyle(PrimaryButtonStyle())
                }.card()
            }
            FlowDestinationRow("과목과 단원", detail: "개념 수업과 단계 평가를 한곳에서", icon: "books.vertical") { store.route = .curriculum }
                .tutorialTarget(.learningCourses)
            if let attempt = store.attemptsV2.attempts.first(where: { $0.serverBacked == true && $0.submittedAt == nil && !$0.isServerCancelled }) {
                FlowDestinationRow("작성하던 평가 확인", detail: attempt.title, icon: "doc.badge.clock") {
                    store.assessmentReturnRoute = .assess
                    store.currentAttemptID = attempt.id; store.route = .paper
                }
            }
            FlowDestinationRow("평가센터", detail: "주간 공식 모의고사 · 응시와 결과", icon: "checkmark.seal") { store.route = .assess }
                .tutorialTarget(.weeklyMockEntry)
            FlowDestinationRow("짧게 연습", detail: "유형을 골라 문제 풀기", icon: "pencil.line") { store.route = .quickPractice }
                .tutorialTarget(.quickPracticeStart)
            DisclosureGroup("연습 자료와 풀이 도구", isExpanded: $showsTools) {
                FlowDestinationRow("기출 연습", icon: "doc.text") { store.route = .kice }
                FlowDestinationRow("시험지 풀이 분석", icon: "camera") { store.route = .pro }
                    .tutorialTarget(.proEntry)
                FlowDestinationRow("오프라인 연습", detail: "공식 점수·진도에 반영되지 않는 기기 내 연습", icon: "wifi.slash") { showsPractice = true }
            }.font(.mBody).padding(.vertical, Tokens.Space.s3)
        }
        .fullScreenCover(isPresented: $showsPractice) { OfflinePracticeScreen() }
        .onReceive(NotificationCenter.default.publisher(for: TutorialFocusRequestCenter.notification)) { _ in
            if TutorialFocusRequestCenter.current?.target == .proEntry { showsTools = true }
        }
    }
}

struct LearningRecordsScreen: View {
    @EnvironmentObject private var store: AppStore
    @State private var showsWeeklyReport = false
    @ObservedObject private var sync = SyncEngine.shared
    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s5) {
            Text("기록").font(.mHeading).accessibilityAddTraits(.isHeader)
            Text("오늘 복습할 오답 \(store.todayReviewIDs.count)개").font(.mTitle)
            if !store.todayReviewIDs.isEmpty {
                Button("먼저 \(min(5, store.todayReviewIDs.count))개 복습") { store.startReview(ids: Array(store.todayReviewIDs.prefix(5))) }.buttonStyle(PrimaryButtonStyle())
            } else {
                Text(store.wrongNotes.isEmpty ? "아직 복습할 문제가 없어요. 학습 중 틀린 문제는 여기에 모아드려요." : "지금 예정된 복습이 없어요. 다음 학습을 하거나 보관한 오답을 골라볼 수 있어요.")
                    .font(.mBody).foregroundStyle(Tokens.text2)
            }
            LearningReviewSchedule()
            FlowDestinationRow("전체 오답", detail: "다시 볼 문제와 복습 예정일", icon: "arrow.counterclockwise") { store.route = .wrongNotes }
                .tutorialTarget(.wrongNotes)
            let summary = store.learningSummary
            FlowDestinationRow("개념 학습 기록", detail: "\(summary.done)/\(summary.total)개 완료 · \(summary.percent)%", icon: "chart.bar.xaxis") { store.route = .curriculum }
            FlowDestinationRow("공식 모의고사 결과", icon: "checkmark.seal") { store.route = .assess }
            FlowDestinationRow("최근 7일 학습 리포트", detail: "공부한 날 · 학습 시간 · 문제 기록", icon: "chart.xyaxis.line") { showsWeeklyReport = true }
            if sync.pending > 0 || sync.lastError != nil {
                Text("계정 확인을 기다리는 기록이 있어요. 기기의 기록과 서버 진도가 잠시 다를 수 있습니다.").font(.mCaption).foregroundStyle(Tokens.text2)
                Button("기록 동기화") { Task { await sync.syncNow() } }.frame(minHeight: 44)
            }
        }
        .sheet(isPresented: $showsWeeklyReport) { WeeklyLearningReportScreen() }
    }
}

struct MeHubScreen: View {
    @EnvironmentObject private var store: AppStore
    @ObservedObject private var journey = FirstLearningJourneyStore.shared
    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s4) {
            Text("나").font(.mTitle).accessibilityAddTraits(.isHeader)
            Button { store.route = .profile } label: {
                HStack(spacing: Tokens.Space.s3) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 38)).foregroundStyle(Tokens.actionPrimary)
                    VStack(alignment: .leading, spacing: Tokens.Space.s1) {
                        Text(store.userName.isEmpty ? "내 계정" : store.userName).font(.mHeading)
                        Text("프로필 · 학교 · 계정 보안").font(.mCaption).foregroundStyle(Tokens.text2)
                    }
                    Spacer(minLength: Tokens.Space.s2)
                    Image(systemName: "chevron.right").font(.mCaption)
                }
                .foregroundStyle(Tokens.ink)
                .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
                .padding(Tokens.Space.s4)
                .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.Radius.lg))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(store.userName), 프로필과 설정")
            .tutorialTarget(.profileSettings)
            if store.workspace == .student { WorkspacePicker() }
            Menu {
                ForEach(LearningGoal.allCases) { goal in
                    Button(goal.title) { journey.setGoal(goal); WidgetBridge.publish(from: store) }
                }
            } label: {
                HStack {
                    Text("학습 목표").foregroundStyle(Tokens.ink)
                    Spacer()
                    Text(journey.goal.title).foregroundStyle(Tokens.text2)
                    Image(systemName: "chevron.up.chevron.down").foregroundStyle(Tokens.text3)
                }.font(.mCallout).frame(minHeight: 44)
            }
            if !journey.journey.isTerminal {
                FlowDestinationRow("첫 학습 이어하기", detail: "개념 하나와 확인 문제 3개", icon: "play.circle") {
                    NotificationCenter.default.post(name: .matthsResumeFirstLearning, object: nil)
                }
            }
            VStack(alignment: .leading, spacing: 0) {
                Text("학습과 이용").font(.mCaption).foregroundStyle(Tokens.text3)
                FlowDestinationRow("학원과 수업", detail: "소속 학원 · 수업 · 출석", icon: "building.2") { store.route = .academy }
                Divider()
                FlowDestinationRow("이용권과 구매 복원", icon: "creditcard") { store.route = .commerce }
                Divider()
                FlowDestinationRow("학습 도구와 자료", detail: "AI 코치 · 자료실 · 커뮤니티", icon: "square.grid.2x2") { store.route = .services }
            }
            VStack(alignment: .leading, spacing: 0) {
                Text("도움이 필요할 때").font(.mCaption).foregroundStyle(Tokens.text3)
                FlowDestinationRow("자주 묻는 질문", icon: "questionmark.circle") { store.route = .faq }
                Divider()
                FlowDestinationRow("문의 내역과 새 문의", detail: "계정 · 학습 · 결제 문제", icon: "bubble.left") { store.route = .support }
            }
        }
    }
}

struct FlowDestinationRow: View {
    let title: String
    let detail: String?
    let icon: String
    let action: () -> Void
    init(_ title: String, detail: String? = nil, icon: String, action: @escaping () -> Void) {
        self.title = title; self.detail = detail; self.icon = icon; self.action = action
    }
    var body: some View {
        Button(action: action) {
            HStack(spacing: Tokens.Space.s3) {
                Image(systemName: icon).frame(width: 28).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Tokens.Space.s1) {
                    Text(title).font(.mBodyB)
                    if let detail { Text(detail).font(.mCaption).foregroundStyle(Tokens.text2) }
                }.fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: Tokens.Space.s2)
                Image(systemName: "chevron.right").font(.mCaption).accessibilityHidden(true)
            }
            .foregroundStyle(Tokens.ink)
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .padding(.vertical, Tokens.Space.s2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain).accessibilityElement(children: .combine)
    }
}
