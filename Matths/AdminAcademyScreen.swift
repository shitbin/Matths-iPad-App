import SwiftUI

@MainActor
final class AdminAcademyScreenModel: ObservableObject {
    @Published var dashboard: ServerAPI.AdminAcademyDashboard?
    @Published var isLoading = false
    @Published var actionID: String?
    @Published var errorMessage: String?
    @Published var noticeMessage: String?

    private var generation = UUID()

    func resetAndLoad() async {
        generation = UUID()
        dashboard = nil
        actionID = nil
        errorMessage = nil
        noticeMessage = nil
        await load()
    }

    func load() async {
        let requestGeneration = generation
        let account = DataScope.slot
        let authorization = ServerAPI.authorizationForCurrentRequest()
        isLoading = dashboard == nil
        errorMessage = nil
        do {
            let value = try await ServerAPI.adminAcademyDashboard(authorization: authorization)
            guard requestGeneration == generation, account == DataScope.slot,
                  ServerAPI.isCurrentAuthorization(authorization) else { return }
            dashboard = value
        } catch is CancellationError {
            return
        } catch {
            guard requestGeneration == generation else { return }
            errorMessage = readable(error)
        }
        if requestGeneration == generation { isLoading = false }
    }

    func review(_ academy: ServerAPI.AdminAcademyApplication, approve: Bool) async {
        guard actionID == nil else { return }
        let requestGeneration = generation
        let account = DataScope.slot
        let authorization = ServerAPI.authorizationForCurrentRequest()
        actionID = academy.id
        errorMessage = nil
        noticeMessage = nil
        do {
            let response = try await ServerAPI.reviewAcademyApplication(
                academyID: academy.id, approve: approve, authorization: authorization)
            guard requestGeneration == generation, account == DataScope.slot,
                  ServerAPI.isCurrentAuthorization(authorization) else { return }
            dashboard = response
            noticeMessage = approve
                ? "\(academy.name) 등록을 승인했습니다."
                : "\(academy.name) 등록을 반려했습니다."
        } catch {
            guard requestGeneration == generation, account == DataScope.slot else { return }
            errorMessage = readable(error)
        }
        actionID = nil
    }

    private func readable(_ error: Error) -> String {
        if (error as? ServerAPIError)?.statusCode == 403 {
            generation = UUID(); dashboard = nil; actionID = nil; isLoading = false
        }
        return (error as? ServerAPIError)?.errorDescription
            ?? (error as NSError).localizedDescription
    }
}

/// 운영자 모바일 작업대. 승인·반려부터 계약, 구성원, 반, 수업·과제, 출결과 통계까지
/// Bearer API 기반 네이티브 화면에서 처리한다.
struct AdminAcademyScreen: View {
    private struct ReviewIntent: Identifiable {
        let academy: ServerAPI.AdminAcademyApplication
        let approve: Bool
        var id: String { "\(academy.id):\(approve)" }
    }

    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @StateObject private var model = AdminAcademyScreenModel()
    @State private var reviewIntent: ReviewIntent?
    @State private var navigation = Self.initialNavigation
    @State private var toolQuery = ""

    private static var initialNavigation: AdminWorkspaceNavigationState {
        var state = AdminWorkspaceNavigationState()
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        let fixtures: [(String, AdminWorkspaceTool)] = [
            ("-adminAcademyExplorer", .academies), ("-adminOperations", .operations),
            ("-adminUsers", .users), ("-adminUserActivity", .users), ("-adminUserAssessment", .users),
            ("-adminFinance", .finance), ("-adminRefunds", .finance), ("-adminPaybacks", .finance),
            ("-adminCommunity", .community), ("-adminWeeklyMock", .weeklyMock),
            ("-adminArchive", .archive), ("-adminStore", .store), ("-adminArena", .arena),
            ("-adminDataAnalysis", .dataAnalysis), ("-adminPdfForensics", .pdfForensics),
            ("-adminArenaPolicies", .arenaPolicies), ("-adminProblemBanks", .problemBanks),
            ("-adminCoachSuggestions", .coachSuggestions), ("-adminOperationsGuide", .operationsGuide)
        ]
        if let fixture = fixtures.first(where: { arguments.contains($0.0) }) { state.open(fixture.1) }
        if arguments.contains("-adminToolHub") { state.showDirectory() }
        #endif
        return state
    }

    private var showsToolHub: Bool {
        get { navigation.tool == nil }
        nonmutating set { if newValue { navigation.showDirectory() } else { navigation.open(.approvals) } }
    }
    private var showsExplorer: Bool {
        get { navigation.tool == .academies }
        nonmutating set { if newValue { navigation.open(.academies) } else { navigation.showDirectory() } }
    }

    private var compactLandscape: Bool {
        verticalSizeClass == .compact && !dynamicTypeSize.isAccessibilitySize
    }

    var body: some View {
        StaffWorkspaceContainer(
            title: "운영 관리", subtitle: "승인·운영·정산 작업공간",
            destinations: AdminWorkspaceArea.allCases.map {
                StaffWorkspaceDestination(id: $0.rawValue, title: $0.title, symbol: $0.symbol)
            }, selectedID: navigation.area.rawValue,
            onSelect: { if let next = AdminWorkspaceArea(rawValue: $0) { navigation.select(next) } }
        ) {
            VStack(spacing: 0) {
                if navigation.tool == nil {
                HStack {
                    Text(navigation.area.title).font(.mHeading).foregroundStyle(Tokens.ink)
                    Spacer()
                    if navigation.tool != nil {
                        Button("업무 목록") { navigation.showDirectory() }.font(.mCaption).frame(minHeight: 44)
                    }
                }
                .padding(.horizontal, Tokens.Space.s3)
                .background(Tokens.surface)
                }
                ZStack(alignment: .topLeading) {
                    ForEach(AdminWorkspaceTool.allCases.filter { navigation.visitedTools.contains($0) }) { tool in
                        toolContent(tool)
                            .environment(\.staffWorkspaceActive, navigation.tool == tool)
                            .opacity(navigation.tool == tool ? 1 : 0)
                            .allowsHitTesting(navigation.tool == tool)
                            .accessibilityHidden(navigation.tool != tool)
                            .zIndex(navigation.tool == tool ? 1 : 0)
                    }
                    if navigation.tool == nil { adminToolHub.zIndex(2) }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .task { if model.dashboard == nil { await model.load() } }
        .onReceive(NotificationCenter.default.publisher(for: DataScope.didSwitchNotification)) { _ in
            navigation.reset()
            reviewIntent = nil
            toolQuery = ""
            Task { await model.resetAndLoad() }
        }
        .compactHeightSheet(item: $reviewIntent) { intent in
            StaffChangeReview(
                title: intent.approve ? "학원 등록 승인" : "학원 등록 반려",
                changes: [StaffChangeValue(label: intent.academy.name, before: "등록 승인 대기", after: intent.approve ? "운영 활성화" : "등록 반려")],
                impact: intent.approve
                    ? "계약 유효기간과 신청자 계정을 확인한 후 학원과 원장 권한을 활성화합니다."
                    : "학원 신청과 원장 소속 요청을 반려합니다. 신청자가 결과를 확인할 수 있습니다.",
                actionTitle: intent.approve ? "승인" : "반려", destructive: !intent.approve, isWorking: model.actionID != nil,
                onCancel: { reviewIntent = nil },
                onConfirm: {
                    Task {
                        await model.review(intent.academy, approve: intent.approve)
                        if model.errorMessage == nil { reviewIntent = nil }
                    }
                })
        }
    }

    @ViewBuilder private func toolContent(_ tool: AdminWorkspaceTool) -> some View {
        switch tool {
        case .approvals:
            GeometryReader { viewport in
                Group {
                    if model.isLoading && model.dashboard == nil {
                        stateShell { ProgressView().tint(Tokens.primary); Text("운영 승인함을 불러오는 중입니다").font(.mHeading) }
                    } else if let dashboard = model.dashboard { dashboardView(dashboard, viewport: viewport) }
                    else { failureState }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        case .operations: AdminOperationsScreen { navigation.showDirectory() }
        case .academies: AdminAcademyExplorer { navigation.showDirectory() }
        case .users: AdminUsersScreen { navigation.showDirectory() }
        case .community: AdminCommunityScreen { navigation.showDirectory() }
        case .weeklyMock: AdminWeeklyMockScreen { navigation.showDirectory() }
        case .archive: AdminArchiveScreen { navigation.showDirectory() }
        case .store: AdminStoreScreen { navigation.showDirectory() }
        case .arena: AdminArenaScreen { navigation.showDirectory() }
        case .finance: AdminFinanceScreen { navigation.showDirectory() }
        case .dataAnalysis: AdminDataAnalysisScreen { navigation.showDirectory() }
        case .pdfForensics: AdminPdfForensicsScreen { navigation.showDirectory() }
        case .arenaPolicies: AdminArenaPolicyScreen { navigation.showDirectory() }
        case .problemBanks: AdminProblemBankScreen { navigation.showDirectory() }
        case .coachSuggestions: CoachSuggestionsScreen { navigation.showDirectory() }
        case .operationsGuide: AdminOperationsGuideScreen { navigation.showDirectory() }
        }
    }

    @ViewBuilder
    private func dashboardView(
        _ dashboard: ServerAPI.AdminAcademyDashboard,
        viewport: GeometryProxy
    ) -> some View {
        if StaffWorkspaceMetrics.usesListDetail(width: viewport.size.width) {
            HStack(alignment: .top, spacing: Tokens.Space.s3) {
                summaryColumn(dashboard)
                    .frame(width: min(290, viewport.size.width * 0.34))
                applicationColumn(dashboard)
            }
            .padding(.horizontal, max(12, viewport.safeAreaInsets.leading + 12))
            .padding(.vertical, Tokens.Space.s2)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: Tokens.Space.s4) {
                    summaryColumn(dashboard)
                    applicationColumn(dashboard, ownsScroll: false)
                }
                .readableWidth(Tokens.readableWidth)
                .adaptiveHPadding()
                .adaptiveVPadding()
            }
            .refreshable { await model.load() }
        }
    }

    private func summaryColumn(_ dashboard: ServerAPI.AdminAcademyDashboard) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s3) {
            HStack(spacing: Tokens.Space.s3) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 23, weight: .semibold))
                    .foregroundStyle(Tokens.onBrand)
                    .frame(width: 48, height: 48)
                    .background(Tokens.actionPrimary,
                                in: RoundedRectangle(cornerRadius: Tokens.Radius.md,
                                                     style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("운영 승인함")
                        .font(compactLandscape ? .mBodyB : .mTitle)
                        .foregroundStyle(Tokens.ink)
                    Text("학원 등록 병목 처리")
                        .font(.mCaption)
                        .foregroundStyle(Tokens.text2)
                }
            }

            HStack(spacing: Tokens.Space.s2) {
                metric(value: dashboard.pendingCount, label: "승인 대기",
                       emphasized: dashboard.pendingCount > 0)
                metric(value: dashboard.activeCount, label: "운영 중", emphasized: false)
            }

            Button("전체 학원 운영") {
                showsExplorer = true
            }
            .buttonStyle(SecondaryButtonStyle())
            .accessibilityHint("모든 학원의 구성원, 반, 초대와 출결 상태를 확인합니다")

            Button {
                toolQuery = ""
                showsToolHub = true
            } label: {
                HStack(spacing: Tokens.Space.s2) {
                    Image(systemName: "square.grid.2x2.fill")
                    Text("운영 업무 목록")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .accessibilityHint("사용자, 결제, 콘텐츠, Arena와 진단 도구를 검색해서 엽니다")

            feedbackText
        }
        .adminAcademySurface()
    }

    private var adminToolHub: some View {
        GeometryReader { viewport in
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                    HStack {
                        Text("업무를 고르거나 전체 도구를 검색하세요")
                            .font(.mCaption).foregroundStyle(Tokens.text3)
                        Spacer(minLength: 0)
                        Button("이전 업무") {
                            let area = navigation.area
                            navigation.select(area)
                        }.font(.mCaption).frame(minHeight: 44)
                    }
                    TextField("도구·업무 검색", text: $toolQuery)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityHint("예: 환불, 신고, PDF, 문제")
                }
                .padding(.horizontal, max(16, viewport.safeAreaInsets.leading + 16))
                .padding(.vertical, Tokens.Space.s3)
                .background(Tokens.surface)

                ScrollView {
                    LazyVGrid(
                        columns: Array(
                            repeating: GridItem(.flexible(), spacing: Tokens.Space.s3),
                            count: viewport.size.width >= 760 ? 2 : 1
                        ),
                        alignment: .leading,
                        spacing: Tokens.Space.s3
                    ) {
                        ForEach(filteredTools) { tool in
                            toolCard(tool.title, detail: tool.detail, icon: tool.symbol, keywords: tool.area.title) {
                                navigation.open(tool)
                            }
                        }
                    }
                    .padding(.horizontal, max(16, viewport.safeAreaInsets.leading + 16))
                    .padding(.vertical, Tokens.Space.s4)

                    if !toolSearchHasMatches {
                        ContentUnavailableView(
                            "검색 결과 없음",
                            systemImage: "magnifyingglass",
                            description: Text("업무명이나 기능을 다른 단어로 검색해 보세요.")
                        )
                        .frame(maxWidth: .infinity, minHeight: 280)
                    }
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .background(Tokens.paper)
        }
    }

    @ViewBuilder
    private func toolCard(
        _ title: String,
        detail: String,
        icon: String,
        keywords: String,
        action: @escaping () -> Void
    ) -> some View {
            Button(action: action) {
                HStack(spacing: Tokens.Space.s3) {
                    Image(systemName: icon)
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(Tokens.primary)
                        .frame(width: 40, height: 40)
                        .background(Tokens.primary.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(.mBodyB)
                            .foregroundStyle(Tokens.ink)
                            .lineLimit(1)
                        Text(detail)
                            .font(.mMicro)
                            .foregroundStyle(Tokens.text3)
                            .lineLimit(2)
                    }
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Tokens.text3)
                }
                .padding(Tokens.Space.s3)
                .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
                .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
                .overlay {
                    RoundedRectangle(cornerRadius: Tokens.Radius.md)
                        .strokeBorder(Tokens.line, lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityHint("열기")
    }

    private var filteredTools: [AdminWorkspaceTool] {
        AdminWorkspaceTool.allCases.filter {
            (toolQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? $0.area == navigation.area : true)
                && $0.matches(toolQuery)
        }
    }

    private var toolSearchHasMatches: Bool {
        !filteredTools.isEmpty
    }

    private func metric(value: Int, label: String, emphasized: Bool) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("\(value)").font(.mHeading.monospacedDigit())
            Text(label).font(.mMicro)
        }
        .foregroundStyle(emphasized ? Tokens.primary : Tokens.ink)
        .padding(.horizontal, Tokens.Space.s3)
        .padding(.vertical, Tokens.Space.s2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(emphasized ? Tokens.primary.opacity(0.10) : Tokens.paper,
                    in: RoundedRectangle(cornerRadius: Tokens.Radius.sm, style: .continuous))
    }

    @ViewBuilder
    private func applicationColumn(
        _ dashboard: ServerAPI.AdminAcademyDashboard,
        ownsScroll: Bool = true
    ) -> some View {
        let content = VStack(alignment: .leading, spacing: Tokens.Space.s3) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("학원 등록 요청").font(.mHeading).foregroundStyle(Tokens.ink)
                    Text(dashboard.applications.isEmpty
                         ? "지금 처리할 신청이 없습니다."
                         : "신청자와 계약 종료일을 확인하고 처리하세요.")
                        .font(.mCaption).foregroundStyle(Tokens.text3)
                }
                Spacer(minLength: Tokens.Space.s2)
                Button {
                    Task { await model.load() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Tokens.primary)
                .disabled(model.actionID != nil)
                .accessibilityLabel("승인 요청 새로고침")
            }

            if dashboard.applications.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: Tokens.Space.s2) {
                    ForEach(dashboard.applications) { application in
                        applicationRow(application)
                    }
                }
            }
        }
        .adminAcademySurface()

        if ownsScroll {
            ScrollView { content }
                .refreshable { await model.load() }
        } else {
            content
        }
    }

    @ViewBuilder
    private func applicationRow(_ application: ServerAPI.AdminAcademyApplication) -> some View {
        if compactLandscape {
            compactApplicationRow(application)
        } else {
            regularApplicationRow(application)
        }
    }

    private func compactApplicationRow(_ application: ServerAPI.AdminAcademyApplication) -> some View {
        let isWorking = model.actionID == application.id
        return HStack(spacing: Tokens.Space.s3) {
            VStack(alignment: .leading, spacing: 2) {
                Text(application.name)
                    .font(.mBodyB)
                    .foregroundStyle(Tokens.ink)
                    .lineLimit(1)
                Text(applicantLine(application))
                    .font(.mMicro)
                    .foregroundStyle(Tokens.text2)
                    .lineLimit(1)
                Text(contractLabel(application.contractEndsAt))
                    .font(.mMicro)
                    .foregroundStyle(contractIsValid(application.contractEndsAt)
                                     ? Tokens.text3 : Tokens.danger)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 6) {
                Button("반려", role: .destructive) {
                    reviewIntent = ReviewIntent(academy: application, approve: false)
                }
                .buttonStyle(.bordered)
                .tint(Tokens.danger)
                .frame(minWidth: 64, minHeight: 44)

                Button("승인") {
                    reviewIntent = ReviewIntent(academy: application, approve: true)
                }
                .buttonStyle(.borderedProminent)
                .tint(Tokens.actionPrimary)
                .frame(minWidth: 64, minHeight: 44)
            }
            .disabled(model.actionID != nil)
            .overlay { if isWorking { ProgressView().tint(Tokens.primary) } }
        }
        .padding(Tokens.Space.s3)
        .background(Tokens.paper,
                    in: RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous)
                .strokeBorder(Tokens.line, lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
    }

    private func regularApplicationRow(_ application: ServerAPI.AdminAcademyApplication) -> some View {
        let isWorking = model.actionID == application.id
        return VStack(alignment: .leading, spacing: Tokens.Space.s2) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(application.name)
                        .font(.mBodyB)
                        .foregroundStyle(Tokens.ink)
                        .lineLimit(1)
                    Text(application.applicant?.name.isEmpty == false
                         ? application.applicant!.name : "신청자 정보 없음")
                        .font(.mCaption)
                        .foregroundStyle(Tokens.text2)
                }
                Spacer(minLength: Tokens.Space.s2)
                Text(contractLabel(application.contractEndsAt))
                    .font(.mMicro)
                    .foregroundStyle(contractIsValid(application.contractEndsAt)
                                     ? Tokens.text3 : Tokens.danger)
                    .lineLimit(1)
            }

            if let email = application.applicant?.email, !email.isEmpty {
                Text(email)
                    .font(.mMicro)
                    .foregroundStyle(Tokens.text3)
                    .textSelection(.enabled)
                    .lineLimit(1)
            }

            HStack(spacing: Tokens.Space.s2) {
                Button("반려", role: .destructive) {
                    reviewIntent = ReviewIntent(academy: application, approve: false)
                }
                .buttonStyle(.bordered)
                .tint(Tokens.danger)
                .frame(maxWidth: .infinity)

                Button("승인") {
                    reviewIntent = ReviewIntent(academy: application, approve: true)
                }
                .buttonStyle(.borderedProminent)
                .tint(Tokens.actionPrimary)
                .frame(maxWidth: .infinity)
            }
            .disabled(model.actionID != nil)
            .overlay { if isWorking { ProgressView().tint(Tokens.primary) } }
        }
        .padding(Tokens.Space.s3)
        .background(Tokens.paper,
                    in: RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous)
                .strokeBorder(Tokens.line, lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
    }

    private func applicantLine(_ application: ServerAPI.AdminAcademyApplication) -> String {
        let name = application.applicant?.name.isEmpty == false
            ? application.applicant!.name : "신청자 정보 없음"
        guard let email = application.applicant?.email, !email.isEmpty else { return name }
        return "\(name) · \(email)"
    }

    private var emptyState: some View {
        VStack(spacing: Tokens.Space.s2) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Tokens.success)
            Text("대기 중인 학원 신청이 없습니다.")
                .font(.mBodyB)
                .foregroundStyle(Tokens.ink)
            Text("새 신청이 들어오면 이 목록에 바로 표시됩니다.")
                .font(.mCaption)
                .foregroundStyle(Tokens.text3)
        }
        .frame(maxWidth: .infinity, minHeight: 150)
    }

    @ViewBuilder private var feedbackText: some View {
        if let message = model.errorMessage {
            Text(message)
                .font(.mCaption)
                .foregroundStyle(Tokens.danger)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel("오류: \(message)")
        } else if let message = model.noticeMessage {
            Text(message)
                .font(.mCaption)
                .foregroundStyle(Tokens.success)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel("완료: \(message)")
        }
    }

    private var failureState: some View {
        stateShell {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Tokens.danger)
            Text("운영 승인함을 열지 못했습니다").font(.mHeading)
            Text(model.errorMessage ?? "잠시 후 다시 시도해 주세요.")
                .font(.mCaption).foregroundStyle(Tokens.text2)
                .multilineTextAlignment(.center)
            Button("다시 시도") { Task { await model.load() } }
                .buttonStyle(PrimaryButtonStyle())
        }
    }

    private func stateShell<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: Tokens.Space.s3) { content() }
            .padding(Tokens.Space.s5)
            .frame(maxWidth: 460)
            .adminAcademySurface()
    }

    private func contractLabel(_ raw: String?) -> String {
        guard let date = parseDate(raw) else { return "계약일 확인 필요" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.dateFormat = "M월 d일까지"
        return formatter.string(from: date)
    }

    private func contractIsValid(_ raw: String?) -> Bool {
        guard let date = parseDate(raw) else { return false }
        return date > Date()
    }

    private func parseDate(_ raw: String?) -> Date? {
        guard let raw else { return nil }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: raw) ?? ISO8601DateFormatter().date(from: raw)
    }
}

private struct AdminAcademySurface: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(Tokens.Space.s4)
            .background(Tokens.surface,
                        in: RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                    .strokeBorder(Tokens.line, lineWidth: 1)
            }
    }
}

private extension View {
    func adminAcademySurface() -> some View { modifier(AdminAcademySurface()) }
}
