import SwiftUI

struct CommerceHubScreen: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    /// iPhone 가로에서는 상단바, 내비게이션 바, 하단탭, 홈 인디케이터가 화면의
    /// 3분의 1을 먹는다. 세로가 짧은 창은 섹션 간격과 제목 무게를 줄인다.
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    /// 아이콘 옆 한 줄 배치가 무너지는 지점은 폭이 아니라 글자 크기가 정한다.
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// 인앱 결제. 싱글턴인 이유는 Transaction.updates 리스너가 **화면보다 오래** 살아야
    /// 하기 때문이다(구입 요청 승인은 상점을 떠난 뒤에 온다). 여기서는 관찰만 한다.
    @ObservedObject private var iap = MatthsIAPStore.shared

    @State private var storefront: ServerAPI.CommerceStorefront?
    @State private var loading = true
    /// 구입 요청(Ask to Buy) 대기 중인 제품 ID.
    @State private var pendingApprovalMessage: String?
    @State private var errorMessage: String?
    @State private var requestID = UUID()
    @State private var accountSlot = DataScope.slot

    private var compact: Bool { horizontalSizeClass == .compact }
    private var compactHeight: Bool { verticalSizeClass == .compact }

    private var sectionSpacing: CGFloat {
        if compactHeight { return Tokens.Space.s3 }
        return compact ? Tokens.Space.s6 : Tokens.Space.s8
    }

    private var requiresLogin: Bool {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-commerceFixture") { return false }
        #endif
        return store.authProvider != "server"
    }

    // 이 화면은 **RootView 셸 안에서 열린다** — 위에 AppTopBar, 아래에 MainTabBar 가
    // safeAreaInset 으로 이미 붙어 있다. 여기에 NavigationStack 을 하나 더 두면
    // 그 내비게이션 바가 AppTopBar 뒤로 들어가 통째로 가려진다. 실측(iOS 26):
    // iPhone 세로 402pt와 iPad 11인치 세로 834pt 모두에서 "이전"과 새로고침이
    // 아예 보이지 않았고, iPhone 가로에서만 AppTopBar 와 겹친 채 윗부분이 잘렸다.
    // 즉 화면을 빠져나갈 길과 새로고침이 어느 기기에서도 손에 닿지 않았다.
    //
    // 그래서 내비게이션 바를 쓰지 않고, 같은 셸에서 사는 ProfileScreen 과 똑같이
    // 본문 머리에 조작 줄을 둔다. 크롬도 한 겹 줄어 세로 짧은 창에 유리하다.
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: sectionSpacing) {
                if compactHeight {
                    compactHeader
                } else {
                    screenControls
                    heading
                    walletBoundary
                }

                if requiresLogin {
                    loginRequired
                } else if loading {
                    loadingView
                } else if let storefront {
                    if !compactHeight || dynamicTypeSize.isAccessibilitySize {
                        accessSummary(storefront.access)
                    }
                    productSection(storefront)
                    rankedShopSection(storefront.access)
                } else if let errorMessage {
                    unavailable(errorMessage)
                }
            }
            .frame(maxWidth: Tokens.readableWidth, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, compact ? Tokens.Space.s4 : Tokens.Space.s8)
            .padding(.vertical, compactHeight ? Tokens.Space.s4 : Tokens.Space.s6)
            // safeAreaInset 은 뷰포트만 줄이고 마지막 섹션의 여백은 만들지 않는다.
            // 세로가 짧은 창에서는 이 값이 뷰포트의 4분의 1을 먹는다. RootView 의
            // AdaptiveVPadding 과 같은 판정(compact 높이면 24pt)을 쓴다.
            .padding(.bottom, compactHeight ? Tokens.Space.s6 : 76)
        }
        .background(Tokens.paper)
        .task { await load() }
        .onReceive(NotificationCenter.default.publisher(for: DataScope.didSwitchNotification)) {
            guard let newSlot = $0.object as? String, newSlot != accountSlot else { return }
            accountSlot = newSlot
            requestID = UUID()
            storefront = nil
            errorMessage = nil
            Task { await load() }
        }
    }

    /// 들어온 곳의 이름. 하단 탭 이름과 같은 말을 쓴다.
    private var backLabel: String {
        switch store.commerceOrigin {
        case .home:       return "홈"
        case .rank:       return "GOAT Arena"
        case .curriculum: return "커리큘럼"
        case .assess:     return "평가센터"
        case .wrongNotes: return "오답노트"
        case .community:  return "게시판"
        default:          return "프로필"
        }
    }

    /// 뒤로 가기와 새로고침. 두 버튼 다 44pt 를 지킨다.
    private var screenControls: some View {
        HStack(spacing: Tokens.Space.s3) {
            // 들어온 곳으로 되돌린다. 전에는 무조건 프로필로 보냈는데,
            // 홈에도 이용권·상점 문이 생기면서 홈에서 들어간 학생이 프로필로
            // 튕겨 나갔다. 나가는 곳과 버튼 이름이 어긋나면 길을 잃는다.
            Button { store.route = store.commerceOrigin } label: {
                Label(backLabel, systemImage: "chevron.left")
                    .font(.mCaption)
                    .foregroundStyle(Tokens.text3)
                    .frame(minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(backLabel)으로 돌아가기")

            Spacer(minLength: Tokens.Space.s3)

            Button { Task { await load() } } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.mBody)
                    .foregroundStyle(Tokens.primary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(loading || iap.purchasing != nil || requiresLogin)
            .accessibilityLabel("이용 상태 새로고침")
        }
    }

    /// iPhone 가로 첫 화면은 설명용 영웅 영역이 아니라 실제 상품을 보여 줘야 한다.
    /// 종전의 `조작 줄 + 3줄 제목 + 지갑 설명 카드`는 709pt 남짓한 본문을 모두 써서,
    /// 결제 화면에 들어왔는데도 첫 상품은 스크롤해야만 보였다. 세 정보를 한 행으로
    /// 합치되 돌아가기·새로고침은 각각 44pt를 유지한다.
    private var compactHeader: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s1) {
            HStack(alignment: .center, spacing: Tokens.Space.s4) {
                Button { store.route = store.commerceOrigin } label: {
                    Image(systemName: "chevron.left")
                        .font(.mBody)
                        .foregroundStyle(Tokens.text3)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(backLabel)으로 돌아가기")

                VStack(alignment: .leading, spacing: 2) {
                    if dynamicTypeSize.isAccessibilitySize {
                        Text("이용권 · Ranked 상점")
                            .font(.mHeading)
                            .foregroundStyle(Tokens.ink)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                        Text("이용권은 App Store 결제 · Ranked 기능은 학습일 사용")
                            .font(.mCaption)
                            .foregroundStyle(Tokens.text2)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text("이용권 · Ranked 상점")
                            .font(.mHeading)
                            .foregroundStyle(Tokens.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                            .accessibilityAddTraits(.isHeader)
                        Text("이용권은 App Store 결제 · Ranked 기능은 학습일 사용")
                            .font(.mCaption)
                            .foregroundStyle(Tokens.text2)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }
                }

                Spacer(minLength: Tokens.Space.s2)

                Button { Task { await load() } } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.mBody)
                        .foregroundStyle(Tokens.primary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(loading || iap.purchasing != nil || requiresLogin)
                .accessibilityLabel("이용 상태 새로고침")
            }

            // 작은 iPhone 가로에서는 별도 상태 카드 하나가 첫 상품 전체를 화면 밖으로
            // 밀었다. 기본 글자 크기에서만 같은 상태 칩을 제목 바로 아래 한 줄로 합친다.
            // 접근성 글자 크기는 축소하지 않고 아래의 상세 상태 카드를 그대로 쓴다.
            if let storefront, !dynamicTypeSize.isAccessibilitySize {
                compactAccessSummary(storefront.access)
            }
        }
        .frame(minHeight: 52)
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s3) {
            Text("결제와 경기 자산을 한곳에서 확인합니다")
                .font(.mMicro)
                .foregroundStyle(Tokens.primary)
            // 줄바꿈은 iPad 폭에서 잡은 조판이다. compact 폭에서는 강제 줄바꿈이
            // 자동 줄바꿈과 겹쳐 "이용권과 Ranked / 상점은 / 서로 다른 / 지갑입니다"
            // 처럼 네 줄로 흩어진다. 좁으면 문장을 그대로 흘려보낸다.
            Text(compact ? "이용권과 Ranked 상점은 서로 다른 지갑입니다." : "이용권과 Ranked 상점은\n서로 다른 지갑입니다.")
                .font(compact ? .mHeading : .mTitle)
                .foregroundStyle(Tokens.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text("기간 이용권은 App Store에서 결제하고, Ranked 상점은 학습일만 사용합니다.")
                .font(.mBody)
                .foregroundStyle(Tokens.text2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var walletBoundary: some View {
        VStack(spacing: 0) {
            boundaryRow(
                icon: "creditcard",
                title: "기간 이용권",
                detail: "원화, 29일 또는 30일",
                tint: Tokens.primary)
            DottedRule()
            boundaryRow(
                icon: "calendar.badge.clock",
                title: "Ranked 상점",
                detail: "학습일, 경기 분석과 일정 편의",
                tint: Tokens.successInk)
        }
        .card()
        .accessibilityElement(children: .contain)
    }

    private func boundaryRow(icon: String, title: String, detail: String, tint: Color) -> some View {
        let mark = Image(systemName: icon)
            .font(.mHeading)
            .foregroundStyle(tint)
            .frame(width: 30)
            // 지갑 종류는 바로 옆 제목이 이미 말한다. 심볼 이름까지 읽히면 소음이다.
            .accessibilityHidden(true)
        let copy = VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.mBodyB).foregroundStyle(Tokens.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(detail).font(.mCaption).foregroundStyle(Tokens.text3)
                .fixedSize(horizontal: false, vertical: true)
        }

        // 접근성 글자 크기에서는 30pt 아이콘 옆에 본문이 설 폭이 남지 않는다.
        // 실측(iPhone 세로 393pt, AX5): 제목과 설명이 아이콘 위로 겹쳐 그려져
        // "기간 이용권"과 카드 아이콘이 서로를 지웠다. 그럴 때는 ProfileScreen
        // 계정 카드와 같은 판정으로 아이콘을 본문 위에 올린다.
        // 기본 글자 크기(모든 iPad 포함)의 배치는 종전 그대로다.
        return Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                    mark
                    copy
                }
            } else {
                HStack(spacing: Tokens.Space.s4) {
                    mark
                    copy
                    Spacer(minLength: Tokens.Space.s3)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 58)
    }

    private func accessSummary(_ access: ServerAPI.CommerceStorefront.Access) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s4) {
            SectionRule(title: "현재 이용 상태")
            accessLine(
                "29일 학습 패키지",
                active: access.learningPackageActive,
                detail: access.learningPackageActive ? "학습과 공식 Arena 이용 중" : "이용 중인 패키지 없음")
            DottedRule()
            accessLine(
                "30일 모의고사 이용권",
                active: access.mockExamPackageActive,
                detail: access.mockExamPackageActive ? mockExamEndLine(access.mockExamEndsAt) : "이용 중인 이용권 없음")
        }
        .card()
    }

    /// iPhone 가로에서는 두 개의 상세 상태 행보다 구매 행동을 먼저 보여 준다.
    /// 상태 자체는 숨기지 않고, VoiceOver 에도 각각 완전한 문장으로 전달한다.
    private func compactAccessSummary(_ access: ServerAPI.CommerceStorefront.Access) -> some View {
        HStack(spacing: Tokens.Space.s4) {
            Text("현재 이용")
                .font(.mMicro)
                .foregroundStyle(Tokens.text3)
                .accessibilityHidden(true)

            compactAccessChip(
                "29일 학습",
                active: access.learningPackageActive,
                detail: access.learningPackageActive ? "이용 중" : "미이용")

            compactAccessChip(
                "30일 모의고사",
                active: access.mockExamPackageActive,
                detail: access.mockExamPackageActive ? mockExamEndLine(access.mockExamEndsAt) : "미이용")

            Spacer(minLength: 0)
        }
        .frame(minHeight: 24)
        .padding(.horizontal, Tokens.Space.s2)
        .background(Tokens.paper2, in: RoundedRectangle(cornerRadius: Tokens.Radius.sm))
    }

    private func compactAccessChip(_ title: String, active: Bool, detail: String) -> some View {
        Label {
            Text("\(title) · \(detail)")
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        } icon: {
            Image(systemName: active ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(active ? Tokens.successInk : Tokens.text4)
        }
        .font(.mCaption)
        .foregroundStyle(active ? Tokens.successInk : Tokens.text2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(detail)")
    }

    private func accessLine(_ title: String, active: Bool, detail: String) -> some View {
        let mark = Image(systemName: active ? "checkmark.circle.fill" : "circle")
            .foregroundStyle(active ? Tokens.successInk : Tokens.text4)
            .accessibilityHidden(true)
        let copy = VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.mBodyB).foregroundStyle(Tokens.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(detail).font(.mCaption).foregroundStyle(Tokens.text3)
                .fixedSize(horizontal: false, vertical: true)
        }
        let state = Text(active ? "이용 중" : "미이용")
            .font(.mMicro)
            .foregroundStyle(active ? Tokens.successInk : Tokens.text3)

        // 상태 배지를 오른쪽에 붙일 폭이 없으면 제목 아래로 내린다. 예전에는
        // "29일 학습 패키지"와 배지가 서로를 밀어 두 글자씩 잘렸다.
        return ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: Tokens.Space.s4) {
                mark.padding(.top, 2)
                copy
                Spacer(minLength: Tokens.Space.s3)
                state
            }
            .frame(minWidth: 320)

            HStack(alignment: .top, spacing: Tokens.Space.s3) {
                mark.padding(.top, 2)
                VStack(alignment: .leading, spacing: Tokens.Space.s1) {
                    copy
                    state
                }
                Spacer(minLength: 0)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func productSection(_ value: ServerAPI.CommerceStorefront) -> some View {
        VStack(alignment: .leading, spacing: compactHeight ? Tokens.Space.s3 : Tokens.Space.s5) {
            if compactHeight {
                HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s3) {
                    Text("기간 이용권")
                        .font(.mMicro)
                        .foregroundStyle(Tokens.text3)
                        .accessibilityAddTraits(.isHeader)
                    Rectangle()
                        .fill(Tokens.line)
                        .frame(height: 1)
                    Text("결제·환불은 Apple 계정에서 처리")
                        .font(.mCaption)
                        .foregroundStyle(Tokens.text3)
                        .lineLimit(1)
                }
                .frame(minHeight: 24)
            } else {
                VStack(alignment: .leading, spacing: 3) {
                    SectionRule(title: "기간 이용권")
                    Text("결제와 환불은 Apple 계정에서 처리됩니다.")
                        .font(.mCaption)
                        .foregroundStyle(Tokens.text3)
                }
            }

            ForEach(value.products) { product in
                productRow(product, checkoutEnabled: value.checkoutEnabled)
            }

            if let message = iap.lastError, !message.isEmpty {
                Label(message, systemImage: "exclamationmark.triangle")
                    .font(.mCaption)
                    .foregroundStyle(Tokens.warningInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let notice = iap.lastNotice, !notice.isEmpty {
                Label(notice, systemImage: "checkmark.circle.fill")
                    .font(.mCaption)
                    .foregroundStyle(Tokens.successInk)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("구매 복원 결과. \(notice)")
            }

            // 복원 버튼은 **애플이 요구한다.** 기기를 바꾸거나 앱을 지웠다 깐 학생이
            // 이미 산 이용권을 되찾을 길이 화면에 보여야 한다. 이게 없으면 심사에서
            // 걸리고, 걸리기 전에 학생이 먼저 돈을 두 번 낸다.
            Button {
                Task {
                    await iap.restore()
                    // 상품 재조회 성공이 방금 나온 복원 성공·실패 문구를 지우면,
                    // 사용자는 복원 버튼이 아무 일도 하지 않은 것으로 보게 된다.
                    await load(preservingPurchaseFeedback: true)
                }
            } label: {
                Label(iap.loading ? "확인 중" : "구매 내역 복원", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SecondaryButtonStyle())
            .disabled(iap.loading || iap.purchasing != nil)

            subscriptionDisclosure
        }
    }

    /// 자동갱신 구독 고지 — **애플이 요구하는 항목이다.**
    ///
    /// 자동갱신 구독을 파는 화면에는 구독 기간, 갱신 방식, 해지 방법, 그리고
    /// **이용약관과 개인정보처리방침 링크**가 있어야 한다. 링크가 없으면 심사지침
    /// 3.1.2 로 반려된다. 상품 설명 어딘가에 적어 두는 것으로는 부족하고,
    /// 구매 버튼이 있는 화면에서 손이 닿아야 한다.
    ///
    /// 링크는 SFSafariViewController 가 아니라 Link 로 연다. 이 화면에서
    /// SafariServices 를 다시 들이면 계약 테스트가 막는다 — 그 금지는 결제 경로가
    /// 되살아나는 것을 잡으려는 것이고(심사지침 3.1.1), 약관 열람은 그것과 다르지만
    /// 같은 화면에 그 임포트를 되살려 두면 다음 사람이 결제에도 쓴다.
    private var subscriptionDisclosure: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
            Text("구독은 기간이 끝나기 24시간 전에 자동으로 갱신되고 Apple 계정으로 청구됩니다. 해지는 기기의 설정 → Apple 계정 → 구독에서 언제든 할 수 있고, 갱신 24시간 전까지 해지하면 다음 청구가 없습니다.")
                .font(.mCaption)
                .foregroundStyle(Tokens.text3)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: Tokens.Space.s4) {
                Link("이용약관", destination: Self.termsURL)
                Link("개인정보처리방침", destination: Self.privacyURL)
            }
            .font(.mCaption)
            .foregroundStyle(Tokens.primary)
            .frame(minHeight: 44)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 서버 주소에서 만든다. 운영·검수 서버가 갈릴 때 링크만 옛 주소로 남는 일을 막는다.
    private static var termsURL: URL {
        ServerAPI.baseURL.appendingPathComponent("terms")
    }

    private static var privacyURL: URL {
        ServerAPI.baseURL.appendingPathComponent("privacy")
    }

    private func productRow(
        _ product: ServerAPI.CommerceStorefront.Product,
        checkoutEnabled: Bool
    ) -> some View {
        Group {
            if compactHeight && !dynamicTypeSize.isAccessibilitySize {
                compactProductRow(product, checkoutEnabled: checkoutEnabled)
            } else {
                regularProductRow(product, checkoutEnabled: checkoutEnabled)
            }
        }
    }

    private func regularProductRow(
        _ product: ServerAPI.CommerceStorefront.Product,
        checkoutEnabled: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s4) {
            productHeader(product)

            Text(product.description)
                .font(.mBody)
                .foregroundStyle(Tokens.text2)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                ForEach(product.features, id: \.self) { feature in
                    Label(feature, systemImage: "checkmark")
                        .font(.mCaption)
                        .foregroundStyle(Tokens.text2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if product.current {
                Label("현재 이용 중", systemImage: "checkmark.seal.fill")
                    .font(.mBodyB)
                    .foregroundStyle(Tokens.successInk)
                    .frame(minHeight: 44)
            }

            purchaseControls(product, checkoutEnabled: checkoutEnabled)
        }
        .card()
    }

    /// 2868×1320 iPhone 가로 첫 화면에서 상품명·용도·가격·구매 버튼을 함께 보인다.
    /// 세로 화면과 접근성 글자 크기는 정보가 잘리지 않는 기존 세로 카드를 유지한다.
    private func compactProductRow(
        _ product: ServerAPI.CommerceStorefront.Product,
        checkoutEnabled: Bool
    ) -> some View {
        HStack(alignment: .center, spacing: Tokens.Space.s5) {
            VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                Text(product.name)
                    .font(.mHeading)
                    .foregroundStyle(Tokens.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text("\(product.periodLabel) · \(product.description)")
                    .font(.mCaption)
                    .foregroundStyle(Tokens.text2)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if product.current {
                Label("현재 이용 중", systemImage: "checkmark.seal.fill")
                    .font(.mBodyB)
                    .foregroundStyle(Tokens.successInk)
                    .frame(minWidth: 220, minHeight: 44)
            } else {
                purchaseControls(product, checkoutEnabled: checkoutEnabled)
                    .frame(width: 290, alignment: .trailing)
            }
        }
        .frame(minHeight: 76)
        .card()
        .accessibilityElement(children: .contain)
    }

    /// 결제 줄. **App Store 인앱 결제만** 쓴다.
    ///
    /// 전에는 여기서 서버 핸드오프로 토스 결제창을 열었다(그것도 #if DEBUG 안에만 있었다).
    /// 앱 안에서 쓰는 디지털 콘텐츠를 외부 결제로 파는 것은 심사지침 3.1.1 위반이라
    /// iOS 에서는 그 길을 완전히 닫았다. 웹 브라우저에서 토스로 결제하는 길은 그대로다.
    ///
    /// "부모님께 요청" 버튼도 없앴다. 애플의 **구입 요청(Ask to Buy)** 이 같은 일을
    /// 시스템 차원에서 더 잘 한다 — 가족 공유에 묶인 자녀 계정이 구매를 누르면 부모
    /// 기기로 승인 요청이 가고, 승인되면 Transaction.updates 로 우리에게 도착한다.
    @ViewBuilder
    private func purchaseControls(
        _ product: ServerAPI.CommerceStorefront.Product,
        checkoutEnabled: Bool
    ) -> some View {
        if product.current {
            // 이미 이용 중이면 다시 살 수 없다. 서버도 잔액이 0일 때만 재구매를 연다.
            EmptyView()
        } else if let item = MatthsProduct(serverCode: product.code) {
            let storeProduct = iap.product(for: item)
            let busy = iap.purchasing == item.rawValue

            VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                if let storeProduct {
                    Button {
                        Task { await buy(item) }
                    } label: {
                        // 가격은 **App Store 가 준 문자열**을 쓴다. 서버 금액을 그대로 찍으면
                        // 통화·세금·지역 할인이 어긋나 애플이 실제로 청구하는 값과 달라진다.
                        Text(busy ? "결제 중" : "\(storeProduct.displayPrice) 결제")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!checkoutEnabled || iap.purchasing != nil || iap.loading)

                    Text(item == .learningPass
                         ? "1개월 자동 갱신 · 결제마다 29일 학습 사이클"
                         : "1개월 자동 갱신")
                        .font(.mCaption)
                        .foregroundStyle(Tokens.text3)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .accessibilityLabel(item == .learningPass
                                            ? "한 달마다 자동 갱신되며, 결제마다 29일 학습 사이클을 제공합니다"
                                            : "한 달마다 자동 갱신됩니다")
                } else if iap.loading {
                    Button("가격 확인 중") {}
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(true)
                } else {
                    // 실패 상태를 비활성 `결제` 버튼으로만 표현하면 복구할 길을 찾기
                    // 어렵다. 특히 iPhone 가로에서는 상단 새로고침 아이콘과 카드가
                    // 멀리 떨어지므로, 문제가 난 바로 그 카드에서 재시도하게 한다.
                    Button {
                        Task { await iap.loadProducts() }
                    } label: {
                        Label("가격 다시 불러오기", systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(iap.purchasing != nil)
                }

                if !checkoutEnabled {
                    Text("현재 판매가 잠시 중지되었습니다.")
                        .font(.mCaption)
                        .foregroundStyle(Tokens.warningInk)
                }

                if checkoutEnabled && storeProduct == nil {
                    Text(iap.loading ? "App Store에서 가격을 불러오는 중입니다."
                                     : "App Store 가격이 아직 준비되지 않았습니다.")
                        .font(.mCaption)
                        .foregroundStyle(Tokens.text3)
                }

                if let pending = pendingApprovalMessage, pending == item.rawValue {
                    Label("가족 공유 승인을 기다리는 중입니다. 승인되면 자동으로 열립니다.",
                          systemImage: "clock")
                        .font(.mCaption)
                        .foregroundStyle(Tokens.warningInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        } else {
            Text("이 상품은 앱에서 결제할 수 없습니다.")
                .font(.mCaption)
                .foregroundStyle(Tokens.text3)
        }
    }

    private func buy(_ item: MatthsProduct) async {
        pendingApprovalMessage = nil
        switch await iap.purchase(item) {
        case .granted:
            await load()
        case .pendingApproval:
            pendingApprovalMessage = item.rawValue
        case .cancelled:
            break
        }
    }

    /// 상품명(22pt bold)과 가격(22pt bold)을 한 줄에 두면 320pt Slide Over 와
    /// iPhone 세로에서 둘 다 잘린다. 폭이 판단하게 두고 가격을 아래로 내린다.
    private func productHeader(
        _ product: ServerAPI.CommerceStorefront.Product
    ) -> some View {
        let name = VStack(alignment: .leading, spacing: 2) {
            Text(product.name).font(.mHeading).foregroundStyle(Tokens.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(product.periodLabel).font(.mCaption).foregroundStyle(Tokens.text3)
        }
        // 가격은 **App Store 가 준 값이 우선**이다.
        //
        // 서버의 amount 는 웹 결제(토스) 기준이라, App Store Connect 에 등록한 가격과
        // 어긋날 수 있다. 등록가를 바꾸고 서버 정책을 안 고치면 학생이 보는 금액과
        // 애플이 실제로 청구하는 금액이 달라진다 — 그건 표시 오류가 아니라 분쟁거리다.
        // 그래서 애플 값이 있으면 그것을 쓰고, 없을 때만 서버 값으로 내려앉는다
        // (그 상태에서는 결제 버튼도 비활성이라 실제 청구가 일어나지 않는다).
        let displayPrice = MatthsProduct(serverCode: product.code)
            .flatMap { iap.product(for: $0)?.displayPrice }
            ?? formattedKRW(product.amount)
        let price = Text(displayPrice)
            .font(.mHeading)
            .foregroundStyle(Tokens.ink)
            .fixedSize(horizontal: true, vertical: false)

        return ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s3) {
                name
                Spacer(minLength: Tokens.Space.s3)
                price
            }

            VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                name
                price
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func rankedShopSection(_ access: ServerAPI.CommerceStorefront.Access) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s5) {
            SectionRule(title: "Ranked 상점")
            Text("현금 결제가 아닙니다. 서버가 확정한 학습일 잔액과 현재 사이클 조건만 사용합니다.")
                .font(.mBody)
                .foregroundStyle(Tokens.text2)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                Label("경기 상세 분석", systemImage: "chart.xyaxis.line")
                Label("경기 일정 편의", systemImage: "calendar.badge.clock")
                Label("시즌 장식과 활성 효과", systemImage: "sparkles")
            }
            .font(.mCaption)
            .foregroundStyle(Tokens.text2)

            if access.rankedShopAvailable {
                Button {
                    store.route = .arenaShop
                } label: {
                    Label("Ranked 상점 열기", systemImage: "bag.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityHint("학습일로 이용하는 Ranked 전용 기능을 엽니다")
            } else {
                Button {
                    store.route = .rank
                } label: {
                    Label("GOAT Arena에서 이용 조건 확인", systemImage: "lock.open.display")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryButtonStyle())
                .accessibilityHint("현재 사이클과 이용권 상태를 확인합니다")
            }
        }
        .card()
    }

    private var loginRequired: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s4) {
            Label("로그인이 필요합니다", systemImage: "person.crop.circle.badge.exclamationmark")
                .font(.mHeading)
                .foregroundStyle(Tokens.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text("구매 내역과 학습일 잔액은 계정 소유 정보라 로그인 뒤 확인합니다.")
                .font(.mBody)
                .foregroundStyle(Tokens.text2)
                .fixedSize(horizontal: false, vertical: true)
            Button("로그인하기") { store.signOut() }
                .buttonStyle(PrimaryButtonStyle())
        }
        .card()
    }

    private var loadingView: some View {
        HStack(spacing: Tokens.Space.s3) {
            ProgressView()
            Text("이용 상태를 확인하고 있습니다.")
                .font(.mBody)
                .foregroundStyle(Tokens.text2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(minHeight: 72)
        .accessibilityElement(children: .combine)
    }

    private func unavailable(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s4) {
            Label("이용권 정보를 불러오지 못했습니다", systemImage: "exclamationmark.triangle.fill")
                .font(.mHeading)
                .foregroundStyle(Tokens.warningInk)
                .fixedSize(horizontal: false, vertical: true)
            Text(message).font(.mBody).foregroundStyle(Tokens.text2)
                .fixedSize(horizontal: false, vertical: true)
            Button("다시 확인") { Task { await load() } }
                .buttonStyle(SecondaryButtonStyle())
        }
        .card()
    }

    @MainActor
    private func load(preservingPurchaseFeedback: Bool = false) async {
        let id = UUID()
        requestID = id
        let slot = DataScope.slot
        accountSlot = slot
        loading = true
        errorMessage = nil

        // App Store 가격 조회를 **맨 앞에서, 조기 반환보다 먼저** 건다.
        //
        // 이 값은 우리 서버와도 로그인 상태와도 무관하다 — 애플에서 직접 온다.
        // 아래 두 조기 반환(디버그 픽스처, 비로그인) 뒤에 두었더니 그 경로에서
        // 가격이 영영 안 들어와 결제 버튼이 비활성으로 남았다. QA 픽스처로 화면을
        // 볼 때도 값이 비어서, 정작 확인해야 할 것이 안 보였다.
        async let appStorePrices: Void = iap.loadProducts(
            preservingFeedback: preservingPurchaseFeedback)

        #if DEBUG
        if applyDebugFixtureIfPresent() {
            await appStorePrices
            loading = false
            return
        }
        #endif

        guard store.authProvider == "server" else {
            await appStorePrices
            storefront = nil
            loading = false
            return
        }
        do {
            let value = try await ServerAPI.getCommerceStorefront()
            await appStorePrices
            guard requestID == id, DataScope.slot == slot else { return }
            storefront = value
        } catch {
            await appStorePrices
            guard requestID == id, DataScope.slot == slot else { return }
            storefront = nil
            errorMessage = commerceReadableError(error)
        }
        guard requestID == id, DataScope.slot == slot else { return }
        loading = false
    }

    private func formattedKRW(_ amount: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return "\(formatter.string(from: NSNumber(value: amount)) ?? String(amount))원"
    }

    private func mockExamEndLine(_ value: String?) -> String {
        guard let value, !value.isEmpty else { return "이용 중" }
        return "만료 시각 \(String(value.prefix(10)))"
    }

    #if DEBUG
    @MainActor
    private func applyDebugFixtureIfPresent() -> Bool {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-commerceFixture"),
              arguments.indices.contains(index + 1) else { return false }
        let fixture = arguments[index + 1].lowercased()
        switch fixture {
        case "active":
            storefront = CommerceHubFixture.make(active: true, checkoutEnabled: true)
        case "open":
            storefront = CommerceHubFixture.make(active: false, checkoutEnabled: true)
        case "closed":
            storefront = CommerceHubFixture.make(active: false, checkoutEnabled: false)
        case "failure":
            storefront = nil
            errorMessage = "서버 연결을 확인한 뒤 다시 시도해 주세요."
        default:
            return false
        }
        return true
    }
    #endif
}

private func commerceReadableError(_ error: Error) -> String {
    if error is DecodingError {
        return "이용권 정보를 읽지 못했습니다. 앱을 최신 버전으로 업데이트해 주세요."
    }
    if let apiError = error as? ServerAPIError,
       let message = apiError.message, !message.isEmpty {
        return message
    }
    if error is URLError {
        return "인터넷 연결을 확인한 뒤 다시 시도해 주세요."
    }
    return "잠시 후 다시 시도해 주세요."
}

#if DEBUG
private enum CommerceHubFixture {
    static func make(active: Bool, checkoutEnabled: Bool) -> ServerAPI.CommerceStorefront {
        ServerAPI.CommerceStorefront(
            generatedAt: "2026-08-15T00:00:00.000Z",
            checkoutEnabled: checkoutEnabled,
            currency: "KRW",
            access: .init(
                packageType: active ? "LEARNING_PACKAGE_29" : nil,
                learningPackageActive: active,
                mockExamPackageActive: false,
                arenaAllowed: active,
                rankedShopAvailable: active,
                mockExamEndsAt: nil),
            products: [
                .init(
                    code: "LEARNING_PACKAGE_29",
                    name: "29일 학습 패키지",
                    amount: 29_000,
                    periodLabel: "29일",
                    description: "학습 사이클과 GOAT Arena 공식 경기를 함께 이용합니다.",
                    features: ["모의고사와 배치고사", "GOAT Arena 공식 경기", "29일 학습 사이클"],
                    current: active),
                .init(
                    code: "MOCK_EXAM_ONLY",
                    name: "모의고사 이용권",
                    amount: 9_900,
                    periodLabel: "30일",
                    description: "주간 공식 모의고사와 응시 기록을 확인합니다.",
                    features: ["주간 공식 모의고사", "응시 기록과 성적 확인", "30일 이용"],
                    current: false),
            ])
    }
}
#endif
