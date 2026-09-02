import SwiftUI

/// 첫 로그인에서 제품 설명을 읽히지 않고 사용자가 하려는 공부를 바로 고르게 한다.
/// 상세 기능 투어는 프로필의 명시적 재시작에만 남겨 둔다.
struct FirstRunOnboardingOverlay: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var isPresented = false
    @State private var selectedIntent: StudyIntent = .newConcept
    @State private var selectedCoach: SpiceLevel = .mild
    @State private var saving = false
    @State private var errorMessage: String?

    private var accountRole: String {
        #if DEBUG
        if DemoMode.isOn { return DemoMode.demoUser.role?.lowercased() ?? "student" }
        #endif
        return store.serverProfile?.role?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? "student"
    }

    private var isStaffAccount: Bool {
        accountRole == "teacher" || accountRole == "admin"
    }

    private var staffTitle: String {
        accountRole == "admin" ? "운영 현황부터 확인할까요?" : "오늘 수업부터 확인할까요?"
    }

    private var staffDetail: String {
        accountRole == "admin"
            ? "승인 대기 학원과 운영 상태를 한 화면에서 확인하고 바로 처리할 수 있어요."
            : "담당 반의 출결, 학생, 수업 자료와 초대를 한 작업대에서 관리할 수 있어요."
    }

    private var staffActionTitle: String {
        accountRole == "admin" ? "운영 작업대 열기" : "수업 작업대 열기"
    }

    private enum StudyIntent: String, CaseIterable, Identifiable {
        case newConcept
        case weakness
        case exam

        var id: String { rawValue }

        var title: String {
            switch self {
            case .newConcept: "새 개념 배우기"
            case .weakness: "틀린 문제 복습"
            case .exam: "시험 대비하기"
            }
        }

        var detail: String {
            switch self {
            case .newConcept: "과목과 단원을 고르고 개념부터 시작해요."
            case .weakness: "오늘 다시 풀 문제를 우선순위대로 모아 봐요."
            case .exam: "평가·배치고사·모의고사에서 실력을 확인해요."
            }
        }

        var icon: String {
            switch self {
            case .newConcept: "point.topleft.down.to.point.bottomright.curvepath"
            case .weakness: "arrow.counterclockwise.circle.fill"
            case .exam: "checkmark.seal.fill"
            }
        }

        var destination: AppStore.Route {
            switch self {
            case .newConcept: .curriculum
            case .weakness: .wrongNotes
            case .exam: .assess
            }
        }
    }

    private var triggerKey: String {
        [
            store.authProvider ?? "",
            accountRole,
            store.serverProfile?.dashboardTutorial?.status ?? "",
            String(store.serverProfile?.dashboardTutorial?.shouldAutoStart == true),
            String(store.requestedDashboardTutorial),
        ].joined(separator: "|")
    }

    var body: some View {
        Group {
            if isPresented {
                GeometryReader { proxy in
                    ZStack {
                        Color.black.opacity(0.64)
                            .ignoresSafeArea()

                        onboardingCard(compactHeight: proxy.size.height < 500)
                            .frame(maxWidth: 760)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(.horizontal, max(16, proxy.safeAreaInsets.leading + 16))
                            .padding(.vertical, max(12, proxy.safeAreaInsets.bottom + 12))
                    }
                }
                .transition(.opacity)
                .zIndex(19_500)
                .accessibilityElement(children: .contain)
                .accessibilityAddTraits(.isModal)
            }
        }
        .task(id: triggerKey) { presentIfNeeded() }
    }

    private func onboardingCard(compactHeight: Bool) -> some View {
        VStack(spacing: 0) {
            if isStaffAccount && !dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading,
                       spacing: compactHeight ? Tokens.Space.s3 : Tokens.Space.s5) {
                    header(compactHeight: compactHeight)
                    onboardingError
                }
                .padding(compactHeight ? Tokens.Space.s4 : Tokens.Space.s6)
            } else {
                ScrollView {
                    VStack(alignment: .leading,
                           spacing: compactHeight ? Tokens.Space.s3 : Tokens.Space.s5) {
                        header(compactHeight: compactHeight)
                        if !isStaffAccount {
                            intentPicker(compactHeight: compactHeight)
                            coachPicker(compactHeight: compactHeight)
                        }
                        onboardingError
                    }
                    .padding(compactHeight ? Tokens.Space.s4 : Tokens.Space.s6)
                }
                .scrollIndicators(dynamicTypeSize.isAccessibilitySize ? .visible : .hidden)
            }

            actionBar(compactHeight: compactHeight)
        }
        .background(
            Color(uiColor: .systemBackground),
            in: RoundedRectangle(cornerRadius: Tokens.Radius.xl, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.xl, style: .continuous))
        .shadow(color: .black.opacity(0.22), radius: 28, y: 12)
    }

    @ViewBuilder private var onboardingError: some View {
        if let errorMessage {
            Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                .font(.mCaption)
                .foregroundStyle(Tokens.dangerInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func header(compactHeight: Bool) -> some View {
        HStack(alignment: .top, spacing: Tokens.Space.s3) {
            VStack(alignment: .leading, spacing: Tokens.Space.s1) {
                Text(isStaffAccount ? staffTitle : "첫 공부를 정해볼까요?")
                    .font(compactHeight ? .mHeading : .mTitle)
                    .foregroundStyle(Tokens.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text(isStaffAccount
                     ? staffDetail
                     : "설명부터 외울 필요 없어요. 지금 필요한 공부 하나를 고르면 바로 그 화면에서 시작합니다.")
                    .font(.mCallout)
                    .foregroundStyle(Tokens.text2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: Tokens.Space.s2)
            BrandMark(tile: true)
                .frame(width: compactHeight ? 36 : 44, height: compactHeight ? 36 : 44)
                .accessibilityHidden(true)
        }
    }

    private func intentPicker(compactHeight: Bool) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
            Text("오늘의 목적")
                .font(.mCaption)
                .foregroundStyle(Tokens.text3)
            if compactHeight && !dynamicTypeSize.isAccessibilitySize {
                HStack(alignment: .top, spacing: Tokens.Space.s2) {
                    ForEach(StudyIntent.allCases) { intent in
                        intentButton(intent, compact: true)
                    }
                }
            } else {
                VStack(spacing: Tokens.Space.s2) {
                    ForEach(StudyIntent.allCases) { intent in
                        intentButton(intent, compact: compactHeight)
                    }
                }
            }
        }
    }

    private func intentButton(_ intent: StudyIntent, compact: Bool) -> some View {
        let selected = intent == selectedIntent
        return Button {
            selectedIntent = intent
        } label: {
            HStack(alignment: .top, spacing: Tokens.Space.s2) {
                Image(systemName: intent.icon)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(selected ? Tokens.actionPrimary : Tokens.text2)
                    .frame(width: 24, height: 24)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(intent.title)
                        .font(.mBodyB)
                        .foregroundStyle(Tokens.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    if !compact {
                        Text(intent.detail)
                            .font(.mCaption)
                            .foregroundStyle(Tokens.text2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? Tokens.actionPrimary : Tokens.lineStrong)
                    .accessibilityHidden(true)
            }
            .padding(Tokens.Space.s3)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .background(selected ? Tokens.primarySoft : Tokens.paper,
                        in: RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous)
                    .strokeBorder(selected ? Tokens.actionPrimary : Tokens.line,
                                  lineWidth: selected ? 1.5 : 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(intent.title), \(intent.detail)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func coachPicker(compactHeight: Bool) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
            Text("코치 말투")
                .font(.mCaption)
                .foregroundStyle(Tokens.text3)
            Picker("코치 말투", selection: $selectedCoach) {
                ForEach(SpiceLevel.allCases) { level in
                    Text(level.name).tag(level)
                }
            }
            .pickerStyle(.segmented)
            Text(coachDescription)
                .font(.mCaption)
                .foregroundStyle(Tokens.text2)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(compactHeight ? 1 : nil)
        }
    }

    private var coachDescription: String {
        switch selectedCoach {
        case .mild: "틀린 이유와 다음 행동을 차분하게 알려줘요."
        case .spicy: "같은 내용을 더 직설적으로 짚어줘요."
        case .silent: "코치 멘트 없이 문제와 풀이에만 집중해요."
        }
    }

    private func actionBar(compactHeight: Bool) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Tokens.Space.s3) {
                skipButton
                Spacer(minLength: Tokens.Space.s3)
                startButton
                    .frame(minWidth: 210)
            }
            VStack(spacing: Tokens.Space.s2) {
                startButton
                skipButton
            }
        }
        .padding(.horizontal, compactHeight ? Tokens.Space.s4 : Tokens.Space.s6)
        .padding(.vertical, compactHeight ? Tokens.Space.s2 : Tokens.Space.s4)
        .background(Color(uiColor: .systemBackground))
        .overlay(alignment: .top) { Rectangle().fill(Tokens.line).frame(height: 0.5) }
    }

    private var startButton: some View {
        Button {
            finish(skipped: false)
        } label: {
            HStack(spacing: Tokens.Space.s2) {
                if saving { ProgressView().tint(Tokens.onBrand) }
                Text(saving ? "저장 중" : (isStaffAccount ? staffActionTitle : "\(selectedIntent.title) 시작"))
                if !saving { Image(systemName: "arrow.right") }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(saving)
    }

    private var skipButton: some View {
        Button(isStaffAccount ? "나중에, 홈으로" : "홈부터 둘러보기") { finish(skipped: true) }
            .font(.mCallout)
            .foregroundStyle(Tokens.text2)
            .frame(minHeight: 44)
            .buttonStyle(.plain)
            .disabled(saving)
    }

    @MainActor
    private func presentIfNeeded() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-firstRunFixture") {
            guard !isPresented else { return }
            store.isTutorialPresentationActive = true
            isPresented = true
            return
        }
        #endif
        guard !isPresented,
              !store.isSessionMode,
              store.authProvider == "server",
              !store.requestedDashboardTutorial,
              store.serverProfile?.dashboardTutorial?.shouldAutoStart == true else { return }
        selectedCoach = SpiceLevel.fromServer(store.serverProfile?.coachMode)
        store.isTutorialPresentationActive = true
        withAnimation(reduceMotion || !store.motionOn ? nil : .easeOut(duration: 0.2)) {
            isPresented = true
        }
    }

    private func finish(skipped: Bool) {
        guard !saving else { return }
        saving = true
        errorMessage = nil
        Task { @MainActor in
            do {
                if !skipped && !isStaffAccount {
                    try await ServerAPI.updateCoachMode(selectedCoach.serverValue)
                    store.coach.level = selectedCoach
                }
                _ = try await ServerAPI.updateDashboardTutorial(skipped ? "SKIP" : "COMPLETE")
                await store.refreshServerProfile()
            } catch {
                saving = false
                errorMessage = (error as? ServerAPIError)?.errorDescription
                    ?? "첫 설정을 저장하지 못했습니다. 다시 시도해 주세요."
                return
            }
            store.requestedDashboardTutorial = false
            store.isTutorialPresentationActive = false
            store.route = skipped ? .home : (isStaffAccount ? .academy : selectedIntent.destination)
            saving = false
            withAnimation(reduceMotion || !store.motionOn ? nil : .easeOut(duration: 0.18)) {
                isPresented = false
            }
        }
    }
}
