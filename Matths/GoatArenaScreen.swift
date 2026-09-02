//
//  GoatArenaScreen.swift
//  Matths
//
//  FINAL_LOGIC_FLOW Part V–VII와 GOAT Arena 룰북 v2.0의 iPad 읽기 화면.
//  MMR(실력)과 Arena Position(자리)을 한 순위로 섞지 않고, 30일 사이클과
//  페이백 세 조건은 서버가 내려준 판정을 그대로 표현한다.
//

import SwiftUI

struct GoatArenaScreen: View {
    private typealias Snapshot = ServerAPI.GoatArenaSnapshot

    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var screenshotGuard: ScreenshotGuard
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private enum FailureKind: Equatable {
        case offline
        case timeout
        case server
        case incompatible
    }

    private struct FailurePresentation {
        let kind: FailureKind
        let message: String
    }

    private enum SnapshotFreshness {
        case fresh(receivedAt: Date)
        case cached(savedAt: Date, failure: FailurePresentation)
    }

    private struct LoadedContent {
        let snapshot: Snapshot
        let freshness: SnapshotFreshness
    }

    private struct MatchLaunch: Identifiable {
        let id: String
        /// 경기 화면 시작 로비가 **서버를 다시 부르지 않고** 읽을 사실들.
        /// 값은 전부 이 화면이 이미 들고 있는 스냅샷에서 온다(GoatArenaMatchBriefing 주석).
        /// nil 이면 종전처럼 커버가 뜨자마자 POST /start 가 나간다.
        var briefing: GoatArenaMatchBriefing? = nil
    }

    private struct SupplementalEvidenceTarget: Identifiable {
        let id: String
    }

    private struct DecisionPresentation {
        let icon: String
        let title: String
        let detail: String
        let badge: String
        let tint: Color
        let background: Color
    }

    private enum LoadState {
        case idle
        case loading
        case signedOut
        case loaded(LoadedContent)
        case failed(FailurePresentation)
    }

    @State private var state: LoadState = .idle
    @State private var requestID = UUID()
    @State private var isRefreshing = false
    @State private var matchLaunch: MatchLaunch?
    /// 서버가 이미 정산한 최근 경기. 승패를 보여 주는 화면이 앱에 하나도 없었다
    /// (recentResultsSection 주석). 스냅샷과 별개의 읽기 전용 목록이라 실패해도
    /// 화면을 막지 않는다.
    @State private var recentMatches: [ServerAPI.GoatArenaParticipantMatch] = []
    @State private var loadedAccountSlot: String?
    @State private var defenderCommandInFlight: GoatArenaDefenderCommandAction?
    @State private var pendingDefenderCommand: GoatArenaPendingDefenderCommand?
    @State private var defenderCommandReceipt: ServerAPI.GoatArenaMatchCommandResponse.Match?
    @State private var confirmDefenderAccept = false
    @State private var confirmDefenderDecline = false
    @State private var defenderCommandError: String?
    /// 401(세션 만료) 오류 알림에만 "다시 로그인" 버튼을 붙이기 위한 표식.
    /// 문구가 "다시 로그인한 뒤 …" 라고 지시하면서 수단은 홈 배너에만 있으면,
    /// 401 로 키체인 토큰이 지워진 채 authProvider 만 남은 사용자는 로그인된
    /// 것처럼 보이는 화면에서 같은 오류만 반복해서 만난다.
    @State private var defenderCommandErrorIsAuthExpired = false
    @State private var showsRulebook = false
    /// 전체 순위표(RankArenaScreen) 시트. 로그인한 학생은 종전에 순위표로 가는
    /// 문이 앱 어디에도 없었다 — RootView 는 로그인 상태에서 GoatArenaScreen 만
    /// 띄우고, RankArenaScreen 은 비로그인 미리보기로만 쓰였다. "내가 몇 등인지"
    /// 를 못 보는 경쟁 화면이라 감독 피드백("뭘 봐야 할지 모르겠다")의 한 축이다.
    /// 새 화면을 만들지 않고 이미 있는 순위표를 시트로 연다.
    @State private var showsLeaderboard = false
    @State private var showsMainMatchMaker = false
    @State private var showsFriendlyMatchMaker = false
    @State private var showsRevengeRights = false
    @State private var showsPaybackAccount = false
    @State private var supplementalEvidenceTarget: SupplementalEvidenceTarget?
    @State private var isCreatingSubMatch = false
    @State private var subMatchCommandId = UUID().uuidString
    @State private var subMatchCreateError: String?
    /// 경기 명령 라우트(HTTP_404)가 없는 서버(웹 세션 전용)를 만났을 때 true.
    /// 상대 찾기·초대 응답 CTA 대신 웹 GOAT Arena 링크를 보여 준다. GET /goat-arena 는
    /// 여전히 capabilities 를 광고하므로 스냅샷으로는 판별할 수 없어 첫 실패에서 세운다.
    @State private var arenaCommandsUnavailable = false
    /// 좁은 폭에서 펼쳐 둔 상세 묶음의 id. 기본은 전부 접힘 —
    /// 첫 화면에서 규정 문단부터 읽게 하지 않는다(감독 피드백: "스크롤 지옥").
    /// 화면 전용 상태라 저장하지 않는다. 계정 전환 때는 아래 onReceive 가 비운다.
    @State private var expandedCompactSections: Set<String> = []
    /// 보조 아레나 기능(우편함·상점·규정·계좌·대전 준비)을 모아 여는 시트.
    /// WHY 한 칸인가. 목적지가 열 개가 넘는데 버튼으로 낱개로 세우면 좁은 폭에서
    /// 줄여 놓은 스크롤(3647 → 1081pt)이 도로 늘어난다. 진입점은 보조 버튼 한 칸이고
    /// 목록은 시트 안에서 스크롤한다 — 첫 화면 높이는 한 픽셀도 늘지 않는다.
    @State private var showsArenaMoreMenu = false

    private var snapshot: Snapshot? {
        loadedContent?.snapshot
    }

    private var loadedContent: LoadedContent? {
        guard case .loaded(let value) = state else { return nil }
        return value
    }

    private var hasFreshSnapshot: Bool {
        guard let loadedContent,
              case .fresh = loadedContent.freshness else {
            return false
        }
        return true
    }

    /// 폭이 좁거나 세로가 짧은 모든 상황. 기기 이름으로 가르지 않는다.
    ///
    /// iPhone Pro Max 가로는 가로 size class 가 `regular`이지만 실제 남은 높이는
    /// 약 440pt다. 가로 size class 하나만 보면 iPad 배치로 잘못 들어가
    /// 첫 CTA 전에 스크롤이 필요해진다. 세로 compact 또한 같은 압축 정보구조를
    /// 쓰도록 해서 모든 iPhone 가로를 단일 화면 계약으로 묶는다. Split View 와
    /// Stage Manager 에서 작아진 iPad 도 자연스럽게 같은 축약을 받는다.
    private var isCompact: Bool {
        horizontalSizeClass == .compact || verticalSizeClass == .compact
    }

    /// 세로가 짧은 뷰포트(iPhone 가로, 가용 높이 약 390pt). 상단바와 하단탭,
    /// 홈 인디케이터가 이미 화면의 3분의 1을 먹기 때문에 이 구간에서만 장식 크롬
    /// (히어로 여백, 대형 숫자, 아트 배너, 순위 패널 최소 높이)을 줄인다.
    /// 전체화면과 Split View 의 iPad 는 세로가 regular 라 여기에 걸리지 않는다.
    /// 반대로 Stage Manager 로 창을 낮게 줄인 iPad 는 같은 축약을 받는다.
    /// 그게 의도다. 기준은 기기 이름이 아니라 남은 높이다.
    private var isShortViewport: Bool {
        verticalSizeClass == .compact
    }

    /// 섹션 사이 간격. 짧은 뷰포트에서만 32 에서 24 로 줄인다.
    private var sectionSpacing: CGFloat {
        isShortViewport ? Tokens.Space.s6 : Tokens.Space.s8
    }

    /// 히어로 안쪽 여백. 폭이 좁으면 20, 세로까지 짧으면 16.
    private var heroPadding: CGFloat {
        if isShortViewport { return Tokens.Space.s4 }
        return isCompact ? Tokens.Space.s5 : Tokens.Space.s6
    }

    /// 주 행동 버튼의 최대 폭. 좁은 폭에서는 340pt 로 잘라 가운데 띄우는 대신
    /// 폭을 꽉 채운다. 터치 타깃 높이는 버튼 스타일의 52pt 를 그대로 쓴다.
    private var actionMaxWidth: CGFloat {
        isCompact ? .infinity : 340
    }

    private var isBusy: Bool {
        if case .loading = state { return true }
        return isRefreshing
    }

    /// 데모 실행인가. 데모는 서버·계정 없이 도는 더미 전송계층이라 웹을 열 수 없고
    /// (웹 브리지는 "데모 모드입니다" 카드로 막는다), 반대로 네이티브 상대 찾기는
    /// 픽스처로 끝까지 동작한다. 릴리스 빌드에는 DemoMode 심볼 자체가 없다.
    private var isDemoRun: Bool {
        #if DEBUG
        return DemoMode.isOn
        #else
        return false
        #endif
    }

    /// 상대 찾기(도전·초대·경기 신청)를 **앱이 직접** 칠 수 있는가.
    ///
    /// 서버가 `ARENA_MATCH_V1`을 선언한 경우에만 네이티브 명령을 연다. 구버전 서버나
    /// 롤백 중인 인스턴스는 capability가 없으므로 첫 404를 맞기 전에 웹 동선으로
    /// 물러난다. 데모 픽스처는 네트워크 없이도 전체 흐름을 검증해야 하므로 예외다.
    private var canCommandMatchesNatively: Bool {
        guard !arenaCommandsUnavailable else { return false }
        return isDemoRun
            || loadedContent?.snapshot.capabilities.challengeCommands == "ARENA_MATCH_V1"
    }

    /// 웹 전용 아레나 페이지를 **앱 안의 로그인된 웹뷰**로 연다.
    /// Safari 로 내보내지 않는 이유: 앱 세션과 웹 세션이 갈려 학생이 웹에서 다시
    /// 로그인해야 하고, 그렇게 만든 웹 세션은 앱 계정과 다른 계정일 수도 있다.
    private func openArenaWeb(_ destination: ArenaWebDestination) {
        ArenaWebPresenter.open(
            destination,
            // 경기 페이지는 문항이 그대로 보이는 평가면이라 네이티브 경기 화면과
            // 같은 보호 계층을 웹뷰 위에도 건넨다.
            guardModel: destination.isProtectedAssessmentSurface ? screenshotGuard : nil,
            onCapture: { store.recordStuckPoint($0) })
    }

    /// 상대 찾기를 웹에서 이어 갈 자리. 서버 division 코드(MAIN/SUB)에 맞춘다.
    private func matchmakingWebDestination(_ cycle: Snapshot.Cycle) -> ArenaWebDestination {
        cycle.activeRanking == "MAIN" ? .rankedBattle : .unrankedChallenge
    }

    var body: some View {
        // 세션 만료·비로그인은 죽은 게이트 대신 순위표 미리보기 화면으로 —
        // 로그인 배너와 예시 순위표는 RankArenaScreen 이 담당한다(3차 리디자인).
        if case .signedOut = state {
            RankArenaScreen()
        } else {
            arenaBody
        }
    }

    private var arenaBody: some View {
        // 좁은 폭(iPhone 세로, iPad Split View)과 넓은 폭은 정보구조 자체가 다르다.
        // 넓은 폭은 종전 배치를 한 글자도 바꾸지 않는다(iPad 회귀 방지).
        Group {
            if isCompact {
                // 두 거대한 본문 타입을 조건부 뷰 하나로 다시 합치면 Swift
                // 런타임의 mangled-type 해석이 간헐적으로 스택을 넘긴다.
                AnyView(compactArenaBody)
            } else {
                AnyView(regularArenaBody)
            }
        }
        #if DEBUG
        .modifier(ArenaHeightProbe(label: isCompact ? "compact" : "regular"))
        #endif
        .task {
            #if DEBUG
            if applyDebugFixtureIfPresent() { return }
            #endif
            guard case .idle = state else { return }
            await load()
        }
        .onReceive(NotificationCenter.default.publisher(for: DataScope.didSwitchNotification)) {
            guard let newSlot = $0.object as? String, newSlot != loadedAccountSlot else { return }
            // 이전 계정의 snapshot·명령 응답·경기 진입을 새 학생 화면에 남기지 않는다.
            requestID = UUID()
            state = .idle
            isRefreshing = false
            matchLaunch = nil
            recentMatches = []
            loadedAccountSlot = nil
            defenderCommandInFlight = nil
            pendingDefenderCommand = nil
            defenderCommandReceipt = nil
            defenderCommandError = nil
            defenderCommandErrorIsAuthExpired = false
            showsMainMatchMaker = false
            showsFriendlyMatchMaker = false
            showsRevengeRights = false
            showsPaybackAccount = false
            supplementalEvidenceTarget = nil
            showsLeaderboard = false
            isCreatingSubMatch = false
            subMatchCommandId = UUID().uuidString
            subMatchCreateError = nil
            arenaCommandsUnavailable = false
            expandedCompactSections.removeAll()
            // 앞 계정으로 연 보조 메뉴가 새 학생 화면에서 이어지지 않게 같이 비운다.
            showsArenaMoreMenu = false
            Task { await load() }
        }
        .fullScreenCover(item: $matchLaunch, onDismiss: {
            Task { await load() }
        }) { launch in
            GoatArenaMatchPlayScreen(matchId: launch.id, briefing: launch.briefing)
                .protectedAssessmentPresentation(
                    "goat-arena-match",
                    guardModel: screenshotGuard
                ) { stuckPoint in
                    store.recordStuckPoint(stuckPoint)
                }
        }
        .compactHeightSheet(isPresented: $showsRulebook) {
            GoatArenaRulebookScreen()
        }
        .compactHeightSheet(isPresented: $showsLeaderboard) {
            GoatArenaLeaderboardSheet()
                .environmentObject(store)
        }
        .compactHeightSheet(isPresented: $showsArenaMoreMenu) {
            GoatArenaMoreMenuSheet(
                onOpenNotifications: {
                    showsArenaMoreMenu = false
                    store.route = .notifications
                },
                onOpenLeaderboard: {
                    showsArenaMoreMenu = false
                    Task { @MainActor in
                        await Task.yield()
                        showsLeaderboard = true
                    }
                },
                onOpenRulebook: {
                    showsArenaMoreMenu = false
                    Task { @MainActor in
                        await Task.yield()
                        showsRulebook = true
                    }
                },
                onOpenArenaShop: {
                    showsArenaMoreMenu = false
                    store.route = .arenaShop
                },
                onOpenRankedMatchmaker: {
                    showsArenaMoreMenu = false
                    Task { @MainActor in
                        await Task.yield()
                        showsMainMatchMaker = true
                    }
                },
                onOpenFriendlyMatchmaker: {
                    showsArenaMoreMenu = false
                    Task { @MainActor in
                        await Task.yield()
                        showsFriendlyMatchMaker = true
                    }
                },
                onOpenRevengeRights: {
                    showsArenaMoreMenu = false
                    Task { @MainActor in
                        await Task.yield()
                        showsRevengeRights = true
                    }
                },
                onOpenPaybackAccount: {
                    showsArenaMoreMenu = false
                    Task { @MainActor in
                        await Task.yield()
                        showsPaybackAccount = true
                    }
                })
        }
        .compactHeightSheet(isPresented: $showsMainMatchMaker) {
            GoatArenaMainMatchSheet(
                onMatchCreated: { matchId in
                    showsMainMatchMaker = false
                    Task { @MainActor in
                        await Task.yield()
                        matchLaunch = MatchLaunch(id: matchId)
                    }
                },
                onInvitationCreated: {
                    Task { await load() }
                })
        }
        .compactHeightSheet(isPresented: $showsPaybackAccount) {
            GoatArenaPaybackAccountSheet()
        }
        .compactHeightSheet(isPresented: $showsFriendlyMatchMaker) {
            GoatArenaFriendlyMatchSheet(
                onMatchCreated: { matchId in
                    showsFriendlyMatchMaker = false
                    Task { @MainActor in
                        await Task.yield()
                        matchLaunch = MatchLaunch(id: matchId)
                    }
                },
                onChanged: { Task { await load() } })
        }
        .compactHeightSheet(isPresented: $showsRevengeRights) {
            GoatArenaRevengeRightSheet(
                onMatchCreated: { matchId in
                    showsRevengeRights = false
                    Task { @MainActor in
                        await Task.yield()
                        matchLaunch = MatchLaunch(id: matchId)
                    }
                },
                onChanged: { Task { await load() } })
        }
        .compactHeightSheet(item: $supplementalEvidenceTarget) { target in
            GoatArenaSupplementalEvidenceSheet(matchId: target.id) {
                Task { await load() }
            }
        }
        .confirmationDialog(
            "자리 도전을 수락할까요?",
            isPresented: $confirmDefenderAccept,
            titleVisibility: .visible
        ) {
            Button("수락하고 경기 준비") {
                Task {
                    await respondToDefenderChallenge(action: .accept)
                }
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("수락하면 경기 준비가 완료됩니다. 이어서 이 화면에서 개인 경기를 시작할 수 있습니다.")
        }
        .confirmationDialog(
            "자리 도전을 거절할까요?",
            isPresented: $confirmDefenderDecline,
            titleVisibility: .visible
        ) {
            if let pending = pendingDefenderCommand,
               pending.action == .decline,
               let reason = pending.reasonCode {
                Button(
                    "\(declineReasonLabel(reason)) 사유로 다시 확인",
                    role: .destructive
                ) {
                    Task {
                        await respondToDefenderChallenge(
                            action: .decline,
                            reasonCode: reason
                        )
                    }
                }
            } else {
                ForEach(
                    ServerAPI.GoatArenaDeclineReasonCode.allCases,
                    id: \.rawValue
                ) { reason in
                    Button(declineReasonLabel(reason), role: .destructive) {
                        Task {
                            await respondToDefenderChallenge(
                                action: .decline,
                                reasonCode: reason
                            )
                        }
                    }
                }
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("선택한 거절 사유만 전달됩니다. 별도 메시지나 자리·학습일 정보는 보내지 않으며, 거절한 경기는 시작할 수 없습니다.")
        }
        .alert(
            "경기 응답을 확인하지 못했습니다",
            isPresented: Binding(
                get: { defenderCommandError != nil },
                set: {
                    if !$0 {
                        defenderCommandError = nil
                        defenderCommandErrorIsAuthExpired = false
                    }
                }
            )
        ) {
            // 세션 만료면 문구가 지시하는 행동을 이 자리에서 제공한다 —
            // 홈 대시보드의 statusAction("다시 로그인")과 같은 동선(signOut → 인증 화면).
            if defenderCommandErrorIsAuthExpired {
                Button("다시 로그인") { store.signOut() }
            }
            Button("확인", role: .cancel) {}
        } message: {
            Text(defenderCommandError ?? "")
        }
        .alert(
            "상대 찾기를 완료하지 못했습니다",
            isPresented: Binding(
                get: { subMatchCreateError != nil },
                set: { if !$0 { subMatchCreateError = nil } }
            )
        ) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(subMatchCreateError ?? "")
        }
    }

    // MARK: Regular width body (iPad — 종전 배치 그대로)

    /// 넓은 폭의 본문. 세로로 길어도 iPad 한 화면이 넓어 스캔이 되는 배치라
    /// 감독 지적(iPhone 과밀) 대상이 아니다. **여기는 손대지 않는다.**
    private var regularArenaBody: some View {
        // WHY AnyView 인가 — 이 화면이 iPad 에서 켜자마자 죽었다(SIGSEGV, 실기 크래시로그
        // Matths-2026-08-18-204228.ips). 스택은 앱 코드가 아니라 스위프트 런타임의
        // decodeMangledType 재귀로 가득 찼다: regularArenaBody 가 10개 섹션을 그대로
        // 중첩해 담으면서 뷰의 **제네릭 타입 이름 자체**가 너무 길어졌고,
        // __swift_instantiateConcreteTypeFromMangledNameV2 가 그 이름을 푸는 도중
        // 스택 가드 페이지를 밟았다(무한 재귀가 아니라 깊이 폭발이다).
        //
        // 그래서 각 섹션을 AnyView 로 감싸 **이음매마다 타입을 끊는다.** 그러면 이
        // VStack 의 타입은 섹션 수만큼의 AnyView 튜플로 고정돼 더 자라지 않는다.
        // 섹션을 하나 더 붙여도 다시 터지지 않는다 — 이 화면은 앞으로도 늘어난다.
        // AnyView 비용은 화면 진입당 한 번이라 이 크기의 섹션에서는 무시할 수준이고,
        // 죽는 화면보다는 낫다.
        VStack(alignment: .leading, spacing: sectionSpacing) {
            AnyView(header.entrance(0))

            if let loadedContent {
                if case .cached = loadedContent.freshness {
                    AnyView(staleSnapshotNotice(loadedContent).entrance(1))
                }

                let snapshot = loadedContent.snapshot

                // 로그인 뒤에는 서버가 준 현재 티어·MMR·Arena Position을 가장 먼저
                // 보여 준다. 계산이나 상태 판정은 그대로 두고 표시 순서만 고정한다.
                AnyView(rankingSection(snapshot).entrance(2))
                AnyView(hero.entrance(3))

                if snapshot.cycle != nil {
                    if let match = snapshot.activeMatch {
                        AnyView(activeMatchSection(
                            match,
                            showsDefenderRefresh: needsDefenderResponseRefresh(snapshot)
                        ).entrance(4))
                    }

                    if let invitation = snapshot.pendingInvitation {
                        AnyView(pendingInvitationSection(invitation).entrance(4))
                    }

                    // 좁은 폭과 같은 이유로 넓은 폭에도 복구 묶음을 붙인다 —
                    // 배치는 종전 그대로고, 없던 회복 경로만 살린다.
                    if let pendingDefenderCommand {
                        AnyView(defenderPendingRecovery(pendingDefenderCommand).entrance(4))
                    }

                    AnyView(accessWindowSection(snapshot).entrance(5))
                    AnyView(paybackSection(snapshot).entrance(6))
                    AnyView(assetSection(snapshot).entrance(7))
                }

                AnyView(heldReviewSection.entrance(8))
                // 정산된 결과는 사이클이 끝나도 남는다 — 사이클 게이트 바깥에 둔다.
                AnyView(recentResultsSection.entrance(8))
                AnyView(truthNotice(snapshot).entrance(9))
            } else {
                AnyView(hero.entrance(1))
            }
        }
    }

    // MARK: Compact width body (iPhone — 3단 정보구조)
    //
    // 감독 피드백(실기기 iPhone): "정보가 난잡하게 늘어져 있고 과밀, 정렬도 안 돼
    // 있고 스크롤 지옥, 뭘 봐야 할지 모르겠다."
    //
    // 원인은 값이 아니라 **순서와 밀도**였다. 종전 좁은 폭 배치는
    //   제목 → 설명문단 → 보조버튼 2개 → 티어 카드 → "실력과 자리는 다른 숫자입니다"
    //   설명 → 자리 상태 카드 → MMR/자리 패널 → 네이비 히어로 → 경기 → 이용상태 →
    //   페이백 → 자산 → 각주
    // 를 전부 같은 무게로 세로에 쌓았다. 한 화면에 "지금 상태"도 "지금 할 일"도
    // 온전히 들어오지 않는다.
    //
    // 그래서 좁은 폭만 세 단으로 다시 짠다. **서버 값과 룰북 문구는 그대로 쓰고
    // 배치만 바꾼다** — 새 숫자·새 규정 문구를 만들지 않는다.
    //   1) 지금 상태 한 덩어리 — 티어 / MMR / Arena 자리 / 사이클 진행·남은 조건
    //   2) 지금 할 수 있는 행동 — 주 CTA 하나 + 보조 이동(상점·룰북·Ranked 상점)
    //   3) 나머지 상세는 전부 접힌 디스클로저. 접힌 줄에도 서버가 준 요약
    //      (경기 상태, 이용 상태 배지, 페이백 판정, 잔액)이 붙어 스캔이 된다.

    private var compactArenaBody: some View {
        // regularArenaBody 와 같은 이유로 이음매마다 타입을 끊는다(그쪽 주석 참조).
        // 지금은 섹션이 6개라 아직 안 터지지만, 넓은 폭이 10개에서 터졌으므로
        // 여기도 한두 개만 더 붙으면 같은 자리에 도달한다. 미리 끊어 둔다.
        VStack(alignment: .leading,
               spacing: isShortViewport ? Tokens.Space.s3 : Tokens.Space.s6) {
            AnyView(compactHeader.entrance(0))

            if let loadedContent {
                if case .cached = loadedContent.freshness {
                    AnyView(staleSnapshotNotice(loadedContent).entrance(1))
                }

                let snapshot = loadedContent.snapshot

                AnyView(compactStatusCard(snapshot).entrance(2))
                AnyView(compactActionStack(snapshot).entrance(3))
                // 방금 한 행동의 결과가 바로 아래에 온다 — 접힌 상세보다 앞이다.
                AnyView(heldReviewSection.entrance(4))
                AnyView(recentResultsSection.entrance(4))
                AnyView(compactDetailFolds(snapshot).entrance(5))
                AnyView(truthNotice(snapshot).entrance(6))
            } else {
                // 로딩·실패·비로그인은 기존 히어로가 문구와 재시도 버튼을 모두 갖고
                // 있다. 상태 화면까지 새로 만들지 않는다.
                hero
                    .entrance(1)
            }
        }
    }

    /// 좁은 폭 머리말 — 제목과 신선도·새로고침만 남긴다.
    /// 종전의 홍보 문장("매일의 학습으로 …")은 바로 위 아이브로우
    /// "수학으로 겨루는 1대1 Arena" 와 같은 말이라 좁은 폭에서 뺀다. 보조 버튼
    /// (상점·이용권 / 공식 룰북)은 아래 "지금 할 수 있는 행동"으로 내렸다 —
    /// 첫 화면의 버튼은 지금 눌러야 하는 것 옆에 있어야 한다.
    private var compactHeader: some View {
        Group {
            if isShortViewport && !dynamicTypeSize.isAccessibilitySize {
                AnyView(shortCompactHeader)
            } else {
                AnyView(stackedCompactHeader)
            }
        }
    }

    /// iPhone 가로에서는 상단 앱 바가 이미 화면명을 보조하고, 본문 높이는 약 200pt뿐이다.
    /// 눈썹줄+대형 제목으로 70pt를 쓰면 경기 CTA가 반드시 다음 화면으로 밀린다.
    /// 제목·동기화만 한 줄에 두되 헤더 의미와 44pt 새로고침 표적은 유지한다.
    private var shortCompactHeader: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s1) {
            HStack(alignment: .center, spacing: Tokens.Space.s3) {
                Text("GOAT Arena")
                    .font(.mHeading)
                    .foregroundStyle(Tokens.ink)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: Tokens.Space.s2)
                headerSyncControl
            }
            ExamRule()
        }
    }

    private var stackedCompactHeader: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s3) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s3) {
                    headerTitle
                    Spacer(minLength: Tokens.Space.s2)
                    headerSyncControl
                }

                VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                    headerTitle
                    headerSyncControl
                }
            }

            ExamRule()
        }
    }

    // MARK: 1단 — 지금 상태 한 덩어리

    /// 화면에서 유일한 네이비 면(CI 규정: 히어로는 하나). 종전에 세로로 흩어져
    /// 있던 네 값(티어·MMR·Arena 자리·사이클 진행)을 한 카드로 모은다.
    /// 값·상태 문구는 전부 서버 스냅샷과 기존 라벨 함수에서 온다.
    private func compactStatusCard(_ snapshot: Snapshot) -> some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Tokens.arenaAccent)
                .frame(height: 3)
                .accessibilityHidden(true)

            Group {
                if isShortViewport && !dynamicTypeSize.isAccessibilitySize {
                    shortCompactStatusContent(snapshot)
                } else {
                    stackedCompactStatusContent(snapshot)
                }
            }
            .padding(.horizontal, isShortViewport ? Tokens.Space.s3 : heroPadding)
            .padding(.vertical, isShortViewport ? Tokens.Space.s2 : heroPadding)
        }
        // 이미지 없는 정보 카드라도 접근성 최대 크기에서는 4값이 서로를 밀어낸다.
        // 같은 정보가 아래 디스클로저 본문에서 제한 없이 다시 읽히므로 상한을 둔다.
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tokens.brandNavy)
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.xl))
        .overlay {
            RoundedRectangle(cornerRadius: Tokens.Radius.xl)
                .strokeBorder(Tokens.brandCyan.opacity(0.26), lineWidth: 1)
        }
    }

    /// 상태 카드도 두 레이아웃을 각각 지운다. 이 화면은 섹션 수가 많아 작은
    /// 분기 하나만 더 중첩해도 런타임 타입 해석 재귀가 다시 깊어진다.
    private func shortCompactStatusContent(_ snapshot: Snapshot) -> AnyView {
        AnyView(
            HStack(alignment: .top, spacing: Tokens.Space.s3) {
                shortIdentityTier(snapshot)
                    .frame(maxWidth: .infinity, alignment: .topLeading)

                Rectangle()
                    .fill(onNavy.opacity(0.16))
                    .frame(width: 1)
                    .frame(maxHeight: .infinity)
                    .accessibilityHidden(true)

                compactSkillSeatRow(snapshot)
                    .frame(maxWidth: .infinity, alignment: .topLeading)

                Rectangle()
                    .fill(onNavy.opacity(0.16))
                    .frame(width: 1)
                    .frame(maxHeight: .infinity)
                    .accessibilityHidden(true)

                shortCycleSummary(snapshot)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        )
    }

    /// 짧은 화면의 신원·티어 열. 같은 내용을 두 덩어리로 세로 적층하지 않고
    /// 배지와 티어를 한 줄로 묶어 카드 높이를 줄인다.
    private func shortIdentityTier(_ snapshot: Snapshot) -> some View {
        let skill = snapshot.ranking.skill
        return VStack(alignment: .leading, spacing: Tokens.Space.s2) {
            HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s2) {
                Text(snapshot.identity.displayName)
                    .font(.mBodyB)
                    .foregroundStyle(onNavy)
                    .lineLimit(1)
                Spacer(minLength: 0)
                compactPhaseChip(snapshot)
            }
            Text(identityDetail(snapshot))
                .font(.mMicro)
                .foregroundStyle(onNavy.opacity(0.62))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            HStack(spacing: Tokens.Space.s2) {
                RankBadgeView(tierCode: skill.tier, size: 32, animated: true)
                VStack(alignment: .leading, spacing: 0) {
                    Text("현재 티어")
                        .font(.mMicro)
                        .foregroundStyle(onNavy.opacity(0.55))
                    Text(tierLabel(skill.tier))
                        .font(.mCallout)
                        .foregroundStyle(onNavy)
                        .lineLimit(1)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(snapshot.identity.displayName), \(identityDetail(snapshot)), 현재 티어 \(tierLabel(skill.tier))")
    }

    /// 진행일·전장·남은 조건을 세 번째 열 하나에 모은다. 접근성 큰 글자에서는 이
    /// 축약을 쓰지 않고 아래 stackedCompactStatusContent가 모든 줄을 세로로 푼다.
    @ViewBuilder
    private func shortCycleSummary(_ snapshot: Snapshot) -> some View {
        if let cycle = snapshot.cycle {
            VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s1) {
                    Text("진행일")
                        .font(.mMicro)
                        .foregroundStyle(onNavy.opacity(0.55))
                    Text("\(cycle.cycleDay ?? 0) / 30")
                        .font(.mBodyB)
                        .foregroundStyle(onNavy)
                        .monospacedDigit()
                    Spacer(minLength: Tokens.Space.s1)
                    Text(ArenaDisplayTerms.mode(cycle.activeRanking))
                        .font(.mMicro)
                        .foregroundStyle(onNavy.opacity(0.72))
                        .lineLimit(1)
                }
                cycleRunline(day: cycle.cycleDay ?? 0)
                HStack(alignment: .top, spacing: Tokens.Space.s1) {
                    Image(systemName: "target")
                        .font(.mMicro)
                        .foregroundStyle(Tokens.brandCyan)
                        .accessibilityHidden(true)
                    Text(compactRequirementLine(snapshot))
                        .font(.mMicro)
                        .foregroundStyle(onNavy.opacity(0.78))
                        .lineLimit(2)
                        .minimumScaleFactor(0.76)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                "30일 중 \(cycle.cycleDay ?? 0)일차, \(ArenaDisplayTerms.mode(cycle.activeRanking)), \(compactRequirementLine(snapshot))")
        } else {
            Text("현재 활성 30일 사이클이 없습니다")
                .font(.mBodyB)
                .foregroundStyle(onNavy)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func stackedCompactStatusContent(_ snapshot: Snapshot) -> AnyView {
        AnyView(
            VStack(alignment: .leading, spacing: Tokens.Space.s5) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: Tokens.Space.s3) {
                        heroIdentity(snapshot)
                        Spacer(minLength: Tokens.Space.s2)
                        compactPhaseChip(snapshot)
                    }

                    VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                        heroIdentity(snapshot)
                        compactPhaseChip(snapshot)
                    }
                }

                compactTierRow(snapshot)
                compactSkillSeatRow(snapshot)
                compactCycleOrEmpty(snapshot)
            }
        )
    }

    @ViewBuilder
    private func compactCycleOrEmpty(_ snapshot: Snapshot) -> some View {
        if let cycle = snapshot.cycle {
            compactCycleBlock(snapshot, cycle: cycle)
        } else {
            Text("현재 활성 30일 사이클이 없습니다")
                .font(.mBodyB)
                .foregroundStyle(onNavy)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private func compactPhaseChip(_ snapshot: Snapshot) -> some View {
        if let cycle = snapshot.cycle {
            heroEyebrow(phaseLabel(cycle), color: phaseColor(cycle))
        } else {
            heroEyebrow("사이클 시작 전", color: onNavy.opacity(0.68))
        }
    }

    /// 티어 한 줄 — 휘장 + "현재 티어" + 서버 티어 라벨.
    private func compactTierRow(_ snapshot: Snapshot) -> some View {
        let skill = snapshot.ranking.skill
        return HStack(alignment: .center, spacing: Tokens.Space.s3) {
            RankBadgeView(tierCode: skill.tier, size: 46, animated: true)
            VStack(alignment: .leading, spacing: 2) {
                Text("현재 티어")
                    .font(.mMicro)
                    .foregroundStyle(onNavy.opacity(0.55))
                Text(tierLabel(skill.tier))
                    .font(.mHeading)
                    .foregroundStyle(onNavy)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("현재 티어 \(tierLabel(skill.tier))")
    }

    /// MMR 과 Arena 자리를 한 줄에 나란히. 두 값이 다른 숫자라는 사실은
    /// 라벨과 상태 문구가 말한다(설명 문단은 아래 디스클로저로 내렸다).
    private func compactSkillSeatRow(_ snapshot: Snapshot) -> some View {
        let skill = snapshot.ranking.skill
        let seat = snapshot.ranking.seat
        return HStack(alignment: .top, spacing: Tokens.Space.s4) {
            compactStatusMetric(
                label: "실력 점수 MMR",
                value: skill.mmr.map(formatted) ?? "미발급",
                note: skillStatusLabel(skill.status))
            Rectangle()
                .fill(onNavy.opacity(0.16))
                .frame(width: 1)
                .frame(maxHeight: .infinity)
                .accessibilityHidden(true)
            compactStatusMetric(
                label: "Arena 자리",
                value: seat.arenaPosition.map { "#\($0)" } ?? "미배정",
                note: seatStatusLabel(seat.status))
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func compactStatusMetric(
        label: String,
        value: String,
        note: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.mMicro)
                .foregroundStyle(onNavy.opacity(0.55))
            Text(value)
                .font(.mStat)
                .foregroundStyle(onNavy)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(note)
                .font(.mMicro)
                .foregroundStyle(onNavy.opacity(0.62))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) \(value), \(note)")
    }

    /// 사이클 — 며칠째인지와 남은 조건 한 줄. 진행선은 종전 30칸 런라인 그대로.
    private func compactCycleBlock(_ snapshot: Snapshot, cycle: Snapshot.Cycle) -> some View {
        VStack(alignment: .leading,
               spacing: isShortViewport ? Tokens.Space.s2 : Tokens.Space.s3) {
            HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s2) {
                Text("진행일")
                    .font(.mMicro)
                    .foregroundStyle(onNavy.opacity(0.55))
                Text("\(cycle.cycleDay ?? 0)")
                    .font(Font.stat(dynamicTypeSize.isAccessibilitySize ? 28 : 34))
                    .foregroundStyle(onNavy)
                    .monospacedDigit()
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                Text("/ 30")
                    .font(.mCallout)
                    .foregroundStyle(onNavy.opacity(0.5))
                    .lineLimit(1)
                Spacer(minLength: Tokens.Space.s2)
                Text(ArenaDisplayTerms.mode(cycle.activeRanking))
                    .font(.mCaption)
                    .foregroundStyle(onNavy.opacity(0.72))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                "30일 중 \(cycle.cycleDay ?? 0)일차, 현재 \(ArenaDisplayTerms.mode(cycle.activeRanking))")

            cycleRunline(day: cycle.cycleDay ?? 0)

            HStack(alignment: .top, spacing: Tokens.Space.s2) {
                Image(systemName: "target")
                    .font(.mMicro)
                    .foregroundStyle(Tokens.brandCyan)
                    .accessibilityHidden(true)
                Text(compactRequirementLine(snapshot))
                    .font(.mCaption)
                    .foregroundStyle(onNavy.opacity(0.78))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
        }
    }

    /// "남은 조건" 한 줄. 서버 payback.conditions 의 미충족 항목을 기존 라벨·
    /// 카운트 함수로 그대로 이어 붙일 뿐, 새 기준이나 숫자를 만들지 않는다.
    private func compactRequirementLine(_ snapshot: Snapshot) -> String {
        if snapshot.payback.state == "POLICY_PENDING" {
            return "최종 판정 기준 확인 중"
        }
        let unmet = snapshot.payback.conditions.filter { !$0.met }
        guard !unmet.isEmpty else {
            return snapshot.payback.eligible == true
                ? "세 조건을 모두 충족했습니다"
                : "서버의 다음 판정을 기다리세요"
        }
        return unmet
            .prefix(2)
            .map { "\(conditionTitle($0.key)) \(conditionCount($0))" }
            .joined(separator: " · ")
    }

    // MARK: 2단 — 지금 할 수 있는 행동

    private func compactActionStack(_ snapshot: Snapshot) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s3) {
            // 도착한 Ranked 초대(= 수락·거절을 실제로 보낼 수 있는 유일한 상태)를
            // 주 CTA 보다 **먼저** 놓는다. 실제 응답 버튼이 있는 최신 초대가
            // 설명문 아래로 밀리면 사용자가 할 일을 찾지 못한다.
            if let invitation = snapshot.pendingInvitation {
                pendingInvitationSection(invitation)
            }

            // 결과를 확인하지 못한 지난 응답의 복구 버튼. 종전에는 이 두 조각이
            // 파일 안에 정의만 되어 있고 부르는 곳이 없어(HEAD 도 동일) 타임아웃
            // 뒤 같은 요청을 다시 확인할 길이 화면에 없었다.
            if let pendingDefenderCommand {
                defenderPendingRecovery(pendingDefenderCommand)
            }

            compactPrimaryAction(snapshot)

            compactSecondaryActions
        }
    }

    /// 보조 이동 버튼(랭킹·상점·룰북·아레나 더 보기)을 **2열 격자**로 맞춘다.
    /// 한 줄에 세 개는 iPhone 폭(402pt)에서 못 들어가 ViewThatFits 가 2+1 로
    /// 흘리는데, 그때 버튼 폭이 글자 길이대로 제각각이라 감독이 말한 "정렬도
    /// 안 돼 있다"가 여기서 그대로 보인다. 칸을 같은 폭으로 고정한다.
    /// 접근성 큰 글자에서는 두 칸이 좁아지므로 한 열로 내려간다.
    ///
    /// 네 번째 칸은 종전에 Ranked(MAIN)일 때만 "Ranked 상점"이었고 아니면 **빈 칸**이었다.
    /// 그 자리를 "아레나 더 보기"가 항상 채운다 — 칸 수가 그대로라 좁은 폭 높이는
    /// 한 픽셀도 늘지 않고, 알림·상점·규정·경기 관리·계좌 기능의 진입점이 생긴다.
    /// Ranked 상점은 그 시트 첫 줄과 "상점·이용권"(CommerceHub) 양쪽에 그대로 있다.
    private var compactSecondaryActions: some View {
        ViewThatFits(in: .horizontal) {
            VStack(spacing: Tokens.Space.s3) {
                HStack(spacing: Tokens.Space.s3) {
                    leaderboardButton.frame(maxWidth: .infinity)
                    commerceButton.frame(maxWidth: .infinity)
                }
                HStack(spacing: Tokens.Space.s3) {
                    rulebookButton.frame(maxWidth: .infinity)
                    arenaMoreMenuButton.frame(maxWidth: .infinity)
                }
            }

            VStack(spacing: Tokens.Space.s3) {
                leaderboardButton.frame(maxWidth: .infinity)
                commerceButton.frame(maxWidth: .infinity)
                rulebookButton.frame(maxWidth: .infinity)
                arenaMoreMenuButton.frame(maxWidth: .infinity)
            }
        }
    }

    /// 응답 결과를 확인하지 못한 상태의 복구 묶음 — 안내 문구와 재확인 버튼 모두
    /// 이미 있던 것을 그대로 쓴다(같은 commandId·같은 사유로만 다시 보낸다).
    private func defenderPendingRecovery(
        _ pending: GoatArenaPendingDefenderCommand
    ) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s3) {
            inlineNotice(
                icon: "arrow.clockwise.circle.fill",
                // 같은 파일의 오류 알림 제목을 그대로 쓴다 — 새 문구를 만들지 않는다.
                title: "경기 응답을 확인하지 못했습니다",
                detail: pendingDefenderCommandNotice,
                tint: Tokens.warningInk,
                background: Tokens.warningSoft)

            defenderPendingRetryButton(pending)
        }
    }

    /// 좁은 폭의 주 CTA 하나. 판정 규칙은 종전 heroPrimaryAction 과 동일하고,
    /// 사이클이 없을 때(이용권 안내)와 배치고사 대기를 히어로 밖에서도 같은
    /// 우선순위로 잡도록 한곳에 모았다. 새 조건을 만들지 않는다.
    @ViewBuilder
    private func compactPrimaryAction(_ snapshot: Snapshot) -> some View {
        if let match = snapshot.activeMatch, canPlay(match) {
            Button {
                guard let matchId = match.id?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !matchId.isEmpty else { return }
                matchLaunch = MatchLaunch(id: matchId, briefing: matchBriefing(match))
            } label: {
                Label(
                    needsEvidenceSubmission(match)
                        ? "풀이 증거 제출하기"
                        : (match.attempt?.status == "IN_PROGRESS"
                            ? "경기 계속하기" : "경기 시작하기"),
                    systemImage: needsEvidenceSubmission(match)
                        ? "photo.badge.arrow.down"
                        : (match.attempt?.status == "IN_PROGRESS"
                            ? "arrow.right.circle.fill" : "play.fill"))
                    .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(PrimaryButtonStyle())
            .accessibilityHint("서버가 확정한 이 경기의 개인 문제 화면을 엽니다")
        } else if snapshot.ranking.skill.status == "PLACEMENT_PENDING" {
            Button {
                store.route = .placement
            } label: {
                Label("배치고사 시작 또는 이어하기", systemImage: "list.number")
                    .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(PrimaryButtonStyle())
            .accessibilityHint("앱 안에서 배치고사 30문항을 시작하거나 저장된 지점부터 이어갑니다")
        } else if let cycle = snapshot.cycle,
                  snapshot.activeMatch == nil,
                  cycle.phase == "PAID_ACCESS",
                  (cycle.cycleDay ?? 0) <= (cycle.challenges.newRequestCutoffDay ?? 28) {
            if !canCommandMatchesNatively {
                // 실서버에는 경기 명령 라우트가 없다 — 눌러도 404 인 CTA 를 세우는 대신
                // 신청 페이지 자체로 보낸다(canCommandMatchesNatively 주석 참조).
                webArenaFallback(
                    onDark: false,
                    destination: matchmakingWebDestination(cycle),
                    title: cycle.activeRanking == "MAIN"
                        ? "웹에서 Ranked 상대 찾기"
                        : "웹에서 Unranked 상대 찾기")
            } else if cycle.activeRanking == "MAIN" {
                Button {
                    showsMainMatchMaker = true
                } label: {
                    HStack(spacing: Tokens.Space.s3) {
                        Image(systemName: "person.2.fill")
                        Text("Ranked 상대 찾기")
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                        Spacer(minLength: Tokens.Space.s3)
                        Image(systemName: "arrow.right")
                    }
                    .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isRefreshing)
                .accessibilityHint("앱 안에서 Ranked 티어와 예치 일수를 선택합니다")
            } else {
                Button {
                    Task { await createUnrankedMatch() }
                } label: {
                    HStack(spacing: Tokens.Space.s3) {
                        if isCreatingSubMatch {
                            ProgressView()
                                .tint(Tokens.onPrimary)
                        } else {
                            Image(systemName: "person.2.fill")
                        }
                        Text(isCreatingSubMatch ? "상대 찾는 중" : "Unranked 상대 찾기")
                            .lineLimit(1)
                        Spacer(minLength: Tokens.Space.s3)
                        Image(systemName: "arrow.right")
                    }
                    .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isCreatingSubMatch || isRefreshing)
                .accessibilityHint("현재 자격을 다시 확인하고 공식 Unranked 경기를 만듭니다")
            }
        } else if snapshot.cycle == nil {
            Button {
                store.route = .commerce
            } label: {
                Label("이용권과 상점 보기", systemImage: "bag")
                    .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(PrimaryButtonStyle())
            .accessibilityHint("구독 상태와 결제, Ranked 상점 이용 조건을 확인합니다")
        } else if let match = snapshot.activeMatch {
            // 지금 누를 수 있는 경기 버튼이 없는 구간(응답 대기·채점·정산 등).
            // 빈 자리로 두면 "뭘 봐야 할지" 다시 사라진다 — 서버가 준 다음 행동
            // 문구를 그대로 한 줄로 세운다.
            VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                inlineNotice(
                    icon: "arrow.right.circle.fill",
                    title: matchNextActionTitle(match),
                    detail: matchNextActionDetail(match),
                    tint: Tokens.primary,
                    background: Tokens.primarySoft)

                if needsDefenderResponseRefresh(snapshot) {
                    defenderResponseRefreshButton
                }
            }
        }
    }

    /// 서버 snapshot에는 방어자 MATCHED 경기가 남아 있지만 응답 가능한 초대가
    /// 함께 오지 않은 복구 상태. 이때 수락·거절 버튼을 꾸며 내면 안 되고, 사용자가
    /// 같은 화면에서 최신 상태를 다시 받을 수 있게 해야 한다.
    private func needsDefenderResponseRefresh(_ snapshot: Snapshot) -> Bool {
        guard let match = snapshot.activeMatch else { return false }
        return match.role == "DEFENDER"
            && match.status == "MATCHED"
            && snapshot.pendingInvitation == nil
            && pendingDefenderCommand == nil
    }

    private var defenderResponseRefreshButton: some View {
        Button {
            Task { await load() }
        } label: {
            Label(
                isRefreshing ? "최신 경기 상태 확인 중" : "최신 경기 상태 다시 확인",
                systemImage: "arrow.clockwise")
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(SecondaryButtonStyle())
        .disabled(isRefreshing)
        .accessibilityHint("수락 또는 거절 가능 여부를 서버에서 다시 확인합니다")
    }

    /// 아레나 보조 기능들의 **단일 진입점**. 목록은 시트가 든다.
    private var arenaMoreMenuButton: some View {
        Button {
            showsArenaMoreMenu = true
        } label: {
            Label("아레나 더 보기", systemImage: "square.grid.2x2")
                .font(.mCaption)
                .frame(minHeight: 44)
        }
        .buttonStyle(SecondaryButtonStyle())
        .accessibilityHint("우편함·상점·경기 규정·프로필 등 웹 GOAT Arena 기능을 목록에서 고릅니다")
    }

    // MARK: 3단 — 접힌 상세

    private func compactDetailFolds(_ snapshot: Snapshot) -> some View {
        VStack(spacing: 0) {
            if let match = snapshot.activeMatch, snapshot.cycle != nil {
                compactFold(
                    id: "match",
                    title: "진행 중인 자리 쟁탈전",
                    summary: matchStatusLabel(match.status),
                    icon: "flag.checkered",
                    tint: Tokens.primary
                ) {
                    compactMatchDetail(match)
                }
            }

            compactFold(
                id: "ranking",
                title: "실력과 자리",
                summary: "\(skillStatusLabel(snapshot.ranking.skill.status)) · \(seatStatusLabel(snapshot.ranking.seat.status))",
                icon: "chart.bar.fill",
                tint: Tokens.text2
            ) {
                compactRankingDetail(snapshot)
            }

            if let cycle = snapshot.cycle {
                compactFold(
                    id: "access",
                    title: "오늘 이용 상태",
                    summary: learningAccessPresentation(cycle).badge,
                    icon: "lock.open.fill",
                    tint: learningAccessPresentation(cycle).tint
                ) {
                    compactAccessDetail(snapshot, cycle: cycle)
                }

                compactFold(
                    id: "payback",
                    title: "페이백 조건",
                    summary: paybackPresentation(snapshot.payback).label,
                    icon: "checkmark.seal.fill",
                    tint: paybackPresentation(snapshot.payback).color
                ) {
                    compactPaybackDetail(snapshot)
                }

                compactFold(
                    id: "asset",
                    title: "Arena 자산",
                    summary: compactAssetSummary(cycle.balances),
                    icon: "creditcard.fill",
                    tint: Tokens.text2
                ) {
                    compactAssetDetail(cycle.balances)
                }
            }
        }
    }

    private func compactAssetSummary(_ balances: Snapshot.Cycle.Balances) -> String {
        "페이백 \(balances.refundAvailableDays)점 · 학습 \(balances.bonusAvailableDays)일"
    }

    /// 접힌 줄 하나. 제목 옆의 요약은 **서버가 준 상태 라벨**이라, 펼치지 않아도
    /// 지금 상태를 읽을 수 있다. 색만으로 말하지 않도록 요약은 항상 글자다.
    @ViewBuilder
    private func compactFold<Content: View>(
        id: String,
        title: String,
        summary: String,
        icon: String,
        tint: Color,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        let expanded = expandedCompactSections.contains(id)

        VStack(alignment: .leading, spacing: Tokens.Space.s4) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    if expanded {
                        expandedCompactSections.remove(id)
                    } else {
                        expandedCompactSections.insert(id)
                    }
                }
            } label: {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: Tokens.Space.s3) {
                        compactFoldIcon(icon, tint: tint)
                        Text(title)
                            .font(.mBodyB)
                            .foregroundStyle(Tokens.ink)
                            .lineLimit(1)
                        Spacer(minLength: Tokens.Space.s3)
                        Text(summary)
                            .font(.mCaption)
                            .foregroundStyle(tint)
                            .lineLimit(1)
                        compactFoldChevron(expanded)
                    }

                    HStack(alignment: .top, spacing: Tokens.Space.s3) {
                        compactFoldIcon(icon, tint: tint)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(title)
                                .font(.mBodyB)
                                .foregroundStyle(Tokens.ink)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(summary)
                                .font(.mCaption)
                                .foregroundStyle(tint)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: Tokens.Space.s2)
                        compactFoldChevron(expanded)
                    }
                }
                .padding(.vertical, Tokens.Space.s3)
                .frame(minHeight: 52)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(title), \(summary)")
            .accessibilityAddTraits(.isButton)
            .accessibilityHint(expanded ? "두 번 탭하면 접습니다" : "두 번 탭하면 자세히 펼칩니다")

            if expanded {
                content()
                    .padding(.bottom, Tokens.Space.s5)
            }
        }
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Tokens.line)
                .frame(height: 1)
                .accessibilityHidden(true)
        }
    }

    private func compactFoldIcon(_ icon: String, tint: Color) -> some View {
        Image(systemName: icon)
            .font(.mCaption)
            .foregroundStyle(tint)
            .frame(width: 22)
            .accessibilityHidden(true)
    }

    private func compactFoldChevron(_ expanded: Bool) -> some View {
        Image(systemName: "chevron.down")
            .font(.mMicro)
            .foregroundStyle(Tokens.text3)
            .rotationEffect(.degrees(expanded ? 180 : 0))
            .accessibilityHidden(true)
    }

    // MARK: 접힌 상세 본문 — 기존 구성요소를 그대로 다시 쓴다

    /// 경기 상세. 주 행동(경기 시작·계속)은 위 CTA 로 이미 올라갔고, 여기는
    /// 상태·자리·마감·정산 규칙만 담는다. 장식 배너는 좁은 폭에서 뺀다.
    private func compactMatchDetail(_ match: Snapshot.ActiveMatch) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s4) {
            statusDecisionRow(matchStatusPresentation(match))

            VStack(alignment: .leading, spacing: Tokens.Space.s4) {
                HStack(spacing: Tokens.Space.s5) {
                    matchPosition(label: "내 자리", value: match.myPositionBefore)
                    Image(systemName: "arrow.left.arrow.right")
                        .foregroundStyle(Tokens.primary)
                        .accessibilityHidden(true)
                    matchPosition(label: "상대 자리", value: match.opponentPositionBefore)
                }
                DottedRule()
                matchFacts(match)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Tokens.Space.s5)
            .background(Tokens.surface)
            .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: Tokens.Radius.lg)
                    .strokeBorder(Tokens.line, lineWidth: 1))

            matchDeadlineSection(match)

            Text(matchSettlementRule(match))
                .font(.mCaption)
                .foregroundStyle(Tokens.text2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// MMR·자리 설명과 두 패널. 카드 위쪽에 이미 값이 있으므로 여기는 "왜 두
    /// 숫자가 다른가"와 상태 문구를 담당한다.
    private func compactRankingDetail(_ snapshot: Snapshot) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s4) {
            Text("MMR은 시험 성과로 바뀌고, Arena Position은 직접 대결에서만 서로 교환됩니다.")
                .font(.mCallout)
                .foregroundStyle(Tokens.text2)
                .fixedSize(horizontal: false, vertical: true)

            statusDecisionRow(rankingLifecyclePresentation(snapshot))

            mmrPanel(snapshot.ranking.skill)
            seatPanel(
                snapshot.ranking.seat,
                activeRanking: snapshot.ranking.activeRanking)

            if let season = snapshot.season {
                HStack(spacing: Tokens.Space.s2) {
                    Image(systemName: "calendar")
                    Text(
                        [season.title, season.currentWeekKey]
                            .compactMap { $0 }
                            .joined(separator: ", "))
                }
                .font(.mCaption)
                .foregroundStyle(Tokens.text2)
                .accessibilityElement(children: .combine)
            }

            if snapshot.ranking.activeRanking == "MAIN",
               snapshot.capabilities.mainArena == "POLICY_PENDING" {
                inlineNotice(
                    icon: "clock.badge.exclamationmark",
                    title: "Ranked 운영 기준 확인 중",
                    detail: "티어 간 도전 비용과 Rank Shield·Revenge 관계가 확정되기 전에는 앱이 도전 가능 범위를 추측하지 않습니다.",
                    tint: Tokens.warningInk,
                    background: Tokens.warningSoft)
            }
        }
    }

    private func compactAccessDetail(_ snapshot: Snapshot, cycle: Snapshot.Cycle) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s4) {
            Text("서버가 판정한 오늘의 이용 범위와 다음 행동입니다. Day 30은 유료 이용 연장이 아니라 별도의 Completion Pass입니다.")
                .font(.mCallout)
                .foregroundStyle(Tokens.text2)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 0) {
                statusDecisionRow(learningAccessPresentation(cycle))
                DottedRule()
                statusDecisionRow(challengeWindowPresentation(snapshot, cycle: cycle))
                DottedRule()
                statusDecisionRow(nextActionPresentation(snapshot, cycle: cycle))
            }
        }
    }

    private func compactPaybackDetail(_ snapshot: Snapshot) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s4) {
            Text("같은 이용 주기 안에서 정책에 정한 연속 학습과 페이백 점수 기준을 함께 충족해야 합니다.")
                .font(.mCallout)
                .foregroundStyle(Tokens.text2)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 0) {
                ForEach(Array(snapshot.payback.conditions.enumerated()), id: \.element.id) { index, condition in
                    if index > 0 {
                        DottedRule()
                    }
                    conditionRow(index: index + 1, condition: condition)
                }
            }

            if snapshot.payback.state == "POLICY_PENDING" {
                inlineNotice(
                    icon: "clock.badge.exclamationmark",
                    title: "최종 판정 기준 확인 중",
                    detail: policyPendingDetail(snapshot.payback),
                    tint: Tokens.warningInk,
                    background: Tokens.warningSoft)
            } else {
                ForEach(snapshot.payback.blockers) { blocker in
                    let presentation = paybackBlockerPresentation(blocker)
                    inlineNotice(
                        icon: presentation.icon,
                        title: presentation.title,
                        detail: presentation.detail,
                        tint: presentation.tint,
                        background: presentation.background)
                }
            }
        }
    }

    private func compactAssetDetail(_ balances: Snapshot.Cycle.Balances) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s4) {
            stackedAssetColumns(balances)

            Text("페이백 점수와 학습 가능 일수는 서로 바꾸거나 합산하지 않습니다. 대결에 예치한 값도 사용 가능한 값과 따로 표시됩니다.")
                .font(.mCaption)
                .foregroundStyle(Tokens.text2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s3) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s4) {
                    headerTitle
                    Spacer(minLength: Tokens.Space.s3)
                    headerSyncControl
                }

                VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                    headerTitle
                    headerSyncControl
                }
            }

            ExamRule()

            if dynamicTypeSize.isAccessibilitySize {
                headerActions
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .center, spacing: Tokens.Space.s4) {
                        headerDescription
                        Spacer(minLength: Tokens.Space.s3)
                        headerActions
                    }

                    VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                        headerDescription
                        headerActions
                    }
                }
            }
        }
    }

    private var headerDescription: some View {
        Text("매일의 학습으로 페이백 조건을 채우고, 직접 대결로 Arena 자리를 차지합니다.")
            .font(.mCallout)
            .foregroundStyle(Tokens.text2)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var rulebookButton: some View {
        Button {
            showsRulebook = true
        } label: {
            Label("공식 룰북", systemImage: "book.closed")
                .font(.mCaption)
                .frame(minHeight: 44)
        }
        .buttonStyle(SecondaryButtonStyle())
        .accessibilityHint("GOAT Arena의 공식 경기 규칙을 엽니다")
    }

    private var commerceButton: some View {
        Button {
            store.route = .commerce
        } label: {
            Label("상점·이용권", systemImage: "bag")
                .font(.mCaption)
                .frame(minHeight: 44)
        }
        .buttonStyle(SecondaryButtonStyle())
        .accessibilityHint("기간 이용권과 Ranked 상점을 한곳에서 확인합니다")
    }

    /// 전체 순위표로 가는 문. 이 화면은 "내 자리 #137"만 말하고 그 위아래에 누가
    /// 있는지는 말하지 않았는데, 정작 순위표로 가는 경로가 로그인 상태에서
    /// 사라져 있었다(RootView 279행: authProvider == "server" 면 GoatArenaScreen
    /// 만 뜬다). 새 순위표를 만들지 않고 기존 RankArenaScreen 을 시트로 연다.
    private var leaderboardButton: some View {
        Button {
            showsLeaderboard = true
        } label: {
            Label("전체 랭킹", systemImage: "list.number")
                .font(.mCaption)
                .frame(minHeight: 44)
        }
        .buttonStyle(SecondaryButtonStyle())
        .accessibilityHint("현재 랭킹 순위표를 엽니다")
    }

    /// 넓은 폭(iPad)의 보조 버튼 줄. "아레나 더 보기"가 여기서도 보조 기능의
    /// 진입점이다 — 좁은 폭에만 문을 달면 iPad 학생은 우편함·규정·페이백 계좌로
    /// 갈 길이 아예 없다. 줄바꿈 사다리에 한 단(2×2)을 더해 폭이 모자랄 때도
    /// 버튼 폭이 제각각이 되지 않게 한다.
    private var headerActions: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Tokens.Space.s3) {
                leaderboardButton
                commerceButton
                rulebookButton
                arenaMoreMenuButton
            }
            VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                HStack(spacing: Tokens.Space.s3) {
                    leaderboardButton
                    commerceButton
                }
                HStack(spacing: Tokens.Space.s3) {
                    rulebookButton
                    arenaMoreMenuButton
                }
            }
            VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                leaderboardButton
                commerceButton
                rulebookButton
                arenaMoreMenuButton
            }
        }
    }

    private var headerTitle: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
            if !dynamicTypeSize.isAccessibilitySize {
                Text("수학으로 겨루는 1대1 Arena")
                    .font(.mMicro)
                    .foregroundStyle(Tokens.text3)
            }
            Text("GOAT Arena")
                .font(.mTitle)
                .foregroundStyle(Tokens.ink)
                .accessibilityAddTraits(.isHeader)
        }
    }

    @ViewBuilder
    private var headerSyncControl: some View {
        if isBusy {
            HStack(spacing: Tokens.Space.s2) {
                ProgressView()
                    .controlSize(.small)
                Text(isRefreshing ? "기록 갱신 중" : "불러오는 중")
                    .font(.mCaption)
                    .foregroundStyle(Tokens.text2)
            }
            .frame(minHeight: 44)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(isRefreshing ? "GOAT Arena 기록 갱신 중" : "GOAT Arena 불러오는 중")
        } else if let loadedContent {
            HStack(spacing: Tokens.Space.s2) {
                Label(
                    freshnessShortLabel(loadedContent.freshness),
                    systemImage: freshnessIcon(loadedContent.freshness))
                    .font(.mCaption)
                    .foregroundStyle(freshnessTint(loadedContent.freshness))
                    .lineLimit(1)

                Button {
                    Task { await load() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.body.weight(.semibold))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(Tokens.primary)
                .accessibilityLabel("Arena 기록 새로고침")
                .accessibilityHint("서버의 최신 기록을 다시 불러옵니다")
            }
        }
    }

    private func freshnessShortLabel(_ freshness: SnapshotFreshness) -> String {
        switch freshness {
        case .fresh:
            return "최신 기록"
        case .cached(let savedAt, _):
            return "\(relativeTime(savedAt)) 기록"
        }
    }

    private func freshnessIcon(_ freshness: SnapshotFreshness) -> String {
        switch freshness {
        case .fresh:
            return "checkmark.circle.fill"
        case .cached(_, let failure):
            return failure.kind == .offline ? "wifi.slash" : "clock.arrow.circlepath"
        }
    }

    private func freshnessTint(_ freshness: SnapshotFreshness) -> Color {
        switch freshness {
        case .fresh:
            return Tokens.successInk
        case .cached:
            return Tokens.warningInk
        }
    }

    // MARK: Hero

    private var hero: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Tokens.arenaAccent)
                .frame(height: 3)
                .accessibilityHidden(true)

            Group {
                switch state {
                case .idle, .loading:
                    loadingHero
                case .signedOut:
                    signedOutHero
                case .failed(let failure):
                    failedHero(failure)
                case .loaded(let content):
                    loadedHero(content.snapshot)
                }
            }
            .padding(heroPadding)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tokens.brandNavy)
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.xl))
        .overlay {
            RoundedRectangle(cornerRadius: Tokens.Radius.xl)
                .strokeBorder(Tokens.brandCyan.opacity(0.26), lineWidth: 1)
        }
    }

    private var onNavy: Color { Tokens.onNavy }

    private var loadingHero: some View {
        HStack(spacing: Tokens.Space.s4) {
            ProgressView()
                .tint(onNavy)
            VStack(alignment: .leading, spacing: 3) {
                Text("내 30일 사이클을 확인하고 있습니다")
                    .font(.mBodyB)
                    .foregroundStyle(onNavy)
                Text("출석·일수·Arena 자리 데이터를 서버에서 불러옵니다.")
                    .font(.mCaption)
                    .foregroundStyle(onNavy.opacity(0.66))
            }
        }
        .frame(
            maxWidth: .infinity,
            minHeight: isShortViewport ? 92 : 132,
            alignment: .leading)
    }

    private var signedOutHero: some View {
        CompactHeightColumns(spacing: Tokens.Space.s5, stackedSpacing: Tokens.Space.s5) {
            VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                heroEyebrow("계정 연결 필요", color: Color(hex: 0xFFD66B))
                Text("로그인하면 내 사이클이 이어집니다")
                    .font(.mHeading)
                    .foregroundStyle(onNavy)
            }
        } trailing: {
            VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                Text("학습 기기와 관계없이 같은 출석·일수·Arena 자리를 보려면 Matths 계정이 필요합니다.")
                    .font(.mCallout)
                    .foregroundStyle(onNavy.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
                heroButton("로그인하기") {
                    store.signOut()
                }
            }
        }
    }

    private func failedHero(_ failure: FailurePresentation) -> some View {
        CompactHeightColumns(spacing: Tokens.Space.s5, stackedSpacing: Tokens.Space.s5) {
            VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                heroEyebrow(failureEyebrow(failure.kind), color: Color(hex: 0xFFD66B))
                Text(failureTitle(failure.kind))
                    .font(.mHeading)
                    .foregroundStyle(onNavy)
            }
        } trailing: {
            VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                Text(failure.message)
                    .font(.mCallout)
                    .foregroundStyle(onNavy.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
                heroButton("다시 시도") {
                    Task { await load() }
                }
                .accessibilityHint("서버의 GOAT Arena 기록을 다시 불러옵니다")
            }
        }
    }

    private func failureEyebrow(_ kind: FailureKind) -> String {
        switch kind {
        case .offline: return "오프라인"
        case .timeout: return "응답 지연"
        case .server: return "서버 연결 확인"
        case .incompatible: return "업데이트 필요"
        }
    }

    private func failureTitle(_ kind: FailureKind) -> String {
        switch kind {
        case .offline: return "인터넷 연결이 필요합니다"
        case .timeout: return "서버 응답이 늦어지고 있습니다"
        case .server: return "Arena 기록을 불러오지 못했습니다"
        case .incompatible: return "앱과 서버 버전을 확인해 주세요"
        }
    }

    @ViewBuilder
    private func loadedHero(_ snapshot: Snapshot) -> some View {
        if let cycle = snapshot.cycle {
            cycleHero(snapshot, cycle: cycle)
        } else {
            noCycleHero(snapshot)
        }
    }

    @ViewBuilder
    private func cycleHero(_ snapshot: Snapshot, cycle: Snapshot.Cycle) -> some View {
        // 세로가 짧으면 폭이 regular 인 Max 계열 가로에서도 넓은 히어로를 쓰지 않는다.
        // 54pt 숫자에 s6 간격, 3열 지표까지 얹으면 390pt 높이에서 본문이 화면 밖으로
        // 밀린다.
        if isCompact || isShortViewport || dynamicTypeSize.isAccessibilitySize {
            compactCycleHero(snapshot, cycle: cycle)
        } else {
            regularCycleHero(snapshot, cycle: cycle)
        }
    }

    private func compactCycleHero(_ snapshot: Snapshot, cycle: Snapshot.Cycle) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s4) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: Tokens.Space.s3) {
                    heroIdentity(snapshot)
                    Spacer(minLength: Tokens.Space.s2)
                    heroEyebrow(phaseLabel(cycle), color: phaseColor(cycle))
                }

                VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                    heroIdentity(snapshot)
                    heroEyebrow(phaseLabel(cycle), color: phaseColor(cycle))
                }
            }

            HStack(alignment: .bottom, spacing: Tokens.Space.s3) {
                HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s2) {
                    Text("진행일")
                        .font(.mMicro)
                        .foregroundStyle(onNavy.opacity(0.55))
                    Text("\(cycle.cycleDay ?? 0)")
                        .font(Font.stat(
                            dynamicTypeSize.isAccessibilitySize || isShortViewport ? 34 : 42))
                        .foregroundStyle(onNavy)
                        .monospacedDigit()
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                    Text("/ 30")
                        .font(.mStat)
                        .foregroundStyle(onNavy.opacity(0.5))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
                .layoutPriority(1)
                Spacer(minLength: Tokens.Space.s2)
                VStack(alignment: .leading, spacing: 3) {
                    Text("현재 모드")
                        .font(.mMicro)
                        .foregroundStyle(onNavy.opacity(0.52))
                    Text(ArenaDisplayTerms.mode(cycle.activeRanking))
                        .font(.mBodyB)
                        .foregroundStyle(onNavy)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .layoutPriority(1)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                "30일 중 \(cycle.cycleDay ?? 0)일차, 현재 \(ArenaDisplayTerms.mode(cycle.activeRanking))")

            cycleRunline(day: cycle.cycleDay ?? 0)
            heroPrimaryAction(snapshot, cycle: cycle)
        }
    }

    private func regularCycleHero(_ snapshot: Snapshot, cycle: Snapshot.Cycle) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s6) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: Tokens.Space.s4) {
                    heroIdentity(snapshot)
                    Spacer(minLength: Tokens.Space.s3)
                    heroEyebrow(
                        phaseLabel(cycle),
                        color: phaseColor(cycle))
                }

                VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                    heroIdentity(snapshot)
                    heroEyebrow(
                        phaseLabel(cycle),
                        color: phaseColor(cycle))
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s3) {
                Text("진행일")
                    .font(.mMicro)
                    .foregroundStyle(onNavy.opacity(0.55))
                Text("\(cycle.cycleDay ?? 0)")
                    .font(Font.stat(dynamicTypeSize.isAccessibilitySize ? 40 : 54))
                    .foregroundStyle(onNavy)
                    .monospacedDigit()
                Text("/ 30")
                    .font(.mStat)
                    .foregroundStyle(onNavy.opacity(0.5))
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("30일 중 \(cycle.cycleDay ?? 0)일차")

            cycleRunline(day: cycle.cycleDay ?? 0)

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: Tokens.Space.s8) {
                    heroMetric(
                        label: "현재 경쟁 풀",
                        value: rankingLabel(cycle.activeRanking))
                    heroMetric(
                        label: "페이백 점수",
                        value: "\(cycle.balances.refundAvailableDays)점")
                    heroMetric(
                        label: "완료한 직접 대결",
                        value: "\(cycle.challenges.completed)회")
                }
                .fixedSize(horizontal: true, vertical: false)

                VStack(alignment: .leading, spacing: Tokens.Space.s4) {
                    heroMetric(
                        label: "현재 경쟁 풀",
                        value: rankingLabel(cycle.activeRanking))
                    HStack(alignment: .top, spacing: Tokens.Space.s8) {
                        heroMetric(
                            label: "페이백 점수",
                            value: "\(cycle.balances.refundAvailableDays)점")
                        heroMetric(
                            label: "완료한 직접 대결",
                            value: "\(cycle.challenges.completed)회")
                    }
                }
            }

            Text(cycleFootnote(cycle))
                .font(.mCaption)
                .foregroundStyle(onNavy.opacity(0.66))
                .fixedSize(horizontal: false, vertical: true)

            heroPrimaryAction(snapshot, cycle: cycle)
        }
    }

    @ViewBuilder
    private func heroPrimaryAction(_ snapshot: Snapshot, cycle: Snapshot.Cycle) -> some View {
        if let match = snapshot.activeMatch, canPlay(match) {
            Button {
                guard let matchId = match.id?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !matchId.isEmpty else { return }
                matchLaunch = MatchLaunch(id: matchId, briefing: matchBriefing(match))
            } label: {
                Label(
                    needsEvidenceSubmission(match)
                        ? "풀이 증거 제출하기"
                        : (match.attempt?.status == "IN_PROGRESS"
                            ? "경기 계속하기" : "경기 시작하기"),
                    systemImage: needsEvidenceSubmission(match)
                        ? "photo.badge.arrow.down"
                        : (match.attempt?.status == "IN_PROGRESS"
                            ? "arrow.right.circle.fill" : "play.fill"))
                    .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(PrimaryButtonStyle())
        } else if snapshot.ranking.skill.status == "PLACEMENT_PENDING" {
            Button {
                store.route = .placement
            } label: {
                Label("배치고사 시작 또는 이어하기", systemImage: "list.number")
                    .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(PrimaryButtonStyle())
        } else if snapshot.activeMatch == nil,
                  cycle.phase == "PAID_ACCESS",
                  (cycle.cycleDay ?? 0) <= (cycle.challenges.newRequestCutoffDay ?? 28) {
            if !canCommandMatchesNatively {
                // 이 서버는 경기 명령을 받지 않는다(HTTP_404) — 눌러도 다시 404 인 CTA 대신
                // 신청 페이지 자체로 보낸다(canCommandMatchesNatively 주석 참조).
                webArenaFallback(
                    onDark: true,
                    destination: matchmakingWebDestination(cycle),
                    title: cycle.activeRanking == "MAIN"
                        ? "웹에서 Ranked 상대 찾기"
                        : "웹에서 Unranked 상대 찾기")
            } else if cycle.activeRanking == "MAIN" {
                Button {
                    showsMainMatchMaker = true
                } label: {
                    HStack(spacing: Tokens.Space.s3) {
                        Image(systemName: "person.2.fill")
                        Text("Ranked 상대 찾기")
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                        Spacer(minLength: Tokens.Space.s3)
                        Image(systemName: "arrow.right")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isRefreshing)
                .accessibilityHint("앱 안에서 Ranked 티어와 예치 일수를 선택합니다")
            } else {
                Button {
                    Task { await createUnrankedMatch() }
                } label: {
                    HStack(spacing: Tokens.Space.s3) {
                        if isCreatingSubMatch {
                            ProgressView()
                                .tint(Tokens.onPrimary)
                        } else {
                            Image(systemName: "person.2.fill")
                        }
                        Text(isCreatingSubMatch ? "상대 찾는 중" : "Unranked 상대 찾기")
                            .lineLimit(1)
                        Spacer(minLength: Tokens.Space.s3)
                        Image(systemName: "arrow.right")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isCreatingSubMatch || isRefreshing)
                .accessibilityHint("현재 자격을 다시 확인하고 공식 Unranked 경기를 만듭니다")
            }
        }

        if cycle.activeRanking == "MAIN" {
            Button {
                store.route = .arenaShop
            } label: {
                HStack(spacing: Tokens.Space.s3) {
                    Image(systemName: "bag.fill")
                    Text("Ranked 상점")
                    Spacer(minLength: Tokens.Space.s3)
                    Image(systemName: "chevron.right")
                }
                .font(.mBodyB)
                .foregroundStyle(onNavy)
                .padding(.horizontal, Tokens.Space.s5)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(onNavy.opacity(0.09), in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: Tokens.Radius.md)
                        .strokeBorder(onNavy.opacity(0.22), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityHint("학습일로 이용하는 Ranked 전용 기능을 엽니다")
        }
    }

    private func noCycleHero(_ snapshot: Snapshot) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s5) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: Tokens.Space.s4) {
                    heroIdentity(snapshot)
                    Spacer(minLength: Tokens.Space.s3)
                    heroEyebrow("사이클 시작 전", color: onNavy.opacity(0.68))
                }

                VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                    heroIdentity(snapshot)
                    heroEyebrow("사이클 시작 전", color: onNavy.opacity(0.68))
                }
            }

            Text("현재 활성 30일 사이클이 없습니다")
                .font(.mHeading)
                .foregroundStyle(onNavy)

            heroButton("이용권과 상점 보기") {
                store.route = .commerce
            }
            .accessibilityHint("구독 상태와 결제, Ranked 상점 이용 조건을 확인합니다")
        }
    }

    private func heroIdentity(_ snapshot: Snapshot) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(snapshot.identity.displayName)
                .font(.mHeading)
                .foregroundStyle(onNavy)
            Text(identityDetail(snapshot))
                .font(.mCaption)
                .foregroundStyle(onNavy.opacity(0.62))
        }
        .accessibilityElement(children: .combine)
    }

    private func cycleRunline(day: Int) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
            HStack(spacing: 2) {
                ForEach(1...30, id: \.self) { value in
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(runlineColor(value: value, day: day))
                        .frame(maxWidth: .infinity)
                        .overlay {
                            if value == 30 {
                                RoundedRectangle(cornerRadius: 1.5)
                                    .strokeBorder(Color(hex: 0xFFD66B).opacity(0.8), lineWidth: 1)
                            }
                        }
                }
            }
            .frame(height: 12)
            .accessibilityHidden(true)

            // 가로 iPhone에서는 바로 위 "진행일 N / 30"과 아래 남은 조건이 이미
            // 의미를 설명한다. 세 범례를 한 줄 더 두면 카드 끝이 탭바에 가려지므로
            // 진행선만 남긴다. 전체 뜻은 결합 접근성 라벨에서 그대로 읽힌다.
            if !isShortViewport {
                ViewThatFits(in: .horizontal) {
                    HStack {
                        Text("1일차")
                        Spacer()
                        Text("유료 이용 DAY 29")
                        Spacer()
                        Text("30일차 완료 심사")
                            .foregroundStyle(Color(hex: 0xFFD66B))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("1~29일차 유료 이용")
                        Text("30일차 완료 심사")
                            .foregroundStyle(Color(hex: 0xFFD66B))
                    }
                }
                .font(.mMicro)
                .foregroundStyle(onNavy.opacity(0.48))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "30일 진행선. 현재 \(max(day, 0))일차. 1일부터 29일까지 유료 이용, 30일은 Completion Pass")
    }

    private func runlineColor(value: Int, day: Int) -> Color {
        if value < day {
            return Tokens.brandCyan.opacity(0.72)
        }
        if value == day {
            return onNavy
        }
        return onNavy.opacity(0.14)
    }

    private func heroMetric(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.mMicro)
                .foregroundStyle(onNavy.opacity(0.52))
            Text(value)
                .font(.mStat)
                .foregroundStyle(onNavy)
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }

    private func heroEyebrow(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.mMicro)
            .foregroundStyle(color)
            .padding(.horizontal, Tokens.Space.s3)
            .frame(minHeight: 30)
            .background(onNavy.opacity(0.09), in: Capsule())
    }

    private func heroButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.mBodyB)
                .foregroundStyle(Tokens.brandNavy)
                .padding(.horizontal, Tokens.Space.s5)
                .frame(minHeight: 44)
                .background(onNavy, in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
        }
        .buttonStyle(.plain)
    }

    // MARK: Freshness and access window

    private func staleSnapshotNotice(_ content: LoadedContent) -> some View {
        guard case .cached(let savedAt, let failure) = content.freshness else {
            return AnyView(EmptyView())
        }

        let notice = VStack(alignment: .leading, spacing: Tokens.Space.s3) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: Tokens.Space.s3) {
                    staleNoticeCopy(savedAt: savedAt, failure: failure)
                    Spacer(minLength: Tokens.Space.s3)
                    retryButton
                }

                VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                    staleNoticeCopy(savedAt: savedAt, failure: failure)
                    retryButton
                }
            }
        }
        .padding(Tokens.Space.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tokens.warningSoft)
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.md))

        return AnyView(notice)
    }

    private func staleNoticeCopy(
        savedAt: Date,
        failure: FailurePresentation
    ) -> some View {
        HStack(alignment: .top, spacing: Tokens.Space.s3) {
            Image(systemName: failure.kind == .offline ? "wifi.slash" : "clock.arrow.circlepath")
                .foregroundStyle(Tokens.warningInk)
                .frame(width: 24, height: 24)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(failure.kind == .offline ? "오프라인, 저장된 기록" : "최신 확인에 실패해 저장된 기록")
                    .font(.mBodyB)
                    .foregroundStyle(Tokens.ink)
                Text("\(relativeTime(savedAt))에 저장된 내용입니다. \(failure.message) 대결·일수·페이백 상태가 바뀌었을 수 있습니다.")
                    .font(.mCaption)
                    .foregroundStyle(Tokens.text2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var retryButton: some View {
        Button {
            Task { await load() }
        } label: {
            Label("다시 확인", systemImage: "arrow.clockwise")
                .font(.mBodyB)
                .padding(.horizontal, Tokens.Space.s4)
                .frame(minHeight: 44)
                .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: Tokens.Radius.md)
                        .strokeBorder(Tokens.warningInk.opacity(0.35), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .foregroundStyle(Tokens.warningInk)
        .accessibilityHint("서버의 최신 Arena 기록을 다시 불러옵니다")
    }

    private func accessWindowSection(_ snapshot: Snapshot) -> some View {
        guard let cycle = snapshot.cycle else { return AnyView(EmptyView()) }

        let section = VStack(alignment: .leading, spacing: Tokens.Space.s5) {
            VStack(alignment: .leading, spacing: 3) {
                Text("오늘 이용 상태")
                    .font(.mMicro)
                    .foregroundStyle(Tokens.primary)
                Text("왜 열렸고, 왜 잠겼는지")
                    .font(.mHeading)
                    .foregroundStyle(Tokens.ink)
                    .accessibilityAddTraits(.isHeader)
            }

            Text("서버가 판정한 오늘의 이용 범위와 다음 행동입니다. Day 30은 유료 이용 연장이 아니라 별도의 Completion Pass입니다.")
                .font(.mCallout)
                .foregroundStyle(Tokens.text2)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 0) {
                statusDecisionRow(learningAccessPresentation(cycle))
                DottedRule()
                statusDecisionRow(challengeWindowPresentation(snapshot, cycle: cycle))
                DottedRule()
                statusDecisionRow(nextActionPresentation(snapshot, cycle: cycle))
            }

        }

        return AnyView(section)
    }

    private func statusDecisionRow(_ presentation: DecisionPresentation) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: Tokens.Space.s4) {
                decisionIcon(presentation)
                decisionCopy(presentation)
                Spacer(minLength: Tokens.Space.s3)
                decisionBadge(presentation)
            }

            HStack(alignment: .top, spacing: Tokens.Space.s4) {
                decisionIcon(presentation)
                VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                    decisionCopy(presentation)
                    decisionBadge(presentation)
                }
            }
        }
        .padding(.vertical, Tokens.Space.s4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(presentation.title), \(presentation.badge). \(presentation.detail)")
    }

    private func decisionIcon(_ presentation: DecisionPresentation) -> some View {
        Image(systemName: presentation.icon)
            .font(.body.weight(.semibold))
            .foregroundStyle(presentation.tint)
            .frame(width: 44, height: 44)
            .background(presentation.background, in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
            .accessibilityHidden(true)
    }

    private func decisionCopy(_ presentation: DecisionPresentation) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(presentation.title)
                .font(.mBodyB)
                .foregroundStyle(Tokens.ink)
            Text(presentation.detail)
                .font(.mCaption)
                .foregroundStyle(Tokens.text2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func decisionBadge(_ presentation: DecisionPresentation) -> some View {
        Label(presentation.badge, systemImage: presentation.icon)
            .labelStyle(.titleOnly)
            .font(.mMicro)
            .foregroundStyle(presentation.tint)
            .padding(.horizontal, Tokens.Space.s3)
            .frame(minHeight: 30)
            .background(presentation.background, in: Capsule())
    }

    private func learningAccessPresentation(_ cycle: Snapshot.Cycle) -> DecisionPresentation {
        if ["PAYMENT_DISPUTED", "SUSPENDED"].contains(cycle.status) {
            return DecisionPresentation(
                icon: "exclamationmark.shield.fill",
                title: "학습 이용이 검토 중입니다",
                detail: cycle.status == "PAYMENT_DISPUTED"
                    ? "결제 상태 확인이 끝날 때까지 이용 권리가 잠겨 있습니다. 웹 계정의 주문 상태를 확인하세요."
                    : "계정 검토가 끝날 때까지 이용 권리가 잠겨 있습니다. 기록은 읽기 전용으로 보존됩니다.",
                badge: "검토 잠금",
                tint: Tokens.warningInk,
                background: Tokens.warningSoft)
        }

        if cycle.phase == "COMPLETION_PASS" {
            if cycle.access.completionPassActive {
                return DecisionPresentation(
                    icon: "checkmark.seal.fill",
                    title: "Completion Pass 활동만 열려 있습니다",
                    detail: "Day 30에 서버 정책이 허용한 활동만 출석 판정에 반영됩니다. 일반 유료 학습 이용일은 Day 29에 끝났습니다.",
                    badge: "제한 이용",
                    tint: Tokens.warningInk,
                    background: Tokens.warningSoft)
            }
            return DecisionPresentation(
                icon: "clock.badge.exclamationmark",
                title: "Completion Pass 판정을 기다리고 있습니다",
                detail: "허용 시간과 활동 기준이 확정되기 전에는 앱이 Day 30 이용 가능 여부를 추측하지 않습니다.",
                badge: "정책 대기",
                tint: Tokens.warningInk,
                background: Tokens.warningSoft)
        }

        if cycle.phase == "PAID_ACCESS", cycle.access.learningAccessActive {
            return DecisionPresentation(
                icon: "lock.open.fill",
                title: "오늘의 유료 학습이 열려 있습니다",
                detail: "Day \(cycle.cycleDay ?? 0) 학습 기록은 서버의 유효 학습 기준을 통과한 경우에만 사이클 출석에 반영됩니다.",
                badge: "이용 가능",
                tint: Tokens.successInk,
                background: Tokens.successSoft)
        }

        if cycle.phase == "UPCOMING" || cycle.status == "PAYMENT_PENDING" {
            return DecisionPresentation(
                icon: "clock.fill",
                title: "Day 1 시작을 기다리고 있습니다",
                detail: "결제 승인과 시작일 판정이 끝나면 서버가 이용 권리를 자동으로 엽니다.",
                badge: "시작 대기",
                tint: Tokens.primary,
                background: Tokens.primarySoft)
        }

        return DecisionPresentation(
            icon: "lock.fill",
            title: "일반 학습 이용 기간이 끝났습니다",
            detail: "유료 학습은 Day 1~29에만 열립니다. 현재 기록은 심사·정산을 위해 읽기 전용으로 유지됩니다.",
            badge: "기간 종료",
            tint: Tokens.text2,
            background: Tokens.paper2)
    }

    private func challengeWindowPresentation(
        _ snapshot: Snapshot,
        cycle: Snapshot.Cycle
    ) -> DecisionPresentation {
        let cutoff = cycle.challenges.newRequestCutoffDay ?? 28
        let day = cycle.cycleDay ?? 0

        if snapshot.activeMatch != nil {
            let detail: String
            if let match = snapshot.activeMatch, needsEvidenceSubmission(match) {
                detail = "답안은 고정되었지만 풀이 사진 제출이 남아 있습니다. 새 요청보다 서버 마감 안에 증거 제출을 먼저 완료하세요."
            } else if let match = snapshot.activeMatch, participantHasSubmitted(match) {
                detail = "내 답안은 제출되었습니다. 새 요청보다 상대 제출과 채점·정산 상태를 먼저 확인하세요."
            } else if let match = snapshot.activeMatch, canPlay(match) {
                detail = "새 요청보다 현재 경기를 먼저 시작하거나 이어서 제출하세요."
            } else {
                detail = "새 요청보다 현재 경기의 상태와 마감을 먼저 확인하세요."
            }
            return DecisionPresentation(
                icon: "flag.checkered",
                title: "진행 중인 자리 쟁탈전이 있습니다",
                detail: detail,
                badge: "경기 우선",
                tint: Tokens.primary,
                background: Tokens.primarySoft)
        }

        if cycle.activeRanking == "MAIN",
           snapshot.capabilities.mainArena == "POLICY_PENDING" {
            return DecisionPresentation(
                icon: "clock.badge.exclamationmark",
                title: "Ranked 운영 기준을 확인 중입니다",
                detail: "티어 간 도전 범위와 Rank Shield·Revenge 기준이 확정되기 전에는 도전을 열지 않습니다.",
                badge: "정책 대기",
                tint: Tokens.warningInk,
                background: Tokens.warningSoft)
        }

        if day > cutoff || cycle.phase != "PAID_ACCESS" {
            return DecisionPresentation(
                icon: "lock.fill",
                title: "새 Unranked 도전 요청이 마감되었습니다",
                detail: "새 요청은 Day \(cutoff)까지만 허용됩니다. 이미 성립한 경기는 별도 마감과 정산 절차를 따릅니다.",
                badge: "신청 잠금",
                tint: Tokens.text2,
                background: Tokens.paper2)
        }

        return DecisionPresentation(
            icon: "person.2.fill",
            title: "새 상대를 찾을 수 있습니다",
            detail: "Day \(cutoff)까지 신청할 수 있습니다. 아래 버튼에서 GOAT Arena 상대 찾기를 이어가세요.",
            badge: "상대 찾기",
            tint: Tokens.arenaAccent,
            background: Tokens.primarySoft)
    }

    private func nextActionPresentation(
        _ snapshot: Snapshot,
        cycle: Snapshot.Cycle
    ) -> DecisionPresentation {
        if snapshot.payback.state == "POLICY_PENDING" {
            return DecisionPresentation(
                icon: "doc.text.magnifyingglass",
                title: "기록은 계속 쌓고, 최종 기준을 기다리세요",
                detail: "확정되지 않은 기준 때문에 판정만 보류된 상태입니다. 서버는 출석·일수·완료 경기 기록을 계속 보존합니다.",
                badge: "다음 행동",
                tint: Tokens.warningInk,
                background: Tokens.warningSoft)
        }

        if cycle.phase == "COMPLETION_PASS" {
            return DecisionPresentation(
                icon: "arrow.right.circle.fill",
                title: cycle.access.completionPassActive
                    ? "허용된 Day 30 활동을 마무리하세요"
                    : "Completion Pass 판정 갱신을 기다리세요",
                detail: cycle.access.completionPassActive
                    ? "완료 뒤 이 화면을 새로고침해 30일 출석과 페이백 판정을 확인하세요."
                    : "운영 기준이 서버에 반영되면 이용 가능 상태와 다음 행동이 자동으로 갱신됩니다.",
                badge: "다음 행동",
                tint: Tokens.primary,
                background: Tokens.primarySoft)
        }

        if let next = snapshot.payback.conditions.first(where: { !$0.met }) {
            return DecisionPresentation(
                icon: "arrow.right.circle.fill",
                title: nextConditionAction(next),
                detail: nextConditionActionDetail(next),
                badge: "다음 행동",
                tint: Tokens.primary,
                background: Tokens.primarySoft)
        }

        if snapshot.payback.eligible == true {
            return DecisionPresentation(
                icon: "checkmark.seal.fill",
                title: "세 조건을 모두 충족했습니다",
                detail: snapshot.activeMatch == nil
                    ? "서버의 페이백 지급 절차가 열릴 때까지 원장 상태를 유지하세요."
                    : "진행 중인 경기가 정산된 뒤 최종 페이백 가능 여부가 다시 판정됩니다.",
                badge: "조건 충족",
                tint: Tokens.successInk,
                background: Tokens.successSoft)
        }

        return DecisionPresentation(
            icon: "clock.fill",
            title: "서버의 다음 판정을 기다리세요",
            detail: "사이클·무결성·정산 상태가 갱신되면 이 화면의 다음 행동도 함께 바뀝니다.",
            badge: "판정 대기",
            tint: Tokens.warningInk,
            background: Tokens.warningSoft)
    }

    private func nextConditionAction(_ condition: Snapshot.Payback.Condition) -> String {
        switch condition.key {
        case "CYCLE_ATTENDANCE":
            return "오늘의 유효 학습 기록을 채우세요"
        case "REFUND_DAY_BALANCE":
            return "페이백 점수 원장을 확인하세요"
        case "COMPLETED_SUB_CHALLENGES":
            return "완료 경기 조건을 확인하세요"
        default:
            return "남은 서버 판정 조건을 확인하세요"
        }
    }

    private func nextConditionActionDetail(_ condition: Snapshot.Payback.Condition) -> String {
        let progress = conditionCount(condition)
        switch condition.key {
        case "CYCLE_ATTENDANCE":
            return "현재 \(progress)입니다. 인정 문제 수와 유효 학습 시간은 서버 정책을 충족해야 합니다."
        case "REFUND_DAY_BALANCE":
            return "현재 \(progress)입니다. 잠긴 점수와 학습 가능 일수는 페이백 점수에 합산되지 않습니다."
        case "COMPLETED_SUB_CHALLENGES":
            return "현재 \(progress)입니다. 위의 ‘상대 찾기’에서 새 대결을 시작하면 완료 경기 수가 갱신됩니다."
        default:
            return "현재 \(progress)입니다."
        }
    }

    // MARK: Payback

    private func paybackSection(_ snapshot: Snapshot) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s5) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s4) {
                    paybackHeading
                    Spacer(minLength: Tokens.Space.s3)
                    paybackVerdict(snapshot.payback)
                }

                VStack(alignment: .leading, spacing: 3) {
                    paybackHeading
                    paybackVerdict(snapshot.payback)
                }
            }

            // 154pt 짜리 장식 배너는 세로가 짧은 뷰포트에서 판정 카드를 화면 밖으로
            // 민다. 배너 문구는 바로 아래 섹션 설명과 같은 내용이고 서버 값이 아니라서
            // 감춰도 사라지는 정보가 없다. 폭이 좁아도 세로가 넉넉하면 그대로 둔다.
            if !isShortViewport {
                ArenaArtBanner(
                    imageName: "ArenaVaultBackdrop",
                    eyebrow: "30일 사이클",
                    title: "쌓인 기록이 자격을 해제합니다",
                    detail: "출석과 페이백 점수를 채워 최종 판정을 여세요.")
            }

            Text("같은 이용 주기 안에서 정책에 정한 연속 학습과 페이백 점수 기준을 함께 충족해야 합니다.")
                .font(.mCallout)
                .foregroundStyle(Tokens.text2)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 0) {
                ForEach(Array(snapshot.payback.conditions.enumerated()), id: \.element.id) { index, condition in
                    if index > 0 {
                        DottedRule()
                    }
                    conditionRow(index: index + 1, condition: condition)
                }
            }

            if snapshot.payback.state == "POLICY_PENDING" {
                inlineNotice(
                    icon: "clock.badge.exclamationmark",
                    title: "최종 판정 기준 확인 중",
                    detail: policyPendingDetail(snapshot.payback),
                    tint: Tokens.warningInk,
                    background: Tokens.warningSoft)
            } else {
                ForEach(snapshot.payback.blockers) { blocker in
                    let presentation = paybackBlockerPresentation(blocker)
                    inlineNotice(
                        icon: presentation.icon,
                        title: presentation.title,
                        detail: presentation.detail,
                        tint: presentation.tint,
                        background: presentation.background)
                }
            }
        }
    }

    private var paybackHeading: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("페이백 조건")
                .font(.mMicro)
                .foregroundStyle(Tokens.primary)
            Text("페이백은 세 조건을 모두 봅니다")
                .font(.mHeading)
                .foregroundStyle(Tokens.ink)
                .accessibilityAddTraits(.isHeader)
        }
    }

    private func policyPendingDetail(_ payback: Snapshot.Payback) -> String {
        let fields = payback.blockers
            .first(where: { $0.code == "POLICY_PENDING" })?
            .fields?
            .map(policyFieldLabel) ?? []
        let unique = Array(Set(fields)).sorted()
        guard !unique.isEmpty else {
            return "출석과 대결 기록은 계속 저장됩니다. 아직 확정되지 않은 운영 기준을 앱이 임의로 채우지는 않습니다."
        }
        return "확인 중: \(unique.joined(separator: ", ")). 기록은 계속 저장되며, 앱이 기준값을 임의로 채우지 않습니다."
    }

    private func policyFieldLabel(_ field: String) -> String {
        switch field {
        case "subNormalTakeoverCostDays": return "Unranked 일반 도전 비용"
        case "subRevengeCostDays": return "Unranked 복수전 비용"
        case "minCompletedSubChallenges": return "최소 완료 경기"
        case "completionPass.opensAtKst": return "Day 30 시작 시각"
        case "completionPass.deadlineAtKst": return "Day 30 마감 시각"
        case "completionPass.allowedActivityTypes": return "Day 30 허용 활동"
        case "minRecognizedProblemsPerDay": return "일일 인정 문제 수"
        case "minValidStudySecondsPerDay": return "일일 유효 학습 시간"
        case "noShowCountsAsCompletedChallenge": return "노쇼 경기 인정"
        case "arenaTierStepMappingVersion": return "Ranked 티어 간격"
        case "revengeBypassesShield": return "Revenge·Shield 관계"
        default: return "운영 기준"
        }
    }

    private func paybackBlockerPresentation(_ blocker: Snapshot.Payback.Blocker) -> DecisionPresentation {
        switch blocker.code {
        case "ACTIVE_MATCH":
            return DecisionPresentation(
                icon: "flag.checkered",
                title: "진행 중인 대결이 있습니다",
                detail: "경기 정산이 끝난 뒤 페이백 가능 여부가 다시 판정됩니다.",
                badge: "대결 중",
                tint: Tokens.primary,
                background: Tokens.primarySoft)
        case "LOCKED_DAY_BALANCE":
            return DecisionPresentation(
                icon: "lock.fill",
                title: "대결에 맡겨 둔 일수가 있습니다",
                detail: "잠긴 일수가 정산되어 사용 가능 또는 소각·이전 처리된 뒤 다시 판정됩니다.",
                badge: "일수 잠금",
                tint: Tokens.warningInk,
                background: Tokens.warningSoft)
        case "INTEGRITY_REVIEW":
            return DecisionPresentation(
                icon: "exclamationmark.shield.fill",
                title: "무결성 확인이 진행 중입니다",
                detail: "검토가 끝날 때까지 페이백 판정을 보류합니다. 학습·대결 원장은 그대로 보존됩니다.",
                badge: "검토 중",
                tint: Tokens.warningInk,
                background: Tokens.warningSoft)
        default:
            return DecisionPresentation(
                icon: "clock.fill",
                title: "최종 판정을 기다리고 있습니다",
                detail: "서버 원장의 보류 사유가 해소되면 자동으로 다시 판정됩니다.",
                badge: "판정 대기",
                tint: Tokens.warningInk,
                background: Tokens.warningSoft)
        }
    }

    private func conditionRow(
        index: Int,
        condition: Snapshot.Payback.Condition
    ) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s3) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: Tokens.Space.s3) {
                    conditionMarker(index: index, condition: condition)
                    conditionCopy(condition)
                    Spacer(minLength: Tokens.Space.s3)
                    conditionStatus(condition)
                }

                VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                    HStack(alignment: .top, spacing: Tokens.Space.s3) {
                        conditionMarker(index: index, condition: condition)
                        conditionCopy(condition)
                    }
                    conditionStatus(condition)
                        .padding(.leading, 42)
                }
            }

            conditionProgress(condition)
                .padding(.leading, 42)
        }
        .padding(.vertical, Tokens.Space.s4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(conditionTitle(condition.key)), \(condition.met ? "완료" : conditionCount(condition)). \(conditionDetail(condition))")
    }

    private func conditionMarker(
        index: Int,
        condition: Snapshot.Payback.Condition
    ) -> some View {
        ZStack {
            Circle()
                .fill(condition.met ? Tokens.successInk : Tokens.paper2)
                .frame(width: 30, height: 30)
            if condition.met {
                // 흰 체크를 쓰지 않는다. 아레나는 항상 다크 셸(RootView 의
                // preferredColorScheme(.dark))이라 successInk 가 밝은 연두(#74D9A1)로
                // 굳는데, 그 위의 흰 체크는 대비 1.72:1 — 그래픽 최소 기준 3:1 미달로
                // 체크가 뭉개진다. paper 는 라이트에서 밝고 다크에서 어두워 밑판이
                // 어느 쪽으로 뒤집혀도 반대편에 선다(다크 11.3:1 · 라이트 5.2:1 실측).
                Image(systemName: "checkmark")
                    .font(.caption.bold())
                    .foregroundStyle(Tokens.paper)
            } else {
                Text("\(index)")
                    .font(.mCaption)
                    .foregroundStyle(Tokens.text2)
            }
        }
        .accessibilityHidden(true)
    }

    private func conditionCopy(_ condition: Snapshot.Payback.Condition) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(conditionTitle(condition.key))
                .font(.mBodyB)
                .foregroundStyle(Tokens.ink)
            Text(conditionDetail(condition))
                .font(.mCaption)
                .foregroundStyle(Tokens.text2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func conditionStatus(_ condition: Snapshot.Payback.Condition) -> some View {
        Label(
            condition.met ? "완료" : conditionCount(condition),
            systemImage: condition.met ? "checkmark.circle.fill" : "circle.dotted")
            .font(.mCaption)
            .foregroundStyle(condition.met ? Tokens.successInk : Tokens.text2)
            .monospacedDigit()
    }

    private func conditionProgress(_ condition: Snapshot.Payback.Condition) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Tokens.paper2)
                Capsule()
                    .fill(condition.met ? Tokens.successInk : Tokens.primary)
                    .frame(width: proxy.size.width * conditionRatio(condition))
            }
        }
        .frame(height: 6)
        .accessibilityHidden(true)
    }

    private func paybackVerdict(_ payback: Snapshot.Payback) -> some View {
        let presentation = paybackPresentation(payback)
        return Text(presentation.label)
            .font(.mMicro)
            .foregroundStyle(presentation.color)
            .padding(.horizontal, Tokens.Space.s3)
            .frame(minHeight: 30)
            .background(presentation.background, in: Capsule())
            .accessibilityLabel("페이백 상태 \(presentation.label)")
    }

    // MARK: Assets

    private func assetSection(_ snapshot: Snapshot) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s5) {
            SectionRule(title: "Arena 자산")

            if let balances = snapshot.cycle?.balances {
                // 두 값을 나란히 놓는 건 폭이 남을 때만이다. compact 폭에서는
                // ViewThatFits 의 판정에 맡기지 않고 세로로 편다. iPhone 세로처럼
                // 본문이 360pt 안팎이면 두 열이 각각 150pt 남짓으로 눌려서
                // 34pt 숫자와 "점 사용 가능" 이 한 줄에서 서로를 밀어낸다.
                // regular 폭은 기존 ViewThatFits 판정을 그대로 둔다.
                // 숫자와 단위, 잠금 문구는 서버 값 그대로다. 배치만 바꾼다.
                if isCompact {
                    stackedAssetColumns(balances)
                } else {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 0) {
                            refundAssetColumn(balances)
                            assetDivider
                            bonusAssetColumn(balances)
                        }

                        stackedAssetColumns(balances)
                    }
                }
            }

            Text("페이백 점수와 학습 가능 일수는 서로 바꾸거나 합산하지 않습니다. 대결에 예치한 값도 사용 가능한 값과 따로 표시됩니다.")
                .font(.mCaption)
                .foregroundStyle(Tokens.text2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func refundAssetColumn(_ balances: Snapshot.Cycle.Balances) -> some View {
        assetColumn(
            eyebrow: "UNRANKED",
            title: "페이백 점수",
            available: balances.refundAvailableDays,
            locked: balances.refundLockedDays,
            unit: "점",
            tint: Tokens.brandMagentaInk)
    }

    private func bonusAssetColumn(_ balances: Snapshot.Cycle.Balances) -> some View {
        assetColumn(
            eyebrow: "RANKED",
            title: "학습 가능 일수",
            available: balances.bonusAvailableDays,
            locked: balances.bonusLockedDays,
            unit: "일",
            tint: Tokens.brandCyanInk)
    }

    private func stackedAssetColumns(_ balances: Snapshot.Cycle.Balances) -> some View {
        VStack(spacing: Tokens.Space.s5) {
            refundAssetColumn(balances)
            DottedRule()
            bonusAssetColumn(balances)
        }
    }

    private func assetColumn(
        eyebrow: String,
        title: String,
        available: Int,
        locked: Int,
        unit: String,
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
            Text(eyebrow)
                .font(.mMicro)
                .foregroundStyle(tint)
            Text(title)
                .font(.mBodyB)
                .foregroundStyle(Tokens.ink)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(available)")
                    .font(.mStatLarge)
                    .foregroundStyle(Tokens.ink)
                    .monospacedDigit()
                Text("\(unit) 사용 가능")
                    .font(.mCaption)
                    .foregroundStyle(Tokens.text2)
            }
            Text(locked > 0 ? "대결에 \(locked)\(unit) 잠금" : "잠긴 \(unit) 없음")
                .font(.mCaption)
                .foregroundStyle(locked > 0 ? Tokens.warningInk : Tokens.text2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, Tokens.Space.s3)
        .accessibilityElement(children: .combine)
    }

    private var assetDivider: some View {
        Rectangle()
            .fill(Tokens.line)
            .frame(width: 1)
            .padding(.horizontal, Tokens.Space.s6)
            .accessibilityHidden(true)
    }

    // MARK: Ranking

    private func rankingSection(_ snapshot: Snapshot) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s5) {
            // 서버가 준 tier가 이 섹션의 첫 시각 정보다. 상태 설명과 배치 행동,
            // MMR·Arena Position은 모두 그 아래에 둔다. 값 사이 환산이나 등급
            // 추정 없이 서버 snapshot을 그대로 표시한다.
            tierHero(snapshot.ranking.skill)

            VStack(alignment: .leading, spacing: 3) {
                Text("두 가지 기준")
                    .font(.mMicro)
                    .foregroundStyle(Tokens.primary)
                Text("실력과 자리는 다른 숫자입니다")
                    .font(.mHeading)
                    .foregroundStyle(Tokens.ink)
                    .accessibilityAddTraits(.isHeader)
            }

            Text("MMR은 시험 성과로 바뀌고, Arena Position은 직접 대결에서만 서로 교환됩니다.")
                .font(.mCallout)
                .foregroundStyle(Tokens.text2)
                .fixedSize(horizontal: false, vertical: true)

            statusDecisionRow(rankingLifecyclePresentation(snapshot))

            if snapshot.ranking.skill.status == "PLACEMENT_PENDING" {
                Button {
                    store.route = .placement
                } label: {
                    Label("배치고사 시작 또는 이어하기", systemImage: "list.number")
                }
                .buttonStyle(PrimaryButtonStyle())
                .frame(maxWidth: isCompact ? .infinity : 360, alignment: .leading)
                    .accessibilityHint("앱 안에서 배치고사 30문항을 시작하거나 저장된 지점부터 이어갑니다")
            }

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: Tokens.Space.s4) {
                    mmrPanel(snapshot.ranking.skill)
                    seatPanel(
                        snapshot.ranking.seat,
                        activeRanking: snapshot.ranking.activeRanking)
                }

                VStack(spacing: Tokens.Space.s4) {
                    mmrPanel(snapshot.ranking.skill)
                    seatPanel(
                        snapshot.ranking.seat,
                        activeRanking: snapshot.ranking.activeRanking)
                }
            }

            if let season = snapshot.season {
                HStack(spacing: Tokens.Space.s2) {
                    Image(systemName: "calendar")
                    Text(
                        [season.title, season.currentWeekKey]
                            .compactMap { $0 }
                            .joined(separator: ", "))
                }
                .font(.mCaption)
                .foregroundStyle(Tokens.text2)
                .accessibilityElement(children: .combine)
            }

            if snapshot.ranking.activeRanking == "MAIN",
               snapshot.capabilities.mainArena == "POLICY_PENDING" {
                inlineNotice(
                    icon: "clock.badge.exclamationmark",
                    title: "Ranked 운영 기준 확인 중",
                    detail: "티어 간 도전 비용과 Rank Shield·Revenge 관계가 확정되기 전에는 앱이 도전 가능 범위를 추측하지 않습니다.",
                    tint: Tokens.warningInk,
                    background: Tokens.warningSoft)
            }
        }
    }

    /// 티어 엠블럼 지름. 세로가 짧으면 패널 두 장이 세로로 쌓여도 한 화면에 남는다.
    private var rankBadgeSize: CGFloat {
        if isShortViewport { return 72 }
        return isCompact ? 82 : 96
    }

    private func tierHero(_ skill: Snapshot.Ranking.Skill) -> some View {
        let accent = RankTier(serverCode: skill.tier)?.accentColor ?? Tokens.text3
        return ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: Tokens.Space.s5) {
                RankBadgeView(
                    tierCode: skill.tier,
                    size: rankBadgeSize,
                    animated: true)
                tierHeroText(skill, accent: accent)
                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                RankBadgeView(
                    tierCode: skill.tier,
                    size: isShortViewport ? 72 : 86,
                    animated: true)
                tierHeroText(skill, accent: accent)
            }
        }
        .padding(isShortViewport ? Tokens.Space.s4 : Tokens.Space.s5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [accent.opacity(0.13), Tokens.surface],
                startPoint: .topLeading,
                endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: Tokens.Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.lg)
                .strokeBorder(accent.opacity(0.34), lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("현재 티어 \(tierLabel(skill.tier))")
    }

    private func tierHeroText(
        _ skill: Snapshot.Ranking.Skill,
        accent: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
            Text("현재 티어")
                .font(.mMicro)
                .foregroundStyle(accent)
            Text(tierLabel(skill.tier))
                .font(.mTitle)
                .fontDesign(.rounded)
                .foregroundStyle(Tokens.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text("서버가 확인한 현재 실력 티어")
                .font(.mCaption)
                .foregroundStyle(Tokens.text2)
        }
    }

    private func mmrPanel(_ skill: Snapshot.Ranking.Skill) -> some View {
        rankingPanel(accent: Tokens.brandMagentaInk) {
            Text("실력 점수 MMR")
                .font(.mMicro)
                .foregroundStyle(Tokens.brandMagentaInk)
            skillValue(skill)
            rankingStatusBadge(
                label: skillStatusLabel(skill.status),
                icon: skillStatusIcon(skill.status),
                tint: skillStatusTint(skill.status))
            Text(skillStatusDetail(skill))
                .font(.mCaption)
                .foregroundStyle(Tokens.text2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "실력 MMR \(skill.mmr.map(String.init) ?? "미발급"), \(tierLabel(skill.tier)), \(skillStatusLabel(skill.status)). \(skillStatusDetail(skill))")
    }

    private func skillValue(_ skill: Snapshot.Ranking.Skill) -> some View {
        Text(skill.mmr.map(formatted) ?? "미발급")
            .font(.mStatLarge)
            .foregroundStyle(Tokens.ink)
            .monospacedDigit()
    }

    private func seatPanel(
        _ seat: Snapshot.Ranking.Seat,
        activeRanking: String?
    ) -> some View {
        rankingPanel(accent: Tokens.brandCyanInk) {
            Text("Arena 자리")
                .font(.mMicro)
                .foregroundStyle(Tokens.brandCyanInk)
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: Tokens.Space.s4) {
                    seatPositionGraphic(seat)
                    seatIdentity(seat, activeRanking: activeRanking)
                }

                VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                    seatPositionGraphic(seat)
                    seatIdentity(seat, activeRanking: activeRanking)
                }
            }
            Text(seatStatusDetail(seat))
                .font(.mCaption)
                .foregroundStyle(Tokens.text2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Arena 자리 \(seat.arenaPosition.map(String.init) ?? "미배정"), \(rankingLabel(activeRanking)), \(seatStatusLabel(seat.status)). \(seatStatusDetail(seat))")
    }

    private func seatIdentity(
        _ seat: Snapshot.Ranking.Seat,
        activeRanking: String?
    ) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
            Text(rankingLabel(activeRanking))
                .font(.mCaption)
                .foregroundStyle(Tokens.text2)
            rankingStatusBadge(
                label: seatStatusLabel(seat.status),
                icon: seatStatusIcon(seat.status),
                tint: seatStatusTint(seat.status))
        }
    }

    /// 위치를 축이나 백분율로 바꾸지 않는 고정형 자리 토큰.
    /// 서버 arenaPosition은 토큰 안의 #N 문자열에만 들어가며 도형의 좌표·크기에는
    /// 관여하지 않는다. 총 인원이나 상대 순위를 추정하지 않는 표시 전용 그래픽이다.
    private func seatPositionGraphic(_ seat: Snapshot.Ranking.Seat) -> some View {
        let size: CGFloat = isShortViewport ? 70 : (isCompact ? 80 : 88)
        return ZStack {
            RoundedRectangle(cornerRadius: Tokens.Radius.md)
                .fill(Tokens.brandCyan.opacity(0.1))
            RoundedRectangle(cornerRadius: Tokens.Radius.md)
                .strokeBorder(Tokens.brandCyanInk.opacity(0.45), lineWidth: 1)
            Circle()
                .strokeBorder(Tokens.brandCyanInk.opacity(0.25), lineWidth: 1)
                .padding(size * 0.13)
            VStack(spacing: 2) {
                Image(systemName: "crown.fill")
                    .font(.mMicro)
                    .foregroundStyle(Tokens.brandCyanInk)
                Text(seat.arenaPosition.map { "#\($0)" } ?? "대기")
                    .font(seat.arenaPosition == nil ? .mCaption : .mStat)
                    .foregroundStyle(Tokens.ink)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private func rankingStatusBadge(
        label: String,
        icon: String,
        tint: Color
    ) -> some View {
        Label(label, systemImage: icon)
            .font(.mMicro)
            .foregroundStyle(tint)
            .padding(.horizontal, Tokens.Space.s3)
            .frame(minHeight: 30)
            .background(Tokens.paper2, in: Capsule())
            .fixedSize(horizontal: false, vertical: true)
    }

    private func rankingPanel<Content: View>(
        accent: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s3) {
            Rectangle()
                .fill(accent)
                .frame(height: 3)
                .accessibilityHidden(true)
            content()
                .padding(.horizontal, Tokens.Space.s5)
            Spacer(minLength: 0)
        }
        .padding(.bottom, Tokens.Space.s5)
        .frame(
            maxWidth: .infinity,
            minHeight: isShortViewport ? 124 : 154,
            alignment: .leading)
        .background(Tokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.lg)
                .strokeBorder(Tokens.line, lineWidth: 1))
    }

    // MARK: Match

    // MARK: 최근 경기 결과
    //
    // WHY. 앱은 답안을 제출한 학생에게 "정산이 끝난 GOAT Arena 화면에서 확인" 이라고
    // 안내해 왔지만, 정작 그 화면에 결과가 없었다. 홈 스냅샷의 activeMatch 는 정산되는
    // 순간 사라지고 지난 경기 목록은 앱 어디에도 없었다 — 학생은 경기를 끝내고도
    // 승패를 앱 안에서 영영 볼 수 없었고, 웹 우편함까지 가야 했다.
    //
    // 서버가 **이미 판정해 내려준 값만** 적는다. 앱용 읽기 모델
    // (goatArenaProductionMatchReadService.serializeParticipantMatch)에는 점수·정답
    // 문항 수·풀이 시간이 없다. 웹 결과 카드의 점수 비교는 앱에서 만들 수 없으므로
    // 시도하지 않는다 — 승패, 자리 이동, 맡긴 일수, 접수 시각까지다.
    private var settledRecentMatches: [ServerAPI.GoatArenaParticipantMatch] {
        Array(
            recentMatches
                .filter { ["WON", "LOST"].contains($0.outcome ?? "") }
                .prefix(3))
    }

    private var heldReviewMatches: [ServerAPI.GoatArenaParticipantMatch] {
        let activeID = snapshot?.activeMatch?.id
        return Array(
            recentMatches
                .filter { $0.status == "HELD" && $0.id != activeID }
                .prefix(3))
    }

    @ViewBuilder
    private var heldReviewSection: some View {
        if !heldReviewMatches.isEmpty {
            VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                SectionRule(title: "운영 검토 중 경기")
                ForEach(heldReviewMatches) { match in
                    Button {
                        supplementalEvidenceTarget = SupplementalEvidenceTarget(id: match.id)
                    } label: {
                        HStack(spacing: Tokens.Space.s3) {
                            Image(systemName: "doc.badge.clock")
                                .foregroundStyle(Tokens.warningInk)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("운영 검토 상태 확인")
                                    .font(.mBodyB)
                                    .foregroundStyle(Tokens.text1)
                                Text("\(matchTypeLabel(match.matchType ?? "")) · 제출 기한과 요청 내용을 확인하세요")
                                    .font(.mCaption)
                                    .foregroundStyle(Tokens.text2)
                            }
                            Spacer(minLength: Tokens.Space.s2)
                            Image(systemName: "chevron.right").foregroundStyle(Tokens.text3)
                        }
                        .padding(Tokens.Space.s4)
                        .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
                        .background(Tokens.warningSoft, in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("추가 소명 요청이 있으면 내용과 기한을 확인하고 앱에서 제출합니다")
                }
            }
        }
    }

    @ViewBuilder
    private var recentResultsSection: some View {
        if !settledRecentMatches.isEmpty {
            VStack(alignment: .leading, spacing: Tokens.Space.s4) {
                SectionRule(title: "최근 경기 결과")

                VStack(spacing: 0) {
                    ForEach(Array(settledRecentMatches.enumerated()), id: \.offset) { item in
                        if item.offset > 0 {
                            Rectangle()
                                .fill(Tokens.line)
                                .frame(height: 1)
                                .accessibilityHidden(true)
                        }
                        recentResultRow(item.element)
                    }
                }
                .background(Tokens.surface)
                .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.lg))
                .overlay(
                    RoundedRectangle(cornerRadius: Tokens.Radius.lg)
                        .strokeBorder(Tokens.line, lineWidth: 1))

                Text("승패와 자리 이동은 서버 정산 결과입니다. 점수·정답 문항 수는 앱에 내려오지 않아 표시하지 않습니다.")
                    .font(.mCaption)
                    .foregroundStyle(Tokens.text3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func recentResultRow(
        _ match: ServerAPI.GoatArenaParticipantMatch
    ) -> some View {
        let won = match.outcome == "WON"
        return HStack(alignment: .top, spacing: Tokens.Space.s4) {
            Text(won ? "승" : "패")
                .font(.mBodyB)
                .foregroundStyle(won ? Tokens.successInk : Tokens.dangerInk)
                .frame(width: 40, height: 40)
                .background(won ? Tokens.successSoft : Tokens.dangerSoft, in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text("\(matchTypeLabel(match.matchType ?? "")), \(rankingLabel(match.activeRanking))")
                    .font(.mBodyB)
                    .foregroundStyle(Tokens.ink)
                Text(recentResultDetail(match))
                    .font(.mCaption)
                    .foregroundStyle(Tokens.text2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: Tokens.Space.s2)

            if let seatMove = recentSeatMove(match) {
                VStack(alignment: .trailing, spacing: 3) {
                    Text("내 자리")
                        .font(.mMicro)
                        .foregroundStyle(Tokens.text3)
                    Text(seatMove)
                        .font(.mNumeric)
                        .foregroundStyle(Tokens.ink)
                        .monospacedDigit()
                }
            }
        }
        .padding(Tokens.Space.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func recentResultDetail(
        _ match: ServerAPI.GoatArenaParticipantMatch
    ) -> String {
        var parts: [String] = [roleLabel(match.role)]
        if let days = match.stake?.days {
            parts.append("맡긴 \(days)일, \(stakeAssetLabel(match.stake?.assetType))")
        }
        let settledAt = match.timeline?.settledAt
            ?? match.timeline?.resolvedAt
            ?? match.timeline?.updatedAt
        if let when = shortDateTime(settledAt) {
            parts.append(when)
        }
        return parts.joined(separator: " · ")
    }

    /// 서버가 준 정산 전후 자리. 둘 중 하나라도 없으면 아무것도 적지 않는다.
    private func recentSeatMove(
        _ match: ServerAPI.GoatArenaParticipantMatch
    ) -> String? {
        guard let before = match.myPositionBefore,
              let after = match.myPositionAfter else { return nil }
        return before == after ? "\(before)위 유지" : "\(before)위 → \(after)위"
    }

    private func activeMatchSection(
        _ match: Snapshot.ActiveMatch,
        showsDefenderRefresh: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s5) {
            SectionRule(title: "진행 중인 자리 쟁탈전")

            // 위 paybackSection 과 같은 이유다. 짧은 뷰포트에서는 경기 상태와 마감이
            // 장식 배너보다 먼저 보여야 한다.
            if !isShortViewport {
                ArenaArtBanner(
                    imageName: "ArenaDuelBackdrop",
                    eyebrow: "POSITION DUEL",
                    title: "두 자리 중 하나만 남습니다",
                    detail: "서버가 봉인한 문제와 개인 타이머로 승부가 결정됩니다.")
            }

            statusDecisionRow(matchStatusPresentation(match))

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: Tokens.Space.s6) {
                    matchPosition(
                        label: "내 자리",
                        value: match.myPositionBefore)
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.title3.bold())
                        .foregroundStyle(Tokens.primary)
                        .accessibilityHidden(true)
                    matchPosition(
                        label: "상대 자리",
                        value: match.opponentPositionBefore)
                    Rectangle()
                        .fill(Tokens.line)
                        .frame(width: 1, height: 72)
                        .accessibilityHidden(true)
                    matchFacts(match)
                    Spacer(minLength: 0)
                }

                VStack(alignment: .leading, spacing: Tokens.Space.s4) {
                    HStack(spacing: Tokens.Space.s5) {
                        matchPosition(label: "내 자리", value: match.myPositionBefore)
                        Image(systemName: "arrow.left.arrow.right")
                            .foregroundStyle(Tokens.primary)
                        matchPosition(label: "상대 자리", value: match.opponentPositionBefore)
                    }
                    DottedRule()
                    matchFacts(match)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Tokens.Space.s5)
            .background(Tokens.surface)
            .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: Tokens.Radius.lg)
                    .strokeBorder(Tokens.line, lineWidth: 1))

            matchDeadlineSection(match)

            inlineNotice(
                icon: "arrow.right.circle.fill",
                title: matchNextActionTitle(match),
                detail: matchNextActionDetail(match),
                tint: match.status == "HELD" ? Tokens.warningInk
                    : (needsEvidenceSubmission(match) ? Tokens.warningInk
                        : (participantHasSubmitted(match) ? Tokens.successInk : Tokens.primary)),
                background: match.status == "HELD" ? Tokens.warningSoft
                    : (needsEvidenceSubmission(match) ? Tokens.warningSoft
                        : (participantHasSubmitted(match) ? Tokens.successSoft : Tokens.primarySoft)))

            if showsDefenderRefresh {
                defenderResponseRefreshButton
                    .frame(maxWidth: actionMaxWidth)
            }

            if match.status == "HELD",
               let matchId = match.id?.trimmingCharacters(in: .whitespacesAndNewlines),
               !matchId.isEmpty {
                Button {
                    supplementalEvidenceTarget = SupplementalEvidenceTarget(id: matchId)
                } label: {
                    Label("운영 검토 상태 확인", systemImage: "doc.badge.clock")
                }
                .buttonStyle(PrimaryButtonStyle())
                .frame(maxWidth: actionMaxWidth)
                .accessibilityHint("추가 소명 요청이 있으면 내용과 제출 기한을 확인합니다")
            }

            if canPlay(match) {
                Button {
                    guard let matchId = match.id?.trimmingCharacters(in: .whitespacesAndNewlines),
                          !matchId.isEmpty else { return }
                    matchLaunch = MatchLaunch(id: matchId, briefing: matchBriefing(match))
                } label: {
                    Label(
                        needsEvidenceSubmission(match)
                            ? "풀이 증거 제출하기"
                            : (match.attempt?.status == "IN_PROGRESS"
                                ? "경기 계속하기" : "경기 시작하기"),
                        systemImage: needsEvidenceSubmission(match)
                            ? "photo.badge.arrow.down"
                            : (match.attempt?.status == "IN_PROGRESS"
                                ? "arrow.right.circle.fill"
                                : "play.fill"))
                }
                .buttonStyle(PrimaryButtonStyle())
                .frame(maxWidth: actionMaxWidth)
                .accessibilityHint("서버가 확정한 이 경기의 개인 문제 화면을 엽니다")
            }

            Text(matchSettlementRule(match))
                .font(.mCaption)
                .foregroundStyle(Tokens.text2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func pendingInvitationSection(
        _ invitation: Snapshot.PendingInvitation
    ) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s4) {
            SectionRule(title: "도착한 Ranked 초대")

            statusDecisionRow(
                .init(
                    icon: "envelope.badge",
                    title: "응답 대기",
                    detail: "수락 전에는 공식 경기가 만들어지지 않습니다.",
                    badge: "Ranked 초대",
                    tint: Tokens.arenaAccent,
                    background: Tokens.primarySoft
                )
            )

            ViewThatFits(in: .horizontal) {
                HStack(spacing: Tokens.Space.s6) {
                    matchFact(label: "초대자 티어", value: ArenaDisplayTerms.tier(invitation.initiatorTier))
                    matchFact(label: "내 목표 티어", value: ArenaDisplayTerms.tier(invitation.targetTier))
                    matchFact(label: "양측 예치", value: "각 \(invitation.stakeDays)일")
                }

                VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                    matchFact(label: "초대자 티어", value: ArenaDisplayTerms.tier(invitation.initiatorTier))
                    matchFact(label: "내 목표 티어", value: ArenaDisplayTerms.tier(invitation.targetTier))
                    matchFact(label: "양측 예치", value: "각 \(invitation.stakeDays)일")
                }
            }

            Text("수락하면 서버가 양쪽 자격과 잔액을 다시 확인한 뒤 같은 학습일수를 예치하고 공식 경기를 만듭니다.")
                .font(.mCaption)
                .foregroundStyle(Tokens.text2)
                .fixedSize(horizontal: false, vertical: true)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: Tokens.Space.s3) {
                    defenderAcceptButton(label: "초대 수락")
                    defenderDeclineButton(label: "초대 거절")
                }

                VStack(spacing: Tokens.Space.s3) {
                    defenderAcceptButton(label: "초대 수락")
                    defenderDeclineButton(label: "초대 거절")
                }
            }
            if !canCommandMatchesNatively {
                // 초대 응답(수락·거절)도 실서버에는 라우트가 없다. 응답은 웹의
                // RANKED 대전 준비 페이지에 있으므로 그 자리로 바로 보낸다.
                webArenaFallback(
                    onDark: false,
                    destination: .rankedBattle,
                    title: "웹에서 초대 응답하기")
            }
        }
        .padding(Tokens.Space.s5)
        .background(Tokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.lg)
                .strokeBorder(Tokens.line, lineWidth: 1)
        )
    }

    private func canPlay(_ match: Snapshot.ActiveMatch) -> Bool {
        guard let loadedContent,
              case .fresh = loadedContent.freshness else {
            // 저장된 과거 스냅샷은 상태 설명에만 사용한다. 시간이 흐르는 경기를
            // 시작·재개하는 권한으로 승격하지 않는다.
            return false
        }
        guard ["MATCHED", "READY", "IN_PROGRESS", "SUBMITTED"].contains(match.status),
              ["PENDING", "CLEAR"].contains(match.integrityState),
              let matchId = match.id?.trimmingCharacters(in: .whitespacesAndNewlines)
        else {
            return false
        }
        if let actions = match.availableActions {
            let playable = Set([
                "START", "SAVE_ANSWER", "ADVANCE", "SUBMIT", "SUBMIT_EVIDENCE",
            ])
            return !matchId.isEmpty && !playable.isDisjoint(with: Set(actions))
        }
        // 참가자 개인 제출은 공유 match가 아직 IN_PROGRESS여도 되돌릴 수 없다.
        // 구버전 서버처럼 attempt가 없을 때만 공유 상태 fallback을 허용한다.
        if let attempt = match.attempt {
            if ["EVIDENCE_REQUIRED", "SUBMITTED"].contains(attempt.status) {
                return needsEvidenceSubmission(match)
            }
            guard ["READY", "IN_PROGRESS"].contains(attempt.status) else { return false }
        }
        return !matchId.isEmpty && ["MATCHED", "READY", "IN_PROGRESS"].contains(match.status)
    }

    /// 경기 화면 로비에 적을 사실들을 스냅샷에서 그대로 옮긴다.
    ///
    /// WHY. 종전에는 커버가 뜨는 즉시 `.task` 가 POST /start 를 쳐서, 학생이 스피너를
    /// 보는 동안 이미 서버 개인 타이머가 흘렀다. 몇 분짜리인지, 무엇을 걸었는지
    /// 읽기 전에 시작된 것이다. 웹은 goat-arena-match.ejs:196-217 에서 폼 버튼을
    /// 눌러야 시작한다 — 앱에도 같은 순서(읽고 → 누르고 → 그때 타이머)를 세운다.
    ///
    /// 새 서버 호출을 만들지 않는다. 여기 쓰이는 값은 전부 활성 경기 카드가 이미
    /// 화면에 찍고 있던 것이다. 앱용 읽기 모델에 없는 값(경기 제한 시간·상대 닉네임)은
    /// 지어내지 않고, 로비가 "시작할 때 서버가 확정" 이라고 밝힌다.
    private func matchBriefing(_ match: Snapshot.ActiveMatch) -> GoatArenaMatchBriefing {
        GoatArenaMatchBriefing(
            roleLabel: roleLabel(match.role),
            matchLabel: "\(matchTypeLabel(match.matchType)), \(rankingLabel(match.activeRanking))",
            stakeText: match.stake.days.map {
                "\($0)일, \(stakeAssetLabel(match.stake.assetType))"
            },
            // 서버 스냅샷의 ActiveMatch 에는 경기 제한 시간이 없다. 로비는 그 사실을 밝힌다.
            timeLimitSeconds: nil,
            startsByText: shortDateTime(match.startsBy),
            // 이미 개인 타이머가 흐르는 경기(재개)와 증거 제출 복귀 앞에 확인 단계를
            // 세우면 그 초는 그대로 학생 손해다 — 그 두 경로는 종전처럼 곧장 연다.
            skipsLobby: match.attempt?.status == "IN_PROGRESS"
                || participantHasSubmitted(match)
                || needsEvidenceSubmission(match))
    }

    private func needsEvidenceSubmission(_ match: Snapshot.ActiveMatch) -> Bool {
        guard match.attempt?.evidenceRequired == true else { return false }
        guard let rawDeadline = match.attempt?.evidenceDeadlineAt,
              let deadline = isoDate(rawDeadline) else {
            return true
        }
        return deadline > Date()
    }

    private func participantHasSubmitted(_ match: Snapshot.ActiveMatch) -> Bool {
        match.attempt?.status == "SUBMITTED"
    }

    private var pendingDefenderCommandNotice: String {
        guard let pendingDefenderCommand else { return "" }
        switch pendingDefenderCommand.action {
        case .accept:
            return "이전에 보낸 수락 응답의 결과를 확인하지 못했습니다. 다른 응답을 보내지 않고 같은 수락 요청을 다시 확인합니다."
        case .decline:
            let reason = pendingDefenderCommand.reasonCode
                .map { declineReasonLabel($0) } ?? "선택한"
            return "이전에 보낸 \(reason) 거절 응답의 결과를 확인하지 못했습니다. 같은 사유와 같은 요청으로 다시 확인합니다."
        }
    }

    @ViewBuilder
    private func defenderPendingRetryButton(
        _ pending: GoatArenaPendingDefenderCommand
    ) -> some View {
        switch pending.action {
        case .accept:
            defenderAcceptButton(label: "수락 결과 다시 확인")
                .frame(maxWidth: actionMaxWidth)
        case .decline:
            defenderDeclineButton(label: "거절 결과 다시 확인")
                .frame(maxWidth: actionMaxWidth)
        }
    }

    private func defenderAcceptButton(label: String) -> some View {
        Button {
            confirmDefenderAccept = true
        } label: {
            defenderCommandButtonLabel(
                title: label,
                icon: "checkmark.circle.fill",
                action: .accept
            )
        }
        .buttonStyle(PrimaryButtonStyle())
        .frame(maxWidth: actionMaxWidth)
        .disabled(defenderCommandInFlight != nil || isRefreshing || !hasFreshSnapshot
                  || !canCommandMatchesNatively)
        .accessibilityHint("확인 후 이 자리 도전을 수락합니다")
    }

    private func defenderDeclineButton(label: String) -> some View {
        Button {
            confirmDefenderDecline = true
        } label: {
            defenderCommandButtonLabel(
                title: label,
                icon: "xmark.circle",
                action: .decline
            )
        }
        .buttonStyle(SecondaryButtonStyle())
        .frame(maxWidth: actionMaxWidth)
        .disabled(defenderCommandInFlight != nil || isRefreshing || !hasFreshSnapshot
                  || !canCommandMatchesNatively)
        .accessibilityHint("선택한 사유를 확인한 뒤 이 자리 도전을 거절합니다")
    }

    private func defenderCommandButtonLabel(
        title: String,
        icon: String,
        action: GoatArenaDefenderCommandAction
    ) -> some View {
        HStack(spacing: Tokens.Space.s2) {
            if defenderCommandInFlight == action {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: icon)
            }
            Text(title)
        }
        .frame(maxWidth: .infinity)
    }

    private func matchPosition(label: String, value: Int?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.mMicro)
                .foregroundStyle(Tokens.text2)
            Text(value.map { "#\($0)" } ?? "미배정")
                .font(.mStat)
                .foregroundStyle(Tokens.ink)
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }

    private func matchFacts(_ match: Snapshot.ActiveMatch) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: Tokens.Space.s8) {
                matchFact(
                    label: "경기",
                    value: "\(matchTypeLabel(match.matchType)), \(rankingLabel(match.activeRanking))")
                matchFact(
                    label: "내 역할",
                    value: roleLabel(match.role))
                matchFact(
                    label: "맡긴 일수",
                    value: match.stake.days.map {
                        "\($0)일, \(stakeAssetLabel(match.stake.assetType))"
                    } ?? "서버 확인 중")
                matchFact(
                    label: "무결성",
                    value: integrityLabel(match.integrityState))
            }

            VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                matchFact(
                    label: "경기",
                    value: "\(matchTypeLabel(match.matchType)), \(rankingLabel(match.activeRanking))")
                matchFact(
                    label: "내 역할",
                    value: roleLabel(match.role))
                matchFact(
                    label: "맡긴 일수",
                    value: match.stake.days.map {
                        "\($0)일, \(stakeAssetLabel(match.stake.assetType))"
                    } ?? "서버 확인 중")
                matchFact(
                    label: "무결성",
                    value: integrityLabel(match.integrityState))
            }
        }
    }

    private func matchFact(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.mMicro)
                .foregroundStyle(Tokens.text2)
            Text(value)
                .font(.mCaption)
                .foregroundStyle(Tokens.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func matchDeadlineSection(_ match: Snapshot.ActiveMatch) -> some View {
        let participantEndsAt = match.attempt?.endsAt
        let submissionDeadline = participantEndsAt ?? match.submitsBy
        if match.startsBy != nil || submissionDeadline != nil
            || match.attempt?.submittedAt != nil
            || match.attempt?.evidenceDeadlineAt != nil {
            VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                Text("서버 기준 마감")
                    .font(.mMicro)
                    .foregroundStyle(Tokens.primary)

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: Tokens.Space.s6) {
                        if let starts = shortDateTime(match.startsBy) {
                            matchDeadline(
                                icon: "play.circle",
                                label: "시작 마감",
                                value: starts,
                                emphasized: ["MATCHED", "READY"].contains(match.status))
                        }
                        if let submits = shortDateTime(submissionDeadline) {
                            matchDeadline(
                                icon: "paperplane.circle",
                                label: participantEndsAt == nil ? "공통 제출 마감" : "내 제출 마감",
                                value: submits,
                                emphasized: match.status == "IN_PROGRESS"
                                    && !participantHasSubmitted(match))
                        }
                        if let submitted = shortDateTime(match.attempt?.submittedAt) {
                            matchDeadline(
                                icon: "checkmark.circle",
                                label: "내 답안 접수",
                                value: submitted,
                                emphasized: false)
                        }
                        if let evidence = shortDateTime(match.attempt?.evidenceDeadlineAt),
                           match.attempt?.evidenceRequired == true {
                            matchDeadline(
                                icon: "doc.viewfinder",
                                label: "풀이 사진 마감",
                                value: evidence,
                                emphasized: true)
                        }
                    }

                    VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                        if let starts = shortDateTime(match.startsBy) {
                            matchDeadline(
                                icon: "play.circle",
                                label: "시작 마감",
                                value: starts,
                                emphasized: ["MATCHED", "READY"].contains(match.status))
                        }
                        if let submits = shortDateTime(submissionDeadline) {
                            matchDeadline(
                                icon: "paperplane.circle",
                                label: participantEndsAt == nil ? "공통 제출 마감" : "내 제출 마감",
                                value: submits,
                                emphasized: match.status == "IN_PROGRESS"
                                    && !participantHasSubmitted(match))
                        }
                        if let submitted = shortDateTime(match.attempt?.submittedAt) {
                            matchDeadline(
                                icon: "checkmark.circle",
                                label: "내 답안 접수",
                                value: submitted,
                                emphasized: false)
                        }
                        if let evidence = shortDateTime(match.attempt?.evidenceDeadlineAt),
                           match.attempt?.evidenceRequired == true {
                            matchDeadline(
                                icon: "doc.viewfinder",
                                label: "풀이 사진 마감",
                                value: evidence,
                                emphasized: true)
                        }
                    }
                }
            }
        }
    }

    private func matchDeadline(
        icon: String,
        label: String,
        value: String,
        emphasized: Bool
    ) -> some View {
        HStack(spacing: Tokens.Space.s2) {
            Image(systemName: icon)
                .foregroundStyle(emphasized ? Tokens.warningInk : Tokens.text2)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.mMicro)
                    .foregroundStyle(Tokens.text2)
                Text(value)
                    .font(.mCaption)
                    .foregroundStyle(emphasized ? Tokens.warningInk : Tokens.ink)
                    .monospacedDigit()
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Defender response

    @MainActor
    private func createUnrankedMatch() async {
        guard !isCreatingSubMatch,
              ServerAPI.hasToken,
              let loadedContent,
              case .fresh = loadedContent.freshness,
              loadedContent.snapshot.activeMatch == nil,
              let ownerSlot = loadedAccountSlot,
              ownerSlot == DataScope.slot else { return }
        let commandID = subMatchCommandId
        isCreatingSubMatch = true
        do {
            let response = try await ServerAPI.createUnrankedArenaMatch(
                commandId: commandID,
                clientBuildVersion: ServerAPI.clientBuildVersion
            )
            guard DataScope.slot == ownerSlot,
                  loadedAccountSlot == ownerSlot,
                  subMatchCommandId == commandID else { return }
            let matchId = response.match.id.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            guard !matchId.isEmpty else {
                throw ServerAPIError(
                    message: "생성된 경기 번호를 확인할 수 없습니다.",
                    code: "GOAT_ARENA_MATCH_CREATE_INVALID"
                )
            }
            subMatchCommandId = UUID().uuidString
            matchLaunch = MatchLaunch(id: matchId)
        } catch {
            guard DataScope.slot == ownerSlot,
                  loadedAccountSlot == ownerSlot,
                  subMatchCommandId == commandID else { return }
            if let apiError = error as? ServerAPIError {
                if apiError.isRouteMissing {
                    // 라우트 자체가 없는 서버(웹 세션 전용) — 서버의 "페이지가 없습니다"
                    // 문구 대신 웹으로 안내하고 CTA 를 웹 링크로 바꾼다.
                    arenaCommandsUnavailable = true
                    subMatchCreateError = Self.arenaCommandsUnavailableNotice
                } else {
                    subMatchCreateError = ArenaDisplayTerms.apply(
                        apiError.message ?? "서버가 상대 찾기 결과를 확인하지 못했습니다."
                    )
                }
            } else if error is URLError {
                subMatchCreateError = "네트워크 연결을 확인하지 못했습니다. 같은 버튼을 누르면 동일 요청으로 안전하게 다시 확인합니다."
            } else {
                subMatchCreateError = "상대 찾기 결과를 확인하지 못했습니다. 잠시 후 다시 시도해 주세요."
            }
        }
        guard DataScope.slot == ownerSlot,
              loadedAccountSlot == ownerSlot,
              subMatchCommandId == commandID || matchLaunch != nil else { return }
        isCreatingSubMatch = false
    }

    @MainActor
    private func respondToDefenderChallenge(
        action: GoatArenaDefenderCommandAction,
        reasonCode: ServerAPI.GoatArenaDeclineReasonCode? = nil
    ) async {
        guard defenderCommandInFlight == nil,
              let loadedContent,
              case .fresh = loadedContent.freshness,
              let accountSlot = loadedAccountSlot,
              accountSlot == DataScope.slot
        else {
            return
        }

        let snapshot = loadedContent.snapshot
        guard let invitation = snapshot.pendingInvitation else {
            return
        }
        let matchId = invitation.id.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !matchId.isEmpty else { return }

        if action == .decline, reasonCode == nil {
            defenderCommandError = "거절 사유를 선택한 뒤 다시 시도해 주세요."
            defenderCommandErrorIsAuthExpired = false   // 직전 401 표식이 남지 않게
            return
        }

        defenderCommandInFlight = action
        defer { defenderCommandInFlight = nil }

        do {
            let prepared = try GoatArenaDefenderCommandStore.prepare(
                matchId: matchId,
                action: action,
                reasonCode: reasonCode
            )
            pendingDefenderCommand = prepared.pending

            let response: ServerAPI.GoatArenaMatchCommandResponse
            switch action {
            case .accept:
                response = try await ServerAPI.acceptGoatArenaChallenge(
                    matchId: matchId,
                    commandId: prepared.keys.acceptCommandId,
                    clientBuildVersion: prepared.keys.clientBuildVersion
                )
            case .decline:
                guard let reasonCode else {
                    throw GoatArenaDefenderCommandError.invalidDeclineReason
                }
                response = try await ServerAPI.declineGoatArenaChallenge(
                    matchId: matchId,
                    reasonCode: reasonCode,
                    commandId: prepared.keys.declineCommandId,
                    clientBuildVersion: prepared.keys.clientBuildVersion
                )
            }

            guard DataScope.slot == accountSlot,
                  loadedAccountSlot == accountSlot else {
                throw GoatArenaDefenderCommandError.accountChanged
            }

            let expectedStatus = action == .accept ? "READY" : "CANCELLED"
            guard (response.invitationId ?? response.match.id) == matchId,
                  response.match.status == expectedStatus,
                  !response.match.integrityState.isEmpty else {
                throw GoatArenaDefenderCommandError.invalidResponse
            }

            defenderCommandReceipt = response.match
            try? GoatArenaDefenderCommandStore.clear(matchId: matchId)
            pendingDefenderCommand = nil

            // 명령 응답만으로 경기 전체 읽기 모델을 추측하지 않는다. 성공 영수증을
            // 먼저 고정한 뒤 서버 스냅샷 전체를 다시 받아 화면을 전환한다.
            await load()
        } catch {
            guard DataScope.slot == accountSlot,
                  loadedAccountSlot == accountSlot else {
                return
            }
            defenderCommandError = defenderCommandErrorMessage(
                error,
                action: action
            )
            // 401 만 재로그인 버튼 대상 — 문구(defenderCommandErrorMessage 2140행
            // 부근)와 같은 판정 기준을 쓴다.
            defenderCommandErrorIsAuthExpired =
                (error as? ServerAPIError)?.statusCode == 401
            // 라우트 없음(HTTP_404)은 "도전 없음" 404 와 달리 서버가 명령을 받지 않는
            // 상태 — 수락·거절 버튼을 잠그고 웹 링크를 보여 준다.
            if (error as? ServerAPIError)?.isRouteMissing == true {
                arenaCommandsUnavailable = true
            }

            if let apiError = error as? ServerAPIError,
               [404, 409].contains(apiError.statusCode ?? -1) {
                await load()
            }
        }
    }

    private func defenderCommandErrorMessage(
        _ error: Error,
        action: GoatArenaDefenderCommandAction
    ) -> String {
        if error is CancellationError {
            return "요청이 중단되었습니다. 같은 버튼을 누르면 저장된 동일 요청으로 다시 확인합니다."
        }

        if let commandError = error as? GoatArenaDefenderCommandError {
            switch commandError {
            case .conflictingPending:
                return "직전에 보낸 경기 응답의 결과를 먼저 확인해야 합니다. 화면에 표시된 ‘결과 다시 확인’ 버튼을 사용해 주세요."
            case .persistenceFailed:
                return "안전한 재시도 정보를 이 기기에 저장하지 못해 요청을 보내지 않았습니다. 저장 공간을 확인한 뒤 다시 시도해 주세요."
            case .invalidDeclineReason:
                return "거절 사유를 확인할 수 없습니다. 화면에서 사유를 다시 선택해 주세요."
            case .invalidResponse:
                return "서버 응답 형식을 확인하지 못했습니다. 경기 상태를 새로고침한 뒤 다시 시도해 주세요."
            case .accountChanged:
                return "로그인 계정이 변경되어 요청을 중단했습니다."
            }
        }

        if let apiError = error as? ServerAPIError {
            if apiError.statusCode == 401 {
                return "로그인 시간이 만료되었습니다. 다시 로그인한 뒤 경기 상태를 확인해 주세요."
            }
            // 코드 없는/HTTP_404 는 라우트 없음 — 아래의 "도전 없음" 404 문구와 구분한다.
            if apiError.isRouteMissing {
                return Self.arenaCommandsUnavailableNotice
            }
            if apiError.statusCode == 404 {
                return "현재 계정에서 응답 가능한 도전을 찾을 수 없습니다. 최신 경기 상태를 확인해 주세요."
            }
            if apiError.statusCode == 409 {
                return "경기 상태가 이미 바뀌었습니다. 서버의 최신 상태를 다시 불러왔습니다."
            }
            if apiError.code == "GOAT_ARENA_DECLINE_REASON_INVALID" {
                return "지원되는 거절 사유가 아닙니다. 앱을 업데이트한 뒤 다시 시도해 주세요."
            }
            if apiError.code == "GOAT_ARENA_COMMAND_HEADER_REQUIRED"
                || apiError.code == "GOAT_ARENA_VERSION_MISMATCH" {
                return "앱과 서버 버전이 맞지 않습니다. 앱을 업데이트한 뒤 다시 시도해 주세요."
            }
        }

        if error is URLError {
            return action == .accept
                ? "수락 결과를 확인하지 못했습니다. 같은 수락 버튼을 누르면 동일 요청으로 안전하게 다시 확인합니다."
                : "거절 결과를 확인하지 못했습니다. 같은 거절 사유와 동일 요청으로 안전하게 다시 확인합니다."
        }

        return "경기 응답 결과를 확인하지 못했습니다. 화면에 표시된 같은 응답으로 다시 확인해 주세요."
    }

    private func declineReasonLabel(
        _ reason: ServerAPI.GoatArenaDeclineReasonCode
    ) -> String {
        switch reason {
        case .scheduleConflict:
            return "일정이 맞지 않음"
        case .technicalIssue:
            return "기술 문제"
        case .other:
            return "기타 사유"
        }
    }

    @MainActor
    private func reconcileDefenderCommandState(
        snapshot: Snapshot,
        accountSlot: String,
        authoritative: Bool
    ) {
        guard accountSlot == DataScope.slot else {
            pendingDefenderCommand = nil
            return
        }

        if let invitation = snapshot.pendingInvitation {
            let invitationId = invitation.id.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            pendingDefenderCommand = invitationId.isEmpty
                ? nil
                : (try? GoatArenaDefenderCommandStore.load(
                    matchId: invitationId
                ))?.pending
            return
        }
        // 이미 만들어진 ArenaMatch는 자동 배정/수락 완료 경기다. 해당 match id를
        // MainInvitationOffer id로 재사용하지 않는다.
        pendingDefenderCommand = nil
    }

    // MARK: Notices and labels

    private func truthNotice(_ snapshot: Snapshot) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s3) {
            DottedRule()
            HStack(alignment: .top, spacing: Tokens.Space.s3) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(Tokens.primary)
                    .padding(.top, 1)
                    .accessibilityHidden(true)
                Text(truthNoticeText(snapshot))
                    .font(.mCaption)
                    .foregroundStyle(Tokens.text2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func inlineNotice(
        icon: String,
        title: String,
        detail: String,
        tint: Color,
        background: Color
    ) -> some View {
        HStack(alignment: .top, spacing: Tokens.Space.s3) {
            Image(systemName: icon)
                .foregroundStyle(tint)
                .padding(.top, 2)
                .frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.mBodyB)
                    .foregroundStyle(Tokens.ink)
                Text(detail)
                    .font(.mCaption)
                    .foregroundStyle(Tokens.text2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Tokens.Space.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.md))
        .accessibilityElement(children: .combine)
    }

    private func identityDetail(_ snapshot: Snapshot) -> String {
        let school = snapshot.identity.schoolName?.trimmingCharacters(in: .whitespacesAndNewlines)
        return school?.isEmpty == false ? school! : "학교 비공개"
    }

    private func phaseLabel(_ cycle: Snapshot.Cycle) -> String {
        switch cycle.phase {
        case "PAID_ACCESS":
            return "유료 이용"
        case "COMPLETION_PASS":
            return cycle.access.completionPassActive ? "Completion Pass" : "Day 30 심사"
        case "REVIEW_OR_CLOSED":
            return "심사·정산"
        case "UPCOMING":
            return "시작 대기"
        default:
            return "상태 확인"
        }
    }

    private func phaseColor(_ cycle: Snapshot.Cycle) -> Color {
        switch cycle.phase {
        case "PAID_ACCESS":
            return Tokens.brandCyan
        case "COMPLETION_PASS":
            return Color(hex: 0xFFD66B)
        default:
            return onNavy.opacity(0.68)
        }
    }

    private func cycleFootnote(_ cycle: Snapshot.Cycle) -> String {
        if cycle.phase == "COMPLETION_PASS" {
            return cycle.access.completionPassActive
                ? "Day 30은 일반 유료 이용일이 아닙니다. 허용된 활동만 Completion Pass로 인정됩니다."
                : "Day 30 Completion Pass의 허용 시간과 활동을 서버에서 확인하고 있습니다."
        }
        if cycle.phase == "PAID_ACCESS" {
            let cutoff = cycle.challenges.newRequestCutoffDay.map(String.init) ?? "28"
            return "유료 학습은 Day 1~29에 열립니다. 새로운 Unranked 도전 요청은 Day \(cutoff)까지만 가능합니다."
        }
        return "사이클 상태와 이용 권리는 서버 시각을 기준으로 판정됩니다."
    }

    private func rankingLifecyclePresentation(_ snapshot: Snapshot) -> DecisionPresentation {
        let pool = rankingLabel(snapshot.ranking.activeRanking)
        switch snapshot.ranking.seat.status {
        case "ACTIVE":
            return DecisionPresentation(
                icon: "eye.fill",
                title: "\(pool) 자리가 공개되어 있습니다",
                detail: "현재 Arena Position은 주간 시드의 자리이며, MMR 변화만으로 즉시 움직이지 않습니다.",
                badge: "ACTIVE",
                tint: Tokens.successInk,
                background: Tokens.successSoft)
        case "HIDDEN":
            return DecisionPresentation(
                icon: "eye.slash.fill",
                title: "\(pool) 자리가 일시 숨김 상태입니다",
                detail: "무결성 확인 중에는 공개 순위에서 보이지 않지만 마지막 시드와 원장은 서버에 보존됩니다.",
                badge: "HIDDEN",
                tint: Tokens.warningInk,
                background: Tokens.warningSoft)
        case "SETTLING":
            return DecisionPresentation(
                icon: "arrow.triangle.2.circlepath",
                title: "\(pool) 자리 정산이 진행 중입니다",
                detail: "경기 결과와 일수 원장이 함께 확정될 때까지 자리 숫자를 최종 결과로 보지 마세요.",
                badge: "SETTLING",
                tint: Tokens.primary,
                background: Tokens.primarySoft)
        case "CLOSED":
            return DecisionPresentation(
                icon: "lock.fill",
                title: "이번 Arena 자리가 종료되었습니다",
                detail: "종료된 시즌의 자리는 더 이상 이동하지 않습니다. MMR은 별도 실력 기록으로 계속 보존됩니다.",
                badge: "CLOSED",
                tint: Tokens.text2,
                background: Tokens.paper2)
        case "PLACEMENT_PENDING", "NOT_SEEDED":
            return DecisionPresentation(
                icon: "list.number",
                title: "Arena 자리 배치를 기다리고 있습니다",
                detail: snapshot.ranking.skill.status == "PLACEMENT_PENDING"
                    ? "배치고사를 마치면 첫 MMR이 발급되고, 주간 시드 뒤 Arena Position이 별도로 배정됩니다."
                    : "MMR은 준비되어 있습니다. 다음 유효 주간 시드가 끝나면 Arena Position이 별도로 배정됩니다.",
                badge: "PLACEMENT",
                tint: Tokens.primary,
                background: Tokens.primarySoft)
        default:
            return DecisionPresentation(
                icon: "questionmark.circle.fill",
                title: "Arena 자리 상태를 확인하고 있습니다",
                detail: "알 수 없는 상태를 임의의 순위로 바꾸지 않고 서버 갱신을 기다립니다.",
                badge: "확인 중",
                tint: Tokens.warningInk,
                background: Tokens.warningSoft)
        }
    }

    private func rankingLabel(_ value: String?) -> String {
        switch value?.uppercased() {
        case "SUB", "MAIN": return ArenaDisplayTerms.ranking(value)
        default: return "미지정"
        }
    }

    private func tierLabel(_ value: String?) -> String {
        switch value?.uppercased() {
        case "BRONZE": return "브론즈"
        case "SILVER": return "실버"
        case "GOLD": return "골드"
        case "PLATINUM": return "플래티넘"
        case "EMERALD": return "에메랄드"
        case "DIAMOND": return "다이아몬드"
        case "MASTER": return "마스터"
        case "GRANDMASTER": return "그랜드마스터"
        case "CHALLENGER": return "챌린저"
        default: return "티어 미발급"
        }
    }

    private func skillStatusLabel(_ value: String) -> String {
        switch value {
        case "PLACEMENT_PENDING": return "MMR 배치 대기"
        case "PROVISIONAL": return "잠정 MMR"
        case "CONFIRMED": return "확정 MMR"
        default: return "MMR 상태 확인"
        }
    }

    private func skillStatusIcon(_ value: String) -> String {
        switch value {
        case "PLACEMENT_PENDING": return "list.number"
        case "PROVISIONAL": return "clock.fill"
        case "CONFIRMED": return "checkmark.seal.fill"
        default: return "questionmark.circle.fill"
        }
    }

    private func skillStatusTint(_ value: String) -> Color {
        switch value {
        case "CONFIRMED": return Tokens.successInk
        case "PROVISIONAL": return Tokens.warningInk
        default: return Tokens.primary
        }
    }

    private func seatStatusLabel(_ value: String) -> String {
        switch value {
        case "PLACEMENT_PENDING", "NOT_SEEDED": return "자리 배치 대기"
        case "ACTIVE": return "자리 공개"
        case "HIDDEN": return "자리 숨김"
        case "SETTLING": return "자리 정산 중"
        case "CLOSED": return "자리 종료"
        default: return "자리 상태 확인"
        }
    }

    private func seatStatusIcon(_ value: String) -> String {
        switch value {
        case "PLACEMENT_PENDING", "NOT_SEEDED": return "list.number"
        case "ACTIVE": return "eye.fill"
        case "HIDDEN": return "eye.slash.fill"
        case "SETTLING": return "arrow.triangle.2.circlepath"
        case "CLOSED": return "lock.fill"
        default: return "questionmark.circle.fill"
        }
    }

    private func seatStatusTint(_ value: String) -> Color {
        switch value {
        case "ACTIVE": return Tokens.successInk
        case "HIDDEN": return Tokens.warningInk
        case "SETTLING", "PLACEMENT_PENDING", "NOT_SEEDED": return Tokens.primary
        default: return Tokens.text2
        }
    }

    private func skillStatusDetail(_ skill: Snapshot.Ranking.Skill) -> String {
        if skill.status == "PLACEMENT_PENDING" {
            return "배치고사를 완료하면 첫 MMR이 발급됩니다."
        }
        if skill.status == "PROVISIONAL" {
            let left = skill.weeklyExamsUntilConfirmed ?? 0
            return left > 0
                ? "잠정 MMR, 공식 시험 \(left)회 뒤 확정"
                : "잠정 MMR, 다음 주간 확정 대기"
        }
        if let rank = skill.overallRank {
            return "전체 MMR \(rank)위, 시험 성과로 갱신"
        }
        return "시험 성과로 갱신되는 실력 지표"
    }

    private func seatStatusDetail(_ seat: Snapshot.Ranking.Seat) -> String {
        if seat.status == "ACTIVE", seat.arenaPosition != nil {
            if let week = seat.seedWeekKey {
                return "\(week) 시드, 직접 대결로만 이동"
            }
            return "직접 대결로만 이동하는 자리"
        }
        if seat.status == "HIDDEN" {
            return "무결성 확인 중, 공개 좌석에서 일시 숨김"
        }
        if seat.status == "SETTLING" {
            return "경기 결과를 안전하게 정산하는 중"
        }
        if seat.status == "CLOSED" {
            return "이번 시즌의 Arena 자리는 종료됨, MMR은 별도 보존"
        }
        if ["PLACEMENT_PENDING", "NOT_SEEDED"].contains(seat.status) {
            return "주간 시드가 끝나면 Arena 자리가 배정됩니다."
        }
        return "알 수 없는 자리를 임의로 표시하지 않고 서버 확인 중"
    }

    private func conditionTitle(_ key: String) -> String {
        switch key {
        case "CYCLE_ATTENDANCE":
            return "30일 사이클 출석"
        case "REFUND_DAY_BALANCE":
            return "페이백 점수 기준 달성"
        case "COMPLETED_SUB_CHALLENGES":
            return "완료한 Unranked 직접 대결"
        default:
            return "서버 판정 조건"
        }
    }

    private func conditionDetail(_ condition: Snapshot.Payback.Condition) -> String {
        switch condition.key {
        case "CYCLE_ATTENDANCE":
            return "유효 학습 이벤트가 인정된 날만 누적"
        case "REFUND_DAY_BALANCE":
            return "잠긴 점수와 학습 가능 일수는 합산하지 않음"
        case "COMPLETED_SUB_CHALLENGES":
            return "일반·Revenge 중 완료로 인정된 경기"
        default:
            return "서버 원장 기준"
        }
    }

    private func conditionCount(_ condition: Snapshot.Payback.Condition) -> String {
        guard let required = condition.required else {
            return "\(condition.current), 기준 확인 중"
        }
        let unit = condition.key == "COMPLETED_SUB_CHALLENGES" ? "회" : "일"
        return "\(condition.current)/\(required)\(unit)"
    }

    private func conditionRatio(_ condition: Snapshot.Payback.Condition) -> CGFloat {
        guard let required = condition.required, required > 0 else { return 0 }
        return CGFloat(min(max(Double(condition.current) / Double(required), 0), 1))
    }

    private func paybackPresentation(
        _ payback: Snapshot.Payback
    ) -> (label: String, color: Color, background: Color) {
        switch payback.refundStatus {
        case "COMPLETED":
            return ("지급 완료", Tokens.successInk, Tokens.successSoft)
        case "PAYOUT_REQUESTED", "PAYOUT_PROCESSING":
            return ("지급 처리 중", Tokens.primary, Tokens.primarySoft)
        case "HELD":
            return ("지급 보류", Tokens.warningInk, Tokens.warningSoft)
        case "FAILED":
            return ("지급 확인 필요", Tokens.warningInk, Tokens.warningSoft)
        default:
            break
        }
        if payback.state == "ELIGIBLE" {
            return ("조건 충족", Tokens.successInk, Tokens.successSoft)
        }
        if payback.state == "POLICY_PENDING" {
            return ("판정 대기", Tokens.warningInk, Tokens.warningSoft)
        }
        return ("진행 중", Tokens.primary, Tokens.primarySoft)
    }

    private func matchTypeLabel(_ value: String) -> String {
        value == "REVENGE" ? "Revenge" : "일반 도전"
    }

    private func roleLabel(_ value: String) -> String {
        value == "CHALLENGER" ? "도전자" : "방어자"
    }

    private func matchStatusLabel(_ value: String) -> String {
        switch value {
        case "REQUESTED": return "매칭 대기"
        case "MATCHED": return "매칭 완료"
        case "READY": return "시작 대기"
        case "IN_PROGRESS": return "진행 중"
        case "SUBMITTED": return "채점 중"
        case "HELD": return "무결성 확인 중"
        case "RESOLVED": return "정산 대기"
        default: return "상태 확인"
        }
    }

    private func matchStatusPresentation(_ match: Snapshot.ActiveMatch) -> DecisionPresentation {
        if needsEvidenceSubmission(match) {
            return DecisionPresentation(
                icon: "doc.viewfinder.fill",
                title: "풀이 증거 제출 필요",
                detail: "답안은 서버에 고정되었습니다. 경기 계속하기에서 서버 마감 전 풀이 사진 1~5장을 제출해 주세요.",
                badge: "사진 제출",
                tint: Tokens.warningInk,
                background: Tokens.warningSoft)
        }
        if participantHasSubmitted(match) {
            return DecisionPresentation(
                icon: "checkmark.circle.fill",
                title: "내 답안 제출 완료",
                detail: "내 답안은 서버에 고정되었습니다. 공유 경기가 진행 중이어도 다시 시작하거나 수정하지 않고 상대 제출과 채점 결과를 기다립니다.",
                badge: "제출 완료",
                tint: Tokens.successInk,
                background: Tokens.successSoft)
        }

        let detail: String
        let icon: String
        let tint: Color
        let background: Color

        switch match.status {
        case "REQUESTED":
            detail = "대결 요청이 서버에 기록되었습니다. 상대 확정 전까지 맡긴 일수와 요청 상태를 확인합니다."
            icon = "hourglass"
            tint = Tokens.primary
            background = Tokens.primarySoft
        case "MATCHED":
            detail = match.role == "DEFENDER"
                ? "내가 방어자인 도전입니다. 최신 상태를 확인한 뒤 수락하거나 선택한 사유로 거절할 수 있습니다."
                : "상대와 두 자리, 맡긴 일수가 고정되었습니다. 방어자의 응답을 기다리고 있습니다."
            icon = "person.2.fill"
            tint = Tokens.primary
            background = Tokens.primarySoft
        case "READY":
            detail = "경기 시작 구간입니다. 아래 버튼에서 내 개인 제한 시간이 시작됩니다."
            icon = "play.circle.fill"
            tint = Tokens.warningInk
            background = Tokens.warningSoft
        case "IN_PROGRESS":
            detail = "내 개인 제한 시간이 진행 중입니다. 아래 버튼에서 이어서 풀고 제출할 수 있습니다."
            icon = "bolt.fill"
            tint = Tokens.primary
            background = Tokens.primarySoft
        case "SUBMITTED":
            detail = "답안 제출이 기록되었습니다. 동일한 채점 기준으로 두 결과를 비교하고 있습니다."
            icon = "checkmark.circle.fill"
            tint = Tokens.successInk
            background = Tokens.successSoft
        case "HELD":
            detail = "자동 정산을 멈추고 무결성을 확인하고 있습니다. 자리와 맡긴 일수는 그대로 잠겨 있습니다."
            icon = "exclamationmark.shield.fill"
            tint = Tokens.warningInk
            background = Tokens.warningSoft
        case "RESOLVED":
            detail = "경기 결과는 결정되었고, 자리 교환과 일수 원장을 한 번에 확정하는 중입니다."
            icon = "arrow.triangle.2.circlepath"
            tint = Tokens.primary
            background = Tokens.primarySoft
        default:
            detail = "알 수 없는 경기 상태를 임의로 해석하지 않고 서버 갱신을 기다립니다."
            icon = "questionmark.circle.fill"
            tint = Tokens.warningInk
            background = Tokens.warningSoft
        }

        return DecisionPresentation(
            icon: icon,
            title: matchStatusLabel(match.status),
            detail: detail,
            badge: matchStatusLabel(match.status),
            tint: tint,
            background: background)
    }

    private func matchNextActionTitle(_ match: Snapshot.ActiveMatch) -> String {
        if needsEvidenceSubmission(match) {
            return "풀이 사진을 제출해 주세요"
        }
        if participantHasSubmitted(match) {
            return "상대 제출과 채점 결과를 기다리세요"
        }
        if match.role == "DEFENDER", match.status == "MATCHED" {
            return "자리 도전에 응답해 주세요"
        }
        switch match.status {
        case "REQUESTED": return "상대 확정을 기다리세요"
        case "MATCHED": return "시작 마감을 확인하세요"
        case "READY": return "현재 경기 경로에서 시작하세요"
        case "IN_PROGRESS": return "제출 마감을 놓치지 마세요"
        case "SUBMITTED": return "채점 결과를 기다리세요"
        case "HELD": return "무결성 검토 결과를 기다리세요"
        case "RESOLVED": return "원장 정산 완료를 기다리세요"
        default: return "서버 상태를 다시 확인하세요"
        }
    }

    private func matchNextActionDetail(_ match: Snapshot.ActiveMatch) -> String {
        if needsEvidenceSubmission(match) {
            let deadline = shortDateTime(match.attempt?.evidenceDeadlineAt)
                .map { " 서버 제출 마감은 \($0)입니다." } ?? ""
            return "답안은 이미 고정되어 다시 바꿀 수 없습니다. 아래 경기 계속하기에서 풀이 사진 1~5장을 제출하세요.\(deadline)"
        }
        if participantHasSubmitted(match) {
            return "제출된 답안은 바꿀 수 없습니다. 서버 정산이 끝나면 이 화면의 경기 상태와 Arena Position이 갱신됩니다."
        }
        if match.role == "DEFENDER", match.status == "MATCHED" {
            let deadline = shortDateTime(match.startsBy)
                .map { " 서버 시작 마감은 \($0)입니다." } ?? ""
            return "수락 또는 거절 버튼이 보이지 않으면 최신 경기 상태를 다시 확인하세요.\(deadline)"
        }
        switch match.status {
        case "REQUESTED":
            return "상대가 확정되면 자리와 마감이 이 화면에 표시됩니다."
        case "MATCHED":
            let deadline = shortDateTime(match.startsBy).map { " 시작 마감은 \($0)입니다." } ?? ""
            return "서버가 문제와 시작 조건을 준비하고 있습니다.\(deadline)"
        case "READY":
            let deadline = shortDateTime(match.startsBy).map { " 시작 마감은 \($0)입니다." } ?? ""
            return "아래 경기 시작 버튼을 누르면 내 개인 제한 시간이 시작됩니다.\(deadline)"
        case "IN_PROGRESS":
            let deadline = shortDateTime(match.submitsBy).map { " 제출 마감은 \($0)입니다." } ?? ""
            return "아래 경기 계속하기 버튼에서 답안을 이어서 저장하고 제출하세요.\(deadline)"
        case "SUBMITTED":
            return "채점 중에는 자리를 최종 결과로 보지 마세요. 결과가 확정되면 정산 단계로 이동합니다."
        case "HELD":
            return "검토 중에는 자리와 맡긴 일수가 움직이지 않습니다. 앱이 승패나 정산 결과를 추측하지 않습니다."
        case "RESOLVED":
            return "자리와 일수 원장이 함께 확정되면 Arena Position과 사용 가능 일수가 갱신됩니다."
        default:
            return "잠시 후 새로고침해 서버가 내려준 상태를 다시 확인하세요."
        }
    }

    private func matchSettlementRule(_ match: Snapshot.ActiveMatch) -> String {
        if let serverRule = match.settlementRule?.trimmingCharacters(in: .whitespacesAndNewlines),
           !serverRule.isEmpty {
            return ArenaDisplayTerms.apply(serverRule)
        }
        if match.matchType == "REVENGE" {
            if match.activeRanking == "MAIN" {
                return "Ranked 복수전 정산입니다. 정상 완료에서 1일을 수수료로 소각합니다. 공격자가 이기면 Arena 상태를 교환하고 2×S-1일을 공격자에게 반환하며, 방어자가 이기면 Arena 상태를 유지하고 2×S-1일을 방어자에게 이전합니다. 방어자만 24시간 안에 미완료하면 2×S-1일을 공격자에게 반환하고 1일을 소각하며, 공격자만 미완료하면 2×S-1일을 방어자에게 이전하고 1일을 소각합니다. 양측 모두 미완료하면 예치 전부를 소각합니다."
            }
            return "Unranked 복수전 정산입니다. 정상 완료에서 도전자가 이기면 Arena 상태를 교환하고 예치한 페이백 점수 2점을 전부 소각합니다. 방어자가 이기면 Arena 상태를 유지하고 1점을 방어자에게 이전하며 1점을 소각합니다. 방어자만 24시간 안에 미완료하면 1점을 도전자에게 반환하고 1점을 소각하며, 도전자만 미완료하면 1점을 방어자에게 이전하고 1점을 소각합니다. 양측 모두 미완료하면 예치한 2점을 전부 소각합니다."
        }
        if match.activeRanking == "MAIN" {
            return "Ranked 일반전 정산입니다. 상향 쟁탈전은 공격자만 예치하고, 수락형 하위 티어 초대전은 양쪽이 같은 일수를 예치합니다. 정상 완료 시 승자는 자기 예치금을 돌려받고 상대가 예치한 금액이 있으면 이전받습니다. 공격자가 이기면 Arena 상태를 교환하고 방어자가 이기면 유지합니다."
        }
        return "Unranked 일반 쟁탈전 정산입니다. 도전자가 이기면 경기 시작 전 티어가 브론즈일 때 예치한 페이백 점수 1점을 반환받고, 실버 이상일 때는 1점을 소각하며 Arena 상태를 교환합니다. 방어자가 이기면 그 1점을 방어자에게 이전하고 Arena 상태를 유지합니다."
    }

    private func stakeAssetLabel(_ value: String?) -> String {
        switch value {
        case "PAYBACK_SCORE_DAY", "REFUND_CHALLENGE_DAY": return "페이백 점수"
        case "LEARNING_DAY", "BONUS_ACCESS_DAY": return "학습 가능 일수"
        default: return "자산 확인 중"
        }
    }

    private func integrityLabel(_ value: String) -> String {
        switch value {
        case "CLEAR": return "이상 없음"
        case "HELD", "REVIEW", "FLAGGED": return "검토 중"
        default: return "상태 확인"
        }
    }

    private func shortDateTime(_ value: String?) -> String? {
        guard let value else { return nil }
        guard let date = isoDate(value) else { return nil }
        return date.formatted(
            Date.FormatStyle(date: .abbreviated, time: .shortened)
                .locale(Locale(identifier: "ko_KR")))
    }

    private func isoDate(_ value: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: value) { return date }
        return ISO8601DateFormatter().date(from: value)
    }

    private func relativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.unitsStyle = .full
        let now = Date()
        return formatter.localizedString(for: min(date, now), relativeTo: now)
    }

    private func truthNoticeText(_ snapshot: Snapshot) -> String {
        if snapshot.capabilities.challengeCommands == "NOT_AVAILABLE" {
            if snapshot.pendingInvitation != nil {
                return "새 상대를 찾기 전에 먼저 도착한 Ranked 초대에 응답하세요."
            }
            if let match = snapshot.activeMatch, canPlay(match) {
                return "진행 중인 경기를 이 기기에서 바로 시작하거나 이어서 제출하세요. 경기가 끝나면 새 상대 찾기가 다시 열립니다."
            }
            return "내 Arena 기록은 최신 서버 상태와 동기화됩니다. 새 상대 찾기는 화면의 ‘상대 찾기’ 버튼에서 이어갈 수 있습니다."
        }
        if let generatedAt = isoDate(snapshot.generatedAt) {
            return "공식 시험·경기 기록 기준, \(relativeTime(generatedAt)) 갱신"
        }
        return "공식 시험·경기 기록을 기준으로 갱신됩니다."
    }

    private func formatted(_ value: Int) -> String {
        value.formatted(.number.grouping(.automatic))
    }

    // MARK: Loading

    @MainActor
    private func load() async {
        let nextID = UUID()
        let accountSlot = DataScope.slot
        requestID = nextID
        let existing = loadedContent
        let existingAccountSlot = loadedAccountSlot
        if existing == nil {
            state = .loading
        } else {
            isRefreshing = true
        }

        guard ServerAPI.hasToken else {
            isRefreshing = false
            state = .signedOut
            loadedAccountSlot = nil
            recentMatches = []
            pendingDefenderCommand = nil
            defenderCommandReceipt = nil
            return
        }

        do {
            let value = try await ServerAPI.getGoatArenaSnapshot()
            guard requestID == nextID else { return }
            guard DataScope.slot == accountSlot else {
                isRefreshing = false
                loadedAccountSlot = nil
                pendingDefenderCommand = nil
                state = .idle
                return
            }
            isRefreshing = false
            // 서버가 내려준 방어 마감으로 기기 로컬 알림을 다시 건다(LocalNotifications.swift).
            // 아래 catch 의 캐시 분기가 아니라 이 분기에서만 거는 이유 — 저장된 스냅샷은
            // 이미 끝난 경기의 마감을 담고 있을 수 있고, 끝난 경기로 학생을 부르면
            // 알림이 신뢰를 잃는다. 슬롯은 위 guard 로 이미 확인됐다.
            RankDefenseReminder.reschedule(
                match: value.activeMatch,
                accountSlot: accountSlot,
                allowPermissionPrompt: !store.isTutorialPresentationActive)
            installLoadedSnapshot(
                value,
                freshness: .fresh(receivedAt: Date()),
                accountSlot: accountSlot,
                authoritative: true
            )
            // 결과 목록은 스냅샷과 다른 라우트다. 같은 await 에 묶으면 목록이 느리거나
            // 없는 서버에서 홈 전체가 그만큼 늦게 뜬다 — 따로 띄우고 실패는 삼킨다.
            Task { await loadRecentMatches(accountSlot: accountSlot, token: nextID) }
        } catch {
            guard requestID == nextID else { return }
            guard DataScope.slot == accountSlot else {
                isRefreshing = false
                loadedAccountSlot = nil
                pendingDefenderCommand = nil
                state = .idle
                return
            }
            isRefreshing = false
            if error is CancellationError { return }
            if !ServerAPI.hasToken {
                state = .signedOut
                loadedAccountSlot = nil
                pendingDefenderCommand = nil
                defenderCommandReceipt = nil
            } else if let cached = ServerAPI.cachedGoatArenaSnapshot() {
                installLoadedSnapshot(
                    cached.snapshot,
                    freshness: .cached(
                        savedAt: cached.savedAt,
                        failure: failurePresentation(error)
                    ),
                    accountSlot: accountSlot,
                    authoritative: false
                )
            } else if let existing,
                      existingAccountSlot == accountSlot {
                installLoadedSnapshot(
                    existing.snapshot,
                    freshness: .cached(
                        savedAt: freshnessDate(existing.freshness),
                        failure: failurePresentation(error)
                    ),
                    accountSlot: accountSlot,
                    authoritative: false
                )
            } else {
                state = .failed(failurePresentation(error))
                loadedAccountSlot = nil
                pendingDefenderCommand = nil
            }
        }
    }

    /// 정산이 끝난 최근 경기를 읽는다. **읽기 전용이고 보조 정보다** —
    /// 실패하면 조용히 이전 값을 남긴다(빈 목록으로 덮어 결과를 지우지 않는다).
    /// 라우트가 없는 서버에서도 홈은 종전과 똑같이 동작해야 한다.
    @MainActor
    private func loadRecentMatches(accountSlot: String, token: UUID) async {
        guard ServerAPI.hasToken else { return }
        do {
            let matches = try await ServerAPI.getGoatArenaMatches(limit: 5)
            guard requestID == token, DataScope.slot == accountSlot else { return }
            recentMatches = matches
        } catch {
            return
        }
    }

    @MainActor
    private func installLoadedSnapshot(
        _ snapshot: Snapshot,
        freshness: SnapshotFreshness,
        accountSlot: String,
        authoritative: Bool
    ) {
        state = .loaded(
            LoadedContent(
                snapshot: snapshot,
                freshness: freshness
            )
        )
        loadedAccountSlot = accountSlot
        reconcileDefenderCommandState(
            snapshot: snapshot,
            accountSlot: accountSlot,
            authoritative: authoritative
        )
        if authoritative {
            if let presentation = snapshot.rankUpPresentation {
                store.presentRankPromotion(
                    tierCode: presentation.tierCode,
                    presentationId: presentation.id)
            } else {
                // 구버전 서버만 현재 티어 변화 감지를 보조 경로로 사용한다.
                store.observeArenaTier(snapshot.ranking.skill.tier)
            }
        }
    }

    private func freshnessDate(_ freshness: SnapshotFreshness) -> Date {
        switch freshness {
        case .fresh(let receivedAt): return receivedAt
        case .cached(let savedAt, _): return savedAt
        }
    }

    private func failurePresentation(_ error: Error) -> FailurePresentation {
        if error is DecodingError {
            return FailurePresentation(
                kind: .incompatible,
                message: "서버 응답 형식을 확인할 수 없습니다. 앱과 서버를 업데이트한 뒤 다시 시도해 주세요.")
        }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost,
                    .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
                return FailurePresentation(
                    kind: .offline,
                    message: "인터넷 연결을 확인한 뒤 다시 시도해 주세요.")
            case .timedOut:
                return FailurePresentation(
                    kind: .timeout,
                    message: "잠시 후 다시 시도해 주세요.")
            default:
                return FailurePresentation(
                    kind: .server,
                    message: "서버에 연결하지 못했습니다. 잠시 후 다시 시도해 주세요.")
            }
        }
        if let apiError = error as? ServerAPIError {
            if apiError.code == "GOAT_ARENA_VERSION_MISMATCH"
                || apiError.statusCode == 404 {
                return FailurePresentation(
                    kind: .incompatible,
                    message: "GOAT Arena 서버 기능과 앱 버전을 확인한 뒤 다시 시도해 주세요.")
            }
            if apiError.statusCode == 429 {
                return FailurePresentation(
                    kind: .server,
                    message: "새로고침 요청이 많습니다. 잠시 후 다시 시도해 주세요.")
            }
            // 신 서버는 진행 중인 경기가 있으면 읽기 모델 조립에서 500 을 낸다(서버 버그).
            // 재시도로 풀리지 않으므로 웹에서 확인하라고 안내한다.
            if apiError.statusCode == 500 {
                return FailurePresentation(
                    kind: .server,
                    message: "서버가 진행 중인 경기 정보를 만들지 못했습니다. 웹 GOAT Arena에서 확인해 주세요.")
            }
        }
        return FailurePresentation(
            kind: .server,
            message: "GOAT Arena 정보를 불러오지 못했습니다. 잠시 후 다시 시도해 주세요.")
    }

    /// 경기 명령 라우트가 없는 서버에서 상대 찾기·초대 응답이 받는 안내 문구.
    static let arenaCommandsUnavailableNotice =
        "현재 경기 진행은 앱 안의 웹 GOAT Arena 화면에서 이어집니다."

    /// 앱 CTA 대신 보여 주는 웹 GOAT Arena 진입.
    ///
    /// 종전에는 Safari 로 나가는 `Link` 였다. 그러면 앱 로그인과 웹 세션이 둘로 갈려
    /// 학생이 웹에서 다시 로그인해야 하고, 돌아올 길도 없다. 지금은 같은 계정으로
    /// 세션을 이어 주는 앱 안의 웹 브리지(ArenaWebPresenter)를 띄운다.
    /// - Parameters:
    ///   - onDark: 네이비 히어로 위(true) / 밝은 카드 위(false).
    ///   - destination: 열 아레나 페이지. 기본값은 시작 페이지.
    ///   - title: 버튼 글자.
    private func webArenaFallback(
        onDark: Bool,
        destination: ArenaWebDestination = .home,
        title: String = "웹 GOAT Arena에서 진행"
    ) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s3) {
            Text(Self.arenaCommandsUnavailableNotice)
                .font(.mCaption)
                .foregroundStyle(onDark ? onNavy.opacity(0.72) : Tokens.text2)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                openArenaWeb(destination)
            } label: {
                HStack(spacing: Tokens.Space.s3) {
                    Image(systemName: "person.2.fill")
                    Text(title)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                    Spacer(minLength: Tokens.Space.s3)
                    Image(systemName: "arrow.right")
                }
                .font(.mBodyB)
                .foregroundStyle(onDark ? onNavy : Tokens.primary)
                .padding(.horizontal, Tokens.Space.s5)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(
                    onDark ? onNavy.opacity(0.09) : Tokens.surface,
                    in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: Tokens.Radius.md)
                        .strokeBorder(onDark ? onNavy.opacity(0.22) : Tokens.line, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityHint("앱 안에서 로그인이 이어진 웹 GOAT Arena 페이지를 엽니다")
        }
    }

    #if DEBUG
    @MainActor
    private func applyDebugFixtureIfPresent() -> Bool {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-goatFixture"),
              index + 1 < arguments.count else { return false }

        switch arguments[index + 1].lowercased() {
        case "active":
            state = fixtureState(GoatArenaFixture.make())
        case "main":
            state = fixtureState(GoatArenaFixture.make(main: true))
        case "day30":
            state = fixtureState(GoatArenaFixture.make(day: 30, policyPending: true))
        case "policy":
            state = fixtureState(GoatArenaFixture.make(policyPending: true))
        case "match":
            state = fixtureState(GoatArenaFixture.make(includeMatch: true))
        case "matchplay":
            let snapshot = GoatArenaFixture.make(includeMatch: true)
            state = fixtureState(snapshot)
            matchLaunch = MatchLaunch(
                id: "fixture-match",
                briefing: snapshot.activeMatch.map { matchBriefing($0) })
        case "defender":
            state = fixtureState(
                GoatArenaFixture.make(
                    includeMatch: true,
                    matchStatus: "MATCHED",
                    matchRole: "DEFENDER"
                )
            )
        case "submitted":
            state = fixtureState(
                GoatArenaFixture.make(
                    includeMatch: true,
                    attemptStatus: "SUBMITTED"))
        case "requested":
            state = fixtureState(
                GoatArenaFixture.make(includeMatch: true, matchStatus: "REQUESTED"))
        case "held":
            state = fixtureState(
                GoatArenaFixture.make(includeMatch: true, matchStatus: "HELD"))
        case "empty":
            state = fixtureState(GoatArenaFixture.make(noCycle: true))
        case "placement":
            state = fixtureState(
                GoatArenaFixture.make(skillStatus: "PLACEMENT_PENDING", seatStatus: "PLACEMENT_PENDING"))
        case "hidden":
            state = fixtureState(GoatArenaFixture.make(seatStatus: "HIDDEN"))
        case "settling":
            state = fixtureState(
                GoatArenaFixture.make(main: true, cycleStatus: "MAIN_SETTLING", seatStatus: "SETTLING"))
        case "closed":
            state = fixtureState(
                GoatArenaFixture.make(noCycle: true, seatStatus: "CLOSED"))
        case "offline":
            state = .loaded(
                LoadedContent(
                    snapshot: GoatArenaFixture.make(includeMatch: true),
                    freshness: .cached(
                        savedAt: Date().addingTimeInterval(-45 * 60),
                        failure: FailurePresentation(
                            kind: .offline,
                            message: "인터넷 연결을 확인한 뒤 다시 시도해 주세요."))))
        case "stale":
            state = .loaded(
                LoadedContent(
                    snapshot: GoatArenaFixture.make(),
                    freshness: .cached(
                        savedAt: Date().addingTimeInterval(-3 * 60 * 60),
                        failure: FailurePresentation(
                            kind: .server,
                            message: "서버의 최신 기록을 확인하지 못했습니다."))))
        case "loading":
            state = .loading
        case "signedout":
            state = .signedOut
        case "failure":
            state = .failed(
                FailurePresentation(
                    kind: .server,
                    message: "서버에 연결하지 못했습니다. 잠시 후 다시 시도해 주세요."))
        default:
            return false
        }
        // `-arenaCommandsUnavailable`: 경기 명령 라우트가 없는 서버(= 실서버)를 만난
        // 상태를 픽스처 위에서 재현한다. 실서버 상태는 로그인 계정 없이는 시뮬레이터에서
        // 볼 수 없는데, 상대 찾기 CTA 가 웹 브리지로 바뀌는지는 눈으로 확인해야 한다.
        if arguments.contains("-arenaCommandsUnavailable") {
            arenaCommandsUnavailable = true
        }
        // `-arenaResultsFixture`: 정산이 끝난 최근 경기 줄을 픽스처로 세운다.
        // 서버 계정 없이는 시뮬레이터에서 볼 수 없는 화면이라 눈으로 확인할 길을 둔다.
        if arguments.contains("-arenaResultsFixture") {
            recentMatches = GoatArenaFixture.recentMatches()
        }
        loadedAccountSlot = DataScope.slot
        if case .loaded(let content) = state {
            let authoritative: Bool
            switch content.freshness {
            case .fresh:
                authoritative = true
            case .cached:
                authoritative = false
            }
            reconcileDefenderCommandState(
                snapshot: content.snapshot,
                accountSlot: DataScope.slot,
                authoritative: authoritative
            )
        }
        return true
    }

    private func fixtureState(_ snapshot: Snapshot) -> LoadState {
        .loaded(
            LoadedContent(
                snapshot: snapshot,
                freshness: .fresh(receivedAt: Date())))
    }
    #endif
}

// MARK: - 전체 랭킹 시트
//
// WHY. RankArenaScreen 은 RootView 의 browseScroll 안에서만 살도록 만들어졌다
// (자기 ScrollView 가 없다). 시트로 띄우려면 스크롤과 여백을 이 자리에서
// 감싸 줘야 한다. 순위표 자체는 한 줄도 새로 만들지 않는다 — 같은 화면,
// 같은 데이터 흐름(getArena → getAccessEconomy → getAccessLeaderboard)이다.
private struct GoatArenaLeaderboardSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                RankArenaScreen()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .readableWidth(Tokens.readableWidth)
                    .adaptiveHPadding()
                    .adaptiveVPadding()
            }
            .background(Tokens.paper)
            .navigationBarTitleDisplayMode(.inline)
            // 투명 내비게이션 바를 그대로 두면 순위표 행이 "닫기" 칩 뒤로
            // 지나가면서 둘 다 읽히지 않는다. 바탕을 고정한다.
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Tokens.paper, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
            }
        }
    }
}

// MARK: - 아레나 더 보기 시트
//
// WHY. 앱에 이미 있는 알림함·순위표·상점·룰북을 같은 이름의 웹 페이지로 또 열면
// 로그인 브리지와 뒤로가기가 늘고, 한 메뉴에 같은 목적지가 두 번 생긴다. 네이티브
// 정본은 네이티브로 연다. 이 메뉴에는 세션 웹으로 나가는 행을 남기지 않는다.
//
// 진입점을 화면에 낱개 버튼으로 세우지 않는 이유: 좁은 폭 스크롤을 3647 → 1081pt 로
// 줄여 놓은 성과가 버튼 열 개로 도로 무너진다. 보조 버튼 한 칸("아레나 더 보기") 뒤에
// 목록으로 모으고, 목록은 이 시트 안에서 스크롤한다.
//
// 줄 이름은 ArenaWebDestination.title 을 그대로 쓴다 — 웹 상단 메뉴 이름과 같은 말이라야
// 학생이 같은 곳인지 안다. 아레나 규칙·정산·페이백 설명은 한 글자도 다시 쓰지 않는다
// (그 정본은 웹 페이지가 갖고 있고, 두 벌이 되는 순간 갈린다). 여기 부제는 "어디로
// 가는가" 만 말한다.
private struct GoatArenaMoreMenuSheet: View {
    @Environment(\.dismiss) private var dismiss

    /// 이미 앱에 있는 정본 화면들.
    let onOpenNotifications: () -> Void
    let onOpenLeaderboard: () -> Void
    let onOpenRulebook: () -> Void
    /// 앱 안의 Ranked 상점 화면으로.
    let onOpenArenaShop: () -> Void
    let onOpenRankedMatchmaker: () -> Void
    let onOpenFriendlyMatchmaker: () -> Void
    let onOpenRevengeRights: () -> Void
    let onOpenPaybackAccount: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("알림, 경기 관리, 순위, 상점과 페이백 계좌를 앱 화면에서 바로 엽니다.")
                        .font(.mCaption)
                        .foregroundStyle(Tokens.text2)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, Tokens.Space.s4)

                    menuRow(
                        title: "알림함",
                        detail: "경기 알림 · 공지 · 계정 안내",
                        icon: "envelope.fill",
                        action: onOpenNotifications
                    )

                    menuRow(
                        title: "전체 순위표",
                        detail: "현재 티어와 전체 순위",
                        icon: "list.number",
                        action: onOpenLeaderboard
                    )

                    menuRow(
                        title: "Ranked 상점",
                        detail: "앱 화면에서 열기",
                        icon: "bag.fill",
                    ) {
                        onOpenArenaShop()
                    }

                    menuRow(
                        title: "경기 규정",
                        detail: "Unranked · Ranked 공식 규정",
                        icon: "book.closed.fill",
                        action: onOpenRulebook
                    )

                    menuRow(
                        title: "Ranked 상대 찾기",
                        detail: "상향 도전 · 하위 초대 · 예약 관리",
                        icon: "person.2",
                        action: onOpenRankedMatchmaker
                    )

                    menuRow(
                        title: "친선 경기",
                        detail: "닉네임 검색 · 초대 수락 · 보낸 초대 관리",
                        icon: "figure.2",
                        action: onOpenFriendlyMatchmaker
                    )

                    menuRow(
                        title: "복수전 권리",
                        detail: "사용 가능한 권리 확인 · 시작 · 포기",
                        icon: "arrow.uturn.backward.circle.fill",
                        action: onOpenRevengeRights
                    )

                    menuRow(
                        title: "페이백 계좌",
                        detail: "지급 계좌 확인 · 안전한 계좌 변경",
                        icon: "creditcard.fill",
                        action: onOpenPaybackAccount
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .readableWidth(Tokens.readableWidth)
                .adaptiveHPadding()
                .adaptiveVPadding()
            }
            .background(Tokens.paper)
            .navigationTitle("GOAT Arena 더 보기")
            .navigationBarTitleDisplayMode(.inline)
            // 투명 내비게이션 바를 두면 목록 줄이 "닫기" 칩 뒤로 지나간다(랭킹 시트와 같은 처리).
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Tokens.paper, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
            }
        }
    }

    /// 목록 한 줄. 44pt 가 아니라 52pt 를 최소로 두는 이유는 부제가 두 줄로 접힐 때도
    /// 터치 영역이 줄지 않게 하기 위해서다(접힌 상세 줄과 같은 규격).
    private func menuRow(
        title: String,
        detail: String,
        icon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: Tokens.Space.s3) {
                Image(systemName: icon)
                    .font(.mCaption)
                    .foregroundStyle(Tokens.primary)
                    .frame(width: 22)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.mBodyB)
                        .foregroundStyle(Tokens.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(detail)
                        .font(.mCaption)
                        .foregroundStyle(Tokens.text3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: Tokens.Space.s2)
                Image(systemName: "chevron.right")
                    .font(.mMicro)
                    .foregroundStyle(Tokens.text3)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, Tokens.Space.s3)
            .frame(minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(detail)")
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("앱 화면을 엽니다")
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Tokens.line)
                .frame(height: 1)
                .accessibilityHidden(true)
        }
    }
}

#if DEBUG
// MARK: - 스크롤 깊이 계측 프로브 (DEBUG 전용)
//
// WHY. "스크롤 지옥"은 눈대중이 아니라 숫자로 확인해야 고쳤는지 알 수 있다.
// 배경 GeometryReader 라 레이아웃 제안을 바꾸지 않으므로 붙어 있어도 배치는
// 그대로다. 실행 인자 `-measureArenaHeight` 가 있을 때만 NSLog 를 찍는다.
private struct ArenaHeightProbe: ViewModifier {
    let label: String

    private static let isOn =
        ProcessInfo.processInfo.arguments.contains("-measureArenaHeight")

    private struct HeightKey: PreferenceKey {
        static var defaultValue: CGFloat = 0
        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
            value = max(value, nextValue())
        }
    }

    func body(content: Content) -> some View {
        content
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .preference(key: HeightKey.self, value: proxy.size.height)
                }
                .accessibilityHidden(true)
            }
            .onPreferenceChange(HeightKey.self) { height in
                Self.log(label, height)
            }
    }

    private static func log(_ label: String, _ height: CGFloat) {
        guard isOn else { return }
        NSLog("ARENA-HEIGHT %@ %.1f", label, height)
    }
}
#endif

// MARK: - Account-scoped defender command recovery

private enum GoatArenaDefenderCommandAction: String, Codable, Equatable {
    case accept = "ACCEPT"
    case decline = "DECLINE"
}

private struct GoatArenaPendingDefenderCommand: Codable, Equatable {
    let action: GoatArenaDefenderCommandAction
    let reasonCode: ServerAPI.GoatArenaDeclineReasonCode?
}

private struct GoatArenaDefenderCommandKeys: Codable {
    let matchId: String
    let acceptCommandId: String
    let declineCommandId: String
    let clientBuildVersion: String
    var pending: GoatArenaPendingDefenderCommand?

    private enum CodingKeys: String, CodingKey {
        case matchId
        case acceptCommandId
        case declineCommandId
        case clientBuildVersion
        case pending
    }

    init(
        matchId: String,
        acceptCommandId: String,
        declineCommandId: String,
        clientBuildVersion: String,
        pending: GoatArenaPendingDefenderCommand?
    ) {
        self.matchId = matchId
        self.acceptCommandId = acceptCommandId
        self.declineCommandId = declineCommandId
        self.clientBuildVersion = clientBuildVersion
        self.pending = pending
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        matchId = try values.decode(String.self, forKey: .matchId)
        acceptCommandId = try values.decode(
            String.self,
            forKey: .acceptCommandId
        )
        declineCommandId = try values.decode(
            String.self,
            forKey: .declineCommandId
        )
        let storedBuild = try values.decodeIfPresent(
            String.self,
            forKey: .clientBuildVersion
        )?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let storedBuild, !storedBuild.isEmpty {
            clientBuildVersion = storedBuild
        } else {
            clientBuildVersion = ServerAPI.clientBuildVersion
        }
        pending = try values.decodeIfPresent(
            GoatArenaPendingDefenderCommand.self,
            forKey: .pending
        )
    }
}

private struct GoatArenaPreparedDefenderCommand {
    let keys: GoatArenaDefenderCommandKeys
    let pending: GoatArenaPendingDefenderCommand
}

private enum GoatArenaDefenderCommandError: Error {
    case conflictingPending
    case persistenceFailed
    case invalidDeclineReason
    case invalidResponse
    case accountChanged
}

private enum GoatArenaDefenderCommandStore {
    private static let fileName = "goat-arena-defender-command-keys.json"

    private static var fileURL: URL {
        DataScope.url(fileName)
    }

    static func load(matchId: String) throws -> GoatArenaDefenderCommandKeys? {
        try readAll().first { $0.matchId == matchId }
    }

    static func prepare(
        matchId: String,
        action: GoatArenaDefenderCommandAction,
        reasonCode: ServerAPI.GoatArenaDeclineReasonCode?
    ) throws -> GoatArenaPreparedDefenderCommand {
        if action == .decline, reasonCode == nil {
            throw GoatArenaDefenderCommandError.invalidDeclineReason
        }

        let proposed = GoatArenaPendingDefenderCommand(
            action: action,
            reasonCode: action == .decline ? reasonCode : nil
        )
        var values = try readAll()
        let index = values.firstIndex { $0.matchId == matchId }
        var keys: GoatArenaDefenderCommandKeys

        if let index {
            keys = values[index]
            if let pending = keys.pending, pending != proposed {
                throw GoatArenaDefenderCommandError.conflictingPending
            }
            keys.pending = proposed
            values[index] = keys
        } else {
            keys = GoatArenaDefenderCommandKeys(
                matchId: matchId,
                acceptCommandId: UUID().uuidString,
                declineCommandId: UUID().uuidString,
                clientBuildVersion: ServerAPI.clientBuildVersion,
                pending: proposed
            )
            values.append(keys)
        }

        try write(values)
        return GoatArenaPreparedDefenderCommand(
            keys: keys,
            pending: proposed
        )
    }

    static func clear(matchId: String) throws {
        let remaining = try readAll().filter { $0.matchId != matchId }
        try write(remaining)
    }

    private static func readAll() throws -> [GoatArenaDefenderCommandKeys] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode(
                [GoatArenaDefenderCommandKeys].self,
                from: data
            )
        } catch {
            // 손상된 키 파일을 빈 값으로 덮으면 응답 유실 뒤 다른 멱등키를 보내게
            // 된다. 읽을 수 없을 때는 명령 자체를 막아 중복 결정을 피한다.
            throw GoatArenaDefenderCommandError.persistenceFailed
        }
    }

    private static func write(
        _ values: [GoatArenaDefenderCommandKeys]
    ) throws {
        do {
            let data = try JSONEncoder().encode(values)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            throw GoatArenaDefenderCommandError.persistenceFailed
        }
    }
}

#if DEBUG
private enum GoatArenaFixture {
    typealias Snapshot = ServerAPI.GoatArenaSnapshot

    static func make(
        day: Int = 18,
        main: Bool = false,
        policyPending: Bool = false,
        includeMatch: Bool = false,
        noCycle: Bool = false,
        cycleStatus: String? = nil,
        skillStatus: String = "CONFIRMED",
        seatStatus: String? = nil,
        matchStatus: String = "IN_PROGRESS",
        matchRole: String = "CHALLENGER",
        attemptStatus: String? = nil
    ) -> Snapshot {
        let ranking = main ? "MAIN" : "SUB"
        let refundDays = main ? 30 : 27
        let completed = 2
        let effectiveSeatStatus = seatStatus ?? (noCycle ? "NOT_SEEDED" : "ACTIVE")
        let hasSeat = ["ACTIVE", "HIDDEN", "SETTLING"].contains(effectiveSeatStatus)

        let cycle: Snapshot.Cycle? = noCycle ? nil : Snapshot.Cycle(
            id: "fixture-cycle",
            status: cycleStatus
                ?? (day == 30 ? "SUB_CLOSING" : (main ? "MAIN_ACTIVE" : "SUB_ACTIVE")),
            activeRanking: ranking,
            cycleDay: day,
            phase: day == 30 ? "COMPLETION_PASS" : "PAID_ACCESS",
            startsOn: "2026-07-01",
            paidAccessEndsOn: "2026-07-29",
            day30ReviewOn: "2026-07-30",
            access: Snapshot.Cycle.Access(
                paidAccessActive: day <= 29,
                completionPassActive: day == 30,
                learningAccessActive: true,
                paidAccessDaysRemaining: max(0, 30 - day)),
            balances: Snapshot.Cycle.Balances(
                refundAvailableDays: refundDays,
                refundLockedDays: includeMatch ? 1 : 0,
                bonusAvailableDays: main ? 34 : 0,
                bonusLockedDays: 0,
                source: "LEDGER_DERIVED_CACHE"),
            attendance: Snapshot.Cycle.Attendance(
                cycleStreakDays: day,
                lastRecognizedDate: "2026-07-18"),
            challenges: Snapshot.Cycle.Challenges(
                completed: completed,
                completedNormal: 1,
                completedRevenge: 1,
                requestCount: 5,
                minimumRequired: 2,
                requestLimit: nil,
                newRequestCutoffDay: 28),
            integrityState: "CLEAR",
            autoRenewEnabled: false)

        let conditions: [Snapshot.Payback.Condition] = noCycle ? [] : [
            .init(
                key: "CYCLE_ATTENDANCE",
                current: day,
                required: 30,
                met: day >= 30),
            .init(
                key: "REFUND_DAY_BALANCE",
                current: refundDays,
                required: 30,
                met: refundDays >= 30),
            .init(
                key: "COMPLETED_SUB_CHALLENGES",
                current: completed,
                required: 2,
                met: completed >= 2),
        ]

        let match: Snapshot.ActiveMatch? = includeMatch ? .init(
            id: "fixture-match",
            status: matchStatus,
            role: matchRole,
            matchType: "REVENGE",
            activeRanking: ranking,
            myPositionBefore: 7,
            opponentPositionBefore: 5,
            stake: .init(
                assetType: main ? "BONUS_ACCESS_DAY" : "REFUND_CHALLENGE_DAY",
                days: main ? 3 : 2),
            startsBy: "2026-07-30T10:20:00.000Z",
            submitsBy: "2026-07-30T11:00:00.000Z",
            integrityState: "CLEAR",
            attempt: attemptStatus.map {
                .init(
                    status: $0,
                    startedAt: "2026-07-30T10:08:00.000Z",
                    endsAt: "2026-07-30T10:38:00.000Z",
                    submittedAt: $0 == "SUBMITTED"
                        ? "2026-07-30T10:32:00.000Z" : nil)
            }) : nil

        return Snapshot(
            readModelVersion: "GOAT_ARENA_V1",
            generatedAt: "2026-07-30T10:00:00.000Z",
            state: noCycle ? "NO_ACTIVE_CYCLE" : "ACTIVE_CYCLE",
            identity: .init(
                displayName: "수학왕",
                schoolName: "경기외국어고등학교",
                displayMode: "nickname"),
            cycle: cycle,
            payback: .init(
                state: noCycle ? "NO_ACTIVE_CYCLE" : (policyPending ? "POLICY_PENDING" : "IN_PROGRESS"),
                canEvaluate: !policyPending && !noCycle,
                eligible: policyPending || noCycle ? nil : false,
                refundStatus: noCycle ? nil : "PENDING",
                conditions: conditions,
                blockers: policyPending
                    ? [.init(code: "POLICY_PENDING", fields: nil)]
                    : (includeMatch ? [.init(code: "ACTIVE_MATCH", fields: nil)] : [])),
            ranking: .init(
                activeRanking: noCycle ? nil : ranking,
                skill: .init(
                    status: skillStatus,
                    mmr: skillStatus == "PLACEMENT_PENDING" ? nil : 1_510,
                    tier: skillStatus == "PLACEMENT_PENDING" ? nil : "DIAMOND",
                    rankPoint: skillStatus == "PLACEMENT_PENDING" ? nil : 42,
                    overallRank: skillStatus == "CONFIRMED" ? 12 : nil,
                    weeklyExamsUntilConfirmed: skillStatus == "PROVISIONAL" ? 2 : 0),
                seat: .init(
                    status: effectiveSeatStatus,
                    arenaPosition: hasSeat ? 7 : nil,
                    mmrAtLastSeed: hasSeat ? 1_490 : nil,
                    seededAt: hasSeat ? "2026-07-27T00:00:00.000Z" : nil,
                    seedWeekKey: hasSeat ? "2026-W31" : nil,
                    protectionUntil: nil,
                    rankShieldUntil: main ? "2026-07-31T00:00:00.000Z" : nil),
                contract: "MMR_AND_ARENA_POSITION_ARE_SEPARATE"),
            season: noCycle ? nil : .init(
                id: "2026-season-1",
                title: "GOAT Arena Season 1",
                status: "ACTIVE",
                currentWeekKey: "2026-W31",
                startsAt: "2026-07-01T00:00:00.000Z",
                endsAt: "2026-08-31T00:00:00.000Z"),
            activeMatch: match,
            capabilities: .init(
                paybackEvaluation: policyPending ? "POLICY_PENDING" : "READY",
                mainArena: main ? "READY" : "POLICY_PENDING",
                challengeCommands: "NOT_AVAILABLE"))
    }

    /// 정산이 끝난 최근 경기 세 건. GET /api/v1/goat-arena/matches 응답 모양 그대로다.
    static func recentMatches() -> [ServerAPI.GoatArenaParticipantMatch] {
        [
            .init(
                id: "fixture-settled-1",
                status: "SETTLED",
                role: "CHALLENGER",
                activeRanking: "SUB",
                matchType: "NORMAL",
                myPositionBefore: 9,
                opponentPositionBefore: 7,
                myPositionAfter: 7,
                opponentPositionAfter: 9,
                stake: .init(assetType: "REFUND_CHALLENGE_DAY", days: 1),
                outcome: "WON",
                timeline: .init(settledAt: "2026-07-29T21:14:00.000Z")),
            .init(
                id: "fixture-settled-2",
                status: "SETTLED",
                role: "DEFENDER",
                activeRanking: "SUB",
                matchType: "REVENGE",
                myPositionBefore: 9,
                opponentPositionBefore: 12,
                myPositionAfter: 9,
                opponentPositionAfter: 12,
                stake: .init(assetType: "REFUND_CHALLENGE_DAY", days: 2),
                outcome: "WON",
                timeline: .init(settledAt: "2026-07-27T20:02:00.000Z")),
            .init(
                id: "fixture-settled-3",
                status: "SETTLED",
                role: "CHALLENGER",
                activeRanking: "MAIN",
                matchType: "NORMAL",
                myPositionBefore: 12,
                opponentPositionBefore: 9,
                myPositionAfter: 12,
                opponentPositionAfter: 9,
                stake: .init(assetType: "BONUS_ACCESS_DAY", days: 3),
                outcome: "LOST",
                timeline: .init(settledAt: "2026-07-24T19:40:00.000Z")),
        ]
    }
}
#endif
