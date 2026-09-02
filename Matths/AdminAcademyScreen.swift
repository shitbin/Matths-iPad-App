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
        errorMessage = nil
        noticeMessage = nil
        await load()
    }

    func load() async {
        let requestGeneration = generation
        isLoading = dashboard == nil
        errorMessage = nil
        do {
            let value = try await ServerAPI.adminAcademyDashboard()
            guard requestGeneration == generation else { return }
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
        actionID = academy.id
        errorMessage = nil
        noticeMessage = nil
        do {
            dashboard = try await ServerAPI.reviewAcademyApplication(
                academyID: academy.id, approve: approve)
            noticeMessage = approve
                ? "\(academy.name) 등록을 승인했습니다."
                : "\(academy.name) 등록을 반려했습니다."
        } catch {
            errorMessage = readable(error)
        }
        actionID = nil
    }

    private func readable(_ error: Error) -> String {
        (error as? ServerAPIError)?.errorDescription
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
    @State private var showsToolHub = {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-adminToolHub")
        #else
        false
        #endif
    }()
    @State private var toolQuery = ""
    @State private var showsExplorer = {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-adminAcademyExplorer")
        #else
        false
        #endif
    }()
    @State private var showsOperations = {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-adminOperations")
        #else
        false
        #endif
    }()
    @State private var showsUsers = {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-adminUsers")
            || ProcessInfo.processInfo.arguments.contains("-adminUserActivity")
            || ProcessInfo.processInfo.arguments.contains("-adminUserAssessment")
        #else
        false
        #endif
    }()
    @State private var showsFinance = {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-adminFinance")
            || ProcessInfo.processInfo.arguments.contains("-adminRefunds")
            || ProcessInfo.processInfo.arguments.contains("-adminPaybacks")
        #else
        false
        #endif
    }()
    @State private var showsCommunity = {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-adminCommunity")
        #else
        false
        #endif
    }()
    @State private var showsWeeklyMock = {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-adminWeeklyMock")
        #else
        false
        #endif
    }()
    @State private var showsArchive = {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-adminArchive")
        #else
        false
        #endif
    }()
    @State private var showsStore = {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-adminStore")
        #else
        false
        #endif
    }()
    @State private var showsArenaAdmin = {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-adminArena")
        #else
        false
        #endif
    }()
    @State private var showsDataAnalysis = {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-adminDataAnalysis")
        #else
        false
        #endif
    }()
    @State private var showsPdfForensics = {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-adminPdfForensics")
        #else
        false
        #endif
    }()
    @State private var showsArenaPolicies = {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-adminArenaPolicies")
        #else
        false
        #endif
    }()
    @State private var showsProblemBanks = {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-adminProblemBanks")
        #else
        false
        #endif
    }()
    @State private var showsCoachSuggestions = {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-adminCoachSuggestions")
        #else
        false
        #endif
    }()
    @State private var showsOperationsGuide = {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-adminOperationsGuide")
        #else
        false
        #endif
    }()

    private var compactLandscape: Bool {
        verticalSizeClass == .compact && !dynamicTypeSize.isAccessibilitySize
    }

    var body: some View {
        Group {
            if showsToolHub {
                adminToolHub
            } else if showsOperationsGuide {
                AdminOperationsGuideScreen { showsOperationsGuide = false }
            } else if showsCoachSuggestions {
                CoachSuggestionsScreen { showsCoachSuggestions = false }
            } else if showsProblemBanks {
                AdminProblemBankScreen { showsProblemBanks = false }
            } else if showsArenaPolicies {
                AdminArenaPolicyScreen { showsArenaPolicies = false }
            } else if showsPdfForensics {
                AdminPdfForensicsScreen { showsPdfForensics = false }
            } else if showsDataAnalysis {
                AdminDataAnalysisScreen { showsDataAnalysis = false }
            } else if showsArenaAdmin {
                AdminArenaScreen { showsArenaAdmin = false }
            } else if showsStore {
                AdminStoreScreen { showsStore = false }
            } else if showsArchive {
                AdminArchiveScreen { showsArchive = false }
            } else if showsWeeklyMock {
                AdminWeeklyMockScreen { showsWeeklyMock = false }
            } else if showsCommunity {
                AdminCommunityScreen { showsCommunity = false }
            } else if showsFinance {
                AdminFinanceScreen { showsFinance = false }
            } else if showsUsers {
                AdminUsersScreen { showsUsers = false }
            } else if showsOperations {
                AdminOperationsScreen { showsOperations = false }
            } else if showsExplorer {
                AdminAcademyExplorer { showsExplorer = false }
            } else {
                GeometryReader { viewport in
                    Group {
                        if model.isLoading && model.dashboard == nil {
                            stateShell {
                                ProgressView().tint(Tokens.primary)
                                Text("운영 승인함을 불러오는 중입니다").font(.mHeading)
                            }
                        } else if let dashboard = model.dashboard {
                            dashboardView(dashboard, viewport: viewport)
                        } else {
                            failureState
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .background(Tokens.paper)
            }
        }
        .task { if model.dashboard == nil { await model.load() } }
        .onReceive(NotificationCenter.default.publisher(for: DataScope.didSwitchNotification)) { _ in
            Task { await model.resetAndLoad() }
        }
        .confirmationDialog(
            reviewIntent?.approve == true ? "학원 등록을 승인할까요?" : "학원 등록을 반려할까요?",
            isPresented: Binding(
                get: { reviewIntent != nil },
                set: { if !$0 { reviewIntent = nil } }),
            titleVisibility: .visible,
            presenting: reviewIntent
        ) { intent in
            Button(intent.approve ? "승인" : "반려", role: intent.approve ? nil : .destructive) {
                reviewIntent = nil
                Task { await model.review(intent.academy, approve: intent.approve) }
            }
            Button("취소", role: .cancel) { reviewIntent = nil }
        } message: { intent in
            Text(intent.approve
                 ? "\(intent.academy.name)의 계약 유효기간과 신청자 계정을 확인한 뒤 활성화합니다."
                 : "\(intent.academy.name)의 신청 상태와 원장 소속 요청을 반려 처리합니다.")
        }
    }

    @ViewBuilder
    private func dashboardView(
        _ dashboard: ServerAPI.AdminAcademyDashboard,
        viewport: GeometryProxy
    ) -> some View {
        if compactLandscape {
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
                    Text("운영 도구 15개")
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
                HStack(spacing: Tokens.Space.s3) {
                    Button {
                        showsToolHub = false
                    } label: {
                        Image(systemName: "chevron.left")
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("승인함으로 돌아가기")

                    VStack(alignment: .leading, spacing: 1) {
                        Text("관리자 운영 도구")
                            .font(.mTitle)
                            .foregroundStyle(Tokens.ink)
                        Text("해야 할 일을 검색하거나 업무 영역에서 고르세요")
                            .font(.mCaption)
                            .foregroundStyle(Tokens.text3)
                    }
                    Spacer(minLength: Tokens.Space.s3)
                    TextField("도구·업무 검색", text: $toolQuery)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: compactLandscape ? 290 : 360)
                        .accessibilityHint("예: 환불, 신고, PDF, 문제")
                }
                .padding(.horizontal, max(16, viewport.safeAreaInsets.leading + 16))
                .padding(.vertical, Tokens.Space.s3)
                .background(Tokens.surface)

                ScrollView {
                    LazyVGrid(
                        columns: Array(
                            repeating: GridItem(.flexible(), spacing: Tokens.Space.s3),
                            count: compactLandscape ? 2 : 1
                        ),
                        alignment: .leading,
                        spacing: Tokens.Space.s3
                    ) {
                        toolCard("문의·운영 할 일", detail: "답변 대기 문의와 오늘의 운영 작업", icon: "tray.full.fill", keywords: "문의 공지 할일") { openTool { showsOperations = true } }
                        toolCard("사용자·제재 관리", detail: "계정·보호자·경고·감사 이력", icon: "person.2.fill", keywords: "회원 학생 부모 제재 감사") { openTool { showsUsers = true } }
                        toolCard("게시판 신고·제재", detail: "신고 검토와 게시글·댓글 조치", icon: "exclamationmark.bubble.fill", keywords: "커뮤니티 신고 게시글 댓글") { openTool { showsCommunity = true } }
                        toolCard("주간 모의고사 운영", detail: "회차·채점·이의신청·공정성", icon: "doc.text.fill", keywords: "시험 채점 이의신청 소명") { openTool { showsWeeklyMock = true } }
                        toolCard("GOAT Arena 운영", detail: "실시간 경기·무결성·랭킹", icon: "crown.fill", keywords: "경기 부정행위 랭킹") { openTool { showsArenaAdmin = true } }
                        toolCard("전체 학원 운영", detail: "구성원·반·수업·출결·계약", icon: "building.2.fill", keywords: "학원 반 수업 출석 계약") { openTool { showsExplorer = true } }
                        toolCard("재무·환불·페이백", detail: "출금 장부와 지급 처리", icon: "wonsign.circle.fill", keywords: "결제 돈 출금 환불 페이백") { openTool { showsFinance = true } }
                        toolCard("자료실·배포 파일", detail: "권한·업로드·휴지통·복구", icon: "folder.fill", keywords: "파일 폴더 자료 복구") { openTool { showsArchive = true } }
                        toolCard("수험관·상점 운영", detail: "콘텐츠·상품·카테고리", icon: "storefront.fill", keywords: "상품 상점 수험관 콘텐츠") { openTool { showsStore = true } }
                        toolCard("Arena 정책·가격", detail: "가격·상점·매치메이킹 정책", icon: "slider.horizontal.3", keywords: "가격 정책 매칭") { openTool { showsArenaPolicies = true } }
                        toolCard("문제 유형·Arena 데이터", detail: "유형 리비전과 T1–T9 데이터", icon: "square.stack.3d.up.fill", keywords: "문제 유형 티어 데이터") { openTool { showsProblemBanks = true } }
                        toolCard("코치 문구 검수", detail: "학생 제안 승인·반려", icon: "text.bubble.fill", keywords: "코치 문구 제안") { openTool { showsCoachSuggestions = true } }
                        toolCard("월별 운영 지표", detail: "결제·학습권·Arena 지표", icon: "chart.bar.xaxis", keywords: "통계 분석 지표 월별") { openTool { showsDataAnalysis = true } }
                        toolCard("PDF·스크린샷 유출 추적", detail: "서명 검증과 OCR 분석", icon: "viewfinder", keywords: "PDF 스크린샷 유출 OCR") { openTool { showsPdfForensics = true } }
                        toolCard("운영 매뉴얼·DB 스키마", detail: "권한·자동화·보존·장애 대응", icon: "book.closed.fill", keywords: "매뉴얼 DB 스키마 장애 저장") { openTool { showsOperationsGuide = true } }
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
        if toolQuery.isEmpty || "\(title) \(detail) \(keywords)".localizedCaseInsensitiveContains(toolQuery) {
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
    }

    private func openTool(_ action: () -> Void) {
        action()
        toolQuery = ""
        showsToolHub = false
    }

    private var toolSearchHasMatches: Bool {
        guard !toolQuery.isEmpty else { return true }
        return "문의 운영 공지 할일 사용자 회원 학생 부모 제재 감사 커뮤니티 신고 게시판 게시글 댓글 주간 모의고사 시험 채점 이의신청 소명 GOAT Arena 경기 부정행위 무결성 랭킹 전체 학원 반 수업 출석 계약 재무 결제 돈 출금 환불 페이백 자료실 배포 파일 폴더 복구 수험관 상품 상점 카테고리 콘텐츠 가격 정책 매치메이킹 문제 유형 티어 데이터 코치 문구 제안 통계 분석 지표 월별 PDF 스크린샷 유출 OCR 매뉴얼 DB 스키마 장애 저장 자동화 보존"
            .localizedCaseInsensitiveContains(toolQuery)
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
