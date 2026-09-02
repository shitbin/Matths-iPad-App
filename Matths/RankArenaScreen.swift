//
//  RankArenaScreen.swift
//  Matths
//
//  랭킹전 리디자인 — "죽은 로그인 게이트"를 없앤 버전.
//
//  종전 RankScreen 은 비로그인(게스트·토큰 만료)에서 문장 한 줄 + 로그인 버튼만
//  남는 막다른 화면이었다. 순위표는 이 앱에서 가장 "채워진 상태가 곧 광고"인
//  화면인데, 정작 처음 온 학생에게는 빈 벽을 보여준 셈이다.
//  (원본 RankScreen 은 이 화면으로 대체된 뒤 삭제됐다 — git 이력에 보존.
//   이 파일이 유일한 라이브 구현이므로 순위표 문구·상태 수정은 여기서만 한다.)
//
//  이 화면의 규칙:
//   · 로그인 상태 — 종전 RankScreen 의 데이터 흐름(getArena → getAccessEconomy →
//     getAccessLeaderboard)과 상태기계를 그대로 유지한다. 표시만 다듬는다.
//   · 비로그인 — 게이트 대신 순위표 미리보기를 보여준다. 먼저 같은 공개 풀
//     API 를 토큰 없이 시도하고(ServerAPI.request 는 토큰이 없으면 Authorization
//     헤더를 아예 붙이지 않는다), 거부·실패하면 번들 예시 데이터로 대체한다.
//     예시든 실데이터든 같은 행 컴포넌트로 그린다 — 미리보기가 곧 실화면이다.
//   · 네이비 히어로는 화면에 하나. 그 위의 강조색은 시안 하나다(CI 규정).
//     생성 아트는 정보 없는 배경으로만 쓰며 티어·순위·상태는 네이티브 UI가 맡는다.
//

import SwiftUI

struct RankArenaScreen: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    // MARK: 상태기계

    /// 게스트 미리보기의 출처. 실데이터를 받았는지, 번들 예시인지 화면이 구분해
    /// 말해야 한다 — 예시를 실순위처럼 보여주는 것이 최악의 버그다.
    private enum GuestPreview {
        /// 서버가 익명 읽기를 허용해 실데이터를 받은 경우 (풀 이름 포함)
        case live(ServerAPI.ArenaBoard, ServerAPI.RankingPool)
        /// 공개 읽기 거부·실패 — 번들 예시로 대체
        case sample
    }

    /// 화면과 순위표 상태를 분리한다. `nil + 시도 여부` 조합은 정상 빈 응답과
    /// 네트워크 실패를 같은 문장으로 만들기 쉽고, 계정 전환 때 옛 순위를 남긴다.
    /// (삭제된 원본 RankScreen 의 설계를 가져오고 `guest` 케이스만 더했다.)
    private enum ScreenState {
        case idle
        case loading
        case guest(GuestPreview)
        case unsupported(ServerAPI.ArenaResponse)
        case loaded(ServerAPI.ArenaResponse, ServerAPI.AccessEconomy)
        case failed(ServerAPI.ArenaResponse?, String)
    }

    private enum BoardState {
        case idle
        case loading
        case unavailable(String)
        case empty
        case loaded(ServerAPI.ArenaBoard)
        case failed(String)
    }

    private enum RailState {
        case completed, current, waiting
    }

    @State private var screenState: ScreenState = .idle
    @State private var boardState: BoardState = .idle
    /// 재시도나 계정 전환 뒤 늦게 끝난 요청은 새 화면에 붙이지 않는다.
    @State private var loadID = UUID()
    @State private var accountSlot = DataScope.slot
    /// 헤더의 규칙 전문 펼침 — 화면 전용 토글, 저장하지 않는다.
    @State private var showRules = false

    // MARK: 파생값

    private var arenaResponse: ServerAPI.ArenaResponse? {
        switch screenState {
        case .unsupported(let arena), .loaded(let arena, _):
            return arena
        case .failed(let arena, _):
            return arena
        default:
            return nil
        }
    }

    private var economy: ServerAPI.AccessEconomy? {
        guard case .loaded(_, let economy) = screenState else { return nil }
        return economy
    }

    private var activePool: ServerAPI.RankingPool? {
        economy?.ranking.activePool
    }

    private var board: ServerAPI.ArenaBoard? {
        guard case .loaded(let board) = boardState else { return nil }
        return board
    }

    private var guestPreview: GuestPreview? {
        guard case .guest(let preview) = screenState else { return nil }
        return preview
    }

    private var isGuest: Bool { guestPreview != nil }

    /// 공개 풀 API는 확정 프로필만 내려주지만, 앱에서도 한 번 더 막는다.
    /// 잘못된 구버전 응답 하나가 배치 중인 학생을 공개 목록에 올리면 안 된다.
    private var rows: [ServerAPI.ArenaRow] {
        guard let board else { return [] }
        var result = board.top.filter { $0.status == "CONFIRMED" }
        if let me = board.me,
           me.status == "CONFIRMED",
           !result.contains(where: { $0.userId == me.userId }) {
            result.append(me)
        }
        return result
    }

    /// 미리보기 행. 실데이터를 받았으면 그것을, 아니면 번들 예시를 쓴다.
    /// 어느 쪽이든 아래 leaderboardTable 의 같은 행 컴포넌트로 흐른다.
    private var previewRows: [ServerAPI.ArenaRow] {
        switch guestPreview {
        case .live(let board, _): return board.top
        case .sample:             return Self.sampleRows
        case nil:                 return []
        }
    }

    private var myPoolRank: Int? {
        guard arenaResponse?.arena.status == "CONFIRMED",
              board?.me?.status == "CONFIRMED" else { return nil }
        return board?.me?.rank
    }

    /// 서버 풀 키는 화면에 노출하지 않고 고정 제품 용어로 바꾼다.
    private var poolTitle: String {
        if let preview = guestPreview {
            if case .live(_, let pool) = preview { return ArenaDisplayTerms.ranking(pool.rawValue) }
            return "Unranked 랭킹"
        }
        return activePool.map { ArenaDisplayTerms.ranking($0.rawValue) } ?? "현재 랭킹"
    }

    private var isCompact: Bool {
        horizontalSizeClass == .compact
    }

    private var isLoading: Bool {
        if case .loading = screenState { return true }
        if case .loading = boardState { return true }
        return false
    }

    // MARK: 본문

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s7) {
            VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                // 비인터랙티브 아이브로우 — 파랑(primary)은 탭 가능한 것에 예약하고
                // 여기는 text3 로 가라앉힌다. 폐기한 구 서비스명을 장식으로 되살리지 않는다.
                if !dynamicTypeSize.isAccessibilitySize {
                    Text("30일 랭킹")
                        .font(.mMicro)
                        .foregroundStyle(Tokens.text3)
                }
                HStack(alignment: .firstTextBaseline) {
                    Text("GOAT Arena")
                        .font(.mTitle)
                        .foregroundStyle(Tokens.ink)
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    if isLoading {
                        ProgressView()
                            .controlSize(.small)
                            .accessibilityLabel("랭킹 불러오는 중")
                    }
                }
                ExamRule()
                // 헤더 설명은 한 줄 요약으로 멈춘다 — 배치·갱신 규칙 전문은
                // 규칙 버튼 뒤로 접어, 첫 화면에서 규정집부터 읽게 하지 않는다.
                if !dynamicTypeSize.isAccessibilitySize {
                    Text("최근 30일 학습 기록으로 겨루는 수학 자리 경쟁")
                        .font(.mCallout)
                        .foregroundStyle(Tokens.text3)
                        .fixedSize(horizontal: false, vertical: true)
                    Button {
                        showRules.toggle()
                    } label: {
                        HStack(spacing: Tokens.Space.s1) {
                            Text("GOAT Arena 규칙")
                            Image(systemName: showRules ? "chevron.up" : "chevron.down")
                                .font(.mMicro)
                        }
                        .font(.mCaption)
                        .foregroundStyle(Tokens.primary)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(showRules ? "GOAT Arena 규칙 접기" : "GOAT Arena 규칙 펼치기")
                }
                if showRules && !dynamicTypeSize.isAccessibilitySize {
                    // MMR 첫 등장에서 뜻을 함께 말한다 — 게임 은어를 모르는 학생·학부모용(0371·1410).
                    Text("입단 배치고사 30문항, 100분. 매주 일요일 A·B·C형 모의고사의 대표 성적으로 실력 점수(MMR)가 갱신됩니다.")
                        .font(.mCaption)
                        .foregroundStyle(Tokens.text3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .entrance(0)

            arenaHero
                .entrance(1)

            leaderboardSection
                .entrance(2)

            if isGuest {
                loginBanner
                    .entrance(3)
            }

            Text("공식 시험 기록을 기준으로 갱신되는 실력 점수(MMR)와 현재 풀 순위입니다.")
                .font(.mCallout)
                .foregroundStyle(Tokens.text2)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .task {
            #if DEBUG
            // 성공·게스트·빈 상태를 실계정 조작 없이 시각 검증한다.
            // 예: `-route rank -rankArenaFixture guest -harness 320x1000-compact`
            if applyDebugFixtureIfPresent() { return }
            #endif
            guard case .idle = screenState else { return }
            await loadRanking()
        }
        .onReceive(NotificationCenter.default.publisher(for: DataScope.didSwitchNotification)) {
            guard let newSlot = $0.object as? String, newSlot != accountSlot else { return }
            loadID = UUID()
            accountSlot = newSlot
            screenState = .idle
            boardState = .idle
            Task { await loadRanking() }
        }
        .onDisappear { loadID = UUID() }
    }

    // MARK: 네이비 히어로 — 화면에 하나뿐인 브랜드 면

    private var onNavy: Color { Tokens.onNavy }

    private var arenaHero: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s5) {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                        arenaHeroTitle
                        arenaStatus
                    }
                } else {
                    HStack(alignment: .top, spacing: Tokens.Space.s4) {
                        arenaHeroTitle
                        Spacer(minLength: Tokens.Space.s3)
                        arenaStatus
                    }
                }
            }

            arenaHeroContent
            arenaRail
        }
        // 이미지 위 정보 카드만 접근성 1단계에서 상한을 둔다. 화면 제목·규칙·
        // 순위표 본문은 시스템 최대 크기를 그대로 따르며, 카드의 동일 정보는
        // VoiceOver 결합 라벨로도 읽힌다.
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .padding(Tokens.Space.s6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ArenaArtworkBackground(
                imageName: "ArenaHeroBackdrop",
                focalAlignment: .trailing,
                darkening: 0.14)
        }
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.xl))
        .overlay {
            RoundedRectangle(cornerRadius: Tokens.Radius.xl)
                .strokeBorder(Tokens.brandCyan.opacity(0.26), lineWidth: 1)
        }
    }

    private var arenaHeroTitle: some View {
        VStack(alignment: .leading, spacing: 3) {
            if !dynamicTypeSize.isAccessibilitySize {
                Text(isGuest ? "ARENA PREVIEW" : "MY ARENA")
                    .font(.mMicro)
                    .foregroundStyle(onNavy.opacity(0.68))
            }
            // 게스트에게는 개인화된 실제 데이터처럼 읽히지 않게, 배치 뒤에
            // 열릴 화면의 미리보기임을 제목 자체에서 먼저 밝힌다.
            (Text(isGuest ? "배치 후 열리는 " : "30일의 기록, ")
                .foregroundStyle(onNavy)
             + Text(isGuest ? "나의 자리" : "단 하나의 자리")
                .foregroundStyle(Tokens.brandCyan))
                .font(.mHeading)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if let identity = arenaResponse?.identity {
                Text("\(identity.displayName), \(identity.schoolName), \(identity.displayMode) 공개")
                    .font(.mCaption)
                    .foregroundStyle(onNavy.opacity(0.68))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// 게스트의 "미리보기" 상태는 순위표 헤딩과 같은 칩 하나로 그린다 —
    /// 같은 상태가 한 화면에서 두 외형(시안 점 vs 파랑 칩)으로 갈리지 않게(0407).
    @ViewBuilder private var arenaStatus: some View {
        if isGuest {
            previewChip(onDark: true)
                .accessibilityLabel("현재 상태 미리보기")
        } else {
            HStack(spacing: Tokens.Space.s2) {
                Circle()
                    .fill(arenaStatusColor)
                    .frame(width: 7, height: 7)
                Text(arenaStatusLabel)
                    .font(.mMicro)
                    .foregroundStyle(onNavy)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("현재 상태 \(arenaStatusLabel)")
        }
    }

    // 게스트 분기는 arenaStatus 가 previewChip 으로 직접 처리한다 — 여기서
    // "미리보기" 문자열을 또 만들면 같은 상태의 표기가 다시 갈라진다.
    private var arenaStatusLabel: String {
        if case .loading = screenState { return "확인 중" }
        guard let arena = arenaResponse?.arena else { return "연결 확인" }
        if arena.locked { return "배치 전" }
        return arena.isProvisional ? "티어 확정 전" : "확정"
    }

    /// 네이비 위 상태색 — 시안(활성·확정) 아니면 온-네이비 농도 차이뿐이다.
    /// 앰버·마젠타 등 다른 강조색은 네이비 면에서 금지(디자인 시스템 규정).
    private var arenaStatusColor: Color {
        guard let arena = arenaResponse?.arena else { return onNavy.opacity(0.4) }
        if arena.locked { return onNavy.opacity(0.4) }
        return arena.isProvisional ? onNavy.opacity(0.8) : Tokens.brandCyan
    }

    @ViewBuilder private var arenaHeroContent: some View {
        if isGuest {
            // 게스트 — 죽은 게이트 대신 여정의 예고편. 아래 미리보기로 시선을 넘긴다.
            Text("입단 배치고사 30문항이 첫 기록입니다. 로그인 전에도 아래에서 공개 순위표를 미리 볼 수 있습니다.")
                .font(.mCallout)
                .foregroundStyle(onNavy.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)
            // 행동 유도문 바로 아래에 행동 수단(0041·1437) — 로그인 버튼이
            // 예시 12행 아래 배너에만 있으면 첫 화면의 게스트는 경로를 못 찾는다.
            // 하단 loginBanner 는 그대로 유지한다(중복 무해).
            heroLoginButton
        } else if let arena = arenaResponse?.arena {
            if arena.locked {
                heroMessage(
                    title: "아직 MMR이 발급되지 않았습니다",
                    detail: "배치고사 전 또는 진행 중인 상태입니다. 0 MMR이 아니라 아직 순위 자격이 열리지 않은 상태입니다.")
                goatArenaLink(title: "웹 GOAT Arena에서 배치고사 확인", onDark: true)
            } else if let mmr = arena.mmr {
                // 지표 묶음은 한 단계 밝은 네이비 판 위에 올린다 — 네이비 안 층위는
                // 그림자가 아니라 elevation 색으로 만든다.
                VStack(alignment: .leading, spacing: Tokens.Space.s4) {
                    arenaMetrics(arena: arena, mmr: mmr)

                    ProgressView(
                        value: Double(min(max(arena.rankPoint, 0), 99)),
                        total: 99)
                        .tint(Tokens.brandCyan)
                        .accessibilityLabel("티어 진행도")
                        .accessibilityValue("RP \(arena.rankPoint)")

                    HStack(spacing: Tokens.Space.s4) {
                        // RP 첫 등장에서 뜻을 1회 설명한다(1410)
                        Text("RP \(arena.rankPoint), 티어 승급 점수")
                            .font(.mCaption)
                            .foregroundStyle(onNavy.opacity(0.7))
                        if let pool = activePool {
                            Text("현재 모드 \(ArenaDisplayTerms.mode(pool.rawValue))")
                                .font(.mCaption)
                                .foregroundStyle(onNavy.opacity(0.7))
                        }
                    }
                }
                .padding(Tokens.Space.s5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Tokens.navyElevated,
                            in: RoundedRectangle(cornerRadius: Tokens.Radius.lg))

                Text(arenaNote(arena))
                    .font(.mCaption)
                    .foregroundStyle(onNavy.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                heroMessage(
                    title: "MMR 발급을 확인하는 중입니다",
                    detail: "배치 결과의 티어와 MMR이 함께 도착하면 이 자리에 표시됩니다.")
            }
        } else if case .loading = screenState {
            HStack(spacing: Tokens.Space.s3) {
                ProgressView().tint(onNavy)
                Text("서버에서 내 배치·MMR 상태를 확인하고 있습니다.")
                    .font(.mCallout)
                    .foregroundStyle(onNavy.opacity(0.72))
            }
        } else if case .failed(_, let message) = screenState {
            heroMessage(title: "랭킹 상태를 불러오지 못했습니다", detail: message)
            retryButton(onDark: true)
        }
    }

    @ViewBuilder private func arenaMetrics(arena: ServerAPI.Arena, mmr: Int) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: Tokens.Space.s8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("현재 티어")
                        .font(.mMicro)
                        .foregroundStyle(onNavy.opacity(0.58))
                    TierChip(tierCode: arena.tier, tierLabel: arena.tierLabel,
                             division: arena.division, onDark: true, darkInk: onNavy)
                }
                .accessibilityElement(children: .combine)
                // "SKILL MMR" 은어 대신 뜻이 앞서는 레이블(1410)
                arenaMetric(label: "실력 점수 MMR", value: formatted(mmr))
                arenaMetric(
                    label: activePool.map { ArenaDisplayTerms.ranking($0.rawValue) } ?? "현재 순위",
                    value: myPoolRank.map { "\($0)위" } ?? "집계 전")
            }
            .fixedSize(horizontal: true, vertical: false)

            VStack(alignment: .leading, spacing: Tokens.Space.s4) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("현재 티어")
                        .font(.mMicro)
                        .foregroundStyle(onNavy.opacity(0.58))
                    TierChip(tierCode: arena.tier, tierLabel: arena.tierLabel,
                             division: arena.division, onDark: true, darkInk: onNavy)
                }
                .accessibilityElement(children: .combine)
                HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s8) {
                    arenaMetric(label: "실력 점수 MMR", value: formatted(mmr))
                    arenaMetric(
                        label: activePool.map { ArenaDisplayTerms.ranking($0.rawValue) } ?? "현재 순위",
                        value: myPoolRank.map { "\($0)위" } ?? "집계 전")
                }
            }
        }
    }

    private func arenaMetric(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.mMicro)
                .foregroundStyle(onNavy.opacity(0.58))
            Text(value)
                .font(.mStat)
                .foregroundStyle(onNavy)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private func arenaNote(_ arena: ServerAPI.Arena) -> String {
        if arena.isProvisional {
            let left = arena.weeklyExamsUntilConfirmed ?? 0
            return left > 0
                ? "배치 단계입니다. 주간 공식 시험 \(left)회를 더 완료하면 티어가 확정됩니다."
                : "배치 단계입니다. 다음 주간 결과 확정을 기다리고 있습니다."
        }
        if let pool = activePool {
            return "\(ArenaDisplayTerms.ranking(pool.rawValue))은 아래에서 확인할 수 있습니다."
        }
        return "티어는 확정됐지만 현재 활성 경쟁 풀은 아직 지정되지 않았습니다."
    }

    // MARK: 여정 레일 — 배치 → 확정 → 공개 순위

    private var arenaRail: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Tokens.Space.s5) {
                railCell(title: "입단 배치", detail: placementDetail, state: placementRailState)
                railDivider(vertical: true)
                railCell(title: "티어 상태", detail: confirmationDetail, state: confirmationRailState)
                railDivider(vertical: true)
                railCell(title: "공개 순위표", detail: poolDetail, state: poolRailState)
            }
            .fixedSize(horizontal: true, vertical: false)

            VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                railCell(title: "입단 배치", detail: placementDetail, state: placementRailState)
                railDivider(vertical: false)
                railCell(title: "티어 상태", detail: confirmationDetail, state: confirmationRailState)
                railDivider(vertical: false)
                railCell(title: "공개 순위표", detail: poolDetail, state: poolRailState)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.top, Tokens.Space.s4)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(onNavy.opacity(0.13))
                .frame(height: 1)
        }
    }

    private func railCell(title: String, detail: String, state: RailState) -> some View {
        HStack(spacing: Tokens.Space.s2) {
            Circle()
                .fill(railColor(state))
                .frame(width: 7, height: 7)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.mMicro)
                    .foregroundStyle(onNavy.opacity(0.55))
                Text(detail)
                    .font(.mCaption)
                    .foregroundStyle(onNavy)
            }
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private func railDivider(vertical: Bool) -> some View {
        if vertical {
            Rectangle()
                .fill(onNavy.opacity(0.13))
                .frame(width: 1, height: 34)
        } else {
            Rectangle()
                .fill(onNavy.opacity(0.13))
                .frame(maxWidth: .infinity)
                .frame(height: 1)
        }
    }

    /// 네이비 위 레일 색 — 종전의 앰버(진행 중)를 버렸다. 시안은 "지금 주목할
    /// 단계" 하나에만 쓰고, 완료는 온-네이비 실색, 대기는 흐린 농도로 구분한다.
    /// 색만으로 구분하지 않는다 — 각 셀의 detail 문장이 상태를 함께 말한다.
    private func railColor(_ state: RailState) -> Color {
        switch state {
        case .completed: return onNavy
        case .current:   return Tokens.brandCyan
        case .waiting:   return onNavy.opacity(0.35)
        }
    }

    private var placementDetail: String {
        if isGuest { return "로그인 후 응시" }
        guard let arena = arenaResponse?.arena else { return "확인 중" }
        return arena.locked ? "응시 전·진행 중" : "30문항 완료"
    }

    private var placementRailState: RailState {
        if isGuest { return .waiting }
        guard let arena = arenaResponse?.arena else { return .waiting }
        return arena.locked ? .current : .completed
    }

    private var confirmationDetail: String {
        if isGuest { return "배치 후 시작" }
        guard let arena = arenaResponse?.arena else { return "확인 중" }
        if arena.locked { return "배치 후 시작" }
        if arena.isProvisional {
            let left = arena.weeklyExamsUntilConfirmed ?? 0
            return left > 0 ? "공식 시험 \(left)회 남음" : "결과 확인 중"
        }
        return "확정"
    }

    private var confirmationRailState: RailState {
        if isGuest { return .waiting }
        guard let arena = arenaResponse?.arena else { return .waiting }
        if arena.locked { return .waiting }
        return arena.isProvisional ? .current : .completed
    }

    private var poolDetail: String {
        if isGuest { return "아래 미리보기" }
        if let pool = activePool {
            let mode = ArenaDisplayTerms.mode(pool.rawValue)
            guard let arena = arenaResponse?.arena else { return mode }
            if arena.locked { return "\(mode), 배치 후" }
            if arena.isProvisional { return "\(mode), 확정 후 공개" }
            return mode
        }
        switch screenState {
        case .unsupported: return "온라인 확인 필요"
        case .failed:      return "확인 실패"
        case .loading:     return "확인 중"
        default:           return "지정 전"
        }
    }

    private var poolRailState: RailState {
        if isGuest { return .current }
        if activePool != nil {
            return arenaResponse?.arena.status == "CONFIRMED" ? .completed : .current
        }
        switch screenState {
        case .loaded, .unsupported, .failed: return .current
        default: return .waiting
        }
    }

    private func heroMessage(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
            Text(title)
                .font(.mBodyB)
                .foregroundStyle(onNavy)
            Text(detail)
                .font(.mCallout)
                .foregroundStyle(onNavy.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: 순위표

    private var leaderboardSection: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s4) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .lastTextBaseline, spacing: Tokens.Space.s4) {
                    leaderboardHeading
                    Spacer()
                    if let participantLabel {
                        Text(participantLabel)
                            .font(.mCaption)
                            .foregroundStyle(Tokens.text3)
                    }
                }
                VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                    leaderboardHeading
                    if let participantLabel {
                        Text(participantLabel)
                            .font(.mCaption)
                            .foregroundStyle(Tokens.text3)
                    }
                }
            }

            if case .sample = guestPreview {
                Text("실제 순위가 아닌 예시 화면입니다. 로그인하면 실시간 순위로 바뀝니다.")
                    .font(.mCaption)
                    .foregroundStyle(Tokens.text3)
                    .fixedSize(horizontal: false, vertical: true)
            } else if activePool != nil {
                Text("공개 순위에는 티어가 확정된 현재 풀 참가자만 포함됩니다.")
                    .font(.mCaption)
                    .foregroundStyle(Tokens.text3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Rectangle()
                .fill(Tokens.lineStrong)
                .frame(height: 1)

            leaderboardContent
        }
    }

    private var leaderboardHeading: some View {
        HStack(spacing: Tokens.Space.s3) {
            VStack(alignment: .leading, spacing: 2) {
                // 영문 장식 대신 기능을 바로 설명하고 파랑은 탭 가능한 것에 예약한다.
                Text("공개 순위표")
                    .font(.mMicro)
                    .foregroundStyle(Tokens.text3)
                Text(poolTitle)
                    .font(.mHeading)
                    .foregroundStyle(Tokens.ink)
                    .accessibilityAddTraits(.isHeader)
            }
            if isGuest {
                previewChip(onDark: false)
            }
        }
    }

    /// 게스트 상태의 "미리보기" 칩 — 아이콘+글자, 색만으로 말하지 않는다.
    /// 네이비 히어로와 순위표 헤딩이 이 칩 하나를 공유한다(같은 상태 = 같은 외형).
    /// 네이비 위에서는 시안 잉크 + elevation 면 — 네이비 위 강조는 시안 하나 규칙.
    private func previewChip(onDark: Bool) -> some View {
        Label("미리보기", systemImage: "eye")
            .font(.mMicro)
            .foregroundStyle(onDark ? Tokens.brandCyan : Tokens.primary)
            .padding(.horizontal, Tokens.Space.s2 + 2)
            .padding(.vertical, 4)
            .background(onDark ? Tokens.navyElevated : Tokens.primarySoft,
                        in: RoundedRectangle(cornerRadius: Tokens.Radius.sm))
            .accessibilityLabel("미리보기 순위표")
    }

    private var participantLabel: String? {
        if let preview = guestPreview {
            if case .live(let board, _) = preview { return "확정 참가자 \(board.total)명" }
            return nil   // 예시 화면에 인원수를 붙이면 실데이터처럼 읽힌다
        }
        switch boardState {
        case .loaded(let board): return "확정 참가자 \(board.total)명"
        case .empty:             return "확정 참가자 0명"
        default:                 return nil
        }
    }

    /// 예시 행에만 붙는 학교명. 실데이터(라이브 미리보기 포함)에는 없다.
    /// "OO고" 같은 복자 표기는 개인정보 마스킹으로 읽힐 수 있어, 실존할 수 없는
    /// 이름 "예시 고등학교" 로 샘플임을 표기 자체가 말하게 한다.
    private var sampleSchoolLabel: String? {
        if case .guest(.sample) = screenState { return "예시 고등학교" }
        return nil
    }

    @ViewBuilder private var leaderboardContent: some View {
        if isGuest {
            // 게스트 — 실데이터든 예시든 같은 표로 그린다. 예시 행에는 샘플
            // 학교명("예시 고등학교")이 붙어 채워진 상태의 생김새를 그대로 보여준다.
            // 점선 프레임이 데이터 영역 전체를 감싼다 — 어느 행까지가 미리보기인지
            // 칩 하나에 맡기지 않고 경계 자체가 말하게 한다.
            leaderboardTable(previewRows, school: { _ in sampleSchoolLabel })
                .padding(Tokens.Space.s4)
                .overlay(
                    RoundedRectangle(cornerRadius: Tokens.Radius.lg)
                        .strokeBorder(Tokens.lineStrong,
                                      style: StrokeStyle(lineWidth: 1, dash: [4, 4])))
        } else {
            switch boardState {
            case .idle, .loading:
                HStack(spacing: Tokens.Space.s3) {
                    ProgressView().controlSize(.small)
                    Text("활성 풀 순위표를 불러오는 중입니다.")
                        .font(.mCallout)
                        .foregroundStyle(Tokens.text3)
                }
                .padding(.vertical, Tokens.Space.s5)

            case .unavailable(let message):
                stateMessage(message)
                if arenaResponse?.arena.locked == true
                    || arenaResponse?.arena.isProvisional == true {
                    goatArenaLink(title: "웹 GOAT Arena에서 확인", onDark: false)
                } else if case .unsupported = screenState {
                    retryButton(onDark: false)
                }

            case .empty:
                emptyBoardGhost

            case .failed(let message):
                stateMessage(message)
                retryButton(onDark: false)

            case .loaded:
                leaderboardTable(rows, school: { _ in nil })
            }
        }
    }

    /// 빈 순위표 — "기록 없음" 죽은 문장 대신 채워진 상태의 유령 미리보기.
    /// 예시 3행을 흐리게 깔고, 할 일 하나(다시 확인)와 출구 하나(웹)를 준다.
    private var emptyBoardGhost: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s4) {
            leaderboardTable(Array(Self.sampleRows.prefix(3)), school: { _ in "예시 고등학교" })
                .opacity(0.35)
                .accessibilityHidden(true)
                .allowsHitTesting(false)

            Text("현재 \(ArenaDisplayTerms.mode(activePool?.rawValue))에는 공개할 확정 참가자가 아직 없습니다. 첫 자리가 비어 있습니다.")
                .font(.mCallout)
                .foregroundStyle(Tokens.text3)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: Tokens.Space.s3) {
                retryButton(onDark: false)
                goatArenaLink(title: "웹 GOAT Arena에서 확인", onDark: false)
            }
        }
    }

    private func stateMessage(_ message: String) -> some View {
        Text(message)
            .font(.mCallout)
            .foregroundStyle(Tokens.text3)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, Tokens.Space.s4)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 실데이터와 미리보기가 공유하는 단 하나의 표.
    /// `school` 은 예시 행에만 샘플 학교명을 붙이기 위한 주입 지점이다 —
    /// 서버 ArenaRow 에는 학교 필드가 없어 타입을 늘리는 대신 여기서 붙인다.
    private func leaderboardTable(
        _ tableRows: [ServerAPI.ArenaRow],
        school: @escaping (ServerAPI.ArenaRow) -> String?
    ) -> some View {
        VStack(spacing: 0) {
            tableHeader
            Rectangle()
                .fill(Tokens.lineStrong)
                .frame(height: 1)

            ForEach(Array(tableRows.enumerated()), id: \.element.id) { index, row in
                if isDetachedMe(row) {
                    HStack(spacing: Tokens.Space.s3) {
                        Text("상위 목록 밖 내 순위")
                            .font(.mMicro)
                            .foregroundStyle(Tokens.text3)
                        Rectangle().fill(Tokens.line).frame(height: 1)
                    }
                    .padding(.top, Tokens.Space.s4)
                } else if index > 0 {
                    DottedRule()
                }
                tableRow(row, school: school(row))
            }
        }
    }

    @ViewBuilder private var tableHeader: some View {
        if isCompact {
            HStack(spacing: Tokens.Space.s3) {
                Text("순위").frame(width: 48, alignment: .trailing)
                Text("학생과 티어")
                Spacer()
                Text("MMR")
            }
            .font(.mMicro)
            .foregroundStyle(Tokens.text3)
            .padding(.bottom, Tokens.Space.s2)
            .accessibilityHidden(true)
        } else {
            HStack(spacing: Tokens.Space.s4) {
                Text("순위").frame(width: 44, alignment: .trailing)
                Text("학생")
                Spacer()
                Text("MMR").frame(width: 76, alignment: .trailing)
                Text("티어").frame(width: 124, alignment: .trailing)
            }
            .font(.mMicro)
            .foregroundStyle(Tokens.text3)
            .padding(.bottom, Tokens.Space.s2)
            .accessibilityHidden(true)
        }
    }

    @ViewBuilder private func tableRow(_ row: ServerAPI.ArenaRow, school: String?) -> some View {
        if isCompact {
            HStack(spacing: Tokens.Space.s3) {
                rankText(row)
                    .frame(width: 48, alignment: .trailing)
                VStack(alignment: .leading, spacing: 3) {
                    nameText(row, school: school)
                    TierChip(tierCode: row.tier, tierLabel: row.tierLabel,
                             division: row.division, onDark: false)
                }
                Spacer(minLength: Tokens.Space.s2)
                Text(formatted(row.mmr))
                    .font(.mStat)
                    .foregroundStyle(Tokens.ink)
            }
            .padding(.vertical, Tokens.Space.s4)
            .background(row.isMe == true ? Tokens.primarySoft : Color.clear)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(rowAccessibility(row))
        } else {
            HStack(spacing: Tokens.Space.s4) {
                rankText(row)
                    .frame(width: 44, alignment: .trailing)
                nameText(row, school: school)
                Spacer(minLength: Tokens.Space.s4)
                Text(formatted(row.mmr))
                    .font(.mStat)
                    .foregroundStyle(Tokens.ink)
                    .frame(width: 76, alignment: .trailing)
                TierChip(tierCode: row.tier, tierLabel: row.tierLabel,
                         division: row.division, onDark: false)
                    .frame(width: 124, alignment: .trailing)
            }
            .padding(.vertical, Tokens.Space.s4)
            .background(row.isMe == true ? Tokens.primarySoft : Color.clear)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(rowAccessibility(row))
        }
    }

    /// 순위 숫자. `Text("\(row.rank)")` 는 LocalizedStringKey 보간이라 Int 에
    /// 천단위 구분을 붙인다 — "1,842" 가 38pt 칸에서 "1,84 / 2" 로 접혀 내 순위
    /// 줄만 두 줄이 됐다(iPhone 세로에서 실제로 재현됨). 표시 문자열은 화면의
    /// 다른 숫자와 같은 formatted() 로 고정하고, 접히지 않게 한 줄로 못 박는다.
    private func rankText(_ row: ServerAPI.ArenaRow) -> some View {
        Text(formatted(row.rank))
            .font(.mNumeric)
            .fontWeight(row.rank <= 3 ? .bold : .regular)
            .foregroundStyle(row.rank <= 3 ? Tokens.ink : Tokens.text2)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.6)
    }

    private func nameText(_ row: ServerAPI.ArenaRow, school: String?) -> some View {
        HStack(spacing: Tokens.Space.s2) {
            leaderboardAvatar(row)
            VStack(alignment: .leading, spacing: 2) {
                Text(row.name)
                    .font(row.isMe == true ? .mBodyB : .mBody)
                    .foregroundStyle(Tokens.ink)
                    .lineLimit(1)
                if let level = row.arenaActivityLevel?.level {
                    Text("Arena Lv.\(level)")
                        .font(.mMicro)
                        .foregroundStyle(Tokens.text3)
                }
            }
            if let school {
                Text(school)
                    .font(.mMicro)
                    .foregroundStyle(Tokens.text3)
            }
            if row.isMe == true {
                Text("나")
                    .font(.mMicro)
                    .foregroundStyle(Tokens.danger)
            }
        }
    }

    private func leaderboardAvatar(_ row: ServerAPI.ArenaRow) -> some View {
        let url = row.profileAvatar?.imageSrc.flatMap {
            URL(string: $0, relativeTo: ServerAPI.baseURL)?.absoluteURL
        }
        return ZStack {
            Circle().fill(Tokens.primarySoft)
            if let url {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        Text(String(row.name.prefix(1))).font(.mMicro).fontWeight(.bold)
                    }
                }
            } else {
                Text(String(row.name.prefix(1))).font(.mMicro).fontWeight(.bold)
            }
        }
        .foregroundStyle(Tokens.primary)
        .frame(width: 30, height: 30)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }

    private func tierText(_ row: ServerAPI.ArenaRow) -> String {
        let label = row.tierLabel ?? row.tier ?? "미등재"
        guard let division = row.division else { return label }
        let roman = ["", "I", "II", "III", "IV"][min(max(division, 1), 4)]
        return "\(label) \(roman)"
    }

    private func isDetachedMe(_ row: ServerAPI.ArenaRow) -> Bool {
        guard row.isMe == true, let board else { return false }
        return !board.top.contains(where: { $0.userId == row.userId })
    }

    private func rowAccessibility(_ row: ServerAPI.ArenaRow) -> String {
        "\(row.rank)위, \(row.name)\(row.isMe == true ? ", 나" : ""), \(formatted(row.mmr)) MMR, \(tierText(row)), 확정"
    }

    // MARK: 로그인 배너 — 게이트의 대체물

    /// 미리보기 아래 한 줄 배너. 종전 게이트의 로그인 트리거(store.signOut —
    /// 게스트 슬롯을 비우고 인증 화면으로 돌려보낸다)를 그대로 보존한다.
    private var loginBanner: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Tokens.Space.s4) {
                loginBannerLabel
                Spacer(minLength: Tokens.Space.s3)
                loginButton
            }
            VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                loginBannerLabel
                loginButton
            }
        }
        .card(padding: Tokens.Space.s5)
    }

    private var loginBannerLabel: some View {
        HStack(spacing: Tokens.Space.s2) {
            Image(systemName: "person.crop.circle.badge.checkmark")
                .font(.mBody)
                .foregroundStyle(Tokens.primary)
                .accessibilityHidden(true)
            Text("로그인하면 내 순위가 여기 표시됩니다")
                .font(.mCallout)
                .foregroundStyle(Tokens.text1)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var loginButton: some View {
        Button("로그인하기") {
            store.signOut()
        }
        .buttonStyle(SecondaryButtonStyle())
    }

    /// 히어로 게스트 분기의 로그인 버튼 — 하단 loginBanner 와 같은 트리거.
    /// 감사 제안은 SecondaryButtonStyle 이었지만 그 스타일은 적응형 surface
    /// 면이라 고정 네이비 위에서 다크 모드에 묻힌다 — 이 화면의 온-네이비 면
    /// 버튼 문법(retryButton onDark 와 동일)을 따른다.
    private var heroLoginButton: some View {
        Button {
            store.signOut()   // 게스트 슬롯을 비우고 인증 화면으로 — loginBanner 와 동일 경로
        } label: {
            // CTA 는 절차(배치고사 응시)가 아니라 결과를 말한다 —
            // 로그인해서 얻는 것이 문구 안에 보여야 누른다.
            Text("로그인하고 내 예상 티어 확인")
                .font(.mBodyB)
                .foregroundStyle(Tokens.brandNavy)
                .padding(.horizontal, Tokens.Space.s5)
                .frame(minHeight: 44)
                .background(onNavy, in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: 상태 동작

    private func retryButton(onDark: Bool) -> some View {
        Button {
            Task { await loadRanking() }
        } label: {
            Text("다시 시도")
                .font(.mBodyB)
                .foregroundStyle(onDark ? Tokens.brandNavy : Tokens.text1)
                .padding(.horizontal, Tokens.Space.s5)
                .frame(minHeight: 44)
                .background(
                    onDark ? onNavy : Tokens.surface,
                    in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: Tokens.Radius.md)
                        .strokeBorder(onDark ? Color.clear : Tokens.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func goatArenaLink(title: String, onDark: Bool) -> some View {
        Button {
            ArenaWebPresenter.open(.home)
        } label: {
            Text(title)
                .font(.mBodyB)
                .foregroundStyle(onDark ? Tokens.brandNavy : Tokens.primary)
                .padding(.horizontal, Tokens.Space.s5)
                .frame(minHeight: 44)
                .background(
                    onDark ? onNavy : Tokens.surface,
                    in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: Tokens.Radius.md)
                        .strokeBorder(onDark ? Color.clear : Tokens.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityHint("앱 안에서 로그인 상태를 유지한 채 웹 GOAT Arena를 엽니다")
    }

    private func formatted(_ value: Int) -> String {
        value.formatted(.number.grouping(.automatic))
    }

    // MARK: 데이터 적재

    @MainActor
    private func loadRanking() async {
        let ownerSlot = accountSlot
        let requestID = UUID()
        loadID = requestID
        // 이전 계정의 이름·순위를 즉시 비운다. 늦은 응답도 requestID로 폐기한다.
        screenState = .loading
        boardState = .idle

        guard ServerAPI.hasToken else {
            // 게이트 대신 미리보기 — 여기서 화면이 끝나지 않는 것이 이 리디자인의 핵심.
            await loadGuestPreview(requestID: requestID, accountSlot: ownerSlot)
            return
        }

        let arena: ServerAPI.ArenaResponse
        do {
            arena = try await ServerAPI.getArena()
        } catch {
            guard ownsLoad(requestID, slot: ownerSlot) else { return }
            if !ServerAPI.hasToken {
                // 요청 중 토큰이 만료·폐기됐다(401 이면 ServerAPI 가 지운다).
                // 로그인 문장으로 멈추지 않고 게스트 미리보기로 이어간다.
                await loadGuestPreview(requestID: requestID, accountSlot: ownerSlot)
            } else {
                let message = failureMessage(error)
                screenState = .failed(nil, message)
                boardState = .failed(message)
            }
            return
        }
        guard ownsLoad(requestID, slot: ownerSlot) else { return }

        let economy: ServerAPI.AccessEconomy
        do {
            economy = try await ServerAPI.getAccessEconomy()
        } catch {
            guard ownsLoad(requestID, slot: ownerSlot) else { return }
            if !ServerAPI.hasToken {
                await loadGuestPreview(requestID: requestID, accountSlot: ownerSlot)
            } else if (error as? ServerAPIError)?.statusCode == 404 {
                screenState = .unsupported(arena)
                boardState = .unavailable(
                    "현재 풀 순위를 지금 불러올 수 없습니다. 웹 GOAT Arena에서 확인해 주세요.")
            } else {
                let message = failureMessage(error)
                screenState = .failed(arena, message)
                boardState = .failed(message)
            }
            return
        }
        guard ownsLoad(requestID, slot: ownerSlot) else { return }

        screenState = .loaded(arena, economy)

        guard let pool = economy.ranking.activePool else {
            boardState = .unavailable(
                "현재 활성 Arena 모드가 없습니다. 패키지가 시작되면 Unranked 또는 Ranked 순위가 이곳에 열립니다.")
            return
        }
        guard !arena.arena.locked else {
            boardState = .unavailable(
                "배치고사를 완료하면 \(ArenaDisplayTerms.ranking(pool.rawValue)) 참가 자격을 확인할 수 있습니다.")
            return
        }
        guard arena.arena.status == "CONFIRMED" else {
            let left = arena.arena.weeklyExamsUntilConfirmed ?? 0
            boardState = .unavailable(
                left > 0
                    ? "티어 확정 전에는 공개 순위에 올라가지 않습니다. 주간 공식 시험 \(left)회를 더 완료해 주세요."
                    : "티어 확정 처리가 끝나면 \(ArenaDisplayTerms.ranking(pool.rawValue))이 열립니다.")
            return
        }

        boardState = .loading
        do {
            let response = try await ServerAPI.getAccessLeaderboard(ranking: pool)
            guard ownsLoad(requestID, slot: ownerSlot) else { return }
            let top = response.top.filter { $0.status == "CONFIRMED" }
            let me = response.me?.status == "CONFIRMED" ? response.me : nil
            if response.total == 0 {
                boardState = .empty
            } else if top.isEmpty {
                boardState = .failed("순위표 응답을 확인할 수 없습니다. 잠시 후 다시 시도해 주세요.")
            } else {
                boardState = .loaded(
                    ServerAPI.ArenaBoard(total: response.total, top: top, me: me))
            }
        } catch {
            guard ownsLoad(requestID, slot: ownerSlot) else { return }
            if !ServerAPI.hasToken {
                await loadGuestPreview(requestID: requestID, accountSlot: ownerSlot)
            } else if (error as? ServerAPIError)?.statusCode == 404 {
                boardState = .failed(
                    "현재 경쟁 풀 순위표를 열 수 없습니다. 잠시 후 다시 확인해 주세요.")
            } else {
                boardState = .failed(failureMessage(error))
            }
        }
    }

    /// 게스트 미리보기 적재.
    ///
    /// 1) 같은 공개 풀 API 를 토큰 없이 시도한다 — ServerAPI.request 는 토큰이
    ///    없으면 Authorization 헤더를 붙이지 않으므로 익명 GET 이 그대로 나간다.
    ///    서버가 익명 읽기를 허용하면 실데이터 미리보기가 된다.
    ///    게스트는 /access 를 못 불러 활성 풀을 모르므로 SUB → MAIN 순서로 짚는다.
    /// 2) 거부(401 등)·실패·빈 응답이면 번들 예시 데이터로 조용히 대체한다.
    ///    실패 문장을 게스트에게 보여주지 않는다 — 미리보기는 항상 채워져 있다.
    @MainActor
    private func loadGuestPreview(requestID: UUID, accountSlot ownerSlot: String) async {
        for pool in [ServerAPI.RankingPool.sub, .main] {
            if let response = try? await ServerAPI.getAccessLeaderboard(ranking: pool) {
                guard ownsLoad(requestID, slot: ownerSlot) else { return }
                let top = response.top.filter { $0.status == "CONFIRMED" }
                if !top.isEmpty {
                    screenState = .guest(.live(
                        ServerAPI.ArenaBoard(total: response.total, top: top, me: nil),
                        pool))
                    boardState = .idle
                    return
                }
            }
            guard ownsLoad(requestID, slot: ownerSlot) else { return }
        }
        screenState = .guest(.sample)
        boardState = .idle
    }

    private func ownsLoad(_ requestID: UUID, slot: String) -> Bool {
        loadID == requestID && accountSlot == slot && DataScope.slot == slot
    }

    private func failureMessage(_ error: Error) -> String {
        if error is DecodingError {
            return "최신 순위 상태를 읽지 못했습니다. 앱을 업데이트한 뒤 다시 시도해 주세요."
        }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet:
                return "인터넷 연결을 확인한 뒤 다시 시도해 주세요."
            case .timedOut:
                return "서버 응답이 늦어지고 있습니다. 잠시 후 다시 시도해 주세요."
            default:
                return "서버에 연결하지 못했습니다. 잠시 후 다시 시도해 주세요."
            }
        }
        if let apiError = error as? ServerAPIError,
           let message = apiError.message,
           !message.isEmpty {
            return message
        }
        return "랭킹 정보를 불러오지 못했습니다. 잠시 후 다시 시도해 주세요."
    }

    // MARK: 프리뷰 전용 예시 데이터
    //
    // ⚠️ 프리뷰 전용 — 화면 렌더링에만 쓰고 어떤 API 로도 보내지 않는다.
    // 로그인 게이트를 없애면서 "채워진 상태의 유령 미리보기"를 그리기 위한
    // 번들 데이터다. 닉네임은 실존 학생과 무관한 창작이고, 학교명은 화면에서
    // "예시 고등학교" 로 일괄 표기해 실데이터로 오인될 여지를 없앤다.
    // 티어는 챌린저→브론즈 분포, GP(MMR) 는 내림차순 — 실제 순위표의 생김새다.

    private static let sampleRows: [ServerAPI.ArenaRow] = [
        .init(userId: "preview-01", name: "미적분의신", rank: 1, mmr: 1_524,
              tier: "CHALLENGER", tierLabel: "챌린저", rankPoint: 88, division: 1,
              status: "CONFIRMED", isMe: false),
        .init(userId: "preview-02", name: "수학은암기다", rank: 2, mmr: 1_462,
              tier: "GRANDMASTER", tierLabel: "그랜드마스터", rankPoint: 74, division: 1,
              status: "CONFIRMED", isMe: false),
        .init(userId: "preview-03", name: "벡터소년", rank: 3, mmr: 1_401,
              tier: "MASTER", tierLabel: "마스터", rankPoint: 69, division: 2,
              status: "CONFIRMED", isMe: false),
        .init(userId: "preview-04", name: "확통마스터", rank: 4, mmr: 1_345,
              tier: "DIAMOND", tierLabel: "다이아몬드", rankPoint: 61, division: 1,
              status: "CONFIRMED", isMe: false),
        .init(userId: "preview-05", name: "삼각치환장인", rank: 5, mmr: 1_298,
              tier: "DIAMOND", tierLabel: "다이아몬드", rankPoint: 43, division: 3,
              status: "CONFIRMED", isMe: false),
        .init(userId: "preview-06", name: "무한급수", rank: 6, mmr: 1_244,
              tier: "EMERALD", tierLabel: "에메랄드", rankPoint: 77, division: 1,
              status: "CONFIRMED", isMe: false),
        .init(userId: "preview-07", name: "기하왕민준", rank: 7, mmr: 1_210,
              tier: "EMERALD", tierLabel: "에메랄드", rankPoint: 52, division: 2,
              status: "CONFIRMED", isMe: false),
        .init(userId: "preview-08", name: "로그함수러버", rank: 8, mmr: 1_163,
              tier: "PLATINUM", tierLabel: "플래티넘", rankPoint: 64, division: 2,
              status: "CONFIRMED", isMe: false),
        .init(userId: "preview-09", name: "수1레전드", rank: 9, mmr: 1_118,
              tier: "GOLD", tierLabel: "골드", rankPoint: 71, division: 1,
              status: "CONFIRMED", isMe: false),
        .init(userId: "preview-10", name: "폴리매스지망", rank: 10, mmr: 1_074,
              tier: "GOLD", tierLabel: "골드", rankPoint: 38, division: 3,
              status: "CONFIRMED", isMe: false),
        .init(userId: "preview-11", name: "등차수열", rank: 11, mmr: 1_029,
              tier: "SILVER", tierLabel: "실버", rankPoint: 55, division: 2,
              status: "CONFIRMED", isMe: false),
        .init(userId: "preview-12", name: "내신역전러", rank: 12, mmr: 968,
              tier: "BRONZE", tierLabel: "브론즈", rankPoint: 47, division: 2,
              status: "CONFIRMED", isMe: false),
    ]

    // MARK: 디버그 픽스처

    #if DEBUG
    /// 게스트·성공·빈 상태를 실계정 조작 없이 시각 검증한다.
    /// 예: `-route rank -rankArenaFixture guest -harness 320x1000-compact`
    @MainActor
    private func applyDebugFixtureIfPresent() -> Bool {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-rankArenaFixture"),
              index + 1 < arguments.count else { return false }

        let name = arguments[index + 1].lowercased()
        switch name {
        case "guest":
            screenState = .guest(.sample)
            boardState = .idle
        case "guestlive":
            screenState = .guest(.live(
                ServerAPI.ArenaBoard(total: 24, top: Self.sampleRows, me: nil), .sub))
            boardState = .idle
        case "sub", "main":
            let pool: ServerAPI.RankingPool = name == "main" ? .main : .sub
            screenState = .loaded(debugArena(), debugEconomy(pool: pool))
            boardState = .loaded(debugBoard())
        case "empty":
            screenState = .loaded(debugArena(), debugEconomy(pool: .sub))
            boardState = .empty
        default:
            return false
        }
        return true
    }

    private func debugArena() -> ServerAPI.ArenaResponse {
        ServerAPI.ArenaResponse(
            arena: ServerAPI.Arena(
                locked: false,
                mmr: 1_180,
                tier: "EMERALD",
                tierLabel: "에메랄드",
                rankPoint: 66,
                division: 2,
                status: "CONFIRMED",
                weeklyExamsUntilConfirmed: 0,
                // 풀 순위 3위와 의도적으로 다르다. 화면에 47위가 나오면 회귀다.
                overallRank: 47,
                percentile: 0.93,
                recentPerformances: [0.72, 0.76]),
            ladder: [],
            identity: ServerAPI.ArenaIdentity(
                displayName: "수학왕",
                schoolName: "경기외고",
                displayMode: "닉네임"))
    }

    private func debugEconomy(pool: ServerAPI.RankingPool) -> ServerAPI.AccessEconomy {
        ServerAPI.AccessEconomy(
            state: pool == .main ? "MAIN_RANKER" : "REFUND_CHALLENGE",
            cycleId: "debug-cycle",
            access: ServerAPI.AccessEconomy.Access(
                paidAccessDays: 12,
                refundChallengeDays: 12,
                bonusAccessDays: pool == .main ? 31 : 0,
                lockedDays: 0,
                paidAccessStartsAt: nil,
                paidAccessEndsAt: nil),
            refund: ServerAPI.AccessEconomy.Refund(
                status: "CHALLENGING",
                eligible: false,
                day30CompletionPassAvailable: false,
                streakDays: 12,
                targetStreakDays: 30,
                targetChallengeDays: 30,
                paybackAmountKRW: 29_000,
                completedAt: nil),
            ranking: ServerAPI.AccessEconomy.Ranking(
                activeRanking: pool.rawValue,
                skillMMR: 1_180,
                rankTier: "EMERALD",
                // 전역 47위. 활성 풀 순위 표시에는 절대 쓰지 않는다.
                ladderPosition: 47,
                mainRankingEnteredAt: pool == .main ? "2026-07-01T00:00:00.000Z" : nil,
                rankShieldUntil: nil),
            purchase: ServerAPI.AccessEconomy.Purchase(
                allowed: false,
                blockers: []))
    }

    private func debugBoard() -> ServerAPI.ArenaBoard {
        let rows = [
            ServerAPI.ArenaRow(
                userId: "debug-1", name: "벡터마스터", rank: 1, mmr: 1_420,
                tier: "MASTER", tierLabel: "마스터", rankPoint: 71, division: 2,
                status: "CONFIRMED", isMe: false),
            ServerAPI.ArenaRow(
                userId: "debug-2", name: "적분고양이", rank: 2, mmr: 1_260,
                tier: "DIAMOND", tierLabel: "다이아몬드", rankPoint: 54, division: 2,
                status: "CONFIRMED", isMe: false),
            ServerAPI.ArenaRow(
                userId: "debug-me", name: "수학왕", rank: 3, mmr: 1_180,
                tier: "EMERALD", tierLabel: "에메랄드", rankPoint: 66, division: 2,
                status: "CONFIRMED", isMe: true),
        ]
        return ServerAPI.ArenaBoard(total: 24, top: rows, me: rows[2])
    }
    #endif
}

// MARK: - 티어 칩

/// 순위표·히어로가 공유하는 티어 배지 — 작은 라운드 칩.
/// 티어색 점 + 글자로 말한다(색만으로 구분 금지). 배경은 티어색의 옅은 판인데,
/// 글자까지 티어색으로 쓰면 실버·플래티넘이 흰 카드에서 대비가 무너진다 —
/// RankBadgeView 의 0.16 배경 관행을 따르되 글자는 잉크로 지킨다.
/// 그라데이션은 쓰지 않는다 — 이 화면의 그라데이션 예산은 0이다.
private struct TierChip: View {
    let tierCode: String?
    let tierLabel: String?
    let division: Int?
    /// 네이비 히어로 위에서는 배경 농도를 올리고 글자 잉크를 밝게 바꾼다.
    /// 잉크 색은 호출부가 넘긴다 — 온-네이비 잉크 상수를 이중으로 만들지 않는다.
    var onDark = false
    var darkInk: Color = Tokens.ink

    private var tier: RankTier? { RankTier(serverCode: tierCode) }

    private var label: String {
        let base = tierLabel ?? tier?.label ?? "미등재"
        guard let division else { return base }
        let roman = ["", "I", "II", "III", "IV"][min(max(division, 1), 4)]
        return "\(base) \(roman)"
    }

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(tier?.accentColor ?? Tokens.text4)
                .frame(width: 6, height: 6)
            Text(label)
                .font(.mCaption)
                .foregroundStyle(onDark ? darkInk : Tokens.text1)
                .lineLimit(1)
        }
        .padding(.horizontal, Tokens.Space.s2 + 2)
        .padding(.vertical, 4)
        .background(
            (tier?.accentColor ?? Tokens.text4).opacity(onDark ? 0.22 : 0.14),
            in: RoundedRectangle(cornerRadius: Tokens.Radius.sm))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("티어 \(label)")
    }
}
