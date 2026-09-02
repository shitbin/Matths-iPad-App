//  ArenaWebModel.swift
//  Matths
//
//  아레나 웹 브리지의 알맹이 — WKWebView 소유자 + 로그인 핸드오프 + 내비게이션 위임.
//
//  게시판(CommunityWebModel)이 실기기에서 검증된 유일한 세션 브리지라서 **그대로 본떴다**.
//  같은 통로를 두 번 발명하지 않는다:
//    POST /api/v1/commerce/handoffs (Bearer) → 2분짜리 1회용
//    https://<서버>/app/commerce/<token> → 웹뷰가 열면 서버가 세션 쿠키를 심고 303
//    → 우리는 그 303 목적지(/pricing)를 딱 한 번 가로채 아레나 목적지로 튼다.
//  앱은 쿠키를 직접 만들거나 읽지 않는다. 쿠키는 WKWebsiteDataStore.default() 가 든다.
//
//  게시판과 다른 점 세 가지 — 이것 때문에 파일을 나눴다.
//  ① 아레나는 **전 경로가 로그인 필수**다(routes/goat-arena-routes.js 의 모든 라우트가
//     authMiddleware.isLoggedIn). 게시판처럼 "읽기 모드로라도 열기" 가 없다. 그래서
//     로그인 없이 여는 시도는 서버를 치기 전에 앱이 먼저 막는다 — /login 으로 튕겨
//     웹 로그인 폼을 보여 주면 앱 계정과 웹 계정이 둘로 갈린다.
//  ② 목적지가 여러 개다(우편함·상점·경기·규정…). 화면이 목적지를 들고 열린다.
//  ③ 경기 페이지는 평가면이라 화면 보호를 같이 걸어야 한다(ArenaWebScreen 참조).
//
//  세션 재사용: 한 번 이어 둔 웹 세션은 7일짜리 쿠키로 남는다. 목적지를 열 때마다
//  핸드오프를 새로 하면 1회용 토큰을 낭비하고 매번 왕복이 한 번 더 늘어난다.
//  그래서 **세션이 있으면 바로 목적지를 열고**, 서버가 /login 으로 튕길 때만 다시 잇는다.

import Foundation
import SwiftUI
import WebKit

@MainActor
final class ArenaWebModel: NSObject, ObservableObject {
    /// 프로세스에 하나. 목적지를 바꿔 가며 열어도 쿠키·뒤로가기 기록이 이어진다.
    static let shared = ArenaWebModel()

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

    /// 웹을 열 수 없어 화면 전체를 덮는 안내. 서버를 치지 않는 상태들이다.
    enum Block: Equatable {
        /// 앱에 서버 로그인이 없다 — 아레나 웹은 전 경로가 로그인 필수다.
        case signedOut
        /// 데모 모드. 서버도 계정도 없이 도는 실행이라 웹을 열지 않는다.
        case demo
    }

    @Published private(set) var destination: ArenaWebDestination = .home
    @Published private(set) var progress: Double = 0
    @Published private(set) var isLoading = false
    @Published private(set) var canGoBack = false
    @Published private(set) var canGoForward = false
    @Published private(set) var loadFailure: LoadFailure?
    /// 페이지 위에 한 줄로 뜨는 안내. 오른쪽 버튼이 무엇이어야 하는지까지 같이 든다 —
    /// "다시 연결" 이 답이 아닌 안내(웹 로그아웃 차단)에 재연결 버튼을 달면 거짓말이 된다.
    @Published private(set) var sessionNotice: SessionNotice?

    struct SessionNotice: Equatable {
        let message: String
        /// true 면 오른쪽 버튼이 "다시 연결"(핸드오프 재시도), false 면 "확인"(닫기).
        let offersReconnect: Bool
    }

    /// 안내 줄의 "확인".
    func dismissSessionNotice() { sessionNotice = nil }
    @Published private(set) var block: Block?
    /// 웹뷰 인스턴스가 통째로 바뀌었음을 표현 계층에 알리는 세대 번호.
    /// (계정이 바뀌면 앞사람 페이지가 남지 않게 웹뷰를 새로 만든다)
    @Published private(set) var webViewGeneration = 0
    /// 웹이 "앱으로 돌아가는 링크"(Matths 대시보드)를 눌렀다. 화면이 닫는다.
    @Published var wantsClose = false
    @Published var wantsNativeCommerce = false
    @Published var externalDestination: ExternalDestination?
    @Published var previewFile: PreviewFile?

    private let serverBase = ServerAPI.baseURL

    private(set) var webView: WKWebView
    private var observers: [NSKeyValueObservation] = []
    /// 웹뷰를 새로 만들 때마다 같이 새로 만든다 — 같은 컨트롤을 다시 붙이면
    /// addTarget 이 겹쳐 당겨 새로고침 한 번에 두 번 로드된다.
    private var refreshControl = UIRefreshControl()

    private var signedIn = false
    /// 이번 계정으로 아레나 페이지를 실제로 띄운 적이 있다 = 웹 세션 쿠키가 살아 있다.
    private var hasWebSession = false
    /// 계정이 바뀌었다. 다음 진입에서 쿠키를 지우고 웹뷰를 새로 만든다.
    ///
    /// 처음부터 true 로 두지 않는 이유: 세션 쿠키는 게시판 웹뷰와 **같은 저장소**에 있다.
    /// 아레나를 열 때마다 쿠키를 지우면 학생이 글을 쓰던 게시판 세션까지 같이 끊긴다.
    /// 첫 진입은 어차피 핸드오프가 세션을 새로 만들어 쿠키를 덮어쓰므로 지울 필요가 없다.
    /// 지워야 하는 순간은 딱 하나 — 계정이 바뀌었을 때다.
    private var needsFreshSession = false
    /// 핸드오프 URL 을 여는 중 — 303 목적지를 딱 한 번 가로챌 구간.
    private var handingOff = false
    /// 핸드오프가 끝나면 갈 곳.
    private var pendingDestination: URL?
    private var lastHandoffAt: Date?
    /// 마지막으로 성공적으로 머문 아레나 주소. /login 을 가로챈 뒤 돌아갈 곳이다.
    private var lastArenaURL: URL?
    private var downloadFiles: [ObjectIdentifier: URL] = [:]
    /// 계정 전환 때 WKWebView를 새로 만들어도 현재 Dynamic Type 배율을 잃지 않는다.
    private var hostedPageSize: DynamicTypeSize = .large
    /// 계정 전환·토큰 폐기 알림 구독. 프로세스 수명과 같아서(shared) 해제하지 않는다.
    private var accountObservers: [NSObjectProtocol] = []

    private override init() {
        webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        super.init()
        webView = makeWebView()
        observeAccountChanges()
    }

    /// 계정이 바뀌는 순간을 **모델이 직접** 듣는다. 화면(ArenaWebScreen)에 맡기면
    /// 브리지가 떠 있지 않은 동안 일어난 계정 전환을 아무도 못 듣는다 — 그러면
    /// hasWebSession 이 true 인 채로 남아, 다음에 브리지를 열 때 핸드오프를 건너뛰고
    /// **앞사람의 세션 쿠키로** 아레나 페이지를 그대로 띄운다(다른 계정의 우편함·
    /// 전적·페이백 계좌가 보인다). 실제로 계정 전환은 프로필 화면에서 일어나고
    /// 브리지는 그때 떠 있지 않으므로, 화면에만 맡기면 반드시 새는 경로다.
    private func observeAccountChanges() {
        let center = NotificationCenter.default
        // 계정 슬롯 전환 · 401 로 키체인 토큰이 폐기된 경우(앱은 로그아웃인데 웹뷰만
        // 앞 계정 세션으로 조작이 되는 상태를 만들지 않는다) 둘 다 같은 처리다.
        let names: [Notification.Name] = [
            DataScope.didSwitchNotification,
            .matthsServerAuthenticationExpired,
        ]
        accountObservers = names.map { name in
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.accountDidChange() }
            }
        }
    }

    func updateAccessibility(size: DynamicTypeSize) {
        hostedPageSize = size
        WebContentAccessibility.configureHostedPage(
            webView,
            size: size
        )
    }

    // MARK: 진입

    /// 화면이 뜰 때/목적지를 바꿔 다시 열 때 부른다.
    /// - Parameter signedIn: 앱의 서버 로그인 여부. 넘기지 않으면 키체인 토큰으로 본다.
    func open(_ destination: ArenaWebDestination, signedIn: Bool? = nil) {
        self.destination = destination
        self.signedIn = signedIn ?? ServerAPI.hasToken
        loadFailure = nil
        wantsClose = false

        #if DEBUG
        // 데모 모드: 서버·계정·쿠키가 없다. 핸드오프를 치면 픽스처 없는 경로라
        // 실패 로그만 남기고 빈 화면이 된다 — 무엇을 보고 있는지 화면에 적어 준다.
        // (아레나 규칙·정산 문구를 앱이 새로 쓰지 않으려면 목업을 만들 수 없다.
        //  웹 페이지가 정본이고, 데모에는 그 정본이 없다.)
        if DemoMode.isOn {
            block = .demo
            sessionNotice = nil
            return
        }
        #endif

        guard self.signedIn else {
            // 아레나 웹은 전 경로가 로그인 필수다. 열어 봤자 /login 폼이 뜨고,
            // 그 폼으로 로그인하면 앱 계정과 웹 세션이 둘로 갈린다.
            block = .signedOut
            sessionNotice = nil
            return
        }

        block = nil
        let url = arenaURL(destination.path)
        Task { @MainActor in
            #if DEBUG
            // 브리지가 "핸드오프부터" 시작했는지 "세션 재사용" 인지는 로그만 보고 갈라야 한다.
            // (실측 중 이 한 줄이 없어서 재사용 경로가 안 도는 원인을 못 찾았다)
            NSLog("ARENA-WEB 열기 · %@ · 세션재사용=%@ · 쿠키폐기필요=%@",
                  url.path, hasWebSession ? "예" : "아니오", needsFreshSession ? "예" : "아니오")
            #endif
            if needsFreshSession {
                // 계정이 바뀌었을 수 있다 — 앞사람의 세션 쿠키와 화면을 먼저 버린다.
                await discardWebSession()
                needsFreshSession = false
            }
            if hasWebSession {
                load(url)
            } else {
                await handoff(then: url)
            }
        }
    }

    /// 로그아웃·계정 전환. 앞사람의 웹 세션을 즉시 버린다.
    func accountDidChange() {
        // 겹쳐 오는 알림을 한 번으로 접는다. 로그아웃 한 번에 슬롯 전환과 토큰 폐기가
        // 연달아 오는데, 두 번 돌면 두 번째가 **이미 떼어 낸** 웹뷰를 보고
        // "화면에 없었다" 고 판단해 다시 열지 않는다 — 브리지가 빈 화면으로 남는다.
        guard !discardingSession else { return }
        discardingSession = true
        // 화면이 떠 있는 채로 계정이 바뀌면 빈 웹뷰만 남는다 — 새 계정으로 다시 열거나
        // (로그아웃이면) "로그인이 필요합니다" 카드까지 스스로 보여 준다.
        let wasVisible = webView.superview != nil
        needsFreshSession = true
        hasWebSession = false
        block = nil
        sessionNotice = nil
        Task { @MainActor in
            await discardWebSession()
            // 여기서 이미 지웠으므로 다음 진입이 또 지우지 않게 내린다.
            needsFreshSession = false
            discardingSession = false
            if wasVisible { open(destination, signedIn: ServerAPI.hasToken) }
        }
    }

    /// accountDidChange 가 도는 중인지. 위 guard 의 상태값.
    private var discardingSession = false

    #if DEBUG
    /// 디버그 바의 "데모" 칩. 출처가 통째로 바뀌므로 지금 상태를 다 버리고 다시 판단한다.
    func demoModeDidChange() {
        needsFreshSession = true
        hasWebSession = false
        sessionNotice = nil
        open(destination, signedIn: DemoMode.isOn ? false : ServerAPI.hasToken)
    }
    #endif

    #if DEBUG
    /// 자가진단 전용: "이미 이어 둔 웹 세션이 있다" 고 가정하게 만든다.
    /// 이 상태에서 목적지를 열면 핸드오프 없이 아레나 주소를 바로 치므로,
    /// 세션이 없을 때 서버가 주는 302 /login 을 앱이 가로채 **다시 잇는** 경로
    /// (실제 사용 중 세션 만료와 같은 길)를 로그인 없이도 태워 볼 수 있다.
    func debugAssumeExistingWebSession() {
        needsFreshSession = false
        hasWebSession = true
    }
    #endif

    /// 안내 줄의 "다시 연결" — 핸드오프를 처음부터 다시 한다.
    func reconnect() {
        sessionNotice = nil
        hasWebSession = false
        lastHandoffAt = nil
        open(currentArenaDestination ?? destination, signedIn: signedIn)
    }

    // MARK: 조작

    func goBack() { webView.goBack() }
    func goForward() { webView.goForward() }
    func stop() { webView.stopLoading() }

    func reload() {
        loadFailure = nil
        if webView.url == nil {
            open(destination, signedIn: signedIn)
        } else {
            webView.reload()
        }
    }

    /// 오류 카드의 "다시 시도". 실패한 주소가 있으면 그 주소를, 없으면 목적지부터.
    func retry() {
        let failed = loadFailure?.url
        loadFailure = nil
        if let failed, isServerHost(failed) {
            load(failed)
        } else {
            open(destination, signedIn: signedIn)
        }
    }

    // MARK: 로그인 핸드오프

    /// 게시판·이용권 화면과 **같은 통로**. mode "pricing" 은 결제 여부와 무관하게
    /// 항상 발급된다(서버 규칙) — 우리는 세션 쿠키만 필요하고 결제 화면은 안 본다.
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
            NSLog("ARENA-WEB 핸드오프 요청 성공 → 세션 URL 로드")
            webView.load(URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData))
        } catch {
            // 토큰 만료(401)면 ServerAPI 가 이미 앱 전체에 재로그인을 알렸다.
            // 아레나는 로그인 없이 볼 수 있는 페이지가 하나도 없으므로, 게시판처럼
            // "읽기 모드로 계속" 이 없다. 무엇이 막혔는지 카드로 말하고 멈춘다.
            handingOff = false
            pendingDestination = nil
            NSLog("ARENA-WEB 핸드오프 실패 · %@", String(describing: error))
            loadFailure = LoadFailure(
                message: handoffFailureMessage(error),
                url: nil)
        }
    }

    private func handoffFailureMessage(_ error: Error) -> String {
        if let api = error as? ServerAPIError {
            if api.statusCode == 401 {
                return "로그인 세션이 만료됐습니다. 앱에 다시 로그인한 뒤 열어 주세요."
            }
            if let message = api.message, !message.isEmpty {
                return "GOAT Arena 웹 세션을 잇지 못했습니다. \(message)"
            }
        }
        return "GOAT Arena 웹 세션을 잇지 못했습니다. " + readableMessage(for: error)
    }

    /// 이용권 화면(CommerceHubScreen)·게시판과 같은 검사:
    /// https · 같은 호스트 · /app/commerce/ 경로만 연다.
    private func validatedHandoffURL(_ value: String) -> URL? {
        guard let url = URL(string: value),
              url.scheme == "https",
              url.host?.lowercased() == serverBase.host?.lowercased(),
              url.path.hasPrefix("/app/commerce/") else { return nil }
        return url
    }

    /// 핸드오프 URL 이 리다이렉트 없이 끝났다(410 만료·403 계정 상태).
    private func abandonHandoff(reason: String) {
        handingOff = false
        pendingDestination = nil
        hasWebSession = false
        loadFailure = LoadFailure(message: reason, url: nil)
    }

    // MARK: 웹뷰

    private func makeWebView() -> WKWebView {
        let configuration = WKWebViewConfiguration()
        // 영속 저장소 — 세션 쿠키가 앱을 껐다 켜도 남는다(게시판과 같은 저장소를 쓰므로
        // 한쪽에서 이어 둔 세션을 다른 쪽이 그대로 쓴다).
        configuration.websiteDataStore = .default()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.allowsInlineMediaPlayback = true
        // 아레나 시작 페이지의 히어로 영상은 소리를 켠 채 autoplay 를 시도하고, 막히면
        // 스스로 음소거로 다시 시도한다(public/js/goat-arena.js). 전부 막으면 포스터만
        // 남아 웹과 다른 화면이 되고, 전부 열면 앱이 갑자기 소리를 낸다.
        // 소리만 사용자 조작을 요구하면 웹과 같은 결과가 된다 — 음소거 영상은 돌고,
        // 페이지의 "소리 끄기" 버튼(사용자 조작)으로 소리를 켤 수 있다.
        configuration.mediaTypesRequiringUserActionForPlayback = .audio
        // 웹이 앱 셸 안인지 알아볼 수 있게 UA 뒤에 표식만 붙인다(요청 헤더는 그대로).
        configuration.applicationNameForUserAgent = "MatthsApp/\(ServerAPI.clientBuildVersion)"
        // 사이트 전역 머리와 건너뛰기 링크만 숨긴다. **아레나 HUD 는 그대로 둔다** —
        // 홈·티어 순위·UNRANKED·RANKED·상점·규정·우편함·프로필로 가는 그 줄이
        // 감독이 말한 "GOAT Arena 탭의 버튼들" 자체이기 때문이다.
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
        WebContentAccessibility.configureHostedPage(
            webView,
            size: hostedPageSize
        )

        refreshControl = UIRefreshControl()
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
            open(destination, signedIn: signedIn)
        } else {
            webView.reload()
        }
    }

    /// 사이트 전역 머리만 숨긴다. CSP(style-src 'unsafe-inline')와 무관하게 먹히도록
    /// adoptedStyleSheets 를 먼저 쓴다(게시판에서 실측한 방식).
    private static let shellStyleScript = """
    (function () {
      var css = "header.site-header, .matths-skip-link, .arena-skip-link, .skip-link"
        + " { display: none !important; }";
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

    private func arenaURL(_ path: String) -> URL {
        var components = URLComponents(url: serverBase, resolvingAgainstBaseURL: false)
        let split = path.split(separator: "?", maxSplits: 1).map(String.init)
        let base = split.first ?? "/goat-arena"
        // 목적지 표 밖(custom)에서 들어온 경로가 아레나 밖으로 새지 않게 한 번 더 본다.
        components?.path = ArenaWebDestination.owns(path: base) ? base : "/goat-arena"
        components?.query = split.count > 1 ? split[1] : nil
        return components?.url ?? serverBase
    }

    /// 지금 보고 있는 아레나 페이지를 목적지로 되돌린 값(다시 연결에 쓴다).
    private var currentArenaDestination: ArenaWebDestination? {
        guard let url = webView.url, isServerHost(url),
              ArenaWebDestination.owns(path: url.path) else {
            return nil
        }
        let path = url.query.map { "\(url.path)?\($0)" } ?? url.path
        return .custom(path: path, title: destination.title)
    }

    private func isServerHost(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased(), let base = serverBase.host?.lowercased() else {
            return false
        }
        func strip(_ value: String) -> String {
            value.hasPrefix("www.") ? String(value.dropFirst(4)) : value
        }
        return strip(host) == strip(base)
    }

    /// 웹뷰가 아레나를 벗어나 앱이 이미 갖고 있는 화면(학습 홈·대시보드)으로 가려는 링크.
    /// 웹 대시보드를 앱 안에 또 띄우면 학생은 어느 쪽이 진짜 앱인지 알 수 없다.
    private func isReturnToAppLink(_ url: URL) -> Bool {
        guard isServerHost(url) else { return false }
        return ["/", "/main", "/my-learning", "/war-of-masters"].contains(url.path)
    }

    private func load(_ url: URL) {
        loadFailure = nil
        webView.load(URLRequest(url: url))
    }

    // MARK: 세션 폐기

    /// 계정 전환·로그아웃. 쿠키를 지우고 **웹뷰를 통째로 새로 만든다** —
    /// 쿠키만 지우면 앞사람의 마지막 아레나 페이지가 화면과 뒤로가기 기록에 남는다.
    private func discardWebSession() async {
        hasWebSession = false
        handingOff = false
        pendingDestination = nil
        lastArenaURL = nil
        lastHandoffAt = nil
        webView.stopLoading()
        await clearServerCookies()
        observers.removeAll()
        webView.navigationDelegate = nil
        webView.uiDelegate = nil
        webView.removeFromSuperview()
        webView = makeWebView()
        webViewGeneration &+= 1
        progress = 0
        isLoading = false
        canGoBack = false
        canGoForward = false
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

    fileprivate func readableMessage(for error: Error) -> String {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost,
                 NSURLErrorDataNotAllowed:
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

extension ArenaWebModel: WKNavigationDelegate {
    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }
        // 서브프레임과 리소스는 웹이 알아서 한다.
        let isMainFrame = navigationAction.targetFrame?.isMainFrame ?? true
        guard isMainFrame else {
            decisionHandler(.allow)
            return
        }

        // 1) 핸드오프 뒤 서버가 보내는 /pricing — 여기서 딱 한 번 방향을 튼다.
        //    쿠키는 303 응답과 함께 이미 심겼다. 결제 페이지는 보여 주지 않는다.
        if handingOff, isServerHost(url), url.path == "/pricing" {
            handingOff = false
            let destination = pendingDestination ?? arenaURL(self.destination.path)
            pendingDestination = nil
            decisionHandler(.cancel)
            NSLog("ARENA-WEB 핸드오프 리다이렉트 가로챔 → %@", destination.path)
            load(destination)
            return
        }

        // 서버가 발급한 일회용 핸드오프 URL은 쿠키를 심기 위해 딱 이 구간에만 허용한다.
        // 평상시 같은 경로로 이동하면 아래 결제 경계가 네이티브 구매 화면으로 보낸다.
        if handingOff, isServerHost(url), url.path.hasPrefix("/app/commerce/") {
            decisionHandler(.allow)
            return
        }

        // 웹 아레나에 같은 호스트의 가격·결제 링크가 생겨도 Toss 결제면을 앱 안에서
        // 열지 않는다. 화면이 이 신호를 받아 네이티브 StoreKit 구매 화면으로 전환한다.
        if isServerHost(url), ServerAPI.isWebPurchaseSurface(url) {
            decisionHandler(.cancel)
            wantsNativeCommerce = true
            return
        }

        // 2) 웹의 로그인·가입 화면으로 튕기면 세션이 끊긴 것이다. 앱 계정으로 다시 잇는다
        //    (30초에 한 번만 — 서버가 계속 거부하면 카드로). 웹 로그인 폼은 보여 주지
        //    않는다: 거기서 로그인하면 앱 계정과 웹 세션이 둘로 갈린다.
        if isServerHost(url), ["/login", "/register"].contains(url.path) {
            decisionHandler(.cancel)
            hasWebSession = false
            NSLog("ARENA-WEB 웹 로그인 화면 가로챔(%@) — 세션 다시 잇기", url.path)
            let recently = lastHandoffAt.map { Date().timeIntervalSince($0) < 30 } ?? false
            if signedIn && !recently {
                let destination = lastArenaURL ?? arenaURL(self.destination.path)
                Task { @MainActor in await handoff(then: destination) }
            } else if signedIn {
                // 방금(30초 안에) 세션을 이었는데도 서버가 다시 로그인 화면으로 보낸다.
                // 앱에는 로그인이 되어 있으므로 "로그인이 필요합니다" 는 거짓말이 되고,
                // 학생은 이미 되어 있는 로그인을 찾아 헤맨다. 무엇이 막혔는지 그대로 쓴다.
                // (핸드오프를 즉시 또 걸지 않는 이유: 서버가 계속 거부하면 1회용 토큰만
                //  태우며 무한히 왕복한다 — "다시 시도" 로 사람이 끊어 준다)
                loadFailure = LoadFailure(
                    message: "앱에는 로그인되어 있지만 GOAT Arena 웹 세션을 잇지 못했습니다. "
                        + "잠시 후 다시 시도해 주세요.",
                    url: nil)
            } else {
                block = .signedOut
            }
            return
        }

        // 3) 웹 로그아웃은 앱이 모르는 사이에 세션만 끊는다. 앱의 로그아웃은
        //    프로필 화면에 있고, 그쪽이 키체인 토큰까지 함께 정리한다.
        if isServerHost(url), url.path == "/logout" {
            decisionHandler(.cancel)
            sessionNotice = SessionNotice(
                message: "로그아웃은 앱의 프로필 화면에서 해 주세요.",
                offersReconnect: false)
            return
        }

        // 4) "Matths 대시보드로 돌아가기" 류 링크 — 앱으로 돌아온다.
        if isReturnToAppLink(url) {
            decisionHandler(.cancel)
            wantsClose = true
            return
        }

        // 5) 외부 호스트. 학생이 누른 링크만 Safari 로 보낸다 — 첨부·저장소로 가는
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

        if isServerHost(url), ArenaWebDestination.owns(path: url.path) {
            lastArenaURL = url
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
        if handingOff, let url = http.url, isServerHost(url),
           url.path.hasPrefix("/app/commerce/"), http.statusCode >= 400 {
            decisionHandler(.cancel)
            abandonHandoff(reason: http.statusCode == 403
                ? "계정 상태 때문에 GOAT Arena 웹 세션을 잇지 못했습니다."
                : "로그인 연결이 만료됐습니다. 다시 시도해 주세요.")
            return
        }

        // 서버가 5xx(점검·배포 중)나 404 를 주면 페이지가 빈 흰 화면으로 남는다.
        // 아레나가 자기 사정(자격 없음·잠금)을 말하는 403·423 은 서버가 아레나
        // 오류 페이지를 정성껏 그려 주므로 **가로채지 않는다** — 그게 정본이다.
        if let url = http.url, isServerHost(url), http.statusCode >= 500 || http.statusCode == 404 {
            decisionHandler(.cancel)
            loadFailure = LoadFailure(
                message: http.statusCode >= 500
                    ? "서버가 잠시 응답하지 않습니다(\(http.statusCode)). 점검이나 배포 중일 수 있어요 — 잠시 뒤 다시 시도해 주세요."
                    : "그 페이지를 찾을 수 없습니다(404). 경기가 끝났거나 주소가 바뀌었을 수 있어요.",
                url: url)
            return
        }

        // 증빙·분석 결과 같은 첨부는 WKDownload 로 받아 미리보기로 연다.
        // 안 하면 웹뷰가 빈 화면으로 멈춘다.
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
        // 핸드오프 URL 자체가 최종 페이지로 남았다면(리다이렉트가 안 왔다) 되돌린다.
        if handingOff, let url = webView.url, url.path.hasPrefix("/app/commerce/") {
            abandonHandoff(reason: "로그인 연결이 만료됐습니다. 다시 시도해 주세요.")
            return
        }
        if let url = webView.url, isServerHost(url), ArenaWebDestination.owns(path: url.path) {
            // 아레나 페이지가 실제로 떴다 = 세션이 살아 있다. 다음 목적지는 핸드오프 없이 연다.
            hasWebSession = true
            lastArenaURL = url
            sessionNotice = nil
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
        if webView.url != nil { webView.reload() } else { open(destination, signedIn: signedIn) }
    }

    private func handleFailure(_ error: Error, url: URL?) {
        refreshControl.endRefreshing()
        let nsError = error as NSError
        // 우리가 방향을 튼 내비게이션(핸드오프·/login·앱 복귀 가로채기)과 사용자의 중지는
        // 오류가 아니다.
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled { return }
        // WebKitErrorDomain 102 = FrameLoadInterruptedByPolicyChange. 공개 enum(WKError)에는
        // 없는 내부 코드라 도메인 문자열과 숫자로 본다.
        if nsError.domain == "WebKitErrorDomain" && nsError.code == 102 { return }
        if handingOff {
            handingOff = false
            pendingDestination = nil
        }
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

extension ArenaWebModel: WKUIDelegate {
    /// target="_blank". 같은 호스트면 이 웹뷰에서, 아니면 Safari 로.
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {
        guard let url = navigationAction.request.url else { return nil }
        if isServerHost(url) {
            webView.load(navigationAction.request)
        } else if let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" {
            externalDestination = ExternalDestination(url: url)
        }
        return nil
    }

    /// 아레나 웹은 도전 취소·초대 거절·구매 확인에 confirm 을 쓴다. 위임이 없으면
    /// WebKit 이 조용히 취소(false)로 처리해서 **버튼이 무음으로 죽는다**.
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

    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String,
                 defaultText: String?, initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (String?) -> Void) {
        guard let presenter = Self.topViewController() else {
            completionHandler(nil)
            return
        }
        let alert = UIAlertController(title: nil, message: prompt, preferredStyle: .alert)
        alert.addTextField { $0.text = defaultText }
        alert.addAction(UIAlertAction(title: "취소", style: .cancel) { _ in completionHandler(nil) })
        alert.addAction(UIAlertAction(title: "확인", style: .default) { [weak alert] _ in
            completionHandler(alert?.textFields?.first?.text)
        })
        presenter.present(alert, animated: true)
    }

    static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.flatMap(\.windows).first(where: \.isKeyWindow)
            ?? scenes.first?.windows.first
        var top = window?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}

// MARK: - WKDownloadDelegate

extension ArenaWebModel: WKDownloadDelegate {
    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse,
                  suggestedFilename: String, completionHandler: @escaping (URL?) -> Void) {
        // 임시 폴더 아래 다운로드마다 새 디렉터리 — 같은 파일명끼리 덮어쓰지 않는다.
        // 영구 보관이 아니라 미리보기용이다. 시스템이 tmp 를 정리해도 잃을 것이 없다.
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("arena-web-downloads", isDirectory: true)
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
        loadFailure = LoadFailure(message: "파일을 내려받지 못했습니다. " + readableMessage(for: error),
                                  url: nil)
    }
}
