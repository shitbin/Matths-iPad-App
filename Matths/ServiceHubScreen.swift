import SwiftUI

/// 앱 로그인이 없어도 열려야 하는 서버 공개 문서와 일회용 링크.
///
/// 이 주소를 일반 앱 라우트로 삼키면 유니버설 링크가 앱을 깨운 뒤 아무 화면도
/// 띄우지 않는 문제가 생긴다. 특히 비밀번호 재설정 메일의 token은 서버 세션에서
/// 검증하므로 네이티브 화면으로 임의 변환하지 않고, 같은 호스트의 원래 URL을
/// SFSafariViewController에 그대로 넘긴다.
struct PublicServerWebDestination: Identifiable, Hashable {
    let url: URL

    var id: String { url.absoluteString }

    /// 보호자 센터는 학생 Bearer 세션과 별도 계정·쿠키를 사용한다. 앱의 학생 세션을
    /// 웹 세션으로 교환하지 않고 보호자 경로를 그대로 열어 계정 경계를 보존한다.
    static func parentPortal(path: String = "/parent/login") -> PublicServerWebDestination? {
        let normalized = path.lowercased()
        guard normalized == "/parent" || normalized.hasPrefix("/parent/"),
              !path.hasPrefix("//"),
              let url = URL(string: path, relativeTo: ServerAPI.baseURL)?.absoluteURL,
              isTrustedParentURL(url) else { return nil }
        return PublicServerWebDestination(url: url)
    }

    private static func isTrustedParentURL(_ url: URL) -> Bool {
        guard HostedPortalDestination.isTrustedServerURL(url) else { return false }
        let path = url.path.lowercased()
        return path == "/parent" || path.hasPrefix("/parent/")
    }

    static func fromDeepLink(_ url: URL) -> PublicServerWebDestination? {
        guard HostedPortalDestination.isTrustedServerURL(url) else { return nil }
        let path = url.path.lowercased()
        let isPublicDocument = path == "/terms" || path == "/privacy"
        let isPasswordRecovery = path == "/forgot-password"
            || path == "/forgot-password/link"
        // 학부모 계정은 학생/교사 앱 세션과 별도 세션을 사용한다. 초대 링크를
        // 일반 포털 handoff로 바꾸지 않아야 기존 학부모 로그인·가입 흐름이 유지된다.
        let isParentInvite = path.hasPrefix("/parent/invite/")

        guard isPublicDocument || isPasswordRecovery || isParentInvite else { return nil }
        return PublicServerWebDestination(url: url)
    }
}

/// 서버가 세션으로만 제공하는 기능을 앱 안에서 여는 목적지.
/// 경로는 서버 내부 절대 경로만 허용하고 결제 표면은 CommunityWebModel이 StoreKit으로 돌린다.
struct HostedPortalDestination: Identifiable, Hashable {
    let path: String
    let title: String
    let detail: String
    let icon: String

    var id: String { path }

    static let studentAcademy = HostedPortalDestination(
        path: "/my-academy", title: "내 학원", detail: "수업 주차, 자료, 출석과 소속 상태", icon: "building.2.fill")
    static let teacherAcademy = HostedPortalDestination(
        path: "/academy", title: "학원 관리", detail: "학생·선생님·반·주차·출석 관리", icon: "person.3.fill")
    static let admin = HostedPortalDestination(
        path: "/admin", title: "운영 관리자", detail: "사용자, 학원, 시험, 정산과 운영 현황", icon: "wrench.and.screwdriver.fill")
    static let archive = HostedPortalDestination(
        path: "/archive", title: "자료실", detail: "운영자가 공개한 학습 자료와 파일", icon: "archivebox.fill")
    static let studyStore = HostedPortalDestination(
        path: "/store", title: "학습 콘텐츠", detail: "무료 자료와 공개된 학습 콘텐츠", icon: "books.vertical.fill")
    static let coachSuggestions = HostedPortalDestination(
        path: "/coach-suggestions", title: "코치 의견함", detail: "학습 코치에 제안하고 처리 상태 확인", icon: "bubble.left.and.text.bubble.right.fill")
    static let support = HostedPortalDestination(
        path: "/contact", title: "문의하기", detail: "계정·학습·결제 문제를 운영팀에 전달", icon: "questionmark.bubble.fill")
    static let faq = HostedPortalDestination(
        path: "/faq", title: "자주 묻는 질문", detail: "서비스 이용 방법과 자주 생기는 문제", icon: "questionmark.circle.fill")
    static let parent = HostedPortalDestination(
        path: "/parent/login", title: "보호자 센터", detail: "별도 보호자 계정으로 자녀 연결·결제 관리", icon: "figure.and.child.holdinghands")

    /// 알림·유니버설 링크가 가리킨 하위 페이지를 목록 첫 화면으로 뭉개지 않고 그대로 연다.
    /// 포털이 소유한 서버 내부 경로만 허용하며, 디지털 결제 경로는 항상 네이티브
    /// StoreKit 화면이 소유한다.
    static func fromInternalHref(_ rawHref: String) -> HostedPortalDestination? {
        let withoutFragment = rawHref.split(separator: "#", maxSplits: 1)
            .first.map(String.init) ?? rawHref
        let path = withoutFragment.split(separator: "?", maxSplits: 1)
            .first.map(String.init) ?? withoutFragment
        let normalized = path.lowercased()
        guard path.hasPrefix("/"), !path.hasPrefix("//"),
              !ServerAPI.isWebPurchasePath(path) else { return nil }

        let base: HostedPortalDestination?
        switch normalized {
        case let value where value == "/my-academy" || value.hasPrefix("/my-academy/"):
            base = .studentAcademy
        case let value where value == "/academy/join" || value.hasPrefix("/academy/join/"):
            base = .studentAcademy
        case let value where value == "/academy" || value.hasPrefix("/academy/"):
            base = .teacherAcademy
        case let value where value == "/profile/academy" || value.hasPrefix("/profile/academy/"):
            base = .studentAcademy
        case let value where value == "/admin" || value.hasPrefix("/admin/"):
            base = .admin
        case let value where value == "/archive" || value.hasPrefix("/archive/"):
            base = .archive
        case let value where value == "/store" || value.hasPrefix("/store/"):
            base = .studyStore
        case let value where value == "/coach-suggestions" || value.hasPrefix("/coach-suggestions/"):
            base = .coachSuggestions
        case let value where value == "/contact" || value.hasPrefix("/contact/"):
            base = .support
        case let value where value == "/faq" || value.hasPrefix("/faq/"):
            base = .faq
        case let value where value == "/parent" || value.hasPrefix("/parent/"):
            base = .parent
        default:
            base = nil
        }
        guard let base else { return nil }
        return HostedPortalDestination(path: withoutFragment,
                                       title: base.title,
                                       detail: base.detail,
                                       icon: base.icon)
    }

    /// 같은 서버의 https 유니버설 링크와 `matths://service?path=…`만 포털로 승격한다.
    static func fromDeepLink(_ url: URL) -> HostedPortalDestination? {
        if url.scheme?.lowercased() == "matths", url.host?.lowercased() == "service",
           let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let path = components.queryItems?.first(where: { $0.name == "path" })?.value {
            return fromInternalHref(path)
        }

        guard isTrustedServerURL(url) else { return nil }
        let href = url.query.map { "\(url.path)?\($0)" } ?? url.path
        return fromInternalHref(href)
    }

    static func isTrustedServerURL(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "https",
              let incomingHost = url.host?.lowercased(),
              let serverHost = ServerAPI.baseURL.host?.lowercased() else { return false }
        func unprefixed(_ host: String) -> String {
            host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
        }
        return unprefixed(incomingHost) == unprefixed(serverHost)
    }
}

/// 홈의 여러 보조 기능을 한 문으로 모은 역할 기반 서비스 허브.
struct ServiceHubScreen: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private var role: String {
        store.serverProfile?.role?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            ?? "student"
    }

    private var primaryDestination: HostedPortalDestination {
        switch role {
        case "admin": .admin
        case "teacher": .teacherAcademy
        default: .studentAcademy
        }
    }

    var body: some View {
        Group {
            if verticalSizeClass == .compact && !dynamicTypeSize.isAccessibilitySize {
                compactLandscapeLayout
            } else {
                VStack(alignment: .leading, spacing: Tokens.Space.s7) {
                    header
                    primaryAction
                    commonServices
                    supportServices
                }
            }
        }
    }

    /// iPhone 가로모드의 첫 화면. 역할별 주 기능과 나머지 7개 목적지를 모두 보여 줘
    /// "아래에 더 있는지" 추측하거나 첫 동작 전에 스크롤하지 않게 한다.
    private var compactLandscapeLayout: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s3) {
            HStack(spacing: Tokens.Space.s3) {
                Button {
                    store.route = store.serviceOrigin
                } label: {
                    Label("이전", systemImage: "chevron.left")
                        .font(.mCaption)
                        .foregroundStyle(Tokens.text3)
                        .frame(minWidth: 64, minHeight: 44)
                }
                .buttonStyle(.plain)

                Text("학원·서비스")
                    .font(.mHeading)
                    .foregroundStyle(Tokens.ink)
                    .accessibilityAddTraits(.isHeader)
                Text("관리·자료·지원 기능")
                    .font(.mCaption)
                    .foregroundStyle(Tokens.text3)
                Spacer(minLength: 0)
                ExamRule()
                    .frame(maxWidth: 180)
            }

            HStack(alignment: .top, spacing: Tokens.Space.s3) {
                compactPrimaryAction
                    .frame(width: 236)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Tokens.Space.s2),
                                         count: 3),
                          spacing: Tokens.Space.s2) {
                    compactCommerceButton
                    ForEach([
                        HostedPortalDestination.archive,
                        .studyStore,
                        .coachSuggestions,
                        .support,
                        .faq,
                        .parent,
                    ]) { destination in
                        compactPortalButton(destination)
                    }
                }
            }
        }
    }

    private var compactPrimaryAction: some View {
        Button { openPrimaryDestination() } label: {
            VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                HStack {
                    Image(systemName: primaryDestination.icon)
                        .font(.system(size: 22, weight: .semibold))
                    Spacer()
                    Image(systemName: "arrow.right")
                }
                .accessibilityHidden(true)
                Spacer(minLength: 0)
                Text(primaryDestination.title)
                    .font(.mHeading)
                Text(primaryDestination.detail)
                    .font(.mCaption)
                    .foregroundStyle(Tokens.onBrand.opacity(0.78))
                    .lineLimit(2)
            }
            .foregroundStyle(Tokens.onBrand)
            .padding(Tokens.Space.s4)
            .frame(maxWidth: .infinity, minHeight: 190, alignment: .leading)
            .background(Tokens.actionPrimary,
                        in: RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(primaryDestination.title), \(primaryDestination.detail)")
    }

    private var compactCommerceButton: some View {
        compactServiceButton(title: "이용권·상점", icon: "bag.fill") {
            store.route = .commerce
        }
    }

    private func compactPortalButton(_ destination: HostedPortalDestination) -> some View {
        compactServiceButton(title: destination.title, icon: destination.icon) {
            store.openHostedPortal(destination)
        }
    }

    private func compactServiceButton(title: String, icon: String,
                                      action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Tokens.primary)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.mCaption)
                    .foregroundStyle(Tokens.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .padding(.horizontal, Tokens.Space.s3)
            .padding(.vertical, Tokens.Space.s2)
            .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
            .background(Tokens.surface,
                        in: RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous)
                    .strokeBorder(Tokens.line, lineWidth: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
            Button {
                store.route = store.serviceOrigin
            } label: {
                Label("이전 화면", systemImage: "chevron.left")
                    .font(.mCaption)
                    .foregroundStyle(Tokens.text3)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Text("학원·서비스")
                .font(verticalSizeClass == .compact ? .mHeading : .mTitle)
                .foregroundStyle(Tokens.ink)
                .accessibilityAddTraits(.isHeader)
            Text("공부 화면에 섞지 않은 관리·자료·지원 기능을 여기 모았습니다.")
                .font(.mCallout)
                .foregroundStyle(Tokens.text2)
                .fixedSize(horizontal: false, vertical: true)
            ExamRule()
        }
    }

    private var primaryAction: some View {
        Button { openPrimaryDestination() } label: {
            HStack(spacing: Tokens.Space.s4) {
                Image(systemName: primaryDestination.icon)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(Tokens.onBrand)
                    .frame(width: 52, height: 52)
                    .background(Tokens.brandVioletDeep, in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(primaryDestination.title)
                        .font(.mHeading)
                        .foregroundStyle(Tokens.onBrand)
                    Text(primaryDestination.detail)
                        .font(.mCaption)
                        .foregroundStyle(Tokens.onBrand.opacity(0.78))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: Tokens.Space.s3)
                Image(systemName: "arrow.right")
                    .foregroundStyle(Tokens.onBrand)
                    .accessibilityHidden(true)
            }
            .padding(Tokens.Space.s5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Tokens.actionPrimary,
                        in: RoundedRectangle(cornerRadius: Tokens.Radius.xl, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(primaryDestination.title), \(primaryDestination.detail)")
    }

    private func openPrimaryDestination() {
        store.openHostedPortal(primaryDestination)
    }

    private var commonServices: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s3) {
            SectionRule(title: "학습과 이용")
            serviceGrid([
                .archive,
                .studyStore,
                .coachSuggestions,
            ], includesCommerce: true)
        }
    }

    private var supportServices: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s3) {
            SectionRule(title: "지원")
            serviceGrid([.support, .faq, .parent], includesCommerce: false)
        }
    }

    @ViewBuilder
    private func serviceGrid(_ destinations: [HostedPortalDestination],
                             includesCommerce: Bool) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: Tokens.Space.s2) {
                if includesCommerce { commerceButton }
                ForEach(destinations) { destination in portalButton(destination) }
            }
        } else {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 230), spacing: Tokens.Space.s3)],
                      spacing: Tokens.Space.s3) {
                if includesCommerce { commerceButton }
                ForEach(destinations) { destination in portalButton(destination) }
            }
        }
    }

    private var commerceButton: some View {
        serviceButton(title: "이용권과 Ranked 상점",
                      detail: "구독 상태, 구매 복원과 Arena 상점",
                      icon: "bag.fill") {
            store.route = .commerce
        }
    }

    private func portalButton(_ destination: HostedPortalDestination) -> some View {
        serviceButton(title: destination.title,
                      detail: destination.detail,
                      icon: destination.icon) {
            store.openHostedPortal(destination)
        }
    }

    private func serviceButton(title: String, detail: String, icon: String,
                               action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: Tokens.Space.s3) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Tokens.primary)
                    .frame(width: 24, height: 24)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.mBodyB)
                        .foregroundStyle(Tokens.ink)
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
            .padding(Tokens.Space.s4)
            .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
            .background(Tokens.surface,
                        in: RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                    .strokeBorder(Tokens.line, lineWidth: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title), \(detail)")
    }
}

/// 역할별 웹 기능을 앱 로그인 세션으로 여는 공통 셸.
struct HostedServicePortalScreen: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @StateObject private var model = CommunityWebModel()

    let destination: HostedPortalDestination

    private var signedIn: Bool { store.authProvider == "server" }
    private var obscuresWebContent: Bool {
        (model.isLoading && !model.hasDisplayedPage) || model.loadFailure != nil || model.loginRequired
    }

    var body: some View {
        VStack(spacing: 0) {
            controls
            progressLine
            if let notice = model.sessionNotice {
                sessionNotice(notice)
            }
            GeometryReader { viewport in
                ZStack {
                    CommunityWebView(model: model)
                        .background(Tokens.paper)
                        .accessibilityHidden(obscuresWebContent)
                    if model.isLoading && !model.hasDisplayedPage { loadingCard }
                    if let failure = model.loadFailure { failureCard(failure.message) }
                    if model.loginRequired || !signedIn { loginCard }
                }
                .task(id: "\(destination.id)|\(signedIn)|\(Int(viewport.size.width))x\(Int(viewport.size.height))") {
                    guard viewport.size.width > 1, viewport.size.height > 1 else { return }
                    await Task.yield()
                    model.start(signedIn: signedIn, path: destination.path)
                }
            }
        }
        .background(Tokens.paper)
        .onAppear { model.updateAccessibility(size: dynamicTypeSize) }
        .onChange(of: dynamicTypeSize) { _, size in model.updateAccessibility(size: size) }
        .onChange(of: store.authProvider) { _, _ in
            model.accountDidChange()
            model.start(signedIn: signedIn, path: destination.path)
        }
        .onReceive(NotificationCenter.default.publisher(for: DataScope.didSwitchNotification)) { _ in
            model.accountDidChange()
            model.start(signedIn: signedIn, path: destination.path)
        }
        .onChange(of: model.wantsNativeCommerce) { _, wants in
            guard wants else { return }
            model.wantsNativeCommerce = false
            store.route = .commerce
        }
        .compactHeightSheet(item: $model.externalDestination) { external in
            CommunitySafariView(url: external.url).ignoresSafeArea()
        }
        .compactHeightSheet(item: $model.previewFile) { file in
            CommunityFilePreview(url: file.url) { model.previewFile = nil }
                .ignoresSafeArea()
        }
    }

    private var controls: some View {
        HStack(spacing: Tokens.Space.s1) {
            iconButton("chevron.left", label: "뒤로", enabled: model.canGoBack) { model.goBack() }
            iconButton("chevron.right", label: "앞으로", enabled: model.canGoForward) { model.goForward() }
            Text(destination.title)
                .font(.mBodyB)
                .foregroundStyle(Tokens.ink)
                .lineLimit(1)
                .padding(.leading, Tokens.Space.s2)
            Spacer(minLength: Tokens.Space.s2)
            iconButton(model.isLoading ? "xmark" : "arrow.clockwise",
                       label: model.isLoading ? "불러오기 중지" : "새로고침",
                       enabled: true) {
                if model.isLoading { model.stop() } else { model.reload() }
            }
            Button("닫기") { store.route = .services }
                .font(.mCaption)
                .foregroundStyle(Tokens.primary)
                .frame(minWidth: 44, minHeight: 44)
                .buttonStyle(.plain)
        }
        .adaptiveHPadding()
        .frame(maxWidth: Tokens.readableWidth)
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .systemBackground))
    }

    private func iconButton(_ symbol: String, label: String, enabled: Bool,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(enabled ? Tokens.text2 : Tokens.text4)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(label)
    }

    private var progressLine: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle().fill(Tokens.line)
                if model.isLoading {
                    Rectangle().fill(Tokens.primary)
                        .frame(width: geometry.size.width * max(0.04, model.progress))
                }
            }
        }
        .frame(height: 2)
        .accessibilityHidden(true)
    }

    private func sessionNotice(_ message: String) -> some View {
        HStack(spacing: Tokens.Space.s2) {
            Text(message)
                .font(.mCaption)
                .foregroundStyle(Tokens.text2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: Tokens.Space.s2)
            Button("다시 연결") { model.reconnect() }
                .font(.mCaption)
                .foregroundStyle(Tokens.primary)
                .frame(minHeight: 44)
                .buttonStyle(.plain)
        }
        .adaptiveHPadding()
        .background(Tokens.primarySoft)
    }

    private var loadingCard: some View {
        stateCard(icon: nil,
                  title: "\(destination.title)을 불러오는 중입니다",
                  message: "로그인 상태를 안전하게 연결하고 있어요.") {
            ProgressView().tint(Tokens.primary)
        }
    }

    private func failureCard(_ message: String) -> some View {
        stateCard(icon: "wifi.exclamationmark",
                  title: "페이지를 불러오지 못했습니다",
                  message: message) {
            Button("다시 시도") { model.retry() }
                .buttonStyle(SecondaryButtonStyle())
        }
    }

    private var loginCard: some View {
        stateCard(icon: "person.crop.circle.badge.exclamationmark",
                  title: "로그인이 필요합니다",
                  message: "앱 계정으로 로그인하면 역할에 맞는 기능을 이어서 엽니다.") {
            Button("로그인 화면으로") { store.signOut() }
                .buttonStyle(PrimaryButtonStyle())
        }
    }

    private func stateCard<Actions: View>(icon: String?, title: String, message: String,
                                          @ViewBuilder actions: () -> Actions) -> some View {
        ZStack {
            Tokens.paper.ignoresSafeArea()
            VStack(alignment: .leading, spacing: Tokens.Space.s4) {
                if let icon {
                    Image(systemName: icon)
                        .font(.mTitle)
                        .foregroundStyle(Tokens.primary)
                }
                Text(title)
                    .font(.mHeading)
                    .foregroundStyle(Tokens.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(message)
                    .font(.mBody)
                    .foregroundStyle(Tokens.text2)
                    .fixedSize(horizontal: false, vertical: true)
                actions()
            }
            .padding(Tokens.Space.s5)
            .frame(maxWidth: 480, alignment: .leading)
            .background(Tokens.surface,
                        in: RoundedRectangle(cornerRadius: Tokens.Radius.xl, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Tokens.Radius.xl, style: .continuous)
                    .strokeBorder(Tokens.line, lineWidth: 1)
            }
            .padding(Tokens.Space.s4)
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }
}
