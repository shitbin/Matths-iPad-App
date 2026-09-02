//  CommunityScreen.swift
//  Matths
//
//  게시판 — 웹 커뮤니티(/community)를 감싸는 네이티브 셸.
//
//  왜 웹뷰인가: 커뮤니티는 서버가 EJS 로 그리는 페이지뿐이고 JSON API 가 없다.
//  글·댓글·추천·신고·첨부·운영 공지·게시판 규칙까지 전부 웹이 이미 완성해 두었고,
//  서버는 우리가 고치지 않는다. 그래서 앱은 **로그인이 이어진 웹뷰**만 책임진다.
//  네이티브 글쓰기 화면은 두지 않는다 — 두 벌이 생기는 순간 규칙(하루 5개·
//  첨부 제한·경고 누적)이 앱과 웹에서 갈린다.
//
//  로그인 잇기: 이용권 화면이 쓰는 결제 핸드오프와 **같은 통로**를 쓴다.
//  POST /api/v1/commerce/handoffs (Bearer) → 2분짜리 일회용 URL
//  (https://<서버>/app/commerce/<token>) 을 받고, 이 URL 을 웹뷰가 열면 서버가
//  세션을 새로 만들어 쿠키를 심고 303 으로 /pricing 에 보낸다. 우리는 그 리다이렉트
//  한 번만 가로채서 /pricing 대신 게시판으로 간다. 앱은 웹 세션 쿠키를 직접
//  읽거나 만들지 않는다 — 쿠키는 WKWebsiteDataStore.default() 가 들고 있다.
//
//  셸 안에서 산다: RootView 가 위에 AppTopBar, 아래에 MainTabBar 를 붙인다.
//  그래서 NavigationStack 을 쓰지 않고(CommerceHubScreen 의 실측 주석 참조)
//  본문 머리에 조작 줄 하나만 둔다: 뒤로·앞으로 · "게시판" · 새로고침 · 글쓰기.

import QuickLook
import SafariServices
import SwiftUI
import WebKit

// MARK: - 화면

struct CommunityScreen: View {
    @EnvironmentObject private var store: AppStore
    /// 웹뷰와 그 상태는 프로세스에 하나만 둔다. 탭을 오갈 때마다 페이지를 새로
    /// 받아 오고 로그인 핸드오프를 반복하면, 읽던 글과 스크롤 위치가 매번 사라진다.
    @ObservedObject private var model = CommunityWebModel.shared
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var compact: Bool { horizontalSizeClass == .compact }
    private var compactHeight: Bool { verticalSizeClass == .compact }
    private var signedIn: Bool { store.authProvider == "server" }
    /// 첫 로딩·실패·로그인 안내가 웹 영역을 완전히 덮는 동안 뒤 문서의 링크와
    /// 입력 요소가 VoiceOver에 남으면 보이지 않는 페이지를 조작하게 된다.
    private var webContentObscured: Bool {
        (model.isLoading && !model.hasDisplayedPage)
            || model.loadFailure != nil
            || model.loginRequired
    }

    var body: some View {
        VStack(spacing: 0) {
            controls
            progressLine
            if !signedIn {
                readOnlyNotice
            } else if let notice = model.sessionNotice {
                sessionNoticeBar(notice)
            }
            GeometryReader { viewport in
                ZStack {
                    CommunityWebView(model: model)
                        // 웹 페이지가 자기 배경을 그리기 전까지 셸의 종이색을 보인다.
                        .background(Tokens.paper)
                        .accessibilityHidden(webContentObscured)
                    // 첫 문서를 받는 동안 WKWebView 는 배경색만 그려서 앱이 멈춘 것처럼
                    // 보인다. 특히 iPad 가로에서 빈 면적이 커 오해가 더 심했다. 이미 읽던
                    // 페이지가 있는 일반 링크 이동은 가리지 않고, 첫 진입·계정 전환처럼
                    // 이전 내용을 보여 주면 안 되는 구간에만 명시적인 진행 상태를 둔다.
                    if model.isLoading && !model.hasDisplayedPage {
                        initialLoadingCard
                    }
                    if let failure = model.loadFailure {
                        failureCard(failure)
                    }
                    if model.loginRequired {
                        loginCard
                    }
                }
                .task(id: "\(Int(viewport.size.width))x\(Int(viewport.size.height))-\(signedIn)") {
                    // 첫 라우트 전환에서는 CommunityScreen.onAppear가 WKWebView의 0pt
                    // 배치보다 먼저 왔다. 그때 로드하면 문서는 받아도 첫 진입 화면만
                    // 비고, 나갔다 들어와야 보였다. 실제 뷰포트가 확정된 다음 런루프에
                    // 최초 로드를 시작한다.
                    guard viewport.size.width > 1, viewport.size.height > 1 else { return }
                    await Task.yield()
                    model.start(signedIn: signedIn)
                }
            }
        }
        .background(Tokens.paper)
        // 로그아웃·다른 계정 로그인이면 앞사람의 웹 세션이 남아 있으면 안 된다.
        .onChange(of: store.authProvider) { _, _ in
            model.accountDidChange()
            model.start(signedIn: signedIn)
        }
        .onAppear {
            model.updateAccessibility(size: dynamicTypeSize)
        }
        .onChange(of: dynamicTypeSize) { _, size in
            model.updateAccessibility(size: size)
        }
        .onReceive(NotificationCenter.default.publisher(for: DataScope.didSwitchNotification)) { _ in
            model.accountDidChange()
            model.start(signedIn: signedIn)
        }
        // 게시판의 서버 링크가 웹 가격·결제면을 가리켜도 앱 안에서 Toss 결제를
        // 열지 않는다. 웹뷰 모델이 이동을 취소하면 같은 네이티브 StoreKit 화면으로 간다.
        .onChange(of: model.wantsNativeCommerce) { _, wants in
            guard wants else { return }
            model.wantsNativeCommerce = false
            store.route = .commerce
        }
        // 데모 토글은 슬롯 전환도 같이 일으켜 위 handler 가 needsFreshSession 만 세운다.
        // 화면이 이미 떠 있으면 onAppear 가 다시 오지 않으므로 여기서 바로 다시 연다 —
        // 그래야 감독이 칩을 누른 즉시 목업↔실서버가 바뀌는 것을 눈으로 본다.
        #if DEBUG
        .onReceive(NotificationCenter.default.publisher(for: DemoMode.didChangeNotification)) { _ in
            model.demoModeDidChange()
        }
        #endif
        .compactHeightSheet(item: $model.externalDestination) { destination in
            CommunitySafariView(url: destination.url)
                .ignoresSafeArea()
        }
        .compactHeightSheet(item: $model.previewFile) { file in
            CommunityFilePreview(url: file.url) {
                model.previewFile = nil
            }
                .ignoresSafeArea()
        }
    }

    // MARK: 조작 줄

    /// 뒤로·앞으로 · 제목 · 새로고침 · 글쓰기. 모든 버튼이 44pt 히트 영역을 지킨다.
    /// 접근성 글자 크기에서 한 줄에 다 안 서면 제목 줄과 버튼 줄로 나눈다.
    private var controls: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Tokens.Space.s2) {
                historyButtons
                title
                Spacer(minLength: Tokens.Space.s2)
                reloadButton
                composeButton
            }
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: Tokens.Space.s2) {
                    title
                    Spacer(minLength: Tokens.Space.s2)
                    composeButton
                }
                HStack(spacing: Tokens.Space.s2) {
                    historyButtons
                    Spacer(minLength: Tokens.Space.s2)
                    reloadButton
                }
            }
        }
        .padding(.horizontal, compact ? Tokens.Space.s2 : Tokens.Space.s4)
        .padding(.vertical, compactHeight ? 0 : Tokens.Space.s1)
        .frame(maxWidth: Tokens.readableWidth)
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .systemBackground))
    }

    private var title: some View {
        Text("게시판")
            .font(compactHeight ? .mBodyB : .mHeading)
            .foregroundStyle(Tokens.ink)
            .lineLimit(1)
            .accessibilityAddTraits(.isHeader)
    }

    private var historyButtons: some View {
        HStack(spacing: 0) {
            iconButton("chevron.left", label: "뒤로", enabled: model.canGoBack) { model.goBack() }
            iconButton("chevron.right", label: "앞으로", enabled: model.canGoForward) { model.goForward() }
        }
    }

    private var reloadButton: some View {
        iconButton(model.isLoading ? "xmark" : "arrow.clockwise",
                   label: model.isLoading ? "불러오기 중지" : "새로고침",
                   enabled: true) {
            if model.isLoading { model.stop() } else { model.reload() }
        }
    }

    /// 웹의 /community/new 로 보낸다. 로그인 전이면 웹 왕복 없이 바로 안내 카드를 띄운다 —
    /// 서버도 /community/new 를 로그인 필수로 막고 있어서 결과는 같고 한 번 덜 기다린다.
    private var composeButton: some View {
        Button {
            if signedIn {
                model.openComposer()
            } else {
                model.loginRequired = true
            }
        } label: {
            Label("글쓰기", systemImage: "square.and.pencil")
                .font(.mCaption)
                .foregroundStyle(Tokens.onBrand)
                .padding(.horizontal, Tokens.Space.s4)
                .padding(.vertical, Tokens.Space.s2)
                .background(Tokens.actionPrimary, in: Capsule())
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("글쓰기")
        .accessibilityHint("게시판에 새 글을 씁니다")
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

    /// 2pt 진행선. 다 받으면 사라진다 — 상시 노출되는 회색 줄은 소음이다.
    private var progressLine: some View {
        ZStack(alignment: .leading) {
            Rectangle().fill(Tokens.line).frame(height: 0.5)
            if model.isLoading {
                GeometryReader { geometry in
                    Rectangle()
                        .fill(Tokens.primary)
                        .frame(width: geometry.size.width * max(0.04, model.progress), height: 2)
                        .animation(.linear(duration: 0.15), value: model.progress)
                }
                .frame(height: 2)
            }
        }
        .frame(height: 2)
        .accessibilityHidden(true)
    }

    // MARK: 안내 줄

    /// 게스트·로컬 계정: 게시판은 누구나 읽지만 글·댓글은 서버 로그인이 있어야 한다.
    /// 웹의 로그인 화면으로 보내지 않는다 — 앱 계정과 웹 세션이 둘로 갈리면 안 된다.
    private var readOnlyNotice: some View {
        noticeBar(icon: "info.circle",
                  text: "로그인하면 글과 댓글을 쓸 수 있어요. 지금은 읽기만 가능합니다.",
                  actionTitle: "로그인") {
            store.signOut()
        }
    }

    private func sessionNoticeBar(_ notice: String) -> some View {
        noticeBar(icon: "person.crop.circle.badge.exclamationmark",
                  text: notice,
                  actionTitle: "다시 연결") {
            model.reconnect()
        }
    }

    private func noticeBar(icon: String, text: String, actionTitle: String,
                           action: @escaping () -> Void) -> some View {
        HStack(alignment: .center, spacing: Tokens.Space.s3) {
            Image(systemName: icon)
                .font(.mCaption)
                .foregroundStyle(Tokens.primary)
                .accessibilityHidden(true)
            Text(text)
                .font(.mCaption)
                .foregroundStyle(Tokens.text2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: Tokens.Space.s2)
            Button(actionTitle, action: action)
                .font(.mCaption)
                .foregroundStyle(Tokens.primary)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
                .buttonStyle(.plain)
        }
        .padding(.horizontal, Tokens.Space.s4)
        .frame(maxWidth: Tokens.readableWidth)
        .frame(maxWidth: .infinity)
        .background(Tokens.primarySoft)
        .accessibilityElement(children: .contain)
    }

    // MARK: 오류·로그인 카드

    private var initialLoadingCard: some View {
        ZStack {
            Tokens.paper.ignoresSafeArea()
            fittingOverlayCard {
                VStack(spacing: Tokens.Space.s4) {
                    ProgressView()
                        .controlSize(.large)
                        .tint(Tokens.primary)
                    Text("게시판을 불러오는 중입니다")
                        .font(.mBodyB)
                        .foregroundStyle(Tokens.ink)
                    Text("네트워크 상태에 따라 잠시 걸릴 수 있어요.")
                        .font(.mCaption)
                        .foregroundStyle(Tokens.text2)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isModal)
        .accessibilityLabel("게시판을 불러오는 중입니다")
        .accessibilityHint("네트워크 상태에 따라 잠시 걸릴 수 있습니다")
    }

    /// 오프라인·서버 중단. 반쯤 그려진 페이지가 뒤에 비치지 않게 종이색으로 덮는다.
    private func failureCard(_ failure: CommunityWebModel.LoadFailure) -> some View {
        ZStack {
            Tokens.paper.ignoresSafeArea()
            fittingOverlayCard {
                VStack(alignment: .leading, spacing: Tokens.Space.s4) {
                    Label("게시판을 불러오지 못했습니다", systemImage: "wifi.exclamationmark")
                        .font(.mHeading)
                        .foregroundStyle(Tokens.warningInk)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(failure.message)
                        .font(.mBody)
                        .foregroundStyle(Tokens.text2)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("다시 시도") { model.retry() }
                        .buttonStyle(SecondaryButtonStyle())
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }

    private var loginCard: some View {
        ZStack {
            // 뒤의 페이지는 그대로 두고 살짝만 어둡게 — 읽던 글은 잃지 않는다.
            Color.black.opacity(0.28).ignoresSafeArea()
                .onTapGesture { model.loginRequired = false }
            fittingOverlayCard {
                VStack(alignment: .leading, spacing: Tokens.Space.s4) {
                    Label("로그인이 필요합니다", systemImage: "person.crop.circle.badge.exclamationmark")
                        .font(.mHeading)
                        .foregroundStyle(Tokens.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(signedIn
                         ? "웹 세션을 잇지 못했습니다. 다시 연결하거나 앱에 다시 로그인해 주세요."
                         : "글과 댓글은 계정 소유 활동이라 로그인 뒤 쓸 수 있습니다. 읽기는 계속 가능합니다.")
                        .font(.mBody)
                        .foregroundStyle(Tokens.text2)
                        .fixedSize(horizontal: false, vertical: true)
                    loginCardActions
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }

    /// iPhone 가로에서는 두 버튼을 세로로 쌓으면 두 번째가 탭바 아래로 밀린다.
    /// 폭이 허락하는 동안은 한 행에 두고, 큰 글자처럼 실제로 안 맞을 때만 세로로
    /// 물러난다(바깥 fittingOverlayCard가 그때 스크롤까지 제공한다).
    private var loginCardActions: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Tokens.Space.s3) {
                loginCardPrimaryAction
                continueBrowsingButton
            }
            VStack(spacing: Tokens.Space.s3) {
                loginCardPrimaryAction
                continueBrowsingButton
            }
        }
    }

    @ViewBuilder private var loginCardPrimaryAction: some View {
        if signedIn {
            Button("다시 연결") {
                model.loginRequired = false
                model.reconnect()
            }
            .buttonStyle(PrimaryButtonStyle())
        } else {
            Button("로그인하기") { store.signOut() }
                .buttonStyle(PrimaryButtonStyle())
        }
    }

    private var continueBrowsingButton: some View {
        Button("계속 둘러보기") { model.loginRequired = false }
            .buttonStyle(SecondaryButtonStyle())
    }

    /// 접근성 글자 크기에서 카드가 iPhone 가로 높이를 넘으면 제목이나 마지막
    /// 행동을 자르지 않고 내부 스크롤로 전환한다. 보통 크기에서는 중앙 배치 유지.
    private func fittingOverlayCard<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        ViewThatFits(in: .vertical) {
            content()
                .card()
                .frame(maxWidth: 480)
                .padding(compact ? Tokens.Space.s4 : Tokens.Space.s8)
            ScrollView {
                content()
                    .card()
                    .frame(maxWidth: 480)
                    .padding(compact ? Tokens.Space.s4 : Tokens.Space.s8)
                    .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.visible)
        }
    }
}

// MARK: - 웹뷰 표현

/// 웹뷰 자체는 모델이 만들고 들고 있다. SwiftUI representable이 같은 UIView 인스턴스를
/// 여러 수명 주기에 직접 반환하면, 긴 ScrollView에서 route가 바뀔 때 WebKit 표면이
/// 이전 마운트에 남는 경우가 있다. 매 진입마다 새 호스트를 반환하고 공유 웹뷰는 그
/// 안에 한 번만 붙인다 — 페이지·세션·스크롤은 남고 SwiftUI 뷰 정체성은 새로워진다.
final class CommunityWebHostView: UIView {
    let embeddedWebView: WKWebView

    init(webView: WKWebView) {
        embeddedWebView = webView
        super.init(frame: .zero)
        webView.removeFromSuperview()
        webView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(webView)
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: trailingAnchor),
            webView.topAnchor.constraint(equalTo: topAnchor),
            webView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

struct CommunityWebView: UIViewRepresentable {
    @ObservedObject var model: CommunityWebModel

    func makeUIView(context: Context) -> CommunityWebHostView {
        CommunityWebHostView(webView: model.webView)
    }

    func updateUIView(_ host: CommunityWebHostView, context: Context) {}

    static func dismantleUIView(_ host: CommunityWebHostView, coordinator: ()) {
        if host.embeddedWebView.superview === host {
            host.embeddedWebView.removeFromSuperview()
        }
    }
}

// MARK: - 모델

/// WKWebView 소유자 + 내비게이션·UI·다운로드 위임. 프로세스에 하나(shared).
@MainActor
final class CommunityWebModel: NSObject, ObservableObject {
    static let shared = CommunityWebModel()

    struct LoadFailure: Equatable {
        let message: String
        let url: URL?
    }

    struct ExternalDestination: Identifiable {
        let id = UUID()
        let url: URL
    }

    struct PreviewFile: Identifiable {
        let id = UUID()
        let url: URL
    }

    @Published private(set) var progress: Double = 0
    @Published private(set) var isLoading = false
    /// 현재 계정으로 웹 문서를 한 번이라도 끝까지 표시했는지. 첫 로딩의 빈 웹뷰와
    /// 계정 전환 중 이전 사람의 페이지를 명시적인 로딩 화면으로 가리는 기준이다.
    @Published private(set) var hasDisplayedPage = false
    @Published private(set) var canGoBack = false
    @Published private(set) var canGoForward = false
    @Published private(set) var loadFailure: LoadFailure?
    /// 서버 로그인은 있는데 웹 세션을 잇지 못했을 때의 한 줄 안내(읽기 모드).
    @Published private(set) var sessionNotice: String?
    @Published var loginRequired = false
    @Published var wantsNativeCommerce = false
    @Published var externalDestination: ExternalDestination?
    @Published var previewFile: PreviewFile?

    /// 서버 주소. 호스트 비교와 경로 조립의 기준.
    private let serverBase = ServerAPI.baseURL

    private(set) lazy var webView: WKWebView = makeWebView()
    private var observers: [NSKeyValueObservation] = []
    private let refreshControl = UIRefreshControl()

    private var started = false
    private var signedIn = false
    /// 계정이 바뀌면 다음 진입에서 쿠키를 지우고 처음부터 다시 잇는다.
    private var needsFreshSession = true
    /// 핸드오프 URL 을 여는 중 — /pricing 리다이렉트 한 번을 가로챌 구간.
    private var handingOff = false
    /// 핸드오프가 끝나면 갈 곳(글쓰기 도중 세션이 끊겼으면 다시 그 페이지로).
    private var pendingDestination: URL?
    private var lastHandoffAt: Date?
    /// 마지막으로 열려고 한 게시판 안 페이지. /login 리다이렉트를 가로챈 뒤 돌아갈 곳.
    private var lastInternalURL: URL?
    /// 이 모델 인스턴스가 처음 열고, 오류·세션 복구 때 돌아갈 서버 내부 경로.
    /// 게시판 인스턴스는 `/community`, 서비스 포털 인스턴스는 선택한 학원·관리 경로다.
    private var entryPath = "/community"
    private var downloadFiles: [ObjectIdentifier: URL] = [:]

    override init() {
        super.init()
    }

    // MARK: 진입·계정

    /// 화면이 나타날 때마다 부른다. 이미 열려 있고 계정도 그대로면 아무것도 안 한다.
    func start(signedIn: Bool, path: String = "/community") {
        self.signedIn = signedIn
        let nextPath = normalizedInternalPath(path)
        let destinationChanged = nextPath != entryPath
        entryPath = nextPath
        if started && !needsFreshSession {
            if destinationChanged { load(serverURL(entryPath)) }
            return
        }
        started = true
        openFresh(path: entryPath)
    }

    /// 로그아웃·계정 전환. 화면이 떠 있든 아니든 다음 진입 때 세션을 새로 잇는다.
    func accountDidChange() {
        needsFreshSession = true
        loginRequired = false
    }

    /// 서버 HTML도 App Store의 더 큰 텍스트 기준에 포함되는 공통 작업이다. 번들 HTML
    /// 전용 CSS 변수 대신 WKWebView 문서 배율을 써서 서버 배포와 무관하게 즉시 반영한다.
    func updateAccessibility(size: DynamicTypeSize) {
        WebContentAccessibility.configureHostedPage(
            webView,
            size: size
        )
    }

    #if DEBUG
    /// 디버그 바의 "데모" 칩. 출처가 통째로 바뀌므로(file:// ↔ https) 지금 보던 글이
    /// 아니라 항상 목록에서 다시 시작한다.
    func demoModeDidChange() {
        needsFreshSession = true
        started = true
        sessionNotice = nil
        openFresh(path: entryPath)
    }
    #endif

    /// 안내 줄의 "다시 연결" — 핸드오프를 처음부터 다시 한다.
    func reconnect() {
        sessionNotice = nil
        openFresh(path: currentInternalPath ?? entryPath)
    }

    /// 쿠키를 정리하고(계정이 바뀌었을 수 있다) 로그인 상태면 핸드오프, 아니면 그냥 연다.
    private func openFresh(path: String) {
        needsFreshSession = false
        loadFailure = nil
        loginRequired = false
        hasDisplayedPage = false
        #if DEBUG
        // 데모 모드: 핸드오프 왕복(POST /commerce/handoffs → /app/commerce/<token> → 303)을
        // 통째로 건너뛴다. 서버도 계정도 쿠키도 없이 게시판 UI 를 봐야 하기 때문이다.
        if DemoMode.isOn, path.hasPrefix("/community") {
            loadDemoPage(path: path)
            return
        }
        #endif
        let destination = serverURL(path)
        Task { @MainActor in
            // 게스트로 들어왔거나 계정이 바뀌었으면 앞사람의 세션 쿠키가 남아 있으면 안 된다.
            // 로그인 상태의 핸드오프는 어차피 세션을 새로 만들어 덮어쓰지만, 게스트는
            // 덮어쓸 것이 없으므로 여기서 지운다.
            await clearServerCookies()
            if signedIn {
                await handoff(then: destination)
            } else {
                load(destination)
            }
        }
    }

    // MARK: 조작

    func goBack() { webView.goBack() }
    func goForward() { webView.goForward() }
    func stop() {
        webView.stopLoading()
        // 첫 화면을 받기 전에 중지하면 WKWebView 에는 보여 줄 문서가 없다. 빈 화면으로
        // 되돌아가지 말고 사용자가 방금 한 동작과 재시도 방법을 분명히 남긴다.
        if !hasDisplayedPage {
            loadFailure = LoadFailure(
                message: "불러오기를 중지했습니다. 준비되면 다시 시도해 주세요.",
                url: webView.url)
        }
    }

    func reload() {
        loadFailure = nil
        if webView.url == nil {
            openFresh(path: entryPath)
        } else {
            webView.reload()
        }
    }

    /// 오류 카드의 "다시 시도". 실패한 주소가 있으면 그 주소를, 없으면 처음부터.
    func retry() {
        let failed = loadFailure?.url
        loadFailure = nil
        hasDisplayedPage = false
        if let failed, isServerHost(failed) {
            load(failed)
        } else {
            openFresh(path: currentInternalPath ?? entryPath)
        }
    }

    /// 글쓰기. 지금 보고 있는 게시판(board 질의)을 그대로 넘겨 웹의 "새 글 쓰기"
    /// 링크와 같은 곳에 도착한다.
    func openComposer() {
        #if DEBUG
        if DemoMode.isOn {
            loadDemoPage(path: "/community/new")
            return
        }
        #endif
        var components = URLComponents(url: serverURL("/community/new"), resolvingAgainstBaseURL: false)
        if let current = webView.url,
           let board = URLComponents(url: current, resolvingAgainstBaseURL: false)?
               .queryItems?.first(where: { $0.name == "board" })?.value,
           !board.isEmpty {
            components?.queryItems = [URLQueryItem(name: "board", value: board)]
        }
        load(components?.url ?? serverURL("/community/new"))
    }

    #if DEBUG
    // MARK: 데모 목업 (DEBUG 전용)
    //
    // 감독이 서버 없이 게시판 화면을 눈으로 보기 위한 경로다. 네이티브 셸(조작 줄·진행선·
    // 안내 배너·오류 카드·글쓰기 버튼)은 그대로 두고 **웹 내용만** 번들 안 정적 페이지로
    // 갈아 끼운다 — 감독이 피드백할 대상이 바로 그 셸 + 페이지 조합이기 때문이다.

    /// 목업 폴더 URL. 빌드가 DemoWeb/ 을 폴더째 복사하지만, 동기화 그룹이 평탄화하는
    /// 배선으로 되돌아가도 죽지 않게 LessonWebView 와 같은 순서로 찾는다.
    private static let demoWebDirectory: URL? =
        (Bundle.main.url(forResource: "community", withExtension: "html", subdirectory: "DemoWeb")
            ?? Bundle.main.url(forResource: "community", withExtension: "html"))?
            .deletingLastPathComponent()

    /// 서버 경로 → 목업 파일. 목업에 없는 게시판 경로는 목록으로 되돌린다 —
    /// file:// 에서 없는 파일을 열면 웹뷰가 통째로 시스템 오류 화면이 된다.
    ///
    /// 질의(`?board=`, `?search=`)까지 보는 이유: 목업 안의 링크는 상대경로라 웹뷰가
    /// 알아서 따라가지만, **앱이 경로를 지정해 여는 경우**(reconnect·retry 가
    /// currentCommunityPath 를 그대로 다시 여는 길)에는 여기서 갈라 주지 않으면
    /// 운영 게시판을 보던 감독이 "다시 연결" 한 번에 통합 목록으로 튕긴다.
    private func demoFileName(for path: String) -> String {
        let parts = path.split(separator: "?", maxSplits: 1).map(String.init)
        let base = parts.first ?? path
        let query = parts.count > 1
            ? URLComponents(string: "?\(parts[1])")?.queryItems ?? []
            : []
        func value(_ name: String) -> String? {
            query.first { $0.name == name }?.value.flatMap { $0.isEmpty ? nil : $0 }
        }
        switch base {
        case "/community/new":   return "community-new.html"
        case "/community/rules": return "community-rules.html"
        case "/community":
            if value("search") != nil { return "community-search.html" }
            switch value("board") {
            case "operations":                     return "community-operations.html"
            // 학교·N수생·대학교·직장인 게시판은 서버에서 소속별로 갈리지만
            // 목업은 "소속 전용 게시판" 한 장으로 대표한다(레이아웃이 같다).
            case "school", "retaker", "university", "worker":
                return "community-school.html"
            default:                               return "community.html"
            }
        default:                 return "community.html"
        }
    }

    /// 읽기 허용 범위를 **파일이 아니라 폴더**로 주는 것이 핵심이다. 파일 하나만 허용하면
    /// 형제 CSS·JS·SVG 가 전부 차단돼 스타일이 다 빠진 맨 HTML 이 뜬다(실측).
    private func loadDemoPage(path: String) {
        guard let directory = Self.demoWebDirectory else {
            // 목업이 번들에 없다 = 리소스 배선이 깨진 것. 빈 흰 화면으로 두면 감독은
            // "게시판이 원래 이렇게 비었나" 로 읽는다 — 원인을 화면에 적어 준다.
            loadFailure = LoadFailure(
                message: "데모 게시판 목업(DemoWeb/community.html)이 앱 번들에 없습니다. "
                    + "Xcode 리소스 배선(Debug 데모 게시판 목업 복사 단계)을 확인해 주세요.",
                url: nil)
            return
        }
        loadFailure = nil
        loginRequired = false
        sessionNotice = nil
        let file = directory.appendingPathComponent(demoFileName(for: path))
        webView.loadFileURL(file, allowingReadAccessTo: directory)
    }
    #endif

    // MARK: 로그인 핸드오프

    /// 이용권 화면과 같은 통로: Bearer → 일회용 URL → 웹뷰가 열면 세션 쿠키가 심긴다.
    /// mode "pricing" 은 이용권 결제 여부와 무관하게 항상 발급된다(서버 규칙).
    private func handoff(then destination: URL) async {
        handingOff = true
        pendingDestination = destination
        loadFailure = nil
        do {
            let handoff = try await ServerAPI.createCommerceHandoff(mode: "pricing")
            guard let url = validatedHandoffURL(handoff.url) else {
                throw ServerAPIError(
                    message: "로그인 연결 주소의 안전성을 확인할 수 없습니다.",
                    code: "INVALID_HANDOFF_URL")
            }
            lastHandoffAt = Date()
            sessionNotice = nil
            webView.load(URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData))
        } catch {
            // 토큰 만료(401)면 ServerAPI 가 이미 앱 전체에 재로그인을 알렸다.
            // 여기서는 읽기 모드로 열고 한 줄만 남긴다 — 게시판 읽기까지 막을 이유가 없다.
            handingOff = false
            pendingDestination = nil
            sessionNotice = "로그인 세션을 잇지 못해 읽기 모드로 열었습니다."
            load(destination)
        }
    }

    /// 이용권 화면(CommerceHubScreen.validatedCommerceURL)과 같은 검사:
    /// https · 같은 호스트 · /app/commerce/ 경로만 연다.
    private func validatedHandoffURL(_ value: String) -> URL? {
        guard let url = URL(string: value),
              url.scheme == "https",
              url.host?.lowercased() == serverBase.host?.lowercased(),
              url.path.hasPrefix("/app/commerce/") else { return nil }
        return url
    }

    /// 핸드오프 URL 이 리다이렉트 없이 오류 페이지(410 만료·403 계정 상태)로 끝났을 때.
    private func abandonHandoff(reason: String) {
        handingOff = false
        let destination = pendingDestination ?? serverURL(entryPath)
        pendingDestination = nil
        sessionNotice = reason
        load(destination)
    }

    // MARK: 웹뷰

    private func makeWebView() -> WKWebView {
        let configuration = WKWebViewConfiguration()
        // 영속 저장소 — 세션 쿠키(7일)가 앱을 껐다 켜도 남는다.
        configuration.websiteDataStore = .default()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.allowsInlineMediaPlayback = true
        // 웹이 앱 셸 안인지 알아볼 수 있게 UA 뒤에 표식만 붙인다(요청 헤더는 그대로).
        configuration.applicationNameForUserAgent = "MatthsApp/\(ServerAPI.clientBuildVersion)"
        // 사이트 전역 머리(브랜드·GOAT Arena·학습·서비스 메뉴)는 셸이 이미 맡고 있다.
        // 상단바 두 개가 겹치면 학생은 어느 쪽 뒤로가 진짜인지 모른다. 숨기기만 하고
        // DOM 은 건드리지 않는다 — 웹 팀의 스크립트가 그 요소를 찾아도 깨지지 않는다.
        configuration.userContentController.addUserScript(WKUserScript(
            source: Self.shellStyleScript,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true))

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsLinkPreview = true
        webView.isOpaque = false
        webView.backgroundColor = UIColor(Tokens.paper)
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.keyboardDismissMode = .interactive

        refreshControl.addTarget(self, action: #selector(pullToRefresh), for: .valueChanged)
        webView.scrollView.refreshControl = refreshControl

        // WKWebView 의 KVO 는 메인 스레드에서 온다. 옵저버 클로저는 @Sendable 이라
        // 격리 추론을 못 받으므로 메인 액터임을 명시해 상태를 갱신한다.
        observers = [
            webView.observe(\.estimatedProgress, options: [.new]) { [weak self] web, _ in
                MainActor.assumeIsolated { self?.progress = web.estimatedProgress }
            },
            webView.observe(\.isLoading, options: [.new]) { [weak self] web, _ in
                MainActor.assumeIsolated {
                    self?.isLoading = web.isLoading
                    if !web.isLoading { self?.refreshControl.endRefreshing() }
                }
            },
            webView.observe(\.canGoBack, options: [.new]) { [weak self] web, _ in
                MainActor.assumeIsolated { self?.canGoBack = web.canGoBack }
            },
            webView.observe(\.canGoForward, options: [.new]) { [weak self] web, _ in
                MainActor.assumeIsolated { self?.canGoForward = web.canGoForward }
            },
        ]
        return webView
    }

    @objc private func pullToRefresh() {
        loadFailure = nil
        if webView.url == nil {
            refreshControl.endRefreshing()
            openFresh(path: entryPath)
        } else {
            webView.reload()
        }
    }

    #if DEBUG
    /// 데모에서 게시판이 비어 보일 때 원인을 두 갈래로 가르는 최소 계측.
    ///   innerHeight 가 0  → 문서는 다 받았는데 **보여 줄 창이 0pt**(바깥 ScrollView 가
    ///                       WKWebView 를 접은 경우. RootView 특례 분기를 확인할 것)
    ///   textLength 가 0   → 문서를 못 받았거나 파일이 비었다(리소스 배선 문제)
    /// 실제로 이 두 가지가 똑같이 "빈 종이색 화면" 으로 보였기 때문에 남겨 둔다.
    private static let demoProbeScript = """
    (function () {
      var b = document.body;
      return [document.title,
              'viewport=' + innerWidth + 'x' + innerHeight,
              'doc=' + document.documentElement.scrollHeight,
              'text=' + (b ? b.innerText.length : -1)].join(' · ');
    })();
    """
    #endif

    /// CSP(style-src 'unsafe-inline')와 무관하게 먹히도록 adoptedStyleSheets 를 먼저 쓴다.
    private static let shellStyleScript = """
    (function () {
      var css = "header.site-header, .matths-skip-link { display: none !important; }";
      try {
        var sheet = new CSSStyleSheet();
        sheet.replaceSync(css);
        document.adoptedStyleSheets = document.adoptedStyleSheets.concat([sheet]);
      } catch (e) {
        var style = document.createElement("style");
        style.textContent = css;
        (document.head || document.documentElement).appendChild(style);
      }
    })();
    """

    // MARK: 주소

    private func serverURL(_ path: String) -> URL {
        var components = URLComponents(url: serverBase, resolvingAgainstBaseURL: false)
        let split = path.split(separator: "?", maxSplits: 1).map(String.init)
        components?.path = split.first ?? entryPath
        components?.query = split.count > 1 ? split[1] : nil
        return components?.url ?? serverBase
    }

    /// 지금 보고 있는 서버 내부 경로(질의 포함). 핸드오프·결제·로그인 표면은 복구
    /// 목적지로 보존하지 않는다.
    private var currentInternalPath: String? {
        guard let url = webView.url,
              isServerHost(url),
              !url.path.hasPrefix("/app/commerce/"),
              !ServerAPI.isWebPurchaseSurface(url),
              !["/login", "/register"].contains(url.path) else { return nil }
        return url.query.map { "\(url.path)?\($0)" } ?? url.path
    }

    private func normalizedInternalPath(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("/"),
              !trimmed.hasPrefix("//"),
              !ServerAPI.isWebPurchasePath(trimmed) else { return "/community" }
        return trimmed
    }

    private func isServerHost(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased(), let base = serverBase.host?.lowercased() else { return false }
        func strip(_ value: String) -> String {
            value.hasPrefix("www.") ? String(value.dropFirst(4)) : value
        }
        return strip(host) == strip(base)
    }

    private func load(_ url: URL) {
        loadFailure = nil
        webView.load(URLRequest(url: url))
    }

    /// 서버 호스트의 쿠키만 지운다. 다른 웹뷰(개념 수업 등)는 로컬 파일이라 영향이 없다.
    private func clearServerCookies() async {
        let store = WKWebsiteDataStore.default().httpCookieStore
        let cookies = await store.allCookies()
        for cookie in cookies where isServerCookie(cookie) {
            await store.deleteCookie(cookie)
        }
    }

    private func isServerCookie(_ cookie: HTTPCookie) -> Bool {
        guard let base = serverBase.host?.lowercased() else { return false }
        let domain = cookie.domain.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
        return base == domain || base.hasSuffix("." + domain) || domain.hasSuffix("." + base)
    }

    private func readableMessage(for error: Error) -> String {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost, NSURLErrorDataNotAllowed:
                return "인터넷 연결을 확인한 뒤 다시 시도해 주세요."
            case NSURLErrorTimedOut:
                return "서버 응답이 늦습니다. 잠시 후 다시 시도해 주세요."
            case NSURLErrorCannotFindHost, NSURLErrorCannotConnectToHost, NSURLErrorDNSLookupFailed:
                return "서버에 연결할 수 없습니다. 잠시 후 다시 시도해 주세요."
            default:
                break
            }
        }
        return "잠시 후 다시 시도해 주세요."
    }
}

// MARK: - WKNavigationDelegate

extension CommunityWebModel: WKNavigationDelegate {
    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }
        // 서브프레임(결제 위젯 등)과 리소스는 웹이 알아서 한다.
        let isMainFrame = navigationAction.targetFrame?.isMainFrame ?? true
        guard isMainFrame else {
            decisionHandler(.allow)
            return
        }

        // 1) 핸드오프 뒤 서버가 보내는 /pricing — 여기서 딱 한 번 방향을 튼다.
        //    쿠키는 303 응답과 함께 이미 심겼다. 결제 페이지는 보여 주지 않는다.
        if handingOff, isServerHost(url), url.path == "/pricing" {
            handingOff = false
            let destination = pendingDestination ?? serverURL(entryPath)
            pendingDestination = nil
            decisionHandler(.cancel)
            load(destination)
            return
        }

        // 위 리다이렉트에 도달하려면 서버가 발급한 일회용 URL 자체는 한 번 열어야 한다.
        // 이 예외가 결제 경계보다 뒤에 있으면 로그인 쿠키가 심기기 전에 취소된다.
        if handingOff, isServerHost(url), url.path.hasPrefix("/app/commerce/") {
            decisionHandler(.allow)
            return
        }

        // 로그인된 웹뷰에서 웹 결제 페이지가 열리면 App Review 3.1.1 경계를 넘는다.
        // 최초 핸드오프의 /app/commerce/<token>은 위 리다이렉트 절차에만 허용하고,
        // 그 밖의 가격·결제 링크는 모두 네이티브 StoreKit 화면으로 보낸다.
        if isServerHost(url), ServerAPI.isWebPurchaseSurface(url) {
            decisionHandler(.cancel)
            wantsNativeCommerce = true
            return
        }

        // 2) 웹의 로그인·가입 화면으로 튕기면 세션이 끊긴 것이다.
        //    앱 계정으로 다시 잇는다(30초에 한 번만 — 서버가 계속 거부하면 카드로).
        //    게스트는 앱 로그인으로 안내한다 — 웹 로그인은 계정을 둘로 가른다.
        if isServerHost(url), ["/login", "/register"].contains(url.path) {
            decisionHandler(.cancel)
            let recently = lastHandoffAt.map { Date().timeIntervalSince($0) < 30 } ?? false
            if signedIn && !recently {
                let destination = lastInternalURL ?? serverURL(entryPath)
                Task { @MainActor in await handoff(then: destination) }
            } else {
                loginRequired = true
            }
            return
        }

        // 3) 외부 호스트. 학생이 누른 링크만 Safari 로 보낸다 — 첨부파일 저장소로 가는
        //    서버 리다이렉트(302)는 웹뷰가 그대로 따라가 파일을 보여 주거나 내려받는다.
        if !isServerHost(url) {
            let scheme = url.scheme?.lowercased() ?? ""
            if scheme == "http" || scheme == "https" {
                if navigationAction.navigationType == .linkActivated {
                    decisionHandler(.cancel)
                    externalDestination = ExternalDestination(url: url)
                    return
                }
            } else if scheme == "mailto" || scheme == "tel" || scheme == "sms" {
                decisionHandler(.cancel)
                UIApplication.shared.open(url)
                return
            }
        }

        if isServerHost(url),
           !url.path.hasPrefix("/app/commerce/"),
           !ServerAPI.isWebPurchaseSurface(url),
           !["/login", "/register"].contains(url.path) {
            lastInternalURL = url
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationResponse: WKNavigationResponse,
                 decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        guard navigationResponse.isForMainFrame,
              let http = navigationResponse.response as? HTTPURLResponse else {
            decisionHandler(.allow)
            return
        }

        // 핸드오프 URL 이 리다이렉트 없이 오류 페이지로 끝났다(만료·계정 상태).
        // 결제 화면용 오류 문구를 그대로 보여 주면 학생은 결제 얘기인 줄 안다.
        if handingOff, let url = http.url, isServerHost(url), url.path.hasPrefix("/app/commerce/"),
           http.statusCode >= 400 {
            decisionHandler(.cancel)
            abandonHandoff(reason: http.statusCode == 403
                ? "계정 상태 때문에 로그인 세션을 잇지 못했습니다. 읽기 모드로 열었습니다."
                : "로그인 연결이 만료되어 읽기 모드로 열었습니다.")
            return
        }

        // 서버가 5xx(점검·배포 중)나 404 를 주면 페이지가 빈 흰 화면으로 남는다 —
        // 실측: 웹 재배포 중 /community 가 503 이었고 웹뷰는 아무 말 없이 비어 있었다.
        // 그건 "고장" 이 아니라 "잠시 없음" 이니 다시 시도 카드로 말한다.
        if let url = http.url,
           isServerHost(url),
           (http.statusCode >= 500 || http.statusCode == 404) {
            decisionHandler(.cancel)
            loadFailure = LoadFailure(
                message: http.statusCode >= 500
                    ? "서버가 잠시 응답하지 않습니다(\(http.statusCode)). 점검이나 배포 중일 수 있어요 — 잠시 뒤 다시 시도해 주세요."
                    : "그 글이나 페이지를 찾을 수 없습니다(404). 삭제됐거나 주소가 바뀌었을 수 있어요.",
                url: url)
            return
        }

        // 첨부파일 내려받기(Content-Disposition: attachment)와 표시 못 하는 형식은
        // WKDownload 로 받아 미리보기로 연다. 안 하면 웹뷰가 빈 화면으로 멈춘다.
        let disposition = (http.value(forHTTPHeaderField: "Content-Disposition") ?? "").lowercased()
        if disposition.hasPrefix("attachment") || !navigationResponse.canShowMIMEType {
            decisionHandler(.download)
            return
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        loadFailure = nil
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        refreshControl.endRefreshing()
        hasDisplayedPage = true
        #if DEBUG
        // 데모에서 빈 화면이 뜨면 원인이 "안 그려짐" 인지 "안 받아짐" 인지부터 갈라야 한다.
        // 로드가 끝난 뒤 문서 크기를 한 줄 남겨 두면 로그만 보고 판별된다.
        if DemoMode.isOn {
            webView.evaluateJavaScript(Self.demoProbeScript) { value, error in
                NSLog("DEMO-MODE 목업 로드 %@ · %@",
                      webView.url?.lastPathComponent ?? "?",
                      String(describing: value ?? error.map { "오류 \($0)" } ?? "nil"))
            }
        }
        #endif
        // 핸드오프 URL 자체가 최종 페이지로 남았다면(리다이렉트가 안 왔다) 되돌린다.
        if handingOff, let url = webView.url, url.path.hasPrefix("/app/commerce/") {
            abandonHandoff(reason: "로그인 연결이 만료되어 읽기 모드로 열었습니다.")
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        handleFailure(error, url: webView.url)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!,
                 withError error: Error) {
        let failedURL = (error as NSError).userInfo[NSURLErrorFailingURLErrorKey] as? URL
        handleFailure(error, url: failedURL)
    }

    /// 웹 콘텐츠 프로세스가 죽으면(메모리 압박) 빈 화면이 남는다. 같은 주소를 다시 연다.
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        hasDisplayedPage = false
        if webView.url != nil { webView.reload() } else { openFresh(path: entryPath) }
    }

    private func handleFailure(_ error: Error, url: URL?) {
        refreshControl.endRefreshing()
        let nsError = error as NSError
        // 우리가 방향을 튼 내비게이션(핸드오프·/login 가로채기)과 사용자의 중지는 오류가 아니다.
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled { return }
        // WebKitErrorDomain 102 = FrameLoadInterruptedByPolicyChange. 공개 enum(WKError)에는
        // 없는 내부 코드라 도메인 문자열과 숫자로 본다.
        if nsError.domain == "WebKitErrorDomain" && nsError.code == 102 { return }
        if handingOff {
            // 핸드오프 자체가 네트워크로 실패 — 읽기 모드도 같이 실패할 테니 그냥 오류로 둔다.
            handingOff = false
            pendingDestination = nil
        }
        hasDisplayedPage = false
        loadFailure = LoadFailure(message: readableMessage(for: error), url: url)
    }

    // MARK: 다운로드 전환

    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse,
                 didBecome download: WKDownload) {
        download.delegate = self
    }

    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction,
                 didBecome download: WKDownload) {
        download.delegate = self
    }
}

// MARK: - WKUIDelegate

extension CommunityWebModel: WKUIDelegate {
    /// target="_blank"(첨부 링크·소셜 링크). 같은 호스트면 이 웹뷰에서, 아니면 Safari 로.
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {
        guard let url = navigationAction.request.url else { return nil }
        // 데모 목업의 첨부 썸네일은 원본 템플릿대로 target="_blank" 인데 주소가 file:// 다.
        // 그대로 아래 분기로 흘려보내면 아무 데도 안 걸려 링크가 죽은 채로 보인다
        // (Safari 시트로 넘겨도 file:// 은 열지 못한다). 같은 웹뷰에서 연다 — 뒤로가 있다.
        if url.isFileURL {
            webView.load(navigationAction.request)
            return nil
        }
        if isServerHost(url) {
            webView.load(navigationAction.request)
        } else if let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" {
            externalDestination = ExternalDestination(url: url)
        }
        return nil
    }

    /// 웹이 alert/confirm 을 쓰면 위임 없이는 조용히 취소된다(신고·삭제가 무음 실패).
    /// 지금 커뮤니티 페이지는 안 쓰지만, 웹 팀이 추가해도 앱이 깨지지 않게 받아 둔다.
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        guard let presenter = Self.topViewController() else {
            completionHandler()
            return
        }
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default) { _ in completionHandler() })
        presenter.present(alert, animated: true)
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        guard let presenter = Self.topViewController() else {
            completionHandler(false)
            return
        }
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "취소", style: .cancel) { _ in completionHandler(false) })
        alert.addAction(UIAlertAction(title: "확인", style: .default) { _ in completionHandler(true) })
        presenter.present(alert, animated: true)
    }

    private static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.flatMap(\.windows).first(where: \.isKeyWindow)
            ?? scenes.first?.windows.first
        var top = window?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}

// MARK: - WKDownloadDelegate

extension CommunityWebModel: WKDownloadDelegate {
    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse,
                  suggestedFilename: String, completionHandler: @escaping (URL?) -> Void) {
        // 임시 폴더 아래 다운로드마다 새 디렉터리 — 같은 파일명끼리 덮어쓰지 않는다.
        // 영구 보관이 아니라 미리보기용이다. 시스템이 tmp 를 정리해도 잃을 것이 없다.
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("community-downloads", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            completionHandler(nil)
            return
        }
        let safeName = suggestedFilename.isEmpty ? "attachment" : suggestedFilename
        let file = directory.appendingPathComponent(safeName)
        downloadFiles[ObjectIdentifier(download)] = file
        completionHandler(file)
    }

    func downloadDidFinish(_ download: WKDownload) {
        guard let file = downloadFiles.removeValue(forKey: ObjectIdentifier(download)) else { return }
        previewFile = PreviewFile(url: file)
    }

    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        downloadFiles.removeValue(forKey: ObjectIdentifier(download))
        loadFailure = LoadFailure(message: "첨부파일을 내려받지 못했습니다. " + readableMessage(for: error),
                                  url: nil)
    }
}

// MARK: - Safari · 미리보기

/// 외부 링크(유튜브·인스타그램 등)는 결제 브라우저와 같은 SFSafariViewController 로 연다.
struct CommunitySafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let controller = SFSafariViewController(url: url)
        controller.dismissButtonStyle = .close
        return controller
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

/// 내려받은 첨부파일(PDF·문서·이미지)을 QuickLook 으로 보여 준다.
/// 내비게이션 컨트롤러에 담아야 닫기 버튼과 공유 버튼이 붙는다.
struct CommunityFilePreview: UIViewControllerRepresentable {
    let url: URL
    let onClose: @MainActor () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(url: url, onClose: onClose) }

    func makeUIViewController(context: Context) -> UINavigationController {
        let preview = QLPreviewController()
        preview.dataSource = context.coordinator
        preview.navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "닫기",
            style: .plain,
            target: context.coordinator,
            action: #selector(Coordinator.closePreview))
        return UINavigationController(rootViewController: preview)
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}

    @MainActor
    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        let url: URL
        let onClose: @MainActor () -> Void

        init(url: URL, onClose: @escaping @MainActor () -> Void) {
            self.url = url
            self.onClose = onClose
        }

        @objc func closePreview() { onClose() }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            url as NSURL
        }
    }
}
