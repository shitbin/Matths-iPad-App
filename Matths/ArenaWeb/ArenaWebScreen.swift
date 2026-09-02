//  ArenaWebScreen.swift
//  Matths
//
//  아레나 웹 브리지의 네이티브 셸 — 게시판(CommunityScreen)과 **같은 디자인 언어**다.
//  조작 줄(뒤로·앞으로 · 제목 · 새로고침 · 닫기) · 2pt 진행선 · 안내 줄 · 오류 카드.
//
//  이 화면은 아레나의 규칙·정산·페이백을 **한 글자도 다시 쓰지 않는다**. 그 문장의
//  정본은 웹 페이지이고, 앱이 같은 말을 따로 쓰는 순간 서버가 규정을 고쳐도 앱만
//  옛 문장을 계속 보여 준다. 여기서 앱이 쓰는 말은 "지금 왜 웹을 못 여는가" 뿐이다.
//
//  화면 보호: 경기 페이지(/goat-arena/matches/…)는 문항이 그대로 보이는 평가면이다.
//  guardModel 을 넘겨 열면 네이티브 경기 화면과 같은 보호 계층(앱 전환 덮개·녹화 덮개·
//  워터마크·감사 이벤트)이 웹뷰 위에도 붙는다.

import QuickLook
import SafariServices
import SwiftUI
import WebKit

struct ArenaWebScreen: View {
    /// 열 곳. 화면이 떠 있는 동안 모델이 실제 목적지를 들고 있으므로,
    /// 제목·보호 여부는 모델을 따라간다(딥링크로 목적지가 바뀌어도 맞는다).
    let destination: ArenaWebDestination
    /// 앱의 서버 로그인 여부. 넘기지 않으면 키체인 토큰으로 본다 —
    /// AppStore 를 환경으로 받지 않기 때문에(모달로 단독 표시될 수 있다) 기본값이 필요하다.
    var signedIn: Bool? = nil
    /// 화면 보호를 함께 걸 때만 넘긴다(경기·증빙 목적지).
    var guardModel: ScreenshotGuard? = nil
    /// 보호 화면에서 캡처가 감지됐을 때 앱이 기록할 곳.
    var onCapture: ((String) -> Void)? = nil
    /// 로그인 카드의 "로그인하기". 넘기지 않으면 버튼 없이 안내만 보여 준다.
    var onRequestSignIn: (() -> Void)? = nil
    /// 닫기. 모달로 띄웠으면 여기서 dismiss 한다.
    var onClose: (() -> Void)? = nil

    @ObservedObject private var model = ArenaWebModel.shared
    /// onAppear 는 위에 뜬 시트(Safari·첨부 미리보기)를 닫을 때도 다시 온다.
    /// 그때마다 목적지를 다시 열면 학생이 보던 페이지와 스크롤이 매번 사라진다.
    @State private var didOpen = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var compact: Bool { horizontalSizeClass == .compact }
    private var compactHeight: Bool { verticalSizeClass == .compact }
    /// 오류·로그인 차단 카드가 웹 영역을 완전히 덮는 동안 뒤 문서가 VoiceOver에
    /// 남으면 학생은 보이지 않는 경기 링크와 입력 요소를 조작할 수 있다.
    private var webContentObscured: Bool {
        model.loadFailure != nil || model.block != nil
    }

    var body: some View {
        Group {
            if let guardModel, model.destination.isProtectedAssessmentSurface {
                shell
                    .protectedAssessmentPresentation(
                        model.destination.protectionSurfaceName,
                        guardModel: guardModel
                    ) { stuckPoint in
                        onCapture?(stuckPoint)
                    }
                    // 보호 modifier 안쪽이 @EnvironmentObject 로 guard 를 찾는다.
                    // 이 화면은 모달로 단독 표시될 수 있어 앱 루트의 환경을 못 받는다.
                    .environmentObject(guardModel)
            } else {
                shell
            }
        }
    }

    private var shell: some View {
        VStack(spacing: 0) {
            controls
            progressLine
            if let notice = model.sessionNotice {
                sessionNoticeBar(notice)
            }
            ZStack {
                ArenaWebContainerView(model: model)
                    // 웹 페이지가 자기 배경을 그리기 전까지 셸의 종이색을 보인다.
                    .background(Tokens.paper)
                    .accessibilityHidden(webContentObscured)
                if let failure = model.loadFailure {
                    failureCard(failure)
                }
                if let block = model.block {
                    blockCard(block)
                }
            }
        }
        .background(Tokens.paper)
        .onAppear {
            model.updateAccessibility(size: dynamicTypeSize)
            guard !didOpen else { return }
            didOpen = true
            model.open(destination, signedIn: signedIn)
        }
        .onChange(of: dynamicTypeSize) { _, size in
            model.updateAccessibility(size: size)
        }
        // 계정 전환·토큰 폐기는 **모델이 직접** 듣는다(ArenaWebModel.observeAccountChanges).
        // 여기서 또 듣지 않는 이유: 계정 전환은 브리지가 떠 있지 않을 때도 일어나므로
        // 화면에만 맡기면 앞사람 세션이 남고, 양쪽이 같이 들으면 한 번의 로그아웃에
        // accountDidChange 가 두 번 돌아 두 번째가 화면을 다시 열지 못한다.
        #if DEBUG
        .onReceive(NotificationCenter.default.publisher(for: DemoMode.didChangeNotification)) { _ in
            model.demoModeDidChange()
        }
        #endif
        // 웹의 "Matths 대시보드로 돌아가기" 는 앱에서 이 화면을 닫는 것과 같은 뜻이다.
        .onChange(of: model.wantsClose) { _, wants in
            guard wants else { return }
            model.wantsClose = false
            onClose?()
        }
        // 아레나 웹 문서 안의 이용권 링크도 웹 결제로 보내지 않는다. 루트 라우트를
        // StoreKit 구매 화면으로 바꾼 뒤 이 전체화면 브리지를 닫는다.
        .onChange(of: model.wantsNativeCommerce) { _, wants in
            guard wants else { return }
            model.wantsNativeCommerce = false
            NotificationCenter.default.post(name: .matthsRouteRequest,
                                            object: AppStore.Route.commerce)
            onClose?()
        }
        .compactHeightSheet(item: $model.externalDestination) { destination in
            ArenaWebSafariView(url: destination.url)
                .ignoresSafeArea()
        }
        .compactHeightSheet(item: $model.previewFile) { file in
            ArenaWebFilePreview(url: file.url) {
                model.previewFile = nil
            }
                .ignoresSafeArea()
        }
    }

    // MARK: 조작 줄

    /// 뒤로·앞으로 · 제목 · 새로고침 · 닫기. 모든 버튼이 44pt 히트 영역을 지킨다.
    /// 접근성 글자 크기에서 한 줄에 다 안 서면 제목 줄과 버튼 줄로 나눈다.
    private var controls: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Tokens.Space.s2) {
                historyButtons
                title
                Spacer(minLength: Tokens.Space.s2)
                reloadButton
                closeButton
            }
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: Tokens.Space.s2) {
                    title
                    Spacer(minLength: Tokens.Space.s2)
                    closeButton
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
        Text(model.destination.title)
            .font(compactHeight ? .mBodyB : .mHeading)
            .foregroundStyle(Tokens.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
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

    /// 게시판의 "글쓰기" 자리. 여기서는 앱으로 돌아가는 버튼이 그 자리를 쓴다 —
    /// 브리지는 모달이라 나가는 길이 화면에 항상 보여야 한다.
    /// (탭 안에 끼워 넣는 쓰임에서는 onClose 가 없고, 그때는 버튼도 없다 — 탭바가 나가는 길이다)
    @ViewBuilder private var closeButton: some View {
        if let onClose {
            Button {
                onClose()
            } label: {
                Label("닫기", systemImage: "xmark")
                    .font(.mCaption)
                    .foregroundStyle(Tokens.text2)
                    .padding(.horizontal, Tokens.Space.s4)
                    .padding(.vertical, Tokens.Space.s2)
                    .background(Tokens.surface, in: Capsule())
                    .overlay(Capsule().strokeBorder(Tokens.line, lineWidth: 1))
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("닫기")
            .accessibilityHint("GOAT Arena 웹을 닫고 앱으로 돌아갑니다")
        }
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

    private func sessionNoticeBar(_ notice: ArenaWebModel.SessionNotice) -> some View {
        HStack(alignment: .center, spacing: Tokens.Space.s3) {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.mCaption)
                .foregroundStyle(Tokens.primary)
                .accessibilityHidden(true)
            Text(notice.message)
                .font(.mCaption)
                .foregroundStyle(Tokens.text2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: Tokens.Space.s2)
            Button(notice.offersReconnect ? "다시 연결" : "확인") {
                if notice.offersReconnect { model.reconnect() } else { model.dismissSessionNotice() }
            }
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

    // MARK: 오류·차단 카드

    /// 오프라인·서버 중단·핸드오프 실패. 반쯤 그려진 페이지가 뒤에 비치지 않게 덮는다.
    private func failureCard(_ failure: ArenaWebModel.LoadFailure) -> some View {
        ZStack {
            Tokens.paper.ignoresSafeArea()
            fittingOverlayCard {
                VStack(alignment: .leading, spacing: Tokens.Space.s4) {
                    Label("GOAT Arena를 불러오지 못했습니다", systemImage: "wifi.exclamationmark")
                        .font(.mHeading)
                        .foregroundStyle(Tokens.warningInk)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(failure.message)
                        .font(.mBody)
                        .foregroundStyle(Tokens.text2)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: Tokens.Space.s3) {
                        Button("다시 시도") { model.retry() }
                            .buttonStyle(PrimaryButtonStyle())
                        if onClose != nil {
                            Button("닫기") { onClose?() }
                                .buttonStyle(SecondaryButtonStyle())
                        }
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }

    /// 서버를 치지 않고 멈춘 상태들 — 로그인 없음 · 데모 모드.
    private func blockCard(_ block: ArenaWebModel.Block) -> some View {
        ZStack {
            Tokens.paper.ignoresSafeArea()
            fittingOverlayCard {
                VStack(alignment: .leading, spacing: Tokens.Space.s4) {
                    Label(blockTitle(block), systemImage: blockIcon(block))
                        .font(.mHeading)
                        .foregroundStyle(Tokens.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(blockMessage(block))
                        .font(.mBody)
                        .foregroundStyle(Tokens.text2)
                        .fixedSize(horizontal: false, vertical: true)
                    if block == .signedOut, let onRequestSignIn {
                        Button("로그인하기") { onRequestSignIn() }
                            .buttonStyle(PrimaryButtonStyle())
                    }
                    if onClose != nil {
                        Button("닫기") { onClose?() }
                            .buttonStyle(SecondaryButtonStyle())
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }

    /// iPhone 가로 + 접근성 글자 크기에서는 안내 카드가 화면보다 높아진다.
    /// 평소에는 중앙 카드를 유지하고, 실제로 높이가 모자랄 때만 스크롤 후보로
    /// 내려가 제목과 마지막 닫기/재시도 버튼을 모두 도달 가능하게 한다.
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

    private func blockTitle(_ block: ArenaWebModel.Block) -> String {
        switch block {
        case .signedOut: return "로그인이 필요합니다"
        case .demo:      return "데모 모드입니다"
        }
    }

    private func blockIcon(_ block: ArenaWebModel.Block) -> String {
        switch block {
        case .signedOut: return "person.crop.circle.badge.exclamationmark"
        case .demo:      return "ladybug"
        }
    }

    private func blockMessage(_ block: ArenaWebModel.Block) -> String {
        switch block {
        case .signedOut:
            return "GOAT Arena는 계정 소유 활동이라 로그인 뒤에 열 수 있습니다. "
                + "앱에 로그인하면 이 화면이 그대로 이어집니다."
        case .demo:
            // 데모는 서버·계정·쿠키가 없는 실행이다. 아레나 페이지를 목업으로 흉내 내면
            // 앱이 아레나 문구를 새로 쓰는 셈이 되므로 무엇이 막혔는지만 적는다.
            return "데모 모드에서는 서버에 연결하지 않아 GOAT Arena 웹(\(model.destination.path))을 "
                + "열지 않습니다. 실제 화면은 디버그 바에서 데모를 끄고 로그인한 뒤 확인해 주세요."
        }
    }
}

// MARK: - 웹뷰 표현

/// 모델이 웹뷰를 소유한다. 표현은 컨테이너에 붙였다 뗐다만 한다 —
/// 계정이 바뀌어 모델이 웹뷰를 새로 만들면(webViewGeneration) 여기서 갈아 끼운다.
struct ArenaWebContainerView: UIViewRepresentable {
    @ObservedObject var model: ArenaWebModel

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = UIColor(Tokens.paper)
        attach(model.webView, to: container)
        return container
    }

    func updateUIView(_ container: UIView, context: Context) {
        let webView = model.webView
        guard webView.superview !== container else { return }
        container.subviews.forEach { $0.removeFromSuperview() }
        attach(webView, to: container)
    }

    private func attach(_ webView: WKWebView, to container: UIView) {
        webView.removeFromSuperview()
        webView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            webView.topAnchor.constraint(equalTo: container.topAnchor),
            webView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
    }
}

// MARK: - Safari · 미리보기

/// 외부 링크는 게시판·결제와 같은 SFSafariViewController 로 연다.
private struct ArenaWebSafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let controller = SFSafariViewController(url: url)
        controller.dismissButtonStyle = .close
        return controller
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

/// 내려받은 파일(증빙·분석 결과 등)을 QuickLook 으로 보여 준다.
/// 내비게이션 컨트롤러에 담아야 닫기 버튼과 공유 버튼이 붙는다.
private struct ArenaWebFilePreview: UIViewControllerRepresentable {
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
