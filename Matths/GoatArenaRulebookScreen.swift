import SwiftUI

struct GoatArenaRulebookScreen: View {
    @Environment(\.dismiss) private var dismiss
    @State private var chapter: Chapter = .first
    @State private var liveRulebook: ServerAPI.GoatArenaRulebookDocument?
    @State private var rulebookStatus: String?

    private enum Chapter: String, CaseIterable, Identifiable {
        case first = "먼저 보기"
        case sub = "Unranked"
        case main = "Ranked"
        case final = "Final"

        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                // 가로 iPhone 에서는 표지·장 선택(왼쪽)을 고정된 안내판처럼 두고
                // 규정 본문만 오른쪽에서 읽는다. 세로로 쌓으면 장을 바꿀 때마다
                // 제목과 세그먼트를 지나 본문 첫 줄까지 다시 스크롤해야 한다.
                CompactHeightColumns(spacing: Tokens.Space.s6,
                                     stackedSpacing: Tokens.Space.s7) {
                    VStack(alignment: .leading, spacing: Tokens.Space.s7) {
                        titleBlock
                        chapterPicker
                    }
                } trailing: {
                    LazyVStack(alignment: .leading, spacing: Tokens.Space.s7) {
                        chapterContent
                    }
                }
                .frame(maxWidth: Tokens.readableWidth, alignment: .leading)
                .padding(.horizontal, Tokens.Space.s6)
                .padding(.vertical, Tokens.Space.s7)
                .frame(maxWidth: .infinity)
            }
            .background(Tokens.paper)
            .navigationTitle("공식 룰북")
            .navigationBarTitleDisplayMode(.inline)
            .task { await refreshRulebook() }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("닫기") { dismiss() }
                }
            }
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s4) {
            Text("GOAT Arena 공식 룰북")
                .font(.mMicro)
                .foregroundStyle(Tokens.primary)

            Text("경기 전에 꼭 확인하세요")
                .font(.mTitle)
                .foregroundStyle(Tokens.ink)
                .accessibilityAddTraits(.isHeader)

            Text(rulebookVersionLabel)
                .font(.mCaption)
                .foregroundStyle(Tokens.text3)

            if let rulebookStatus {
                Label(rulebookStatus, systemImage: "arrow.triangle.2.circlepath")
                    .font(.mCaption)
                    .foregroundStyle(Tokens.text3)
            }

            ExamRule()

            HStack(spacing: 0) {
                ruleFact("문제", "5문항")
                Divider()
                ruleFact("시험", "10분")
                Divider()
                ruleFact("증빙", "60초")
            }
            .frame(minHeight: 72)
            .background(Tokens.surface)
            .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.md).stroke(Tokens.line))
            .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.md))
        }
    }

    private func ruleFact(_ label: String, _ value: String) -> some View {
        VStack(spacing: Tokens.Space.s1) {
            Text(label).font(.mMicro).foregroundStyle(Tokens.text3)
            Text(value).font(.mBodyB).foregroundStyle(Tokens.ink)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var chapterPicker: some View {
        Picker("룰북 장", selection: $chapter) {
            ForEach(Chapter.allCases) { item in
                Text(item.rawValue).tag(item)
            }
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    private var chapterContent: some View {
        switch chapter {
        case .first:
            quickRules
            commonRules
        case .sub:
            if let rulebook = liveRulebook?.divisions.sub {
                LiveRulebookView(rulebook: rulebook)
            } else {
                offlineRulebookUnavailable("Unranked")
            }
        case .main:
            if let rulebook = liveRulebook?.divisions.main {
                LiveRulebookView(rulebook: rulebook)
            } else {
                offlineRulebookUnavailable("Ranked")
            }
        case .final:
            finalRules
        }
    }

    private var rulebookVersionLabel: String {
        guard let liveRulebook else {
            return "최신 룰북 확인 필요"
        }
        return "서버 적용본 \(liveRulebook.revision.prefix(8)), Final Ranking v1.4"
    }

    @MainActor
    private func refreshRulebook() async {
        if let cached = ServerAPI.cachedGoatArenaRulebook() {
            liveRulebook = cached.document
            rulebookStatus = "저장된 서버 룰북 확인 중"
        }
        do {
            liveRulebook = try await ServerAPI.getGoatArenaRulebook()
            rulebookStatus = "현재 서버 운영 정책과 동기화됨"
        } catch {
            rulebookStatus = liveRulebook == nil
                ? "네트워크 연결 후 현재 서버 룰북을 확인할 수 있습니다"
                : "오프라인, 마지막 동기화 룰북 표시"
        }
    }

    private func offlineRulebookUnavailable(_ mode: String) -> some View {
        RulebookSection(
            number: "",
            title: "\(mode) 최신 규정을 불러올 수 없습니다",
            summary: "정산·자격 규칙의 오래된 복사본을 표시하지 않습니다. 네트워크 연결 뒤 다시 열어 현재 서버 적용본을 확인해 주세요."
        ) {
            Label("이전에 동기화한 서버 룰북이 있으면 오프라인에서도 그 적용본을 표시합니다.", systemImage: "wifi.exclamationmark")
                .font(.mCallout)
                .foregroundStyle(Tokens.text2)
        }
    }

    private var quickRules: some View {
        RulebookSection(number: "00", title: "먼저 알아둘 6가지", summary: "이 여섯 문장이 이용권과 Arena의 가장 중요한 경계입니다.") {
            RulebookNumberedList(items: [
                "학습일이 끝나면 Ranked에서 Unranked로 전환됩니다.",
                "학습일이 0이면 Arena와 주간 모의고사가 잠깁니다.",
                "학습일이 남아 있으면 새 패키지를 살 수 없습니다.",
                "Ranked 종료 후 72시간 안에 결제하면 시험 없이 복귀 절차를 밟습니다.",
                "72시간이 지나면 랭크 복귀전을 치릅니다.",
                "20:00 이후 결제하면 학습일 차감은 다음 날 시작합니다."
            ])
        }
    }

    private var commonRules: some View {
        Group {
            RulebookSection(number: "01", title: "공식 1대1", summary: "동일한 주관식 준킬러 5문항을 10분 동안 풉니다.") {
                RulebookBullets(items: [
                    "한 번에 한 문제만 볼 수 있습니다. ‘다음’으로 넘어가면 이전 문제를 다시 보거나 고칠 수 없습니다.",
                    "5번 제출 또는 시간 종료 뒤 60초 동안 풀이 사진 1~5장을 올립니다. 사진은 상대에게 공개되지 않습니다.",
                    "분수·소수·동치 표현을 지원하며 서버 채점이 최종 기준입니다.",
                    "배치 완료, 정상 계정, 유료 이용 중, 사용 가능 학습일 1일 이상, 무결성 CLEAR가 필요합니다."
                ])
            }

            RulebookSection(number: "02", title: "승패 판정", summary: "아래 순서를 위에서부터 적용합니다.") {
                RulebookNumberedList(items: ["높은 총점", "많은 정답 수", "짧은 정답 문항 풀이 시간", "짧은 전체 풀이 시간", "모두 같으면 방어자 승"])
                RulebookNotice(title: "도전자 승리", text: "Arena 랭크·랭크 내 순위·Arena GP 전체를 교환합니다. 방어자가 이기면 Arena는 그대로입니다.")
                Text("1대1 결과는 Skill MMR을 바꾸지 않습니다. MMR은 최초 배치와 매주 일요일 공식 모의고사에서만 바뀝니다. Sudden Death는 없습니다.")
                    .font(.mCallout).foregroundStyle(Tokens.text2)
            }

            RulebookSection(number: "03", title: "일요일 잠금", summary: "15:00 공식 기록 고정, 월요일 00:00 새 결과 공개") {
                RulebookTimeline(items: [
                    ("일 14:00", "새 경기 요청·수락·준비·시작 중단"),
                    ("일 15:00", "Arena 기록 반영 중단, 공개 Final Ranking 고정"),
                    ("월 00:00", "새 MMR·주간 보너스·Final Ranking 공개")
                ])
                Text("진행 중인 경기는 일요일 15:00 전까지 제출·증빙·정산되어야 하며, 끝나지 않으면 HELD로 보류합니다.")
                    .font(.mCallout).foregroundStyle(Tokens.text2)
            }

            RulebookSection(number: "04", title: "상대 공개와 복수권", summary: "후보를 고르는 대신 서버가 상대를 배정합니다.") {
                RulebookBullets(items: [
                    "경기 뒤에도 닉네임과 필요한 Arena 정보만 공개합니다. 실명·학교·지역·연락처·결제 정보는 공개하지 않습니다.",
                    "가장 최근 원경기의 패자에게만 복수권이 한 번 생깁니다.",
                    "복수전은 24시간 안이면서 일요일 14:00 전까지 끝내야 합니다. ‘경기 종료’를 선택하면 기권입니다."
                ])
            }
        }
    }

    private var finalRules: some View {
        Group {
            RulebookSection(number: "F1", title: "Final Ranking", summary: "현재 공식 입력으로 매번 다시 계산하며 MMR이나 Arena를 바꾸지 않습니다.") {
                RulebookFormula(lines: ["Final Rating = Skill MMR + 경쟁 구분 기본값 + 성장값 + 위치값 + 주간 보너스 + 임시 조정"])
                RulebookBullets(items: [
                    "활성 순위는 배치 완료, 정상 계정, 유료 이용 중, 유효 학습일, 무결성 CLEAR가 모두 필요합니다.",
                    "주간 공식 모의고사 완료 보너스는 30, 미응시·기한 만료는 0입니다.",
                    "동점은 Final Rating, 시즌 정산 일반 공격 횟수, Skill MMR, 안정 사용자 ID 순서로 가립니다."
                ])
            }

            RulebookSection(number: "F2", title: "정확한 계산식", summary: "표시용 반올림 전의 공식 값으로 계산합니다.") {
                RulebookFormula(lines: [
                    "Unranked 성장 = clamp(80 × (현재 백분위 - 시작 백분위), -20, +20)",
                    "Unranked Final = MMR + 15 + Unranked 성장 + 10 × 현재 백분위 + 주간 보너스 + 임시 조정",
                    "Ranked Final = MMR + 35 + 고정 Unranked 성장 + 10 × 시즌 Unranked 종료 백분위 + Ranked 성장 + 20 × 시즌 Ranked 현재 백분위 + 주간 보너스 + 임시 조정"
                ])
            }

            RulebookSection(number: "F3", title: "연간 시즌", summary: "12월 31일 Arena를 보관·초기화하고 1월 1일 새 시즌을 시작합니다.") {
                RulebookFormula(lines: ["새 시즌 MMR = 1500 + 0.60 × (이전 시즌 MMR - 1500)"])
                Text("경쟁 구분은 유지되지만 Arena 랭크·랭크 내 순위·Arena GP는 시즌 기록으로 보관한 뒤 초기화합니다. 새 시즌 배치를 마쳐야 공식 순위에 다시 들어갑니다.")
                    .font(.mCallout).foregroundStyle(Tokens.text2)
            }

            Text("현재 적용 중인 이용 규칙과 공식 경기 기록을 최종 기준으로 판정합니다.")
                .font(.mCaption)
                .foregroundStyle(Tokens.text3)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, Tokens.Space.s4)
        }
    }
}

private struct LiveRulebookView: View {
    let rulebook: ServerAPI.GoatArenaRulebookDocument.Rulebook

    var body: some View {
        Group {
            RulebookSection(
                number: "00",
                title: rulebook.title,
                summary: rulebook.intro
            ) {
                RulebookBullets(items: rulebook.summary)
            }

            if let policy = rulebook.paybackPolicy {
                ActivePaybackPolicyView(policy: policy)
            }

            if let policy = rulebook.mainPolicy {
                ActiveMainPolicyView(policy: policy)
            }

            if let upcomingPolicy = rulebook.upcomingPolicy {
                UpcomingPolicyNotice(policy: upcomingPolicy)
            }

            ForEach(rulebook.rules) { rule in
                RulebookSection(
                    number: String(format: "%02d", rule.number),
                    title: rule.title,
                    summary: rule.sections.map(\.title).joined(separator: ", ")
                ) {
                    VStack(alignment: .leading, spacing: Tokens.Space.s5) {
                        ForEach(rule.sections) { section in
                            VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                                Text(ArenaDisplayTerms.apply(section.title))
                                    .font(.mBodyB)
                                    .foregroundStyle(Tokens.ink)
                                RulebookBullets(items: section.body)
                            }
                        }
                    }
                }
            }

            Text("현재 적용 중인 이용 규칙과 공식 경기 기록을 최종 기준으로 판정합니다.")
                .font(.mCaption)
                .foregroundStyle(Tokens.text3)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, Tokens.Space.s4)
        }
    }
}

private struct ActivePaybackPolicyView: View {
    let policy: ServerAPI.GoatArenaRulebookDocument.Rulebook.PaybackPolicy

    var body: some View {
        RulebookSection(
            number: "P",
            title: "현재 적용 중인 패키지·페이백 정책",
            summary: policy.isFallback
                ? "서버에 활성 정책이 없어 확정 기본값을 표시합니다."
                : "서버의 활성 정책값을 그대로 표시합니다."
        ) {
            // 신 서버 룰북 뷰는 minimumPaidNormalAttacks 를 내려주지 않으므로 값이 있을 때만
            // 행을 붙인다(없는 값을 "nil회" 로 보여주지 않기 위함).
            RulebookTable(headers: ["항목", "현재 값"], rows: {
                var rows: [[String]] = [
                    ["패키지", policy.displayName],
                    ["가격", "\(policy.priceAmount.formatted())원"],
                    ["시작 학습일", "\(policy.initialLearningDays)일"],
                    ["시작 페이백 점수", "\(policy.initialPaybackScoreDays)점"],
                    ["최소 연속 학습", "\(policy.minimumStreakDays)일"],
                ]
                if let n = policy.minimumPaidNormalAttacks {
                    rows.append(["최소 유료 일반 공격", "\(n)회"])
                }
                rows.append(["최소 페이백 점수", "\(policy.minimumScoreDays)점"])
                return rows
            }())
            if !policy.bands.isEmpty {
                RulebookTable(
                    headers: ["점수", "페이백률", "예상 금액"],
                    rows: policy.bands.map { band in
                        let range = band.maxScoreDays.map {
                            "\(band.minScoreDays)~\($0)"
                        } ?? "\(band.minScoreDays) 이상"
                        return [
                            range,
                            "\(band.ratePercent)%",
                            "\(band.expectedPaybackAmount.formatted())원",
                        ]
                    })
            }
            if !policy.dailyMatchLimitsByTier.isEmpty {
                RulebookTable(
                    headers: ["티어", "공격", "방어"],
                    rows: policy.dailyMatchLimitsByTier.map {
                        [$0.tierLabel, "\($0.attackLimit)회", "\($0.defenseLimit)회"]
                    })
            }
        }
    }
}

private struct ActiveMainPolicyView: View {
    let policy: ServerAPI.GoatArenaRulebookDocument.Rulebook.MainPolicy

    var body: some View {
        RulebookSection(
            number: "P",
            title: "현재 적용 중인 Ranked 운영 정책",
            summary: "\(policy.displayName), \(policy.policyVersionCode)"
        ) {
            RulebookTable(
                headers: [
                    "티어 차이",
                    // 신 서버는 이 값을 내려주지 않으므로 기본값 false(공격자만 예치)로 다룬다.
                    (policy.requiresOpponentDaysGreaterThanStake ?? false)
                        ? "양쪽 최소 예치"
                        : "공격자 최소 예치",
                ],
                rows: policy.stakeDaysByTierGap.map {
                    ["\($0.tierGap)단계", "\($0.stakeDays)일"]
                })
            RulebookBullets(items: [
                "최대 도전 티어 차이는 \(policy.maximumTargetTierGap)단계입니다.",
                (policy.requiresOpponentDaysGreaterThanStake ?? false)
                    ? "양쪽 모두 예치 뒤 사용 가능 학습일을 최소 1일 남겨야 합니다."
                    : "상향 쟁탈전은 공격자만 예치하고, 자동 방어자는 사용 가능 학습일 1일 이상이면 참가할 수 있습니다.",
                "같은 상대는 최근 \(policy.repeatOpponentExclusionDays)일 동안 후보에서 제외합니다.",
                "복수전은 원경기 예치의 \(policy.revengeStakeMultiplier)배를 예치하고 수수료 \(policy.revengeFeeDays)일을 적용합니다.",
            ])
        }
    }
}

private struct UpcomingPolicyNotice: View {
    let policy: ServerAPI.GoatArenaRulebookDocument.Rulebook.UpcomingPolicy

    private var effectiveDateLabel: String {
        guard let raw = policy.effectiveFrom else { return "적용 시각 확인 중" }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let standard = ISO8601DateFormatter()
        guard let date = fractional.date(from: raw) ?? standard.date(from: raw) else {
            return "적용 시각 확인 중"
        }
        return date.formatted(
            Date.FormatStyle(date: .long, time: .shortened)
                .locale(Locale(identifier: "ko_KR")))
    }

    var body: some View {
        RulebookNotice(
            title: "다음 운영 정책 사전 고지",
            text: "\(ArenaDisplayTerms.apply(policy.displayName)), \(effectiveDateLabel) 적용 예정"
        )
    }
}

private struct RulebookSection<Content: View>: View {
    let number: String
    let title: String
    let summary: String
    @ViewBuilder let content: Content

    init(number: String, title: String, summary: String, @ViewBuilder content: () -> Content) {
        self.number = number
        self.title = title
        self.summary = summary
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s5) {
            HStack(alignment: .top, spacing: Tokens.Space.s4) {
                Text(number)
                    .font(.mMicro)
                    .foregroundStyle(Tokens.primary)
                    .frame(width: 30, alignment: .leading)
                VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                    Text(ArenaDisplayTerms.apply(title)).font(.mHeading).foregroundStyle(Tokens.ink)
                    Text(ArenaDisplayTerms.apply(summary)).font(.mCallout).foregroundStyle(Tokens.text2)
                }
            }
            DottedRule()
            VStack(alignment: .leading, spacing: Tokens.Space.s5) { content }
        }
        .card(padding: Tokens.Space.s6)
        .accessibilityElement(children: .contain)
    }
}

private struct RulebookBullets: View {
    let items: [String]
    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s3) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .top, spacing: Tokens.Space.s3) {
                    Circle().fill(Tokens.primary).frame(width: 5, height: 5).padding(.top, 8)
                    Text(ArenaDisplayTerms.apply(item)).font(.mCallout).foregroundStyle(Tokens.text1).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

private struct RulebookNumberedList: View {
    let items: [String]
    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s3) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .top, spacing: Tokens.Space.s3) {
                    CircledNumber(n: index + 1, color: Tokens.primary)
                    Text(ArenaDisplayTerms.apply(item)).font(.mCallout).foregroundStyle(Tokens.text1).padding(.top, 2).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

private struct RulebookFormula: View {
    let lines: [String]
    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
            ForEach(lines, id: \.self) { line in
                Text(ArenaDisplayTerms.apply(line))
                    .font(.system(.callout, design: .monospaced, weight: .semibold))
                    .foregroundStyle(Tokens.text1)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Tokens.Space.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tokens.primarySoft)
        .overlay(alignment: .leading) { Rectangle().fill(Tokens.brandViolet).frame(width: 4) }
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.sm))
    }
}

private struct RulebookNotice: View {
    let title: String
    let text: String
    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
            Text(ArenaDisplayTerms.apply(title)).font(.mBodyB).foregroundStyle(Tokens.ink)
            Text(ArenaDisplayTerms.apply(text)).font(.mCallout).foregroundStyle(Tokens.text2).fixedSize(horizontal: false, vertical: true)
        }
        .padding(Tokens.Space.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tokens.primarySoft, in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
    }
}

private struct RulebookTimeline: View {
    let items: [(String, String)]
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .top, spacing: Tokens.Space.s3) {
                    VStack(spacing: 0) {
                        Circle().fill(Tokens.primary).frame(width: 10, height: 10)
                        if index < items.count - 1 { Rectangle().fill(Tokens.lineStrong).frame(width: 1, height: 48) }
                    }
                    Text(ArenaDisplayTerms.apply(item.0)).font(.mCaption).foregroundStyle(Tokens.primary).frame(width: 72, alignment: .leading)
                    Text(ArenaDisplayTerms.apply(item.1)).font(.mCallout).foregroundStyle(Tokens.text1).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

private struct RulebookTable: View {
    let headers: [String]
    let rows: [[String]]
    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(row.enumerated()), id: \.offset) { columnIndex, cell in
                        HStack(alignment: .top, spacing: Tokens.Space.s3) {
                            Text(ArenaDisplayTerms.apply(headers.indices.contains(columnIndex) ? headers[columnIndex] : "항목"))
                                .font(.mMicro)
                                .foregroundStyle(Tokens.text3)
                                .frame(width: 92, alignment: .leading)

                            Text(ArenaDisplayTerms.apply(cell))
                                .font(.mCaption)
                                .fontWeight(columnIndex == 0 ? .bold : .semibold)
                                .foregroundStyle(Tokens.text1)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        }
                        .padding(.horizontal, Tokens.Space.s3)
                        .padding(.vertical, Tokens.Space.s2)
                        .accessibilityElement(children: .combine)

                        if columnIndex < row.count - 1 {
                            Divider().padding(.leading, 116)
                        }
                    }
                }
                .background(Tokens.surface)
                .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.sm).stroke(Tokens.line))
                .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.sm))
            }
        }
        .accessibilityElement(children: .contain)
    }
}

#if DEBUG
private struct GoatArenaRulebookScreen_Previews: PreviewProvider {
    static var previews: some View {
        GoatArenaRulebookScreen()
    }
}
#endif
