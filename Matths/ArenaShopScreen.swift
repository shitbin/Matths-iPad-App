import SwiftUI

struct ArenaShopScreen: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private struct PendingPurchase: Identifiable {
        let id = UUID()
        let item: ServerAPI.ArenaShop.Item
        let operationID: String
        let relatedMatchId: String?
        let relatedInvitationId: String?
        let accountSlot: String
        /// 결과 미확정 상태로 보존돼 있던 이전 시도의 키를 재사용하는지 —
        /// 재확인임을 다이얼로그에서 알려 학생이 이중 차감을 걱정하지 않게 한다.
        let resumed: Bool
    }

    @State private var shop: ServerAPI.ArenaShop?
    @State private var loading = true
    @State private var purchasing = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var matchTargets: [String: String] = [:]
    @State private var invitationTargets: [String: String] = [:]
    @State private var pendingPurchase: PendingPurchase?
    @State private var selectedAnalysis: ServerAPI.ArenaShop.Effect?
    @State private var accountSlot = DataScope.slot
    @State private var requestID = UUID()
    #if DEBUG
    @State private var fixtureAnalysis: ServerAPI.ArenaShopAnalysis?
    #endif

    private var compact: Bool { horizontalSizeClass == .compact }
    private var compactHeight: Bool { verticalSizeClass == .compact }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: compactHeight ? Tokens.Space.s3 : Tokens.Space.s8) {
                if compactHeight {
                    compactHeader
                } else {
                    screenControls
                    heading
                }
                if loading {
                    loadingView
                } else if let shop {
                    if compactHeight && !dynamicTypeSize.isAccessibilitySize {
                        compactWallet(shop)
                    } else {
                        wallet(shop)
                    }
                    if shop.policy.sundayLocked { policyLock(shop.policy) }
                    if let successMessage { successNotice(successMessage) }
                    itemGrid(shop)
                    activeEffects(shop)
                    purchaseHistory(shop)
                    policyNotice(shop.policy)
                } else if let errorMessage {
                    unavailable(errorMessage)
                }
            }
            .frame(maxWidth: Tokens.readableWidth, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, compact ? Tokens.Space.s4 : Tokens.Space.s8)
            .padding(.vertical, compactHeight ? Tokens.Space.s3 : Tokens.Space.s6)
        }
        .background(Tokens.paper)
        .task { await load() }
        .onReceive(NotificationCenter.default.publisher(for: DataScope.didSwitchNotification)) {
            guard let newSlot = $0.object as? String, newSlot != accountSlot else { return }
            requestID = UUID()
            accountSlot = newSlot
            shop = nil
            pendingPurchase = nil
            selectedAnalysis = nil
            matchTargets = [:]
            invitationTargets = [:]
            purchasing = false
            successMessage = nil
            errorMessage = nil
            Task { await load() }
        }
        .onDisappear {
            requestID = UUID()
            loading = false
            purchasing = false
        }
        .confirmationDialog(
            pendingPurchase.map { ArenaDisplayTerms.apply($0.item.displayName) } ?? "구매 확인",
            isPresented: Binding(
                get: { pendingPurchase != nil },
                set: { if !$0 { pendingPurchase = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(purchasing ? "처리 중" : "동의하고 사용하기") {
                guard let pendingPurchase else { return }
                Task { await buy(pendingPurchase) }
            }
            .disabled(purchasing)
            Button("취소", role: .cancel) {
                // 명시적 취소는 구매 의사의 확정 철회다. 보존된 키를 여기서
                // 폐기해, 이후 같은 아이템 구매가 '새 결정 = 새 키'로 나가게
                // 한다. (다이얼로그 바깥 탭 등 모호한 닫힘에서는 폐기하지
                // 않는다 — 돈에 해당하는 값은 보존이 안전한 방향이다.)
                if let pendingPurchase {
                    try? ArenaShopPurchaseIntentStore.clear(
                        operationID: pendingPurchase.operationID,
                        accountSlot: pendingPurchase.accountSlot)
                }
                pendingPurchase = nil
            }
        } message: {
            if let pendingPurchase {
                let preview = pendingPurchase.item.purchasePreview
                let duration = ArenaDisplayTerms.apply(pendingPurchase.item.durationLabel)
                let refund = ArenaDisplayTerms.apply(pendingPurchase.item.refundCondition)
                let base = "잔액이 \(preview.beforeAvailableDays)일에서 \(preview.afterAvailableDays)일로 바뀝니다. \(duration)\n\(refund)\n잔액이 0이 되고 정산이 끝나면 Ranked에서 Unranked로 전환됩니다."
                Text(pendingPurchase.resumed
                    ? base + "\n이전 시도의 결과를 받지 못했습니다. 동일 요청으로 다시 확인하며, 이미 처리된 구매는 추가 차감되지 않습니다."
                    : base)
            }
        }
        .alert(
            "상점 요청을 완료하지 못했습니다",
            isPresented: Binding(
                get: { errorMessage != nil && shop != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .compactHeightSheet(item: $selectedAnalysis) { effect in
            ArenaShopAnalysisScreen(
                effectId: effect.id,
                accountSlot: accountSlot,
                fixture: {
                    #if DEBUG
                    fixtureAnalysis
                    #else
                    nil
                    #endif
                }()
            )
        }
    }

    private var screenControls: some View {
        HStack(spacing: Tokens.Space.s3) {
            Button { store.route = .rank } label: {
                Label("Arena로", systemImage: "chevron.left")
                    .font(.mCaption)
                    .foregroundStyle(Tokens.text3)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("GOAT Arena로 돌아가기")

            Spacer(minLength: Tokens.Space.s3)

            refreshButton
        }
    }

    /// iPhone 가로는 설명용 영웅 영역보다 잔액과 판매 아이템이 먼저 보여야 한다.
    /// 돌아가기·제목·새로고침을 한 줄로 합쳐 두 조작의 44pt 영역도 온전히 보존한다.
    private var compactHeader: some View {
        HStack(spacing: Tokens.Space.s4) {
            Button { store.route = .rank } label: {
                Image(systemName: "chevron.left")
                    .font(.mBody)
                    .foregroundStyle(Tokens.onNavy.opacity(0.72))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("GOAT Arena로 돌아가기")

            VStack(alignment: .leading, spacing: 2) {
                Text("Ranked 상점")
                    .font(.mHeading)
                    .foregroundStyle(Tokens.onNavy)
                    .lineLimit(1)
                    .accessibilityAddTraits(.isHeader)
                Text("경기로 얻은 학습일을 분석·일정·장식 기능에 사용")
                    .font(.mCaption)
                    .foregroundStyle(Tokens.onNavy.opacity(0.62))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            Spacer(minLength: Tokens.Space.s2)
            refreshButton
        }
        .frame(minHeight: 52)
    }

    private var refreshButton: some View {
        Button { Task { await load() } } label: {
            Image(systemName: "arrow.clockwise")
                .font(.mBody)
                .foregroundStyle(compactHeight ? Tokens.brandCyan : Tokens.primary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(loading || purchasing)
        .accessibilityLabel("상점 새로고침")
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s3) {
            Text("Ranked 상점")
                .font(.mMicro)
                .foregroundStyle(Tokens.primary)
            Text("경기로 얻은 시간을\n다음 성장에 사용하세요")
                .font(.mTitle)
                .foregroundStyle(Tokens.ink)
            Text("승패나 GP를 사는 곳이 아닙니다. 분석·일정·장식 기능만 서버 정책에 따라 적용됩니다.")
                .font(.mCallout)
                .foregroundStyle(Tokens.text2)
                .fixedSize(horizontal: false, vertical: true)
            ExamRule()
        }
    }

    private var loadingView: some View {
        HStack(spacing: Tokens.Space.s3) {
            ProgressView()
            Text("잔액과 현재 정책을 확인하고 있습니다")
                .font(.mBodyB)
                .foregroundStyle(Tokens.text2)
        }
        .frame(maxWidth: .infinity, minHeight: 180)
    }

    private func wallet(_ shop: ServerAPI.ArenaShop) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s5) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s4) {
                    walletAmount(shop.wallet.availableLearningDays)
                    Spacer()
                    policyIdentity(shop.policy)
                }
                VStack(alignment: .leading, spacing: Tokens.Space.s4) {
                    walletAmount(shop.wallet.availableLearningDays)
                    policyIdentity(shop.policy)
                }
            }
            DottedRule()
            Label("구매 뒤 최소 \(shop.wallet.minimumBalanceAfterPurchase)일은 남아야 합니다.", systemImage: "shield.checkered")
                .font(.mCaption)
                .foregroundStyle(Tokens.text2)
        }
        .card()
    }

    /// iPhone 가로의 첫 화면은 잔액 설명보다 실제 판매 아이템이 먼저 보여야 한다.
    /// 같은 세 정보를 한 줄로 압축하고, VoiceOver에서는 각 묶음을 완전한 문장으로
    /// 읽는다. 구매 가능 판정과 잔액 차감은 기존 `canPurchase`/서버 경계를 그대로 쓴다.
    private func compactWallet(_ shop: ServerAPI.ArenaShop) -> some View {
        HStack(spacing: Tokens.Space.s5) {
            HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s2) {
                Text("\(shop.wallet.availableLearningDays)")
                    .font(.mStat)
                    .foregroundStyle(Tokens.ink)
                    .monospacedDigit()
                Text("학습일 사용 가능")
                    .font(.mCaption)
                    .foregroundStyle(Tokens.text2)
            }
            .accessibilityElement(children: .combine)

            Divider().frame(height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(ArenaDisplayTerms.apply(shop.policy.displayName))
                    .font(.mCaption)
                    .foregroundStyle(Tokens.text1)
                    .lineLimit(1)
                Text(shop.policy.effectiveFrom.map { "\(formatDate($0)) 적용" }
                     ?? shop.policy.versionCode)
                    .font(.mMicro)
                    .foregroundStyle(Tokens.text3)
            }
            .accessibilityElement(children: .combine)

            Spacer(minLength: 0)

            Label("최소 \(shop.wallet.minimumBalanceAfterPurchase)일 남김",
                  systemImage: "shield.checkered")
                .font(.mCaption)
                .foregroundStyle(Tokens.text2)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(minHeight: 60)
        .card(padding: Tokens.Space.s4)
    }

    private func walletAmount(_ days: Int) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s1) {
            Text("현재 사용 가능")
                .font(.mCaption)
                .foregroundStyle(Tokens.text3)
            HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s2) {
                Text("\(days)")
                    .font(.mStatLarge)
                    .foregroundStyle(Tokens.ink)
                    .monospacedDigit()
                Text("학습일")
                    .font(.mBodyB)
                    .foregroundStyle(Tokens.text2)
            }
        }
    }

    private func policyIdentity(_ policy: ServerAPI.ArenaShop.Policy) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s1) {
            Text(ArenaDisplayTerms.apply(policy.displayName))
                .font(.mCaption)
                .foregroundStyle(Tokens.text1)
            Text(policy.effectiveFrom.map { "\(formatDate($0)) 적용" } ?? policy.versionCode)
                .font(.mMicro)
                .foregroundStyle(Tokens.text3)
        }
    }

    private func itemGrid(_ shop: ServerAPI.ArenaShop) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s5) {
            SectionRule(title: "판매 아이템")
            LazyVGrid(
                columns: dynamicTypeSize.isAccessibilitySize
                    ? [GridItem(.flexible(), spacing: Tokens.Space.s4)]
                    : [GridItem(.adaptive(minimum: compact ? 260 : 330), spacing: Tokens.Space.s4)],
                alignment: .leading,
                spacing: Tokens.Space.s4
            ) {
                ForEach(shop.items) { item in itemCard(item, shop: shop) }
            }
        }
    }

    private func itemCard(_ item: ServerAPI.ArenaShop.Item, shop: ServerAPI.ArenaShop) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s4) {
            HStack(alignment: .top) {
                Text(ArenaDisplayTerms.apply(item.eyebrow).uppercased())
                    .font(.mMicro)
                    .foregroundStyle(Tokens.primary)
                Spacer()
                Text("\(item.priceDays)일")
                    .font(.mStat)
                    .foregroundStyle(Tokens.ink)
            }
            Text(ArenaDisplayTerms.apply(item.displayName))
                .font(.mHeading)
                .foregroundStyle(Tokens.ink)
            Text(ArenaDisplayTerms.apply(item.description))
                .font(.mCallout)
                .foregroundStyle(Tokens.text2)
                .fixedSize(horizontal: false, vertical: true)

            targetControl(item, shop: shop)

            VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                detailLine("잔액", "\(item.purchasePreview.beforeAvailableDays)일에서 \(item.purchasePreview.afterAvailableDays)일로")
                detailLine("효과 만료", ArenaDisplayTerms.apply(item.purchasePreview.expectedEffectEndsAt.map(formatDateTime) ?? item.durationLabel))
                detailLine("강등 위험", riskLabel(item.purchasePreview.demotionRisk))
            }

            Text(ArenaDisplayTerms.apply(item.refundCondition))
                .font(.mCaption)
                .foregroundStyle(Tokens.text3)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                let matchId = matchTargets[item.itemCode]?.trimmingCharacters(in: .whitespacesAndNewlines)
                let invitationId = invitationTargets[item.itemCode]
                let relatedMatchId = matchId?.isEmpty == false ? matchId : nil
                let relatedInvitationId = invitationId?.isEmpty == false ? invitationId : nil
                do {
                    // X-05: 이전 시도의 응답이 유실됐다면(타임아웃 등) 보존된 같은
                    // Idempotency-Key 를 재사용해 서버가 replay 로 판정하게 한다.
                    // 여기서 새 키를 발급하는 순간이 곧 학습일 이중 차감이다.
                    let resolution = try ArenaShopPurchaseIntentStore.resolve(
                        itemCode: item.itemCode,
                        relatedMatchId: relatedMatchId,
                        relatedInvitationId: relatedInvitationId,
                        accountSlot: accountSlot)
                    pendingPurchase = PendingPurchase(
                        item: item,
                        operationID: resolution.operationID,
                        relatedMatchId: relatedMatchId,
                        relatedInvitationId: relatedInvitationId,
                        accountSlot: accountSlot,
                        resumed: resolution.resumed)
                } catch {
                    // 키 파일을 읽지 못한 채 새 키로 보내면 비중복 보장이 깨진다.
                    // GoatArena command-keys 규약과 동일하게 구매 자체를 막는다.
                    errorMessage = "안전한 재시도 정보를 이 기기에서 확인하지 못해 구매를 시작하지 않았습니다. 저장 공간을 확인한 뒤 다시 시도해 주세요."
                }
            } label: {
                Text(item.itemCode == "DEFENSE_SCHEDULE_PROTECTION" ? "적용하기" : "조건 확인 후 사용")
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!canPurchase(item, shop: shop) || purchasing)
            .opacity(canPurchase(item, shop: shop) ? 1 : 0.5)
        }
        .card()
    }

    @ViewBuilder
    private func targetControl(_ item: ServerAPI.ArenaShop.Item, shop: ServerAPI.ArenaShop) -> some View {
        if item.targetType == "MATCH" {
            let targets = item.itemCode == "DEFENSE_SCHEDULE_PROTECTION"
                ? (shop.defenseProtectionTargets ?? [])
                : (shop.analysisTargets ?? [])
            if targets.isEmpty {
                Text(item.itemCode == "DEFENSE_SCHEDULE_PROTECTION"
                     ? "지금 보호권을 적용할 수 있는 경기가 없습니다."
                     : "분석할 수 있는 정산 완료 경기가 없습니다.")
                    .font(.mCaption)
                    .foregroundStyle(Tokens.text3)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Picker(item.itemCode == "DEFENSE_SCHEDULE_PROTECTION" ? "보호할 경기" : "분석할 경기", selection: Binding(
                    get: { matchTargets[item.itemCode, default: ""] },
                    set: { matchTargets[item.itemCode] = $0 }
                )) {
                    Text("경기를 선택해 주세요").tag("")
                    ForEach(targets) { target in
                        Text(matchTargetLabel(target))
                            .tag(target.id)
                    }
                }
                .pickerStyle(.menu)
                .frame(minHeight: 44)
                .accessibilityLabel(item.itemCode == "DEFENSE_SCHEDULE_PROTECTION" ? "보호할 경기 선택" : "분석할 경기 선택")
            }
        } else if item.targetType == "INVITATION" {
            Picker("가속할 초대", selection: Binding(
                get: { invitationTargets[item.itemCode, default: ""] },
                set: { invitationTargets[item.itemCode] = $0 }
            )) {
                Text("초대 요청 선택").tag("")
                ForEach(shop.invitations) { invitation in
                    Text("\(ArenaDisplayTerms.tier(invitation.targetTier)), \(invitation.stakeDays)일 예치")
                        .tag(invitation.id)
                }
            }
            .pickerStyle(.menu)
        }
    }

    private func canPurchase(_ item: ServerAPI.ArenaShop.Item, shop: ServerAPI.ArenaShop) -> Bool {
        guard item.purchasePreview.purchaseEligible, !shop.policy.sundayLocked else { return false }
        if item.targetType == "MATCH" {
            let selected = (matchTargets[item.itemCode] ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let targets = item.itemCode == "DEFENSE_SCHEDULE_PROTECTION"
                ? (shop.defenseProtectionTargets ?? [])
                : (shop.analysisTargets ?? [])
            return targets.contains(where: { $0.id == selected })
        }
        if item.targetType == "INVITATION" {
            return !(invitationTargets[item.itemCode] ?? "").isEmpty
        }
        return true
    }

    private func activeEffects(_ shop: ServerAPI.ArenaShop) -> some View {
        Group {
            if !shop.effects.isEmpty {
                VStack(alignment: .leading, spacing: Tokens.Space.s4) {
                    SectionRule(title: "적용 중인 기능")
                    ForEach(shop.effects) { effect in
                        HStack(alignment: .top, spacing: Tokens.Space.s4) {
                            Image(systemName: effectIcon(effect))
                                .foregroundStyle(effectTint(effect))
                                .frame(width: 28, height: 28)
                            VStack(alignment: .leading, spacing: Tokens.Space.s1) {
                                Text(itemName(effect.itemCode, shop: shop))
                                    .font(.mBodyB)
                                    .foregroundStyle(Tokens.ink)
                                Text(effectStatus(effect))
                                    .font(.mCaption)
                                    .foregroundStyle(Tokens.text2)
                            }
                            Spacer()
                            if effect.itemCode == "MATCH_ANALYSIS", effect.status == "ANALYSIS_READY" {
                                Button("분석 보기") { selectedAnalysis = effect }
                                    .buttonStyle(SecondaryButtonStyle())
                            }
                        }
                        .card(padding: Tokens.Space.s4)
                    }
                }
            }
        }
    }

    private func purchaseHistory(_ shop: ServerAPI.ArenaShop) -> some View {
        Group {
            if !shop.purchases.isEmpty {
                VStack(alignment: .leading, spacing: Tokens.Space.s4) {
                    SectionRule(title: "최근 이용 내역")
                    ForEach(shop.purchases) { purchase in
                        ViewThatFits(in: .horizontal) {
                            HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s4) {
                                purchaseIdentity(purchase)
                                Spacer()
                                purchaseBalance(purchase)
                            }
                            VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                                purchaseIdentity(purchase)
                                purchaseBalance(purchase)
                            }
                        }
                        .padding(.vertical, Tokens.Space.s2)
                        DottedRule()
                    }
                }
            }
        }
    }

    private func purchaseIdentity(_ purchase: ServerAPI.ArenaShop.Purchase) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s1) {
            Text(ArenaDisplayTerms.apply(purchase.displayName)).font(.mBodyB).foregroundStyle(Tokens.ink)
            Text("\(formatDateTime(purchase.purchasedAt)), \(ArenaDisplayTerms.purchaseStatus(purchase.status))")
                .font(.mCaption).foregroundStyle(Tokens.text3)
        }
    }

    private func purchaseBalance(_ purchase: ServerAPI.ArenaShop.Purchase) -> some View {
        Text("\(purchase.beforeAvailableDays)일에서 \(purchase.afterAvailableDays)일로")
            .font(.mNumeric)
            .foregroundStyle(Tokens.text2)
    }

    private func policyLock(_ policy: ServerAPI.ArenaShop.Policy) -> some View {
        Label(ArenaDisplayTerms.apply(policy.sundayLockMessage), systemImage: "lock.fill")
            .font(.mCaption)
            .foregroundStyle(Tokens.warningInk)
            .padding(Tokens.Space.s4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Tokens.warningSoft, in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
    }

    private func successNotice(_ message: String) -> some View {
        Label(message, systemImage: "checkmark.circle.fill")
            .font(.mCaption)
            .foregroundStyle(Tokens.successInk)
            .padding(Tokens.Space.s4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Tokens.successSoft, in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
    }

    private func policyNotice(_ policy: ServerAPI.ArenaShop.Policy) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s3) {
            Label("구매 전에 꼭 확인하세요", systemImage: "exclamationmark.shield")
                .font(.mBodyB)
                .foregroundStyle(Tokens.ink)
            Text(ArenaDisplayTerms.apply(policy.demotionMessage))
            Text(ArenaDisplayTerms.apply(policy.nonRefundableMessage))
        }
        .font(.mCaption)
        .foregroundStyle(Tokens.text2)
        .card()
    }

    private func unavailable(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s4) {
            Image(systemName: "lock.square")
                .font(.largeTitle)
                .foregroundStyle(Tokens.text3)
            Text("현재 상점을 열 수 없습니다")
                .font(.mHeading)
                .foregroundStyle(Tokens.ink)
            Text(ArenaDisplayTerms.apply(message))
                .font(.mCallout)
                .foregroundStyle(Tokens.text2)
            Button("다시 확인") { Task { await load() } }
                .buttonStyle(SecondaryButtonStyle())
        }
        .card()
    }

    private func detailLine(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s3) {
            Text(label).font(.mCaption).foregroundStyle(Tokens.text3)
            Spacer()
            Text(value).font(.mCaption).foregroundStyle(Tokens.text1).multilineTextAlignment(.trailing)
        }
    }

    private func itemName(_ code: String, shop: ServerAPI.ArenaShop) -> String {
        if let name = shop.items.first(where: { $0.itemCode == code })?.displayName {
            return ArenaDisplayTerms.apply(name)
        }
        switch code {
        case "MATCH_ANALYSIS": return "경기 상세 분석"
        case "DEFENSE_REST": return "방어 휴식"
        case "DEFENSE_SCHEDULE_PROTECTION": return "방어 일정 보호"
        case "INVITATION_ACCELERATION": return "초대 진행 가속"
        case "MAIN_PROFILE_BORDER": return "Ranked 프로필 테두리"
        case "STYLE_ENTRANCE": return "입장 장식"
        default: return "Ranked 기능"
        }
    }

    private func effectIcon(_ effect: ServerAPI.ArenaShop.Effect) -> String {
        effect.status == "PENDING" ? "clock.arrow.circlepath" : "checkmark.seal.fill"
    }

    private func effectTint(_ effect: ServerAPI.ArenaShop.Effect) -> Color {
        effect.status == "PENDING" ? Tokens.warningInk : Tokens.successInk
    }

    private func effectStatus(_ effect: ServerAPI.ArenaShop.Effect) -> String {
        if effect.status == "PENDING" { return "분석 생성 중, 실패 시 서버가 자동 반환" }
        if effect.itemCode == "MATCH_ANALYSIS", effect.status == "ANALYSIS_READY" { return "상세 분석 준비 완료" }
        if let endsAt = effect.endsAt { return "\(formatDateTime(endsAt))까지" }
        return "적용 상태를 확인하고 있습니다"
    }

    private func riskLabel(_ risk: String) -> String {
        switch risk {
        case "FINAL_DAY": return "매우 높음, 구매 뒤 마지막 1일"
        case "HIGH": return "높음, 구매 뒤 1일 이하"
        case "LOW": return "주의, 구매 뒤 3일 이하"
        default: return "보통"
        }
    }

    private func matchTargetLabel(_ target: ServerAPI.ArenaShop.MatchTarget) -> String {
        let context = "\(ArenaDisplayTerms.apply(target.divisionLabel)), \(ArenaDisplayTerms.apply(target.matchTypeLabel))"
        guard target.occurredAt != nil else { return context }
        return "\(context), \(formatDateTime(target.occurredAt))"
    }

    private func formatDate(_ value: String) -> String {
        guard let date = parseISO(value) else { return value }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    private func formatDateTime(_ value: String?) -> String {
        guard let value, let date = parseISO(value) else { return "기록 없음" }
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    private func parseISO(_ value: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }

    @MainActor
    private func load() async {
        #if DEBUG
        if applyDebugFixtureIfPresent() {
            loading = false
            return
        }
        #endif
        let ownerSlot = accountSlot
        let nextID = UUID()
        requestID = nextID
        loading = true
        do {
            let loaded = try await ServerAPI.getArenaShop()
            guard ownsRequest(nextID, slot: ownerSlot) else { return }
            shop = loaded
            errorMessage = nil
        } catch {
            guard ownsRequest(nextID, slot: ownerSlot) else { return }
            errorMessage = arenaShopReadableError(error)
            if shop == nil { successMessage = nil }
        }
        guard ownsRequest(nextID, slot: ownerSlot) else { return }
        loading = false
    }

    @MainActor
    private func buy(_ pending: PendingPurchase) async {
        guard pending.accountSlot == accountSlot,
              pending.accountSlot == DataScope.slot else { return }
        let ownerSlot = pending.accountSlot
        let nextID = UUID()
        requestID = nextID
        purchasing = true

        do {
            // B-05: 전송 전에 의도를 디스크에 새긴다 — 응답을 못 받고 앱이
            // 죽어도 다음 시도가 같은 키로 재확인할 수 있게. 저장에 실패하면
            // 요청을 보내지 않는다(키 없이 보낸 요청은 재시도가 곧 이중 차감).
            try ArenaShopPurchaseIntentStore.persist(ArenaShopPurchaseIntent(
                itemCode: pending.item.itemCode,
                relatedMatchId: pending.relatedMatchId,
                relatedInvitationId: pending.relatedInvitationId,
                operationID: pending.operationID),
                accountSlot: ownerSlot)
        } catch {
            guard ownsRequest(nextID, slot: ownerSlot) else { return }
            errorMessage = "안전한 재시도 정보를 이 기기에 저장하지 못해 요청을 보내지 않았습니다. 저장 공간을 확인한 뒤 다시 시도해 주세요."
            purchasing = false
            return
        }

        do {
            let response = try await ServerAPI.purchaseArenaShopItem(
                itemCode: pending.item.itemCode,
                relatedMatchId: pending.relatedMatchId,
                relatedInvitationId: pending.relatedInvitationId,
                operationID: pending.operationID)
            // 요청은 서버에서 원래 계정으로 완료됐을 수 있다. 화면 반영은 현재
            // 계정이 같을 때만 하고, 영수증 키 정리는 원래 슬롯에서만 수행한다.
            try? ArenaShopPurchaseIntentStore.clear(
                operationID: pending.operationID,
                accountSlot: ownerSlot)
            guard ownsRequest(nextID, slot: ownerSlot) else { return }
            shop = response.shop
            pendingPurchase = nil
            // 영수증 수신(replay 포함)이 정상 폐기 시점. clear 실패는 삼켜도
            // 안전한 방향이다 — 남은 키는 다음 구매에서 replay 영수증으로
            // 확인될 뿐, 추가 차감을 만들지 않는다.
            successMessage = response.receipt.replayed
                ? "이미 처리된 요청의 같은 구매 결과를 확인했습니다. 추가 차감은 없습니다."
                : "\(ArenaDisplayTerms.apply(response.receipt.purchase.displayName))을 적용했습니다. 잔액은 \(response.receipt.beforeAvailableDays)일에서 \(response.receipt.afterAvailableDays)일로 바뀌었습니다."
            errorMessage = nil
        } catch {
            // 확정 거절(4xx)은 서버가 이 키의 요청을 판정했다는 뜻 — 이때만
            // 폐기한다. 타임아웃·연결 유실·5xx·디코딩 실패는 '처리됐는지 모름'
            // 이므로 키를 남겨 같은 요청으로 재확인하게 한다.
            if isDefinitiveShopRejection(error) {
                try? ArenaShopPurchaseIntentStore.clear(
                    operationID: pending.operationID,
                    accountSlot: ownerSlot)
            }
            guard ownsRequest(nextID, slot: ownerSlot) else { return }
            errorMessage = arenaShopPurchaseError(error)
        }
        guard ownsRequest(nextID, slot: ownerSlot) else { return }
        purchasing = false
    }

    private func ownsRequest(_ id: UUID, slot: String) -> Bool {
        requestID == id && accountSlot == slot && DataScope.slot == slot
    }

    #if DEBUG
    /// 실계정 잔액을 건드리지 않고 상점의 상태 행렬을 검수하는 전용 픽스처.
    /// `-route arenaShop -arenaShopFixture normal|purchase|confirm|analysis|locked|failure`
    @MainActor
    private func applyDebugFixtureIfPresent() -> Bool {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-arenaShopFixture"),
              arguments.indices.contains(index + 1) else { return false }

        let fixtureName = arguments[index + 1].lowercased()
        switch fixtureName {
        case "normal":
            shop = ArenaShopFixture.make()
            successMessage = nil
        case "purchase":
            shop = ArenaShopFixture.make(includingPurchase: true)
            successMessage = "경기 상세 분석을 적용했습니다. 잔액은 12일에서 11일로 바뀌었습니다."
        case "confirm":
            let value = ArenaShopFixture.make()
            shop = value
            if let item = value.items.first(where: { $0.itemCode == "MATCH_ANALYSIS" }) {
                matchTargets[item.itemCode] = "match-fixture-2026-08-10"
                pendingPurchase = PendingPurchase(
                    item: item,
                    operationID: "fixture-operation",
                    relatedMatchId: "match-fixture-2026-08-10",
                    relatedInvitationId: nil,
                    accountSlot: accountSlot,
                    resumed: false)
            }
        case "analysis":
            let value = ArenaShopFixture.make(includingPurchase: true)
            shop = value
            fixtureAnalysis = ArenaShopFixture.analysis
            selectedAnalysis = value.effects.first(where: {
                $0.itemCode == "MATCH_ANALYSIS" && $0.status == "ANALYSIS_READY"
            })
        case "locked":
            shop = ArenaShopFixture.make(sundayLocked: true)
        case "failure":
            shop = nil
            errorMessage = "상점 정보를 불러오지 못했습니다. 잠시 후 다시 확인해 주세요."
        default:
            return false
        }
        if fixtureName != "failure" { errorMessage = nil }
        return true
    }
    #endif

    /// 4xx = 서버가 이 멱등키 요청을 확정 판정(거절)했다는 뜻.
    /// statusCode 가 없는 오류(네트워크·디코딩)는 전부 '미확정'으로 취급한다.
    private func isDefinitiveShopRejection(_ error: Error) -> Bool {
        guard let apiError = error as? ServerAPIError,
              let status = apiError.statusCode else { return false }
        return (400..<500).contains(status)
    }
}

// MARK: - 오류 문구 변환

/// B-02: 기계용 오류(영문 DecodingError 원문 등)를 학생 화면에 그대로 노출하지
/// 않는다. GoatArenaScreen 의 failurePresentation 과 같은 분류 규약.
private func arenaShopReadableError(_ error: Error) -> String {
    if error is DecodingError {
        #if DEBUG
        print("ArenaShop 디코딩 실패:", error)
        #endif
        return "상점 정보를 읽지 못했습니다. 앱을 최신 버전으로 업데이트한 뒤 다시 시도해 주세요."
    }
    if let message = (error as? ServerAPIError)?.message,
       !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        return ArenaDisplayTerms.apply(message)
    }
    if let urlError = error as? URLError {
        switch urlError.code {
        case .notConnectedToInternet, .networkConnectionLost:
            return "인터넷 연결을 확인한 뒤 상점을 다시 불러와 주세요."
        case .timedOut:
            return "상점 응답이 늦어지고 있습니다. 잠시 후 다시 시도해 주세요."
        default: break
        }
    }
    #if DEBUG
    print("ArenaShop 조회 실패:", error)
    #endif
    return "상점 정보를 불러오지 못했습니다. 잠시 후 다시 시도해 주세요."
}

/// 구매 실패 문구. 키가 보존되는 미확정 실패에서는 '같은 버튼 재시도 = 동일
/// 요청'임을 반드시 알린다 — 학생이 재시도를 겁내 이중 구매하거나 포기하지 않게.
private func arenaShopPurchaseError(_ error: Error) -> String {
    if let apiError = error as? ServerAPIError {
        if let status = apiError.statusCode, (400..<500).contains(status) {
            // 확정 거절: 키는 이미 폐기됐으므로 재시도 안내 없이 사유만 보여준다.
            return ArenaDisplayTerms.apply(
                apiError.message ?? "구매 조건을 확인하지 못했습니다. 이용 상태를 확인한 뒤 다시 시도해 주세요."
            )
        }
        let reason = ArenaDisplayTerms.apply(apiError.message ?? "서버 오류로 구매 결과를 확인하지 못했습니다.")
        return reason + " 같은 버튼을 다시 누르면 동일 요청으로 확인됩니다."
    }
    if error is DecodingError {
        #if DEBUG
        print("ArenaShop 구매 응답 디코딩 실패:", error)
        #endif
        return "구매 응답을 읽지 못했습니다. 같은 버튼을 다시 누르면 동일 요청으로 확인됩니다. 이미 처리된 구매는 추가 차감 없이 그대로 확인됩니다."
    }
    // URLError(타임아웃·연결 유실)·CancellationError 등 — 대표적인 '보냈는지 모름'.
    return "구매 결과를 확인하지 못했습니다. 같은 버튼을 다시 누르면 동일 요청으로 확인됩니다. 추가 차감은 없습니다."
}

// MARK: - 구매 멱등키 보존소

/// 미확정 구매 의도. 같은 (아이템·대상) 조합에는 항상 같은 Idempotency-Key 를
/// 다시 보내, 응답 유실 뒤의 재시도를 서버가 replay 로 판정하게 한다.
private struct ArenaShopPurchaseIntent: Codable, Equatable {
    let itemCode: String
    let relatedMatchId: String?
    let relatedInvitationId: String?
    let operationID: String

    /// 키 재사용 판단 기준 — 대상(경기·초대)이 하나라도 다르면 다른 구매다.
    func matches(itemCode: String, relatedMatchId: String?, relatedInvitationId: String?) -> Bool {
        self.itemCode == itemCode
            && self.relatedMatchId == relatedMatchId
            && self.relatedInvitationId == relatedInvitationId
    }
}

private enum ArenaShopPurchaseIntentError: Error {
    case persistenceFailed
}

/// GoatArenaDefenderCommandStore 와 같은 규약: 전송 전에 키를 디스크(계정 슬롯)에
/// 새기고, 확정 결과(영수증 수신·4xx 확정 거절·명시적 취소)에서만 지운다.
private enum ArenaShopPurchaseIntentStore {
    private static let fileName = "arena-shop-purchase-intents.json"
    private static func fileURL(for accountSlot: String) -> URL {
        DataScope.url(fileName, for: accountSlot)
    }

    /// 같은 의도의 보존된 키가 있으면 재사용(resumed), 없으면 새로 발급한다.
    /// 새 키는 아직 저장하지 않는다 — 실제 전송 직전(persist)에만 디스크에
    /// 남겨, 다이얼로그만 열고 닫은 흔적이 키로 쌓이지 않게 한다.
    static func resolve(
        itemCode: String,
        relatedMatchId: String?,
        relatedInvitationId: String?,
        accountSlot: String
    ) throws -> (operationID: String, resumed: Bool) {
        if let existing = try readAll(accountSlot: accountSlot).first(where: {
            $0.matches(itemCode: itemCode,
                       relatedMatchId: relatedMatchId,
                       relatedInvitationId: relatedInvitationId)
        }) {
            return (existing.operationID, true)
        }
        return ("shop:\(itemCode):\(UUID().uuidString)", false)
    }

    static func persist(
        _ intent: ArenaShopPurchaseIntent,
        accountSlot: String
    ) throws {
        var values = try readAll(accountSlot: accountSlot)
        if let index = values.firstIndex(where: { $0.operationID == intent.operationID }) {
            values[index] = intent
        } else {
            values.append(intent)
        }
        try write(values, accountSlot: accountSlot)
    }

    static func clear(operationID: String, accountSlot: String) throws {
        let remaining = try readAll(accountSlot: accountSlot)
            .filter { $0.operationID != operationID }
        try write(remaining, accountSlot: accountSlot)
    }

    private static func readAll(accountSlot: String) throws -> [ArenaShopPurchaseIntent] {
        let url = fileURL(for: accountSlot)
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([ArenaShopPurchaseIntent].self, from: data)
        } catch {
            // 손상된 키 파일을 빈 값으로 덮으면 응답 유실 뒤 다른 멱등키를 보내게
            // 된다. 읽을 수 없을 때는 구매 자체를 막아 이중 차감을 피한다.
            throw ArenaShopPurchaseIntentError.persistenceFailed
        }
    }

    private static func write(
        _ values: [ArenaShopPurchaseIntent],
        accountSlot: String
    ) throws {
        do {
            let data = try JSONEncoder().encode(values)
            try data.write(to: fileURL(for: accountSlot), options: .atomic)
        } catch {
            throw ArenaShopPurchaseIntentError.persistenceFailed
        }
    }
}

private struct ArenaShopAnalysisScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let effectId: String
    let accountSlot: String
    let fixture: ServerAPI.ArenaShopAnalysis?
    @State private var analysis: ServerAPI.ArenaShopAnalysis?
    @State private var errorMessage: String?
    @State private var requestID = UUID()

    var body: some View {
        NavigationStack {
            ScrollView {
                Group {
                    if let analysis { content(analysis) }
                    else if let errorMessage {
                        Text(errorMessage).font(.mCallout).foregroundStyle(Tokens.danger).card()
                    } else {
                        ProgressView("분석 결과를 불러오는 중")
                            .frame(maxWidth: .infinity, minHeight: 240)
                    }
                }
                .frame(maxWidth: Tokens.readableWidth, alignment: .leading)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, horizontalSizeClass == .compact ? Tokens.Space.s4 : Tokens.Space.s8)
                .padding(.vertical, Tokens.Space.s6)
            }
            .background(Tokens.paper)
            .navigationTitle("경기 상세 분석")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("닫기") { dismiss() } } }
            .task { await load() }
            .onDisappear { requestID = UUID() }
        }
    }

    private func content(_ analysis: ServerAPI.ArenaShopAnalysis) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s6) {
            Text("봉인된 경기 분석").font(.mMicro).foregroundStyle(Tokens.primary)
            Text("상대의 답안과 풀이 증거는 공개하지 않고, 내 경기 문제와 제출 답안만 표시합니다.")
                .font(.mCallout).foregroundStyle(Tokens.text2)
            if analysis.analysisState != "READY" {
                Label("분석 생성 중입니다. 최대 5분, 2회 재시도 뒤 실패하면 1일을 자동 반환합니다.", systemImage: "clock.arrow.circlepath")
                    .font(.mCallout).foregroundStyle(Tokens.warningInk).card()
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: Tokens.Space.s3)], spacing: Tokens.Space.s3) {
                    metric("경기 결과", analysis.result == "WIN" ? "승리" : "패배")
                    metric("점수", analysis.score.map { "\(Int($0))점" } ?? "-")
                    metric("정답", analysis.correctCount.map { "\($0)문항" } ?? "-")
                    metric("풀이시간", duration(analysis.totalSolveTimeMs))
                }
                if !analysis.weakSkills.isEmpty {
                    Label("취약 개념 \(analysis.weakSkills.joined(separator: ", "))", systemImage: "scope")
                        .font(.mBodyB).foregroundStyle(Tokens.text1).card()
                }
                ForEach(analysis.questionReviews) { question in
                    DisclosureGroup {
                        VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                            MathInline(
                                text: question.prompt,
                                font: .mBody,
                                color: Tokens.ink,
                                pixelSize: 17)
                            MathInline(
                                text: "내 답 \(question.submittedAnswer.isEmpty ? "미응답" : question.submittedAnswer), 정답 \(question.correctAnswer)",
                                font: .mCaption,
                                color: Tokens.text2,
                                pixelSize: 13)
                            MathInline(
                                text: question.solution.isEmpty ? "상세 풀이 없음" : question.solution,
                                font: .mCallout,
                                color: Tokens.text1,
                                pixelSize: 15)
                            if !question.referenceSolutionProcess.isEmpty {
                                ForEach(question.referenceSolutionProcess) { step in
                                    HStack(alignment: .top, spacing: Tokens.Space.s3) {
                                        CircledNumber(n: step.step)
                                        MathInline(
                                            text: step.explanation,
                                            font: .mCallout,
                                            color: Tokens.text2,
                                            pixelSize: 15)
                                    }
                                }
                            }
                        }
                        .padding(.top, Tokens.Space.s3)
                    } label: {
                        HStack {
                            Text("\(question.number)번").font(.mBodyB)
                            Spacer()
                            Text(question.correct ? "정답" : "복습 필요")
                                .font(.mCaption)
                                .foregroundStyle(question.correct ? Tokens.successInk : Tokens.warningInk)
                        }
                    }
                    .card()
                }
            }
        }
    }

    private func metric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s1) {
            Text(label).font(.mCaption).foregroundStyle(Tokens.text3)
            Text(value).font(.mStat).foregroundStyle(Tokens.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: Tokens.Space.s4)
    }

    private func duration(_ milliseconds: Int?) -> String {
        guard let milliseconds else { return "-" }
        let seconds = max(0, milliseconds / 1000)
        return "\(seconds / 60)분 \(String(format: "%02d", seconds % 60))초"
    }

    @MainActor
    private func load() async {
        guard accountSlot == DataScope.slot else { return }
        if let fixture {
            analysis = fixture
            return
        }
        let nextID = UUID()
        requestID = nextID
        // 분석 화면도 같은 규약: DecodingError 원문을 학생에게 보여주지 않는다.
        do {
            let loaded = try await ServerAPI.getArenaShopAnalysis(effectId: effectId)
            guard requestID == nextID, accountSlot == DataScope.slot else { return }
            analysis = loaded
        } catch {
            guard requestID == nextID, accountSlot == DataScope.slot else { return }
            errorMessage = arenaShopReadableError(error)
        }
    }
}

#if DEBUG
private enum ArenaShopFixture {
    static func make(
        includingPurchase: Bool = false,
        sundayLocked: Bool = false
    ) -> ServerAPI.ArenaShop {
        let analysisEffect = ServerAPI.ArenaShop.Effect(
            id: "effect-analysis-ready",
            itemCode: "MATCH_ANALYSIS",
            status: "ANALYSIS_READY",
            startsAt: "2026-08-10T09:00:00.000Z",
            endsAt: nil,
            appliedAt: "2026-08-10T09:00:00.000Z",
            analysisState: "READY",
            relatedMatchId: "match-fixture-2026-08-10",
            relatedInvitationId: nil)

        return ServerAPI.ArenaShop(
            generatedAt: "2026-08-10T09:30:00.000Z",
            wallet: .init(
                availableLearningDays: includingPurchase ? 11 : 12,
                minimumBalanceAfterPurchase: 1),
            policy: .init(
                versionCode: "RANKED-SHOP-2026-08",
                displayName: "Ranked 상점 운영 정책",
                effectiveFrom: "2026-08-01T00:00:00.000Z",
                sundayLocked: sundayLocked,
                sundayLockMessage: "일요일 15:00부터 월요일 00:00까지 Arena 정산 중에는 새 상점 기능을 적용할 수 없습니다.",
                demotionMessage: "구매 뒤 최소 1일의 학습일을 남겨야 하며, 모든 잔액이 소진되고 정산이 끝나면 Unranked로 전환됩니다.",
                nonRefundableMessage: "효과가 정상 적용된 뒤에는 임의 취소할 수 없습니다. 서버 처리 실패 시에는 정책에 따라 자동 반환합니다."),
            items: [
                .init(
                    itemCode: "MATCH_ANALYSIS",
                    displayName: "Arena 경기 분석권",
                    priceDays: 1,
                    releasePhase: 1,
                    eyebrow: "경기 복습",
                    description: "정산이 끝난 내 경기의 문항별 결과·풀이시간·취약 개념을 분석하고 맞춤 복습 순서를 제공합니다.",
                    targetType: "MATCH",
                    durationLabel: "경기 한 건 분석",
                    refundCondition: "5분 안에 두 번 재시도한 뒤에도 생성하지 못하면 구매를 자동 취소하고 1일을 반환합니다.",
                    purchasePreview: .init(
                        beforeAvailableDays: includingPurchase ? 11 : 12,
                        afterAvailableDays: includingPurchase ? 10 : 11,
                        purchaseEligible: true,
                        expectedEffectEndsAt: nil,
                        daysUntilAvailableBalanceExhaustion: includingPurchase ? 10 : 11,
                        demotionRisk: "NORMAL")),
                .init(
                    itemCode: "DEFENSE_REST",
                    displayName: "방어 휴식권",
                    priceDays: 1,
                    releasePhase: 1,
                    eyebrow: "일정 관리",
                    description: "24시간 동안 앞으로 배정될 일반 상향 공격의 의무 방어 후보에서 제외됩니다.",
                    targetType: "NONE",
                    durationLabel: "24시간",
                    refundCondition: "방어 편의 기능은 공통 7일에 한 번만 사용할 수 있으며 정상 적용 뒤에는 임의 취소할 수 없습니다.",
                    purchasePreview: .init(
                        beforeAvailableDays: includingPurchase ? 11 : 12,
                        afterAvailableDays: includingPurchase ? 10 : 11,
                        purchaseEligible: true,
                        expectedEffectEndsAt: "2026-08-11T09:00:00.000Z",
                        daysUntilAvailableBalanceExhaustion: includingPurchase ? 10 : 11,
                        demotionRisk: "NORMAL")),
                .init(
                    itemCode: "DEFENSE_SCHEDULE_PROTECTION",
                    displayName: "방어 일정 보호권",
                    priceDays: 2,
                    releasePhase: 2,
                    eyebrow: "일정 보호",
                    description: "조건을 충족한 의무 방어 경기를 승패 없이 종료하고 공격자에게 1일을 보상합니다.",
                    targetType: "MATCH",
                    durationLabel: "경기 배정 후 3시간 이내",
                    refundCondition: "적용 즉시 경기 종료·공격자 보상·학습일수 차감이 확정되므로 사용 뒤에는 취소할 수 없습니다.",
                    purchasePreview: .init(
                        beforeAvailableDays: includingPurchase ? 11 : 12,
                        afterAvailableDays: includingPurchase ? 9 : 10,
                        purchaseEligible: false,
                        expectedEffectEndsAt: "2026-08-13T09:00:00.000Z",
                        daysUntilAvailableBalanceExhaustion: includingPurchase ? 9 : 10,
                        demotionRisk: "NORMAL")),
                .init(
                    itemCode: "INVITATION_ACCELERATION",
                    displayName: "초대 매칭 가속권",
                    priceDays: 1,
                    releasePhase: 2,
                    eyebrow: "초대 경기",
                    description: "대기 중인 Ranked 초대 요청 한 건의 매칭 우선순위를 48시간 동안 높입니다.",
                    targetType: "INVITATION",
                    durationLabel: "48시간 또는 경기 성립 시까지",
                    refundCondition: "매칭 성립을 보장하지 않으며 정상 적용 뒤에는 임의 취소할 수 없습니다.",
                    purchasePreview: .init(
                        beforeAvailableDays: includingPurchase ? 11 : 12,
                        afterAvailableDays: includingPurchase ? 10 : 11,
                        purchaseEligible: false,
                        expectedEffectEndsAt: "2026-08-11T09:00:00.000Z",
                        daysUntilAvailableBalanceExhaustion: includingPurchase ? 10 : 11,
                        demotionRisk: "NORMAL")),
                .init(
                    itemCode: "MAIN_PROFILE_BORDER",
                    displayName: "Ranked 프로필 테두리",
                    priceDays: 2,
                    releasePhase: 1,
                    eyebrow: "시즌 장식",
                    description: "현재 시즌 동안 Ranked 프로필·랭킹·경기 결과에 전용 테두리를 적용합니다.",
                    targetType: "NONE",
                    durationLabel: "현재 시즌 종료까지",
                    refundCondition: "시즌 종료 뒤 자동 만료되며 환불하거나 다른 사용자에게 이전할 수 없습니다.",
                    purchasePreview: .init(
                        beforeAvailableDays: includingPurchase ? 11 : 12,
                        afterAvailableDays: includingPurchase ? 9 : 10,
                        purchaseEligible: true,
                        expectedEffectEndsAt: "2026-12-31T14:59:59.999Z",
                        daysUntilAvailableBalanceExhaustion: includingPurchase ? 9 : 10,
                        demotionRisk: "NORMAL")),
                .init(
                    itemCode: "STYLE_ENTRANCE",
                    displayName: "스타일 칭호·입장 연출",
                    priceDays: 1,
                    releasePhase: 1,
                    eyebrow: "시즌 장식",
                    description: "구매형 스타일 칭호와 경기 입장 연출을 적용하며 승패 판정에는 영향을 주지 않습니다.",
                    targetType: "NONE",
                    durationLabel: "현재 시즌 종료까지",
                    refundCondition: "정상 적용 뒤에는 임의 취소할 수 없으며 시즌 마지막 10일 구매분만 다음 시즌까지 한 번 이월됩니다.",
                    purchasePreview: .init(
                        beforeAvailableDays: includingPurchase ? 11 : 12,
                        afterAvailableDays: includingPurchase ? 10 : 11,
                        purchaseEligible: true,
                        expectedEffectEndsAt: "2026-12-31T14:59:59.999Z",
                        daysUntilAvailableBalanceExhaustion: includingPurchase ? 10 : 11,
                        demotionRisk: "NORMAL"))
            ],
            effects: includingPurchase ? [analysisEffect] : [],
            purchases: includingPurchase ? [
                .init(
                    id: "purchase-fixture-analysis",
                    itemCode: "MATCH_ANALYSIS",
                    displayName: "Arena 경기 분석권",
                    policyVersionCode: "RANKED-SHOP-2026-08",
                    priceDays: 1,
                    beforeAvailableDays: 12,
                    afterAvailableDays: 11,
                    status: "APPLIED",
                    purchasedAt: "2026-08-10T09:00:00.000Z",
                    reversedAt: nil,
                    reversalReason: "",
                    relatedMatchId: "match-fixture-2026-08-10",
                    relatedInvitationId: nil)
            ] : [],
            analysisTargets: [
                .init(
                    id: "match-fixture-2026-08-10",
                    divisionLabel: "Ranked",
                    matchTypeLabel: "공식 경기",
                    occurredAt: "2026-08-10T08:30:00.000Z")
            ],
            defenseProtectionTargets: [],
            invitations: [
                .init(
                    id: "invitation-fixture-01",
                    targetTier: "다이아몬드",
                    stakeDays: 2,
                    status: "PENDING",
                    createdAt: "2026-08-10T08:00:00.000Z",
                    acceleratedAt: nil,
                    accelerationEndsAt: nil)
            ])
    }

    static let analysis = ServerAPI.ArenaShopAnalysis(
        id: "analysis-fixture-ready",
        status: "READY",
        analysisState: "READY",
        relatedMatchId: "match-fixture-2026-08-10",
        result: "WIN",
        score: 84,
        correctCount: 4,
        totalSolveTimeMs: 532_000,
        incorrectQuestionKeys: ["fixture-q3"],
        weakSkills: ["함수의 극값", "정적분 계산"],
        reviewProblemCount: 2,
        checklist: ["극값 조건의 부호 변화를 다시 확인하세요."],
        questionReviews: [
            .init(
                number: 1,
                questionKey: "fixture-q1",
                courseId: "calculus",
                typeId: "extremum",
                skillTags: ["미분", "극값"],
                prompt: "함수 f(x)의 극댓값을 구하세요.",
                submittedAnswer: "4",
                correctAnswer: "4",
                correct: true,
                pointsAwarded: 20,
                responseTimeMs: 96_000,
                solution: "도함수의 부호가 양수에서 음수로 바뀌는 지점을 확인합니다.",
                referenceSolutionProcess: [
                    .init(step: 1, explanation: "f'(x)=0이 되는 후보를 찾습니다."),
                    .init(step: 2, explanation: "후보 전후의 부호 변화를 확인합니다.")
                ],
                referenceFinalCheck: "극댓값 4"),
            .init(
                number: 3,
                questionKey: "fixture-q3",
                courseId: "calculus",
                typeId: "definite-integral",
                skillTags: ["정적분"],
                prompt: "주어진 구간에서 정적분의 값을 구하세요.",
                submittedAnswer: "6",
                correctAnswer: "8",
                correct: false,
                pointsAwarded: 0,
                responseTimeMs: 128_000,
                solution: "원시함수에 상한과 하한을 각각 대입한 뒤 차를 계산합니다.",
                referenceSolutionProcess: [
                    .init(step: 1, explanation: "피적분함수의 원시함수를 구합니다."),
                    .init(step: 2, explanation: "F(b)-F(a)를 계산합니다.")
                ],
                referenceFinalCheck: "정답 8")
        ],
        generatedAt: "2026-08-10T09:03:00.000Z",
        purchasedAt: "2026-08-10T09:00:00.000Z")
}
#endif
