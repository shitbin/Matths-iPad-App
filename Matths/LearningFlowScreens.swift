import SwiftUI

struct LearningFlowTopBar: View {
    @EnvironmentObject private var store: AppStore
    private var title: String {
        switch store.route {
        case .curriculum: "전체 과정"
        case .assess: "공식 평가"
        case .profile: "프로필과 설정"
        case .community: "커뮤니티"
        case .concept: "개념 학습"
        case .quickPractice: "짧게 연습"
        case .commerce: "이용권"
        case .notifications: "알림"
        case .services: "전체 서비스"
        case .chat: "AI 코치"
        case .pro: "풀이 분석"
        case .archive: "자료실"
        case .studyHall: "수험관"
        case .storeCatalog: "상점"
        case .faq: "도움말"
        case .support: "문의"
        case .coachSuggestions: "코치 제안"
        case .arenaShop: "Arena 상점"
        case .hostedPortal: "서비스"
        case .academy: store.workspace == .student ? "학원" : store.workspace.title
        default: StudentDestination.containing(store.route).title
        }
    }
    var body: some View {
        HStack(spacing: Tokens.Space.s3) {
            if !store.route.isTab && store.route != .academy {
                Button {
                    switch store.route {
                    case .commerce: store.route = store.commerceOrigin
                    case .notifications: store.route = store.notificationOrigin
                    case .hostedPortal: store.route = store.serviceOrigin
                    default: store.route = StudentDestination.containing(store.route).route
                    }
                } label: {
                    Image(systemName: "chevron.left").frame(width: 44, height: 44)
                }.accessibilityLabel("이전 화면으로")
            }
            Text(title).font(.mBodyB).accessibilityAddTraits(.isHeader)
            Spacer()
            Button { store.route = .notifications } label: {
                Image(systemName: "bell").frame(width: 44, height: 44)
            }.accessibilityLabel("알림 열기")
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
                PrimaryBrandIdentity().frame(width: 140, height: 44).padding(.bottom, Tokens.Space.s5)
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
    }
}

struct WorkspacePicker: View {
    @EnvironmentObject private var store: AppStore
    var body: some View {
        if store.allowedWorkspaces.count > 1 {
            Menu {
                ForEach(store.allowedWorkspaces, id: \.self) { workspace in
                    Button(workspace.title) { store.selectWorkspace(workspace) }
                }
            } label: {
                Label(store.workspace.title, systemImage: "arrow.left.arrow.right")
                    .font(.mCallout).frame(minHeight: 44)
            }
            .accessibilityLabel("작업공간 변경, 현재 \(store.workspace.title)")
        }
    }
}

struct TodayLearningScreen: View {
    @EnvironmentObject private var store: AppStore
    @ObservedObject private var availability = CurriculumAvailabilityStore.shared

    @Environment(\.matthsBrowseViewportSize) private var viewport
    @Environment(\.dynamicTypeSize) private var typeSize

    private var compact: Bool { viewport.height < 460 && viewport.width >= 620 && !typeSize.isAccessibilitySize }
    var body: some View {
        Group {
            if compact {
                HStack(alignment: .top, spacing: Tokens.Space.s5) {
                    VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                        heading
                        Button("다른 학습 보기") { store.route = .learn }.frame(minHeight: 44)
                        Button("학습 기록") { store.route = .records }.frame(minHeight: 44)
                        connectionNotice
                    }.frame(maxWidth: 220, alignment: .leading).font(.mCallout)
                    if let action = store.resolvedTodayAction { actionCard(action) }
                }
            } else {
                VStack(alignment: .leading, spacing: Tokens.Space.s6) {
                    heading
                    if let action = store.resolvedTodayAction { actionCard(action) }
                    HStack {
                        Button("다른 학습 보기") { store.route = .learn }; Spacer()
                        Button("학습 기록") { store.route = .records }
                    }.font(.mCallout).frame(minHeight: 44)
                    connectionNotice
                }
            }
        }.frame(maxWidth: compact ? 980 : 700, alignment: .leading)
    }
    private var heading: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
            Text("오늘의 수학").font(.mHeading).accessibilityAddTraits(.isHeader)
            Text("한 가지씩, 지금 할 수 있는 것부터.").font(.mBody).foregroundStyle(Tokens.text2)
        }
    }
    private func actionCard(_ action: TodayActionCandidate) -> some View {
        VStack(alignment: .leading, spacing: compact ? Tokens.Space.s3 : Tokens.Space.s4) {
            if !compact {
                Label(action.kind == .timedWork ? "이어서 할 일" : "지금 할 학습", systemImage: "arrow.right.circle")
                    .font(.mCaption).foregroundStyle(Tokens.actionPrimary)
            }
            Text(action.title).font(compact ? .mHeading : .mTitle).fixedSize(horizontal: false, vertical: true)
            Text(action.reason).font(.mCallout).foregroundStyle(Tokens.text2).fixedSize(horizontal: false, vertical: true)
            if let minutes = action.minutes {
                Label("약 \(minutes)분 · 개념 이해와 확인 문제", systemImage: "clock").font(.mCaption).foregroundStyle(Tokens.text2)
            }
            Button(action.action) { perform(action) }.buttonStyle(PrimaryButtonStyle()).accessibilityIdentifier("today-primary-action")
        }
        .padding(compact ? Tokens.Space.s3 : Tokens.Space.s5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.Radius.lg))
    }
    @ViewBuilder private var connectionNotice: some View {
        if availability.state == .offline || availability.state == .failed {
            VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                Text("마지막으로 확인한 학습 정보를 보여드리고 있어요.").font(.mCaption).foregroundStyle(Tokens.text2)
                Button("다시 연결") { Task { await SyncEngine.shared.syncNow() } }.frame(minHeight: 44)
            }
        }
    }
    private func perform(_ action: TodayActionCandidate) {
        switch action.kind {
        case .timedWork: store.currentAttemptID = action.id; store.route = .paper
        case .academy: store.route = .academy
        case .review: store.startReview(ids: store.todayReviewIDs)
        case .curriculum: store.openConceptV2(action.id)
        case .explore: store.route = .learn
        }
    }
}

struct LearningHubScreen: View {
    @EnvironmentObject private var store: AppStore
    @State private var showsPractice = false
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
            if let (course, _, concept) = store.nextLearningConcept {
                VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                    Text("이어서 학습 · \(course.title)").font(.mCaption).foregroundStyle(Tokens.text2)
                    Text(concept.title).font(.mTitle)
                    Button("수업 이어가기") { store.openConceptV2(concept.id) }.buttonStyle(PrimaryButtonStyle())
                }.card()
            }
            FlowDestinationRow("전체 과정", detail: "과목과 단원에서 필요한 개념 찾기", icon: "books.vertical") { store.route = .curriculum }
            FlowDestinationRow("공식 평가", detail: "평가 기록과 다음에 응시할 평가", icon: "checkmark.seal") { store.route = .assess }
            FlowDestinationRow("짧게 연습", detail: "유형을 골라 문제 풀기", icon: "pencil.line") { store.route = .quickPractice }
            FlowDestinationRow("오프라인 연습", detail: "공식 점수와 진도에 반영되지 않는 연습", icon: "wifi.slash") { showsPractice = true }
            DisclosureGroup("시험 대비와 풀이 도구") {
                FlowDestinationRow("주간 모의고사", icon: "calendar") { store.route = .weeklyMock }
                FlowDestinationRow("배치고사", icon: "scope") { store.route = .placement }
                FlowDestinationRow("기출 연습", icon: "doc.text") { store.route = .kice }
                FlowDestinationRow("시험지 풀이 분석", icon: "camera") { store.route = .pro }
            }.font(.mBody).padding(.vertical, Tokens.Space.s3)
        }
        .fullScreenCover(isPresented: $showsPractice) { OfflinePracticeScreen() }
    }
}

struct LearningRecordsScreen: View {
    @EnvironmentObject private var store: AppStore
    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s5) {
            Text("기록").font(.mHeading).accessibilityAddTraits(.isHeader)
            Text("오늘 복습할 오답 \(store.dueReviewCount)개").font(.mTitle)
            if store.dueReviewCount > 0 {
                Button("오늘 복습 시작") { store.startReview() }.buttonStyle(PrimaryButtonStyle())
            } else { Text("예정된 복습을 마쳤어요. 다음 학습으로 이어가세요.").font(.mBody).foregroundStyle(Tokens.text2) }
            FlowDestinationRow("전체 오답", detail: "다시 볼 문제와 복습 예정일", icon: "arrow.counterclockwise") { store.route = .wrongNotes }
            let summary = store.learningSummary
            FlowDestinationRow("개념 학습 기록", detail: "\(summary.done)/\(summary.total)개 완료 · \(summary.percent)%", icon: "chart.bar.xaxis") { store.route = .curriculum }
            FlowDestinationRow("공식 평가 결과", icon: "checkmark.seal") { store.route = .assess }
            FlowDestinationRow("주간 학습 리포트", icon: "chart.xyaxis.line") { store.route = .profile }
        }
    }
}

struct MeHubScreen: View {
    @EnvironmentObject private var store: AppStore
    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s4) {
            Text(store.userName).font(.mHeading).accessibilityAddTraits(.isHeader)
            WorkspacePicker()
            Menu("학습 목표 변경") {
                ForEach(["학교 진도 따라가기", "틀린 문제 줄이기", "시험 대비하기", "실력 확인하기"], id: \.self) { goal in
                    Button(goal) { UserDefaults.standard.set(goal, forKey: "matths.demo.onboarding.v1." + DataScope.slot + ".goal") }
                }
            }.font(.mCallout).frame(minHeight: 44)
            FlowDestinationRow("프로필과 설정", detail: "학교 · 계정 보안 · 튜토리얼", icon: "person.crop.circle") { store.route = .profile }
            FlowDestinationRow("학원", icon: "building.2") { store.route = .academy }
            FlowDestinationRow("알림", icon: "bell") { store.route = .notifications }
            FlowDestinationRow("AI 코치", detail: "질문과 대화 기록 · 모델 관리", icon: "bubble.left.and.text.bubble.right") { store.route = .chat }
            FlowDestinationRow("커뮤니티", icon: "person.2") { store.route = .community }
            FlowDestinationRow("자료실", icon: "folder") { store.route = .archive }
            FlowDestinationRow("수험관", icon: "building.columns") { store.route = .studyHall }
            FlowDestinationRow("이용권과 구매 복원", icon: "creditcard") { store.route = .commerce }
            FlowDestinationRow("전체 서비스", detail: "상점 · 학원 · 지원", icon: "square.grid.2x2") { store.route = .services }
            FlowDestinationRow("도움말과 문의", icon: "questionmark.circle") { store.route = .faq }
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
