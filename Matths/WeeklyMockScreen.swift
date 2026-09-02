//  WeeklyMockScreen.swift
//  Matths
//
//  주간 공식 모의고사 네이티브 흐름. iPad 전체 화면에서는 PDF와 OMR을 나란히,
//  Split View/Slide Over에서는 세그먼트로 전환한다.

import SwiftUI
import UniformTypeIdentifiers

struct WeeklyMockScreen: View {
    @EnvironmentObject private var store: AppStore

    private enum Page: Equatable {
        case center
        case attempt(String)
        case integrity
        case objections
    }

    @State private var page: Page = .center
    /// 이 화면 인스턴스를 연 계정. 네트워크 응답을 기다리는 사이 로그아웃하거나
    /// 다른 계정으로 들어가도 앞 학생의 시험 상태를 새 계정 화면에 쓰지 않는다.
    @State private var accountSlot = DataScope.slot

    var body: some View {
        Group {
            switch page {
            case .center:
                WeeklyMockCenterScreen(
                    accountSlot: accountSlot,
                    onClose: { store.route = .assess },
                    onOpenExam: { page = .attempt($0) },
                    onIntegrity: { page = .integrity },
                    onObjections: { page = .objections })
            case .attempt(let examId):
                WeeklyMockAttemptScreen(examId: examId, accountSlot: accountSlot) { page = .center }
            case .integrity:
                WeeklyMockIntegrityScreen(accountSlot: accountSlot) { page = .center }
            case .objections:
                WeeklyMockObjectionScreen(accountSlot: accountSlot) { page = .center }
            }
        }
        .id(accountSlot)
        .background(Tokens.paper.ignoresSafeArea())
        .onReceive(NotificationCenter.default.publisher(for: DataScope.didSwitchNotification)) { note in
            let nextSlot = note.object as? String ?? DataScope.slot
            guard nextSlot != accountSlot else { return }
            page = .center
            accountSlot = nextSlot
        }
    }
}

// MARK: - Center

private struct WeeklyMockCenterScreen: View {
    let accountSlot: String
    let onClose: () -> Void
    let onOpenExam: (String) -> Void
    let onIntegrity: () -> Void
    let onObjections: () -> Void

    @EnvironmentObject private var store: AppStore
    @State private var dashboard: ServerAPI.WeeklyMockDashboard?
    @State private var loading = true
    @State private var errorText: String?

    var body: some View {
        VStack(spacing: 0) {
            WeeklyMockHeader(
                title: "주간 공식 모의고사",
                subtitle: "매주 일요일 A, B, C형",
                closeLabel: "평가센터로 돌아가기",
                close: onClose)

            ScrollView {
                Group {
                    if loading {
                        ProgressView("시험 일정을 확인하고 있습니다")
                            .frame(maxWidth: .infinity, minHeight: 360)
                    } else if let dashboard {
                        content(dashboard)
                    } else if !ServerAPI.hasToken {
                        // 토큰 부재·401(ServerAPI 가 토큰을 지운다) — "다시 시도"는
                        // 막다른 길이라 로그인 경로를 연다. 네트워크 실패만 재시도로 남긴다.
                        loginGate
                    } else {
                        WeeklyMockFailure(
                            title: "모의고사 정보를 불러오지 못했습니다",
                            message: errorText ?? "잠시 후 다시 시도해주세요.",
                            retry: { Task { await load() } })
                    }
                }
                .readableWidth(980)
                .adaptiveHPadding()
                .padding(.vertical, Tokens.Space.s6)
            }
            .refreshable { await load() }
        }
        .task { await load() }
    }

    @ViewBuilder
    private func content(_ value: ServerAPI.WeeklyMockDashboard) -> some View {
        if !value.eligibility.allowed {
            // 잠긴 상태는 볼 것이 두 덩어리뿐이라 나눌 이유가 없다.
            VStack(alignment: .leading, spacing: Tokens.Space.s7) {
                centerHeadline(value)
                eligibilityCard(value.eligibility)
            }
        } else {
            // 가로 iPhone 에서는 "이번 주 응시"(왼쪽)와 "지난 회차·랭킹·부가 절차"(오른쪽)로
            // 나눈다. 세로로만 쌓으면 응시 버튼 뒤로 목록·대표선택·랭킹 10줄이 이어져,
            // 정작 주 행동인 응시 카드가 화면 한 칸을 넘기는 순간 사라진다.
            CompactHeightColumns(spacing: Tokens.Space.s6, stackedSpacing: Tokens.Space.s7) {
                VStack(alignment: .leading, spacing: Tokens.Space.s7) {
                    centerHeadline(value)

                    if let exam = value.currentExam {
                        currentExamCard(exam)
                    } else {
                        nextReleaseCard(value.nextReleaseAt)
                    }
                }
                .accessibilityElement(children: .contain)
            } trailing: {
                VStack(alignment: .leading, spacing: Tokens.Space.s7) {
                    if !value.weeklyExams.isEmpty {
                        VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                            Text("이번 주 A, B, C형").font(.mHeading).foregroundStyle(Tokens.ink)
                            ForEach(value.weeklyExams) { exam in
                                examRow(exam)
                                if exam.id != value.weeklyExams.last?.id { Divider().overlay(Tokens.line) }
                            }
                        }
                        .card()
                    }

                    if let selection = value.selection {
                        WeeklyMockSelectionView(selection: selection, accountSlot: accountSlot) { attemptId, deferSelection in
                            guard accountSlot == DataScope.slot else { return }
                            try await ServerAPI.selectWeeklyMockRepresentative(
                                weekKey: selection.weekKey,
                                attemptId: attemptId,
                                deferSelection: deferSelection)
                            guard accountSlot == DataScope.slot else { return }
                            await load()
                        }
                    }

                    actionGrid
                    rankingCard(value)
                }
                .accessibilityElement(children: .contain)
            }
        }
    }

    private func centerHeadline(_ value: ServerAPI.WeeklyMockDashboard) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s3) {
            Text("MATTHS 주간 공식 모의고사")
                .font(.mMicro).foregroundStyle(Tokens.primary)
            Text("같은 시간, 같은 규칙으로\n이번 주 실력을 확인합니다")
                .font(.mDisplay).foregroundStyle(Tokens.ink)
            Text(value.scheduleLabel)
                .font(.mCallout).foregroundStyle(Tokens.text2)
        }
    }

    /// 인증 게이트 — 게스트·만료 토큰에게 재시도 버튼만 남기지 않는다.
    /// 가치 한 줄과 시험 구성 프리뷰, 로그인 경로, 대체 행동 하나를 준다.
    /// 트리거는 RankArena 로그인 배너와 같다
    /// (store.signOut — 게스트 슬롯을 비우고 인증 화면으로 돌려보낸다).
    private var loginGate: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s6) {
            VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                Text("MATTHS 주간 공식 모의고사")
                    .font(.mMicro).foregroundStyle(Tokens.primary)
                Text("같은 시간, 같은 규칙으로\n이번 주 실력을 확인합니다")
                    .font(.mDisplay).foregroundStyle(Tokens.ink)
                Text("로그인하면 매주 일요일 A, B, C형 공식 모의고사에 응시하고 전국 표준화 성적을 받습니다.")
                    .font(.mCallout).foregroundStyle(Tokens.text2)
                    .fixedSize(horizontal: false, vertical: true)
                // 시험 구성 프리뷰 — 코드로 확인되는 값만 적는다.
                // 문항 수·제한 시간은 회차마다 서버가 정하므로 여기 박지 않는다.
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: Tokens.Space.s5) { guestMetaItems }
                    VStack(alignment: .leading, spacing: Tokens.Space.s2) { guestMetaItems }
                }
                .padding(.top, Tokens.Space.s2)
            }
            weeklyJourneyPreview
            VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                Button { store.signOut() } label: {
                    Label("로그인하고 응시하기", systemImage: "person.fill")
                }
                .buttonStyle(PrimaryButtonStyle())
                .frame(maxWidth: 360)
                Button("커리큘럼으로 돌아가기") { store.route = .curriculum }
                    .buttonStyle(SecondaryButtonStyle())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, Tokens.Space.s6)
    }

    private var weeklyJourneyPreview: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Tokens.Space.s2) {
                weeklyJourneyStep("1", "회차 응시", "같은 시간과 규칙", "doc.text.fill")
                weeklyJourneyStep("2", "전국 환산", "같은 기준으로 비교", "chart.bar.fill")
                weeklyJourneyStep("3", "대표 결과", "이번 주 기록 확정", "checkmark.seal.fill")
            }
            VStack(spacing: Tokens.Space.s2) {
                weeklyJourneyStep("1", "회차 응시", "같은 시간과 규칙", "doc.text.fill")
                weeklyJourneyStep("2", "전국 환산", "같은 기준으로 비교", "chart.bar.fill")
                weeklyJourneyStep("3", "대표 결과", "이번 주 기록 확정", "checkmark.seal.fill")
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("주간 공식 모의고사 진행, 회차 응시, 전국 기준 환산, 이번 주 대표 결과 확정")
    }

    private func weeklyJourneyStep(
        _ code: String,
        _ title: String,
        _ detail: String,
        _ icon: String
    ) -> some View {
        HStack(spacing: Tokens.Space.s3) {
            ZStack {
                RoundedRectangle(cornerRadius: Tokens.Radius.sm)
                    .fill(Tokens.primarySoft)
                Image(systemName: icon)
                    .font(.mCaption.weight(.bold))
                    .foregroundStyle(Tokens.primary)
            }
            .frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(code)단계").font(.mMicro).foregroundStyle(Tokens.primary)
                Text(title).font(.mBodyB).foregroundStyle(Tokens.ink)
                Text(detail).font(.mCaption).foregroundStyle(Tokens.text3)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 80, alignment: .leading)
        .padding(Tokens.Space.s3)
        .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
        .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.md)
            .strokeBorder(Tokens.line, lineWidth: 1))
    }

    @ViewBuilder private var guestMetaItems: some View {
        guestMetaItem("calendar", "매주 일요일")
        guestMetaItem("doc.on.doc", "A, B, C형 3회분")
        guestMetaItem("chart.bar.xaxis", "전국 표준화 성적")
    }

    private func guestMetaItem(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.mMicro).foregroundStyle(Tokens.text3)
            Text(text).font(.mCaption).foregroundStyle(Tokens.text2)
        }
        .accessibilityElement(children: .combine)
    }

    private func eligibilityCard(_ eligibility: ServerAPI.WeeklyMockEligibility) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s3) {
            Label(eligibility.title, systemImage: eligibility.status == "integrity-restriction" ? "exclamationmark.shield.fill" : "lock.fill")
                .font(.mHeading).foregroundStyle(Tokens.warningInk)
            Text(eligibility.message)
                .font(.mCallout).foregroundStyle(Tokens.text2)
                .fixedSize(horizontal: false, vertical: true)
            if eligibility.status == "placement-required" || eligibility.status == "verification-required" {
                Text("GOAT Arena 탭에서 배치 절차를 먼저 완료해 주세요.")
                    .font(.mCaption).foregroundStyle(Tokens.text3)
            }
        }
        .padding(Tokens.Space.s6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tokens.warningSoft, in: RoundedRectangle(cornerRadius: Tokens.Radius.lg))
    }

    private func currentExamCard(_ exam: ServerAPI.WeeklyMockExamSummary) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Tokens.Space.s6) {
                examHeroCopy(exam)
                Spacer(minLength: Tokens.Space.s4)
                examButton(exam).frame(width: 220)
            }
            VStack(alignment: .leading, spacing: Tokens.Space.s4) {
                examHeroCopy(exam)
                examButton(exam)
            }
        }
        .padding(Tokens.Space.s6)
        .background(Tokens.primarySoft, in: RoundedRectangle(cornerRadius: Tokens.Radius.xl))
        .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.xl).strokeBorder(Tokens.primary.opacity(0.28)))
    }

    private func examHeroCopy(_ exam: ServerAPI.WeeklyMockExamSummary) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
            Text("\(exam.formCode)형 \(exam.attemptNumber)회차")
                .font(.mMicro).foregroundStyle(Tokens.primary)
            Text(exam.title)
                .font(.mTitle)
                .foregroundStyle(Tokens.ink)
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(1)
            Text("\(exam.questionCount)문항, \(max(exam.durationMinutes, 100))분, 답안 서버 자동 저장")
                .font(.mCallout).foregroundStyle(Tokens.text2)
            if let release = WeeklyMockFormat.dateTime(exam.releaseAt) {
                Text("시작 \(release)").font(.mCaption).foregroundStyle(Tokens.text3)
            }
        }
    }

    private func examButton(_ exam: ServerAPI.WeeklyMockExamSummary) -> some View {
        Button {
            onOpenExam(exam.id)
        } label: {
            Label(examActionLabel(exam), systemImage: exam.attemptStatus == "in_progress" ? "arrow.right.circle.fill" : "doc.text.fill")
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(!exam.canEnterRoom && exam.attemptStatus == "new")
    }

    private func examRow(_ exam: ServerAPI.WeeklyMockExamSummary) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Tokens.Space.s4) {
                examRowCopy(exam)
                Spacer(minLength: Tokens.Space.s4)
                Button(examActionLabel(exam)) { onOpenExam(exam.id) }
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(!exam.canEnterRoom && exam.attemptStatus == "new")
            }
            VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                examRowCopy(exam)
                Button(examActionLabel(exam)) { onOpenExam(exam.id) }
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(!exam.canEnterRoom && exam.attemptStatus == "new")
            }
        }
        .padding(.vertical, Tokens.Space.s2)
    }

    private func examRowCopy(_ exam: ServerAPI.WeeklyMockExamSummary) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("\(exam.formCode)형 \(exam.title)")
                .font(.mBodyB)
                .foregroundStyle(Tokens.ink)
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(1)
            Text(examScheduleLine(exam)).font(.mCaption).foregroundStyle(Tokens.text3)
            if let performance = exam.standardizedPerformance {
                Text("표준화 성적 \(WeeklyMockFormat.score(performance))")
                    .font(.mCaption).foregroundStyle(Tokens.successInk)
            }
        }
    }

    private func nextReleaseCard(_ raw: String?) -> some View {
        HStack(spacing: Tokens.Space.s4) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 28)).foregroundStyle(Tokens.primary)
            VStack(alignment: .leading, spacing: 3) {
                Text("다음 회차를 준비 중입니다").font(.mHeading).foregroundStyle(Tokens.ink)
                Text(WeeklyMockFormat.dateTime(raw) ?? "매주 일요일 오후 3시")
                    .font(.mCallout).foregroundStyle(Tokens.text2)
            }
        }
        .card()
    }

    private var actionGrid: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Tokens.Space.s4) {
                actionCard("풀이과정 소명", "요청 문항과 제출 기한 확인", "shield.lefthalf.filled", onIntegrity)
                actionCard("문항 이의제기", "공개된 시험 문항 검토 요청", "bubble.left.and.exclamationmark.bubble.right", onObjections)
            }
            VStack(spacing: Tokens.Space.s3) {
                actionCard("풀이과정 소명", "요청 문항과 제출 기한 확인", "shield.lefthalf.filled", onIntegrity)
                actionCard("문항 이의제기", "공개된 시험 문항 검토 요청", "bubble.left.and.exclamationmark.bubble.right", onObjections)
            }
        }
    }

    private func actionCard(_ title: String, _ detail: String, _ icon: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Tokens.Space.s4) {
                Image(systemName: icon).font(.title2).foregroundStyle(Tokens.primary)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.mBodyB).foregroundStyle(Tokens.ink)
                    Text(detail).font(.mCaption).foregroundStyle(Tokens.text3)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Tokens.text4)
            }
            .card()
        }
        .buttonStyle(.plain)
    }

    private func rankingCard(_ value: ServerAPI.WeeklyMockDashboard) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s4) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(value.rankingTitle).font(.mHeading).foregroundStyle(Tokens.ink)
                    if let summary = value.rankingSummary {
                        Text("참가 \(summary.participantCount)명, 평균 \(WeeklyMockFormat.score(summary.averageScore))")
                            .font(.mCaption).foregroundStyle(Tokens.text3)
                    }
                }
                Spacer()
                if !value.rankingFinalized { Text("집계 중").font(.mCaption).foregroundStyle(Tokens.warningInk) }
            }
            if value.weeklyRanking.isEmpty {
                Text(value.rankingPending == nil ? "공개된 주간 랭킹이 없습니다." : "마지막 회차 종료 후 표준화 성적을 집계합니다.")
                    .font(.mCallout).foregroundStyle(Tokens.text3)
            } else {
                ForEach(value.weeklyRanking.prefix(10)) { row in
                    HStack(spacing: Tokens.Space.s3) {
                        Text("\(row.rank)").font(.mNumeric).frame(width: 28, alignment: .trailing)
                        Text(row.displayName).font(.mBodyB).lineLimit(1)
                        Spacer()
                        Text(row.standardizedPerformance.map(WeeklyMockFormat.score) ?? "집계 중")
                            .font(.mNumeric).foregroundStyle(Tokens.primary)
                    }
                    if row.id != value.weeklyRanking.prefix(10).last?.id { Divider().overlay(Tokens.line) }
                }
            }
        }
        .card()
    }

    private func examActionLabel(_ exam: ServerAPI.WeeklyMockExamSummary) -> String {
        switch exam.attemptStatus {
        case "in_progress": return "이어 풀기"
        case "submitted": return "결과 보기"
        case "expired": return "종료됨"
        default: return exam.canStart ? "응시 시작" : "시험장 입장"
        }
    }

    private func examScheduleLine(_ exam: ServerAPI.WeeklyMockExamSummary) -> String {
        let release = WeeklyMockFormat.dateTime(exam.releaseAt) ?? "시각 미정"
        return "\(release), \(exam.questionCount)문항, 상태 \(examStatusLabel(exam.attemptStatus))"
    }

    private func examStatusLabel(_ status: String) -> String {
        switch status {
        case "new": return "응시 전"
        case "lobby": return "입장 가능"
        case "in_progress": return "응시 중"
        case "submitted": return "제출 완료"
        case "expired": return "종료"
        default: return "확인 중"
        }
    }

    @MainActor
    private func load() async {
        guard accountSlot == DataScope.slot else { return }
        loading = dashboard == nil
        defer { loading = false }
        // 토큰이 없으면 서버를 두드리지 않는다 — 본문이 곧장 로그인 안내를 그린다.
        guard ServerAPI.hasToken else { return }
        do {
            let value = try await ServerAPI.weeklyMockDashboard()
            guard accountSlot == DataScope.slot else { return }
            dashboard = value
            errorText = nil
            // 서버가 알려 준 회차 시각으로 기기에 예고 알림을 건다.
            // 회차가 바뀌면 옛 예약은 지우고 다시 건다. 예약할 회차가 실제로 잡혀
            // 있고 권한이 아직 미결정이면, 이 시점에 한 번 권한을 묻는다
            // (LocalNotificationPermission — 알릴 것이 생겼을 때가 물을 때다).
            WeeklyMockReminder.reschedule(nextReleaseAt: value.nextReleaseAt,
                                          lobbyOpensAt: value.currentExam?.lobbyOpensAt,
                                          allowPermissionPrompt: !store.isTutorialPresentationActive)
        } catch {
            guard accountSlot == DataScope.slot else { return }
            errorText = WeeklyMockFormat.message(error)
        }
    }
}

// MARK: - Attempt / result

private struct WeeklyMockAttemptScreen: View {
    let examId: String
    let accountSlot: String
    let onClose: () -> Void

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var attempt: ServerAPI.WeeklyMockAttempt?
    @State private var answers: [String] = []
    @State private var paperURL: URL?
    @State private var pane: Pane = .paper
    @State private var now = Date()
    @State private var loading = true
    @State private var starting = false
    @State private var saving = false
    @State private var submitting = false
    @State private var draftSyncState: WeeklyMockDraftSyncState
    @State private var telemetry: [ServerAPI.WeeklyMockTelemetryEvent] = []
    @State private var errorText: String?
    @State private var confirmSubmit = false
    @State private var didRequestExpiry = false

    private enum Pane: String, CaseIterable { case paper = "문제지", omr = "답안지" }
    private let clock = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(examId: String, accountSlot: String, onClose: @escaping () -> Void) {
        self.examId = examId
        self.accountSlot = accountSlot
        self.onClose = onClose
        let draftKey = DataScope.defaultsKey(
            "matths.weeklyMock.draft.\(examId)",
            for: accountSlot)
        let dirtyKey = DataScope.defaultsKey(
            "matths.weeklyMock.draftDirty.\(examId)",
            for: accountSlot)
        let persistedDraft = WeeklyMockPersistedDraft.decode(
            UserDefaults.standard.data(forKey: draftKey),
            legacyDirty: UserDefaults.standard.bool(forKey: dirtyKey))
        _draftSyncState = State(initialValue: WeeklyMockDraftSyncState(
            persistedDirty: persistedDraft?.dirty == true))
    }

    private var questionCount: Int { attempt?.exam.questionCount ?? answers.count }
    private var answeredCount: Int { answers.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count }
    private var deadline: Date? { WeeklyMockFormat.date(attempt?.deadline) }
    private var remaining: Int? { deadline.map { max(0, Int(ceil($0.timeIntervalSince(now)))) } }
    private var taking: Bool { attempt?.state == "in-progress" }
    /// 높이가 짧은 iPhone 가로에서는 폭이 900pt보다 작아도 문제지와 답안지를
    /// 동시에 보여 준다. 종전 900pt 고정선은 852pt Pro Max까지 세그먼트 전환으로
    /// 떨어뜨려, 문제를 확인할 때마다 답안지가 사라지는 왕복을 만들었다.
    /// 접근성 글자 크기에서는 오른쪽 답안 행의 44pt 조작 영역과 라벨 폭을 지키기
    /// 위해 기존 전환형 화면을 유지한다.
    private var usesLandscapeSplitWorkspace: Bool {
        verticalSizeClass == .compact && !dynamicTypeSize.isAccessibilitySize
    }

    var body: some View {
        VStack(spacing: 0) {
            attemptHeader
            Group {
                if loading {
                    ProgressView("시험 상태를 확인하고 있습니다")
                } else if let attempt {
                    if attempt.submitted {
                        WeeklyMockResultView(
                            attempt: attempt,
                            accountSlot: accountSlot,
                            refresh: { Task { await load() } })
                    }
                    // 서버 Bearer adapter의 첫 응시 상태는 `lobby`다. 초기 앱
                    // prototype의 `not-started`도 구버전 응답 호환으로만 함께 받는다.
                    // 둘을 갈라 놓으면 첫 응시자에게 시작 CTA 대신 빈 taking 화면이
                    // 나타난다.
                    else if LearningEntryStatePolicy.isWeeklyMockLobby(attempt.state) { lobby(attempt) }
                    else { takingView(attempt) }
                } else {
                    WeeklyMockFailure(title: "시험을 열지 못했습니다", message: errorText ?? "잠시 후 다시 시도해주세요.", retry: { Task { await load() } })
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .task { await load() }
        .task(id: draftSyncState.editRevision) {
            guard draftSyncState.editRevision > 0 else { return }
            try? await Task.sleep(for: .milliseconds(650))
            guard !Task.isCancelled else { return }
            // editRevision 변경은 debounce task를 취소한다. 실제 PATCH까지 구조화
            // task에 묶으면 in-flight 요청도 취소되므로 독립 task로 직렬 저장한다.
            Task { @MainActor in await save(reportError: false) }
        }
        .onReceive(clock) { value in
            now = value
            if taking, remaining == 0, !didRequestExpiry {
                didRequestExpiry = true
                Task { await expire() }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await load(silent: true) } }
            else if taking {
                persistDraft()
                telemetry.append(.init(eventType: "VISIBILITY_CHANGED", questionNumber: nil, clientAt: Date(), visibility: "hidden", answerLength: nil))
                Task { await save(reportError: false) }
            }
        }
        .confirmationDialog("답안을 최종 제출할까요?", isPresented: $confirmSubmit, titleVisibility: .visible) {
            Button("최종 제출") { Task { await submit() } }
            Button("계속 풀기", role: .cancel) {}
        } message: {
            Text(answeredCount == questionCount ? "제출 뒤에는 답안을 바꿀 수 없습니다." : "미응답 문항이 \(max(0, questionCount - answeredCount))개 있습니다.")
        }
        .alert("요청을 완료하지 못했습니다", isPresented: Binding(get: { errorText != nil }, set: { if !$0 { errorText = nil } })) {
            Button("확인", role: .cancel) {}
        } message: { Text(errorText ?? "") }
    }


    private var attemptHeader: some View {
        VStack(spacing: 0) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Tokens.Space.s4) { closeButton; titleCopy; Spacer(); timerCopy }
                VStack(spacing: Tokens.Space.s2) {
                    HStack { closeButton; titleCopy; Spacer() }
                    if taking { timerCopy.frame(maxWidth: .infinity, alignment: .trailing) }
                }
            }
            .padding(.horizontal, Tokens.Space.s4)
            .padding(.vertical, Tokens.Space.s2)
            if taking {
                ProgressView(
                    value: Double(answeredCount),
                    total: Double(max(questionCount, 1)))
                    .tint(Tokens.primary)
                    .accessibilityLabel("모의고사 답안 진행률")
                    .accessibilityValue("\(questionCount)문항 중 \(answeredCount)문항 응답")
            }
            Divider().overlay(Tokens.line)
        }
        .background(.bar)
    }

    private var closeButton: some View {
        Button {
            if taking { Task { await save(reportError: false); onClose() } }
            else { onClose() }
        } label: {
            Image(systemName: "xmark").font(.system(size: 16, weight: .bold))
                .frame(width: 44, height: 44).background(Tokens.paper2, in: Circle())
        }
        .buttonStyle(.plain).accessibilityLabel("모의고사 센터로 돌아가기")
    }

    private var titleCopy: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(attempt.map { "주간 공식 모의고사 \($0.exam.formCode)형" } ?? "주간 공식 모의고사")
                .font(.mMicro).foregroundStyle(Tokens.primary)
            Text(headerVisibleTitle)
                .font(.mBodyB).foregroundStyle(Tokens.ink).lineLimit(1)
                // 접근성 크기에서는 시각 제목만 짧게 쓰지만, 보조 기술에는 서버가
                // 내려 준 연도·주차·회차가 포함된 전체 이름을 보존한다.
                .accessibilityLabel(attempt?.exam.title ?? "주간 공식 모의고사")
        }
    }

    private var headerVisibleTitle: String {
        guard let attempt else { return "주간 공식 모의고사" }
        guard dynamicTypeSize.isAccessibilitySize else { return attempt.exam.title }
        return "\(attempt.exam.formCode)형 \(attempt.exam.attemptNumber)회차"
    }

    @ViewBuilder private var timerCopy: some View {
        if taking {
            HStack(spacing: 6) {
                Image(systemName: "timer")
                Text(WeeklyMockFormat.clock(remaining ?? 0)).monospacedDigit()
                Text("답안 \(answeredCount)/\(questionCount)").foregroundStyle(Tokens.text2)
                if saving { ProgressView().controlSize(.small) }
            }
            .font(.mNumeric)
            .foregroundStyle((remaining ?? 0) <= 300 ? Tokens.danger : Tokens.ink)
            .padding(.horizontal, Tokens.Space.s4).frame(minHeight: 40)
            .background((remaining ?? 0) <= 300 ? Tokens.dangerSoft : Tokens.paper2, in: Capsule())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                "남은 시간 \(WeeklyMockFormat.clock(remaining ?? 0)), "
                + "\(questionCount)문항 중 \(answeredCount)문항 응답")
        }
    }

    private func lobby(_ value: ServerAPI.WeeklyMockAttempt) -> some View {
        ScrollView {
            // 가로 iPhone: 회차 소개(왼쪽)와 진행 규칙·시작 버튼(오른쪽)을 나눈다.
            // 세로로 쌓으면 안내 세 줄 뒤에 시작 버튼이 붙어, 시험을 시작하려면
            // 매번 스크롤을 내려야 한다 — 제한 시간이 걸린 화면에서 가장 나쁜 배치다.
            CompactHeightColumns(spacing: Tokens.Space.s6, stackedSpacing: Tokens.Space.s6) {
                VStack(alignment: .leading, spacing: Tokens.Space.s6) {
                    Text("\(value.exam.formCode)형 \(value.exam.attemptNumber)회차")
                        .font(.mMicro).foregroundStyle(Tokens.primary)
                    Text(value.exam.title).font(.mDisplay).foregroundStyle(Tokens.ink)
                    Text("\(value.exam.questionCount ?? 30)문항, \(value.exam.durationMinutes ?? 100)분. 시작 버튼을 누르는 순간 개인 제한 시간이 시작되며, 앱을 벗어나도 서버 시계는 멈추지 않습니다.")
                        .font(.mCallout).foregroundStyle(Tokens.text2)
                }
                .accessibilityElement(children: .contain)
            } trailing: {
                VStack(alignment: .leading, spacing: Tokens.Space.s6) {
                    VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                        Label("문제지는 시작 후 이 기기로 안전하게 내려받습니다.", systemImage: "lock.doc.fill")
                        Label("답안은 입력할 때마다 서버와 기기에 저장됩니다.", systemImage: "arrow.triangle.2.circlepath")
                        Label("마지막 회차 후 대표 성적을 직접 고를 수 있습니다.", systemImage: "checkmark.seal.fill")
                    }
                    .font(.mBody).foregroundStyle(Tokens.text2)
                    Button { Task { await start() } } label: {
                        if starting { ProgressView().tint(Tokens.onPrimary) } else { Label("응시 시작", systemImage: "arrow.right") }
                    }
                    .buttonStyle(PrimaryButtonStyle()).disabled(starting || value.canStart == false)
                    .frame(maxWidth: 360)
                }
                .accessibilityElement(children: .contain)
            }
            .readableWidth(780).adaptiveHPadding().padding(.vertical, Tokens.Space.s8)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func takingView(_ value: ServerAPI.WeeklyMockAttempt) -> some View {
        GeometryReader { geometry in
            if geometry.size.width >= 900 || usesLandscapeSplitWorkspace {
                HStack(spacing: 0) {
                    paperPane.frame(maxWidth: .infinity)
                    Divider().overlay(Tokens.line)
                    // 667pt급 가로 iPhone에서도 선지 5개의 44pt 터치 영역이 들어갈
                    // 최소 300pt를 답안지에 보장한다. 큰 화면에서는 종전 36%/390pt
                    // 상한을 그대로 유지해 문제지를 과도하게 좁히지 않는다.
                    omrPane(value)
                        .frame(width: min(390, max(300, geometry.size.width * 0.36)))
                }
            } else {
                VStack(spacing: 0) {
                    Picker("시험 화면", selection: $pane) {
                        ForEach(Pane.allCases, id: \.self) { Text($0.rawValue) }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel("시험 화면")
                    .accessibilityValue(pane.rawValue)
                    .accessibilityHint("문제지와 답안지를 전환합니다")
                    .padding(.horizontal, Tokens.Space.s4)
                    .padding(.vertical, Tokens.Space.s2)
                    switch pane {
                    case .paper: paperPane
                    case .omr: omrPane(value)
                    }
                }
            }
        }
    }

    @ViewBuilder private var paperPane: some View {
        if let paperURL {
            WeeklyMockPDFView(url: paperURL)
        } else {
            VStack(spacing: Tokens.Space.s4) {
                ProgressView().controlSize(.large)
                Text("문제지를 안전하게 내려받고 있습니다").font(.mBodyB)
                Text("답안지는 먼저 작성할 수 있습니다.").font(.mCaption).foregroundStyle(Tokens.text3)
                Button("다시 다운로드") { Task { await downloadPaper() } }.buttonStyle(SecondaryButtonStyle())
            }
        }
    }

    private func omrPane(_ value: ServerAPI.WeeklyMockAttempt) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Tokens.Space.s4) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("답안지").font(.mHeading).foregroundStyle(Tokens.ink)
                        Text("\(questionCount)문항 중 \(answeredCount)문항 응답").font(.mCaption).foregroundStyle(Tokens.text3)
                    }
                    Spacer()
                    if saving { Label("저장 중", systemImage: "arrow.triangle.2.circlepath").font(.mCaption).foregroundStyle(Tokens.text3) }
                }
                answerRows(value)
                Button { confirmSubmit = true } label: {
                    if submitting { ProgressView().tint(Tokens.onPrimary) } else { Text("최종 제출") }
                }
                .buttonStyle(PrimaryButtonStyle()).disabled(submitting || remaining == 0)
                Text("정답과 점수는 서버의 공식 공개 시각 전에는 표시되지 않습니다.")
                    .font(.mMicro).foregroundStyle(Tokens.text4)
            }
            .padding(Tokens.Space.s4)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Tokens.paper2)
    }

    @ViewBuilder private func answerRows(_ value: ServerAPI.WeeklyMockAttempt) -> some View {
        ForEach(0..<questionCount, id: \.self) { index in
            WeeklyMockAnswerRow(
                number: index + 1,
                mode: value.exam.mode(at: index),
                answer: binding(index))
            if index < questionCount - 1 { Divider().overlay(Tokens.line) }
        }
    }

    private func binding(_ index: Int) -> Binding<String> {
        Binding(
            get: { answers.indices.contains(index) ? answers[index] : "" },
            set: { value in
                guard answers.indices.contains(index) else { return }
                answers[index] = String(value.prefix(80))
                telemetry.append(.init(
                    eventType: "ANSWER_CHANGED",
                    questionNumber: index + 1,
                    clientAt: Date(),
                    visibility: "visible",
                    answerLength: answers[index].count))
                // in-flight snapshot의 prefix는 ACK 뒤 제거해야 하므로 저장 중에는
                // 잘라내지 않는다. 그렇지 않으면 새 ANSWER_CHANGED까지 함께 지워진다.
                if telemetry.count > 200, !saving {
                    telemetry.removeFirst(telemetry.count - 200)
                }
                draftSyncState.recordEdit()
                persistDraftSyncState()
            })
    }

    @MainActor private func load(silent: Bool = false) async {
        guard accountSlot == DataScope.slot else { return }
        let loadRequest = draftSyncState.beginLoad()
        if !silent { loading = true }
        do {
            let value = try await ServerAPI.weeklyMockAttempt(examId: examId)
            finishLoading(loadRequest)
            guard accountSlot == DataScope.slot,
                  draftSyncState.shouldApplyMetadata(loadRequest) else { return }
            apply(
                value,
                preservingLocalDraft: draftSyncState.shouldPreserveLocalDraft(loadRequest))
            errorText = nil
            if value.state == "in-progress" {
                if draftSyncState.hasUnsavedChanges {
                    await save(reportError: false)
                }
                if paperURL == nil { await downloadPaper() }
            }
        } catch {
            finishLoading(loadRequest)
            guard accountSlot == DataScope.slot,
                  draftSyncState.shouldApplyMetadata(loadRequest) else { return }
            if !silent { attempt = nil }
            errorText = WeeklyMockFormat.message(error)
        }
    }

    @MainActor private func finishLoading(
        _ request: WeeklyMockDraftSyncState.LoadRequest
    ) {
        // 최신 요청이 편집 때문에 폐기되는 경우에도 spinner는 끝낸다. 다만 이전
        // 세대 응답은 아직 진행 중인 최신 요청의 loading 상태를 건드리지 않는다.
        if accountSlot != DataScope.slot || draftSyncState.isLatest(request) {
            loading = false
        }
    }

    @MainActor private func start() async {
        guard accountSlot == DataScope.slot else { return }
        starting = true
        defer { starting = false }
        do {
            let value = try await ServerAPI.startWeeklyMock(examId: examId)
            guard accountSlot == DataScope.slot else { return }
            apply(value)
            await downloadPaper()
        } catch {
            guard accountSlot == DataScope.slot else { return }
            errorText = WeeklyMockFormat.message(error)
        }
    }

    @MainActor private func downloadPaper() async {
        guard accountSlot == DataScope.slot else { return }
        do {
            let value = try await ServerAPI.downloadWeeklyMockPaper(
                examId: examId,
                accountSlot: accountSlot)
            guard accountSlot == DataScope.slot else { return }
            paperURL = value
        } catch {
            guard accountSlot == DataScope.slot else { return }
            errorText = WeeklyMockFormat.message(error)
        }
    }

    @MainActor private func save(reportError: Bool) async {
        guard accountSlot == DataScope.slot, taking, !saving else { return }
        saving = true
        defer { saving = false }

        while accountSlot == DataScope.slot, taking {
            let saveRequest = draftSyncState.beginSave()
            let answerSnapshot = answers
            let eventSnapshot = telemetry
            do {
                let draft = try await ServerAPI.saveWeeklyMockDraft(
                    examId: examId,
                    answers: answerSnapshot,
                    telemetry: eventSnapshot)
                guard accountSlot == DataScope.slot else { return }
                draftSyncState.markSaveSucceeded(saveRequest)
                persistDraftSyncState()
                if draftSyncState.canApplySaveResponse(saveRequest),
                   draft.submitted,
                   let value = draft.attempt {
                    apply(value)
                }
                if telemetry.count >= eventSnapshot.count { telemetry.removeFirst(eventSnapshot.count) }
                if telemetry.count > 200 { telemetry.removeFirst(telemetry.count - 200) }
            } catch {
                guard accountSlot == DataScope.slot else { return }
                if reportError { errorText = WeeklyMockFormat.message(error) }
                // 실패 중 새 답이 생겼다면 최신 snapshot을 한 번 즉시 시도한다.
                // 최신 요청 자체가 실패한 경우에는 로컬 draft를 dirty로 보존한다.
                guard draftSyncState.hasEdits(after: saveRequest) else { return }
                continue
            }

            // PATCH가 await 중일 때 생긴 편집은 첫 ACK로 clean 처리하지 않는다.
            // debounce task를 기다리지 않고 최신 전체 snapshot을 곧바로 저장한다.
            guard draftSyncState.hasEdits(after: saveRequest) else { return }
        }
    }

    @MainActor private func submit() async {
        guard accountSlot == DataScope.slot, taking, !submitting else { return }
        submitting = true
        defer { submitting = false }
        do {
            _ = try await ServerAPI.submitWeeklyMock(examId: examId, answers: answers, telemetry: telemetry)
            guard accountSlot == DataScope.slot else { return }
            clearDraft()
            telemetry.removeAll()
            let value = try await ServerAPI.weeklyMockAttempt(examId: examId)
            guard accountSlot == DataScope.slot else { return }
            apply(value)
        } catch {
            guard accountSlot == DataScope.slot else { return }
            errorText = WeeklyMockFormat.message(error)
        }
    }

    @MainActor private func expire() async {
        guard accountSlot == DataScope.slot else { return }
        do {
            _ = try await ServerAPI.expireWeeklyMock(examId: examId)
            guard accountSlot == DataScope.slot else { return }
            clearDraft()
            await load()
        } catch let api as ServerAPIError where api.statusCode == 409 {
            guard accountSlot == DataScope.slot else { return }
            didRequestExpiry = false
        } catch {
            guard accountSlot == DataScope.slot else { return }
            errorText = WeeklyMockFormat.message(error)
        }
    }

    @MainActor private func apply(
        _ value: ServerAPI.WeeklyMockAttempt,
        preservingLocalDraft: Bool = false
    ) {
        guard accountSlot == DataScope.slot else { return }
        attempt = value
        didRequestExpiry = false
        guard value.state == "in-progress" else {
            answers.removeAll()
            draftSyncState.markTerminal()
            clearDraft()
            return
        }
        let count = value.exam.questionCount ?? value.attempt?.answers.count ?? 30
        let preserveLocal = preservingLocalDraft || restoredDraftIsDirty()
        answers = WeeklyMockDraftRecovery.answers(
            server: value.attempt?.answers ?? [],
            local: restoredDraft(),
            current: answers,
            count: count,
            preserveLocal: preserveLocal)
        if !preserveLocal {
            draftSyncState.markServerSnapshotApplied()
        }
        persistDraft()
        persistDraftSyncState()
    }

    private var draftKey: String {
        DataScope.defaultsKey("matths.weeklyMock.draft.\(examId)", for: accountSlot)
    }
    private var draftDirtyKey: String {
        DataScope.defaultsKey("matths.weeklyMock.draftDirty.\(examId)", for: accountSlot)
    }
    private func persistDraft() {
        let value = WeeklyMockPersistedDraft(
            answers: answers,
            dirty: draftSyncState.hasUnsavedChanges)
        if let data = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(data, forKey: draftKey)
        }
    }
    private func restoredDraft() -> [String]? {
        WeeklyMockPersistedDraft.decode(
            UserDefaults.standard.data(forKey: draftKey),
            legacyDirty: UserDefaults.standard.bool(forKey: draftDirtyKey))?.answers
    }
    private func restoredDraftIsDirty() -> Bool {
        WeeklyMockPersistedDraft.decode(
            UserDefaults.standard.data(forKey: draftKey),
            legacyDirty: UserDefaults.standard.bool(forKey: draftDirtyKey))?.dirty == true
    }
    private func persistDraftSyncState() {
        persistDraft()
        UserDefaults.standard.removeObject(forKey: draftDirtyKey)
    }
    private func clearDraft() {
        UserDefaults.standard.removeObject(forKey: draftKey)
        UserDefaults.standard.removeObject(forKey: draftDirtyKey)
    }
}

private struct WeeklyMockAnswerRow: View {
    let number: Int
    let mode: String
    @Binding var answer: String
    @FocusState private var focused: Bool
    private static let circled = ["①", "②", "③", "④", "⑤"]

    var body: some View {
        HStack(spacing: Tokens.Space.s2) {
            Text("\(number)").font(.mNumeric).foregroundStyle(Tokens.text2)
                .frame(width: 28, alignment: .trailing)
                // 각 선지/단답 입력이 이미 문항 번호를 포함해 읽는다. 번호만 따로
                // 포커스되면 30번의 불필요한 VoiceOver 정지가 생긴다.
                .accessibilityHidden(true)
            if mode == "multiple-choice" {
                ForEach(1...5, id: \.self) { choice in
                    let key = "\(choice)"
                    Button { answer = answer == key ? "" : key } label: {
                        Text(Self.circled[choice - 1]).font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(answer == key ? Tokens.onPrimary : Tokens.text2)
                            .frame(width: 36, height: 36)
                            .background(answer == key ? Tokens.primary : Tokens.surface, in: Circle())
                            .overlay(Circle().strokeBorder(answer == key ? Tokens.primary : Tokens.line, lineWidth: 1.2))
                    }
                    .frame(width: 36, height: 44)
                    .contentShape(Rectangle())
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(number)번 \(choice)번 선지")
                    .accessibilityAddTraits(answer == key ? .isSelected : [])
                }
            } else {
                TextField("0~999", text: $answer)
                    .keyboardType(.numberPad).multilineTextAlignment(.center).focused($focused)
                    .frame(maxWidth: 140, minHeight: 44)
                    .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.Radius.sm))
                    .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.sm).strokeBorder(focused ? Tokens.primary : Tokens.line))
                    .accessibilityLabel("\(number)번 단답")
                    .accessibilityValue(answer.isEmpty ? "미응답" : answer)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 5)
    }
}

private struct WeeklyMockResultView: View {
    let attempt: ServerAPI.WeeklyMockAttempt
    let accountSlot: String
    let refresh: () -> Void

    var body: some View {
        ScrollView {
            // 가로 iPhone: 성적(왼쪽)과 그 뒤에 할 일(오른쪽)을 나눈다. 문항별 복기는
            // 30줄까지 늘어나므로, 세로로 쌓으면 점수를 확인하는 순간 대표 성적 선택과
            // 소명 안내가 화면 밖으로 밀려난다.
            CompactHeightColumns(spacing: Tokens.Space.s6, stackedSpacing: Tokens.Space.s6) {
                VStack(alignment: .leading, spacing: Tokens.Space.s6) {
                    VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                        Text("SUBMITTED \(attempt.exam.formCode)형")
                            .font(.mMicro).foregroundStyle(Tokens.primary)
                        Text(attempt.pendingAggregation == true ? "답안 제출 완료" : "공식 결과")
                            .font(.mDisplay).foregroundStyle(Tokens.ink)
                        Text(attempt.pendingAggregation == true
                             ? "회차 종료 후 전체 응시자의 표준화 성적을 함께 계산합니다."
                             : "서버에서 확정한 이번 회차 성적입니다.")
                            .font(.mCallout).foregroundStyle(Tokens.text2)
                    }

                    if let result = attempt.result {
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: Tokens.Space.s4) { resultMetric("표준화", result.standardizedPerformance.map(WeeklyMockFormat.score) ?? "집계 중"); resultMetric("백분위", result.totalPercentile.map(WeeklyMockFormat.score) ?? "집계 중"); resultMetric("원점수", result.rawScore.map(WeeklyMockFormat.score) ?? "공개 전") }
                            VStack(spacing: Tokens.Space.s3) { resultMetric("표준화", result.standardizedPerformance.map(WeeklyMockFormat.score) ?? "집계 중"); resultMetric("백분위", result.totalPercentile.map(WeeklyMockFormat.score) ?? "집계 중"); resultMetric("원점수", result.rawScore.map(WeeklyMockFormat.score) ?? "공개 전") }
                        }
                    }
                }
                .accessibilityElement(children: .contain)
            } trailing: {
                VStack(alignment: .leading, spacing: Tokens.Space.s6) {
                    if let selection = attempt.selection {
                        WeeklyMockSelectionView(selection: selection, accountSlot: accountSlot) { attemptId, deferSelection in
                            guard accountSlot == DataScope.slot else { return }
                            try await ServerAPI.selectWeeklyMockRepresentative(
                                weekKey: selection.weekKey, attemptId: attemptId, deferSelection: deferSelection)
                            guard accountSlot == DataScope.slot else { return }
                            refresh()
                        }
                    }

                    if attempt.integrityReview != nil {
                        Label("풀이과정 소명 요청이 도착했습니다. 센터의 ‘풀이과정 소명’에서 기한 안에 제출해주세요.", systemImage: "exclamationmark.shield.fill")
                            .font(.mCallout).foregroundStyle(Tokens.warningInk)
                            .padding(Tokens.Space.s5)
                            .background(Tokens.warningSoft, in: RoundedRectangle(cornerRadius: Tokens.Radius.lg))
                            .accessibilityHint("센터의 풀이과정 소명에서 제출 기한과 내용을 확인할 수 있습니다")
                    }

                    if attempt.reviewAvailable == true, let review = attempt.review, !review.isEmpty {
                        VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                            Text("문항별 복기").font(.mHeading).foregroundStyle(Tokens.ink)
                            ForEach(review) { row in
                                HStack(alignment: .top, spacing: Tokens.Space.s3) {
                                    Image(systemName: row.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundStyle(row.isCorrect ? Tokens.success : Tokens.danger)
                                        .accessibilityHidden(true)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("\(row.isCorrect ? "정답" : "오답"), \(row.number)번, 내 답 \(row.submittedAnswer.isEmpty ? "무응답" : row.submittedAnswer), 정답 \(row.correctAnswer)")
                                            .font(.mBodyB)
                                        if let explanation = row.explanation, !explanation.isEmpty {
                                            Text(explanation).font(.mCaption).foregroundStyle(Tokens.text2)
                                        }
                                    }
                                }
                                .accessibilityElement(children: .combine)
                                if row.id != review.last?.id { Divider().overlay(Tokens.line) }
                            }
                        }
                        .card()
                    } else {
                        Label("정답과 해설은 \(WeeklyMockFormat.dateTime(attempt.reviewPublishesAt) ?? "공식 공개 시각") 이후 열립니다.", systemImage: "lock.fill")
                            .font(.mCallout).foregroundStyle(Tokens.text3)
                    }

                    Button("결과 새로고침", action: refresh).buttonStyle(SecondaryButtonStyle())
                }
                .accessibilityElement(children: .contain)
            }
            .readableWidth(900).adaptiveHPadding().padding(.vertical, Tokens.Space.s7)
        }
    }

    private func resultMetric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.mCaption).foregroundStyle(Tokens.text3)
            Text(value).font(.mStatLarge).foregroundStyle(Tokens.ink).lineLimit(1).minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Representative selection

private struct WeeklyMockSelectionView: View {
    let selection: ServerAPI.WeeklyMockSelection
    let accountSlot: String
    let submit: (String?, Bool) async throws -> Void
    @State private var busy = false
    @State private var errorText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s4) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("대표 성적 선택").font(.mHeading).foregroundStyle(Tokens.ink)
                    Text(selection.locked ? "선택이 마감되었습니다." : "A, B, C형 중 종합 랭킹에 반영할 성적을 고릅니다.")
                        .font(.mCaption).foregroundStyle(Tokens.text3)
                }
                Spacer()
                Text("\(selection.attemptCount)회 응시").font(.mCaption).foregroundStyle(Tokens.primary)
            }
            ForEach(selection.attempts) { option in
                Button {
                    Task { await choose(option.id, deferSelection: false) }
                } label: {
                    HStack(spacing: Tokens.Space.s3) {
                        Image(systemName: selected(option) ? "largecircle.fill.circle" : "circle")
                            .foregroundStyle(selected(option) ? Tokens.primary : Tokens.text4)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(option.formCode)형 \(option.attemptNumber)회차").font(.mBodyB).foregroundStyle(Tokens.ink)
                            Text("표준화 \(option.standardizedPerformance.map(WeeklyMockFormat.score) ?? "집계 중"), 백분위 \(option.totalPercentile.map(WeeklyMockFormat.score) ?? "집계 중")")
                                .font(.mCaption).foregroundStyle(Tokens.text3)
                        }
                        Spacer()
                        if option.isRepresentative { Text("확정").font(.mMicro).foregroundStyle(Tokens.successInk) }
                    }
                    .padding(Tokens.Space.s4).background(selected(option) ? Tokens.primarySoft : Tokens.paper2, in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected(option) ? .isSelected : [])
                .disabled(!selection.canChoose || busy)
            }
            if selection.canChoose {
                Button("3회차까지 선택 미루기") { Task { await choose(nil, deferSelection: true) } }
                    .buttonStyle(SecondaryButtonStyle()).disabled(busy)
            }
            if busy { ProgressView("선택을 저장하고 있습니다") }
            if let errorText { Text(errorText).font(.mCaption).foregroundStyle(Tokens.dangerInk) }
        }
        .card()
    }

    private func selected(_ option: ServerAPI.WeeklyMockSelectionAttempt) -> Bool {
        selection.selectedAttemptId == option.id || selection.representativeAttemptId == option.id
    }

    @MainActor private func choose(_ id: String?, deferSelection: Bool) async {
        guard accountSlot == DataScope.slot else { return }
        busy = true
        defer { busy = false }
        do {
            try await submit(id, deferSelection)
            guard accountSlot == DataScope.slot else { return }
            errorText = nil
        } catch {
            guard accountSlot == DataScope.slot else { return }
            errorText = WeeklyMockFormat.message(error)
        }
    }
}

// MARK: - Integrity evidence

private struct WeeklyMockIntegrityScreen: View {
    let accountSlot: String
    let onClose: () -> Void
    @State private var cases: [ServerAPI.WeeklyMockIntegrityCase] = []
    @State private var selected: ServerAPI.WeeklyMockIntegrityCase?
    @State private var note = ""
    @State private var files: [URL] = []
    @State private var importing = false
    @State private var submitting = false
    @State private var loading = true
    @State private var loadError: String?
    @State private var message: String?

    var body: some View {
        VStack(spacing: 0) {
            WeeklyMockHeader(
                title: "풀이과정 소명",
                subtitle: "요청 문항, 제출 기한, 접수증",
                closeLabel: "모의고사 센터로 돌아가기",
                close: onClose)
            ScrollView {
                Group {
                    if loading { ProgressView("소명 요청을 확인하고 있습니다").frame(minHeight: 320) }
                    else if let loadError, cases.isEmpty {
                        WeeklyMockFailure(
                            title: "소명 요청을 불러오지 못했습니다",
                            message: loadError,
                            retry: { Task { await load() } })
                    }
                    else if let selected { detail(selected) }
                    else if cases.isEmpty { ContentUnavailableView("도착한 소명 요청이 없습니다", systemImage: "checkmark.shield.fill", description: Text("무결성 검토가 필요한 경우 이 화면에 요청 문항과 기한이 표시됩니다.")) }
                    else {
                        VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                            if let loadError { refreshFailureBanner(loadError) }
                            list
                        }
                    }
                }
                .readableWidth(900).adaptiveHPadding().padding(.vertical, Tokens.Space.s6)
            }
        }
        .task { await load() }
        .onDisappear { cleanupFiles() }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.pdf, .image], allowsMultipleSelection: true) { result in
            do { files = try copyForUpload(Array(try result.get().prefix(10))); message = nil }
            catch { message = WeeklyMockFormat.message(error) }
        }
        .alert("소명 제출", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("확인", role: .cancel) {}
        } message: { Text(message ?? "") }
    }

    private var list: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s4) {
            Text("요청 내역").font(.mTitle).foregroundStyle(Tokens.ink)
            ForEach(cases) { item in
                Button { selected = item } label: {
                    HStack(spacing: Tokens.Space.s4) {
                        Image(systemName: item.canSubmit ? "exclamationmark.shield.fill" : "checkmark.shield.fill")
                            .font(.title2).foregroundStyle(item.canSubmit ? Tokens.warning : Tokens.success)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.exam?.title ?? "주간 공식 모의고사").font(.mBodyB).foregroundStyle(Tokens.ink)
                            Text("요청 문항 \(item.requestedQuestionNumbers.map(String.init).joined(separator: ", "))번, \(WeeklyMockFormat.status(item.status))")
                                .font(.mCaption).foregroundStyle(Tokens.text3)
                        }
                        Spacer(); Image(systemName: "chevron.right").foregroundStyle(Tokens.text4)
                    }
                    .card()
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func refreshFailureBanner(_ text: String) -> some View {
        HStack(alignment: .center, spacing: Tokens.Space.s3) {
            Label(text, systemImage: "wifi.exclamationmark")
                .font(.mCaption)
                .foregroundStyle(Tokens.warningInk)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: Tokens.Space.s2)
            Button("다시 시도") { Task { await load() } }
                .font(.mCaption)
                .foregroundStyle(Tokens.primary)
                .frame(minHeight: 44)
                .buttonStyle(.plain)
        }
        .padding(Tokens.Space.s3)
        .background(Tokens.warningSoft,
                    in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
    }

    private func detail(_ item: ServerAPI.WeeklyMockIntegrityCase) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s6) {
            Button { selected = nil; files.removeAll(); note = "" } label: { Label("요청 목록", systemImage: "chevron.left") }
                .buttonStyle(SecondaryButtonStyle())
            // iPhone 가로에서 요청 요약만 왼쪽 절반에 보이고, 정작 파일 선택과
            // 제출 버튼은 빈 오른쪽을 두고 아래로 밀렸다. 요약과 행동을 나란히 둔다.
            CompactHeightColumns(spacing: Tokens.Space.s5, stackedSpacing: Tokens.Space.s6) {
                VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                    Text(item.exam?.title ?? "주간 공식 모의고사").font(.mTitle).foregroundStyle(Tokens.ink)
                    Text("상태 \(WeeklyMockFormat.status(item.status))").font(.mCallout).foregroundStyle(item.canSubmit ? Tokens.warningInk : Tokens.text2)
                    Label("요청 문항 \(item.requestedQuestionNumbers.map(String.init).joined(separator: ", "))번", systemImage: "number.square.fill")
                    Label("제출 기한 \(WeeklyMockFormat.dateTime(item.evidenceRequest.deadlineAt) ?? "확인 필요")", systemImage: "clock.fill")
                    Text(item.evidenceRequest.instructions).font(.mCallout).foregroundStyle(Tokens.text2)
                }
                .card()
                .accessibilityElement(children: .contain)
            } trailing: {
                VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                    if item.canSubmit {
                        VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                            Text("풀이 파일").font(.mHeading).foregroundStyle(Tokens.ink)
                            Text("요청 문항의 전체 풀이가 보이는 PDF 또는 이미지, 파일당 10MB 이하, 최대 10개")
                                .font(.mCaption).foregroundStyle(Tokens.text3)
                            ViewThatFits(in: .horizontal) {
                                HStack(spacing: Tokens.Space.s2) { evidenceActionButtons(item) }
                                VStack(spacing: Tokens.Space.s2) { evidenceActionButtons(item) }
                            }
                            ForEach(files, id: \.self) { file in
                                Label(file.lastPathComponent, systemImage: "doc.fill").font(.mCaption).foregroundStyle(Tokens.text2)
                            }
                            Text("추가 설명 (선택)").font(.mCaption).foregroundStyle(Tokens.text3)
                            TextEditor(text: $note).frame(minHeight: 110).padding(8)
                                .background(Tokens.paper2, in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
                                .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.md).strokeBorder(Tokens.line))
                                .accessibilityLabel("추가 설명")
                        }
                        .card()
                    }

                    if !item.evidenceSubmissions.isEmpty {
                        VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                            Text("접수 내역").font(.mHeading).foregroundStyle(Tokens.ink)
                            ForEach(item.evidenceSubmissions) { receipt in
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("접수번호 \(receipt.receiptId)").font(.mBodyB)
                                    Text("\(WeeklyMockFormat.dateTime(receipt.submittedAt) ?? "제출됨"), 파일 \(receipt.files.count)개")
                                        .font(.mCaption).foregroundStyle(Tokens.text3)
                                }
                            }
                        }
                        .card()
                    }
                }
                .accessibilityElement(children: .contain)
            }
        }
    }

    @ViewBuilder private func evidenceActionButtons(
        _ item: ServerAPI.WeeklyMockIntegrityCase
    ) -> some View {
        Button { importing = true } label: {
            Label("파일 선택", systemImage: "paperclip")
        }
        .buttonStyle(SecondaryButtonStyle())
        Button { Task { await submit(item) } } label: {
            if submitting { ProgressView().tint(Tokens.onPrimary) }
            else { Text("소명 자료 제출") }
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(files.isEmpty || submitting)
    }

    @MainActor private func load() async {
        guard accountSlot == DataScope.slot else { return }
        loading = true
        loadError = nil
        defer { loading = false }
        do {
            let value = try await ServerAPI.weeklyMockIntegrityCases()
            guard accountSlot == DataScope.slot else { return }
            cases = value
            if let selected { self.selected = cases.first { $0.id == selected.id } }
        } catch {
            guard accountSlot == DataScope.slot else { return }
            loadError = WeeklyMockFormat.message(error)
        }
    }

    @MainActor private func submit(_ item: ServerAPI.WeeklyMockIntegrityCase) async {
        guard accountSlot == DataScope.slot else { return }
        let submissionId = WeeklyMockEvidenceCommandStore.loadOrCreate(
            caseId: item.id,
            accountSlot: accountSlot)
        submitting = true
        defer { submitting = false }
        do {
            let receipt = try await ServerAPI.submitWeeklyMockEvidence(
                caseId: item.id,
                files: files,
                note: note,
                submissionId: submissionId)
            guard accountSlot == DataScope.slot else { return }
            WeeklyMockEvidenceCommandStore.clear(
                caseId: item.id,
                accountSlot: accountSlot)
            cleanupFiles(); files.removeAll(); note = ""
            message = "접수번호 \(receipt.receiptId)로 제출되었습니다."
            await load()
        } catch {
            guard accountSlot == DataScope.slot else { return }
            message = WeeklyMockFormat.message(error)
        }
    }

    private func copyForUpload(_ source: [URL]) throws -> [URL] {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("WeeklyMockEvidence", isDirectory: true)
            .appendingPathComponent(accountSlot, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return try source.map { url in
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            let target = directory.appendingPathComponent("\(UUID().uuidString)-\(url.lastPathComponent)")
            try FileManager.default.copyItem(at: url, to: target)
            return target
        }
    }

    private func cleanupFiles() { files.forEach { try? FileManager.default.removeItem(at: $0) } }
}

private enum WeeklyMockEvidenceCommandStore {
    private static func key(caseId: String, accountSlot: String) -> String {
        DataScope.defaultsKey(
            "matths.weeklyMock.evidenceCommand.\(caseId)",
            for: accountSlot)
    }

    static func loadOrCreate(caseId: String, accountSlot: String) -> String {
        let commandKey = key(caseId: caseId, accountSlot: accountSlot)
        if let value = UserDefaults.standard.string(forKey: commandKey),
           !value.isEmpty {
            return value
        }
        let value = UUID().uuidString
        UserDefaults.standard.set(value, forKey: commandKey)
        return value
    }

    static func clear(caseId: String, accountSlot: String) {
        UserDefaults.standard.removeObject(
            forKey: key(caseId: caseId, accountSlot: accountSlot))
    }
}

// MARK: - Objections

private struct WeeklyMockObjectionScreen: View {
    let accountSlot: String
    let onClose: () -> Void
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var exams: [ServerAPI.WeeklyMockObjectionExam] = []
    @State private var objections: [ServerAPI.WeeklyMockObjection] = []
    @State private var examId = ""
    @State private var questionNumber = 1
    @State private var detail = ""
    @State private var loading = true
    @State private var submitting = false
    @State private var loadError: String?
    @State private var message: String?

    private var usesLandscapeForm: Bool {
        verticalSizeClass == .compact && !dynamicTypeSize.isAccessibilitySize
    }

    var body: some View {
        VStack(spacing: 0) {
            WeeklyMockHeader(
                title: "문항 이의제기",
                subtitle: "공개된 시험, 문항 단위 검토",
                closeLabel: "모의고사 센터로 돌아가기",
                close: onClose)
            ScrollView {
                VStack(alignment: .leading, spacing: Tokens.Space.s6) {
                    if loading { ProgressView("이의제기 내역을 확인하고 있습니다").frame(maxWidth: .infinity, minHeight: 240) }
                    else if let loadError, exams.isEmpty {
                        WeeklyMockFailure(
                            title: "이의제기 내역을 불러오지 못했습니다",
                            message: loadError,
                            retry: { Task { await load() } })
                    }
                    else if exams.isEmpty {
                        ContentUnavailableView("이의제기 가능한 시험이 없습니다", systemImage: "doc.questionmark", description: Text("공식 복기 공개가 끝난 시험이 이곳에 표시됩니다."))
                    } else {
                        if let loadError { refreshFailureBanner(loadError) }
                        form
                    }
                    if !objections.isEmpty { history }
                }
                .readableWidth(860).adaptiveHPadding().padding(.vertical, Tokens.Space.s6)
            }
        }
        .task { await load() }
        .alert("이의제기", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("확인", role: .cancel) {}
        } message: { Text(message ?? "") }
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s4) {
            Text("새 이의제기").font(.mTitle).foregroundStyle(Tokens.ink)
            CompactHeightColumns(spacing: Tokens.Space.s5, stackedSpacing: Tokens.Space.s4) {
                VStack(alignment: .leading, spacing: Tokens.Space.s4) {
                    Picker("시험", selection: $examId) {
                        ForEach(exams) { Text("\($0.formCode)형 \($0.title)").tag($0.id) }
                    }
                    .pickerStyle(.menu)
                    Stepper("문항 번호 \(questionNumber)번", value: $questionNumber, in: 1...max(selectedExam?.questionCount ?? 30, 1))
                        .font(.mBodyB)
                }
                .accessibilityElement(children: .contain)
            } trailing: {
                VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                    Text("문제가 있다고 판단한 부분").font(.mCaption).foregroundStyle(Tokens.text3)
                    TextEditor(text: $detail)
                        .frame(minHeight: usesLandscapeForm ? 82 : 150)
                        .padding(8)
                        .background(Tokens.paper2, in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
                        .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.md).strokeBorder(Tokens.line))
                        .accessibilityLabel("이의제기 내용")
                    Text("10자 이상, 최대 5,000자").font(.mMicro).foregroundStyle(Tokens.text4)
                    Button { Task { await submit() } } label: {
                        if submitting { ProgressView().tint(Tokens.onPrimary) }
                        else { Text("검토 요청 제출") }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(examId.isEmpty || detail.trimmingCharacters(in: .whitespacesAndNewlines).count < 10 || submitting)
                }
                .accessibilityElement(children: .contain)
            }
        }
        .card()
    }

    private var history: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s3) {
            Text("내 요청 내역").font(.mHeading).foregroundStyle(Tokens.ink)
            ForEach(objections) { item in
                VStack(alignment: .leading, spacing: 3) {
                    HStack { Text("\(item.examTitle) \(item.questionNumber)번").font(.mBodyB); Spacer(); Text(WeeklyMockFormat.status(item.status)).font(.mCaption).foregroundStyle(item.status == "accepted" ? Tokens.successInk : Tokens.text3) }
                    Text(item.issueDetail).font(.mCaption).foregroundStyle(Tokens.text2).lineLimit(3)
                    if !item.reviewReason.isEmpty { Text("검토: \(item.reviewReason)").font(.mCaption).foregroundStyle(Tokens.primary) }
                }
                .padding(.vertical, Tokens.Space.s2)
                .accessibilityElement(children: .combine)
                if item.id != objections.last?.id { Divider().overlay(Tokens.line) }
            }
        }
        .card()
    }

    private var selectedExam: ServerAPI.WeeklyMockObjectionExam? { exams.first { $0.id == examId } }

    private func refreshFailureBanner(_ text: String) -> some View {
        HStack(alignment: .center, spacing: Tokens.Space.s3) {
            Label(text, systemImage: "wifi.exclamationmark")
                .font(.mCaption)
                .foregroundStyle(Tokens.warningInk)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: Tokens.Space.s2)
            Button("다시 시도") { Task { await load() } }
                .font(.mCaption)
                .foregroundStyle(Tokens.primary)
                .frame(minHeight: 44)
                .buttonStyle(.plain)
        }
        .padding(Tokens.Space.s3)
        .background(Tokens.warningSoft,
                    in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
    }

    @MainActor private func load() async {
        guard accountSlot == DataScope.slot else { return }
        loading = true
        loadError = nil
        defer { loading = false }
        do {
            async let options = ServerAPI.weeklyMockObjectionOptions()
            async let history = ServerAPI.weeklyMockObjections()
            let (loadedExams, loadedObjections) = try await (options, history)
            guard accountSlot == DataScope.slot else { return }
            exams = loadedExams
            objections = loadedObjections
            if examId.isEmpty { examId = exams.first?.id ?? "" }
        } catch {
            guard accountSlot == DataScope.slot else { return }
            loadError = WeeklyMockFormat.message(error)
        }
    }

    @MainActor private func submit() async {
        guard accountSlot == DataScope.slot else { return }
        submitting = true
        defer { submitting = false }
        do {
            _ = try await ServerAPI.createWeeklyMockObjection(
                examId: examId,
                questionNumber: questionNumber,
                issueDetail: detail.trimmingCharacters(in: .whitespacesAndNewlines))
            guard accountSlot == DataScope.slot else { return }
            detail = ""; questionNumber = 1
            message = "이의제기가 접수되었습니다. 검토 결과는 알림과 이메일로 안내됩니다."
            await load()
        } catch {
            guard accountSlot == DataScope.slot else { return }
            message = WeeklyMockFormat.message(error)
        }
    }
}

// MARK: - Shared

private struct WeeklyMockHeader: View {
    let title: String
    let subtitle: String
    let closeLabel: String
    let close: () -> Void

    var body: some View {
        HStack(spacing: Tokens.Space.s4) {
            Button(action: close) {
                Image(systemName: "xmark").font(.system(size: 16, weight: .bold))
                    .frame(width: 44, height: 44).background(Tokens.paper2, in: Circle())
            }
            .buttonStyle(.plain).accessibilityLabel(closeLabel)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.mBodyB).foregroundStyle(Tokens.ink)
                Text(subtitle).font(.mMicro).foregroundStyle(Tokens.text3)
            }
            Spacer()
        }
        .padding(.horizontal, Tokens.Space.s4).padding(.vertical, Tokens.Space.s2)
        .background(.bar).overlay(alignment: .bottom) { Divider().overlay(Tokens.line) }
    }
}

private struct WeeklyMockFailure: View {
    let title: String
    let message: String
    let retry: () -> Void
    var body: some View {
        VStack(spacing: Tokens.Space.s4) {
            Image(systemName: "wifi.exclamationmark").font(.system(size: 34)).foregroundStyle(Tokens.warningInk)
            Text(title).font(.mHeading).foregroundStyle(Tokens.ink)
            Text(message).font(.mCallout).foregroundStyle(Tokens.text2).multilineTextAlignment(.center)
            Button("다시 시도", action: retry).buttonStyle(PrimaryButtonStyle()).frame(maxWidth: 260)
        }
        .frame(maxWidth: .infinity, minHeight: 360).padding(Tokens.Space.s6)
    }
}

private enum WeeklyMockFormat {
    static func date(_ raw: String?) -> Date? {
        guard let raw else { return nil }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: raw) ?? ISO8601DateFormatter().date(from: raw)
    }

    static func dateTime(_ raw: String?) -> String? {
        guard let value = date(raw) else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.dateFormat = "M월 d일(EEE) a h:mm"
        return formatter.string(from: value)
    }

    static func score(_ value: Double) -> String {
        value.rounded() == value ? String(Int(value)) : String(format: "%.1f", value)
    }

    static func clock(_ seconds: Int) -> String {
        let value = max(0, seconds)
        return String(format: "%02d:%02d:%02d", value / 3600, (value % 3600) / 60, value % 60)
    }

    static func message(_ error: Error) -> String {
        if let api = error as? ServerAPIError { return api.errorDescription ?? "서버 요청을 확인해주세요." }
        if let url = error as? URLError {
            switch url.code {
            case .notConnectedToInternet, .networkConnectionLost: return "인터넷 연결이 끊겼습니다. 작성한 답안은 이 기기에 보관됩니다."
            case .timedOut: return "서버 응답이 늦어지고 있습니다. 잠시 후 다시 시도해주세요."
            default: break
            }
        }
        #if DEBUG
        print("주간 모의고사 요청 실패:", error)
        #endif
        return "요청을 처리하지 못했습니다. 작성한 답안은 이 기기에 보관됩니다. 잠시 후 다시 시도해 주세요."
    }

    static func status(_ raw: String) -> String {
        switch raw {
        case "EVIDENCE_REQUIRED": return "소명 필요"
        case "SUBMITTED": return "제출 완료"
        case "UNDER_REVIEW", "reviewing": return "검토 중"
        case "CLEARED", "accepted": return "정상 확인"
        case "INSUFFICIENT_EVIDENCE": return "자료 보완 필요"
        case "CONFIRMED_CHEATING": return "위반 확정"
        case "OVERDUE_PENALIZED": return "기한 초과"
        case "pending": return "접수"
        case "rejected": return "기각"
        default: return raw
        }
    }
}
