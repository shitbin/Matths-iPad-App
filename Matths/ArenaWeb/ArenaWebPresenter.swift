//  ArenaWebPresenter.swift
//  Matths
//
//  아레나 웹 브리지를 **어디서든 한 줄로** 여는 문.
//
//  왜 UIKit 표시인가. 브리지를 부르는 자리는 여러 곳이다(GOAT Arena 화면의 웹 폴백,
//  우편함 배지, 상점 버튼, 딥링크, 알림). 그때마다 화면마다 @State 와 .sheet 를 새로
//  만들면 같은 코드가 다섯 벌이 되고, 그중 하나만 목적지를 안 넘겨도 조용히 홈이 열린다.
//  표시 자체를 여기 한 곳에 두면 부르는 쪽은 목적지만 고르면 된다.
//
//    ArenaWebPresenter.open(.mailbox)
//    ArenaWebPresenter.open(.match(matchId: id), guardModel: screenshotGuard)
//
//  SwiftUI 안에서 직접 쓰고 싶으면 ArenaWebScreen(destination:) 을 .fullScreenCover 에
//  넣어도 된다 — 모델(ArenaWebModel.shared)이 같으므로 세션은 한 벌만 쓴다.

import SwiftUI
import UIKit

@MainActor
enum ArenaWebPresenter {
    /// 화면 보호 여부는 표시 시점에 정해지므로(경기 목적지인지) 컨트롤러가 기억한다.
    private final class Host: UIHostingController<ArenaWebScreen> {
        var carriesScreenshotGuard = false
    }

    /// 닫기 클로저가 자기 컨트롤러를 붙잡아 순환 참조가 되지 않도록 중간에 둔다.
    @MainActor
    private final class Dismisser {
        weak var controller: UIViewController?
        func dismiss() { controller?.dismiss(animated: true) }
    }

    private static weak var presented: Host?

    /// 이미 떠 있으면 새 컨트롤러를 쌓지 않고 목적지만 바꾼다 —
    /// 브리지가 두 겹 쌓이면 뒤엣것의 웹뷰가 같은 모델을 잡고 있어 뒤로가기가 엉킨다.
    static func open(_ destination: ArenaWebDestination,
                     signedIn: Bool? = nil,
                     guardModel: ScreenshotGuard? = nil,
                     onCapture: ((String) -> Void)? = nil,
                     onRequestSignIn: (() -> Void)? = nil) {
        if let host = presented, host.presentingViewController != nil {
            // 보호가 필요한 목적지인데 지금 컨트롤러가 보호 없이 떠 있으면 다시 띄운다.
            // 평가면을 무방비로 보여 주느니 한 번 깜빡이는 편이 낫다.
            let needsGuard = destination.isProtectedAssessmentSurface && guardModel != nil
            if !needsGuard || host.carriesScreenshotGuard {
                ArenaWebModel.shared.open(destination, signedIn: signedIn)
                return
            }
            host.dismiss(animated: false)
            presented = nil
        }

        guard let presenter = ArenaWebModel.topViewController() else {
            NSLog("ARENA-WEB 표시할 뷰 컨트롤러를 찾지 못했습니다 · %@", destination.path)
            return
        }

        let dismisser = Dismisser()
        let screen = ArenaWebScreen(
            destination: destination,
            signedIn: signedIn,
            guardModel: guardModel,
            onCapture: onCapture,
            onRequestSignIn: onRequestSignIn,
            onClose: { dismisser.dismiss() })
        let host = Host(rootView: screen)
        host.carriesScreenshotGuard = guardModel != nil
        host.modalPresentationStyle = .fullScreen
        host.view.backgroundColor = UIColor(Tokens.paper)
        dismisser.controller = host
        presented = host
        presenter.present(host, animated: true)
    }

    /// 계정 전환처럼 앱이 스스로 브리지를 걷어야 할 때.
    static func dismiss() {
        presented?.dismiss(animated: true)
        presented = nil
    }

    /// 지금 브리지가 떠 있는지. 알림 처리 쪽에서 중복 표시를 피할 때 쓴다.
    static var isPresenting: Bool {
        presented?.presentingViewController != nil
    }
}

// MARK: - 딥링크

/// `matths://arena-web/<목적지>[/<id>]` 로 특정 아레나 페이지를 바로 연다.
/// 위젯 딥링크(matths://arena)는 앱의 GOAT Arena 탭으로 가는 기존 통로라 건드리지 않는다 —
/// 이 문은 **웹으로만 있는 조작 페이지**를 겨냥한 별도 host 를 쓴다.
///
///   matths://arena-web/mailbox
///   matths://arena-web/shop
///   matths://arena-web/match/<matchId>
///   matths://arena-web/feature/main/<featureKey>
///
/// 서버가 보낸 https 주소(.../goat-arena/...)도 같은 문으로 받는다. 그래야 우편함 알림의
/// 링크를 Safari 로 새로 열지 않고 앱 안의 로그인된 웹뷰에서 이어 볼 수 있다.
@MainActor
enum ArenaWebDeepLink {
    /// - Returns: 이 URL 을 아레나 브리지가 처리했으면 true. false 면 부르는 쪽이
    ///   기존 처리(WidgetBridge 등)를 그대로 이어 가면 된다.
    @discardableResult
    static func handle(_ url: URL,
                       signedIn: Bool? = nil,
                       guardModel: ScreenshotGuard? = nil,
                       onRequestSignIn: (() -> Void)? = nil) -> Bool {
        guard let destination = destination(for: url) else { return false }
        open(destination, signedIn: signedIn, guardModel: guardModel,
             onRequestSignIn: onRequestSignIn)
        return true
    }

    private static func open(_ destination: ArenaWebDestination,
                             signedIn: Bool?,
                             guardModel: ScreenshotGuard?,
                             onRequestSignIn: (() -> Void)?) {
        ArenaWebPresenter.open(destination, signedIn: signedIn,
                               guardModel: destination.isProtectedAssessmentSurface ? guardModel : nil,
                               onRequestSignIn: onRequestSignIn)
    }

    /// 주소 → 목적지. 모르는 주소는 nil 이다(임의 경로가 웹뷰로 흘러들지 않게).
    static func destination(for url: URL) -> ArenaWebDestination? {
        if url.scheme?.lowercased() == "matths" {
            guard url.host?.lowercased() == "arena-web" else { return nil }
            let path = url.pathComponents.filter { $0 != "/" }.joined(separator: "/")
            return ArenaWebDestination.parse(path.isEmpty ? "home" : path)
        }
        // https://<서버>/goat-arena/... — 서버가 준 아레나 주소만 받는다.
        guard let scheme = url.scheme?.lowercased(), scheme == "https",
              let host = url.host?.lowercased(),
              let base = ServerAPI.baseURL.host?.lowercased() else { return nil }
        func strip(_ value: String) -> String {
            value.hasPrefix("www.") ? String(value.dropFirst(4)) : value
        }
        guard strip(host) == strip(base), ArenaWebDestination.owns(path: url.path) else { return nil }
        let full = url.query.map { "\(url.path)?\($0)" } ?? url.path
        // 경기 주소는 보호 대상이라 목적지 종류를 정확히 알아야 한다.
        let parts = url.path.split(separator: "/").map(String.init)
        if parts.count >= 3, parts[0] == "goat-arena", parts[1] == "matches" {
            return parts.count >= 4 && parts[3] == "supplemental-evidence"
                ? .matchSupplementalEvidence(matchId: parts[2])
                : .match(matchId: parts[2])
        }
        return .custom(path: full, title: "GOAT Arena")
    }
}

#if DEBUG
// MARK: - 디버그 진입점 (DEBUG 전용)
//
// 진입 버튼이 아직 앱 화면에 배선되지 않아도 **시뮬레이터에서 실제로 열어 보기 위한**
// 문이다. 실행 인자로 목적지를 준다:
//
//   -arenaWeb mailbox
//   -arenaWeb shop
//   -arenaWeb match/<matchId>
//
// 인자가 없으면 옵저버조차 걸지 않는다(평소 실행에는 흔적이 없다).
// 이 클래스를 부르는 것은 같은 폴더의 ArenaWebLaunchShim.m 의 +load 다 —
// 앱 진입점(MatthsApp.swift)은 다른 사람이 고치는 파일이라 손대지 않는다.
@MainActor
@objc(MatthsArenaWebLaunchHook)
final class ArenaWebLaunchHook: NSObject {
    private static let flag = "-arenaWeb"
    private static var installed = false
    /// 블록 옵저버 토큰을 콜백 지역 변수로 캡처하면 Swift 6 동시성 검사에서
    /// non-Sendable 토큰의 캡처와 캡처 후 변경 경고가 난다. 훅 자체가 MainActor라
    /// 한 번짜리 토큰도 같은 격리에 보관한다.
    private static var keyWindowObserver: NSObjectProtocol?

    /// ObjC +load 에서 부른다. 실제 표시는 창이 뜨고 스플래시가 걷힌 뒤로 미룬다.
    @objc static func install() {
        guard !installed, let value = requestedValue() else { return }
        installed = true
        NSLog("ARENA-WEB 디버그 진입점 대기 · 목적지=%@", value)
        keyWindowObserver = NotificationCenter.default.addObserver(
            forName: UIWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated {
                if let observer = keyWindowObserver {
                    NotificationCenter.default.removeObserver(observer)
                    keyWindowObserver = nil
                }
                // 스플래시가 0.8초 상한이라 그보다 넉넉히 뒤에 연다.
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                    MainActor.assumeIsolated { presentRequested(value) }
                }
            }
        }
    }

    private static func requestedValue() -> String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: flag) else { return nil }
        guard arguments.indices.contains(index + 1) else { return "home" }
        let next = arguments[index + 1]
        return next.hasPrefix("-") ? "home" : next
    }

    private static func presentRequested(_ value: String) {
        if value == "selftest" {
            runDeepLinkSelfTest()
            return
        }
        guard let destination = ArenaWebDestination.parse(value) else {
            NSLog("ARENA-WEB 디버그 진입점: 모르는 목적지 %@", value)
            return
        }
        // `-arenaWebForceSignedIn`: 로그인 게이트를 건너뛰고 **핸드오프 요청 자체**를
        // 태워 보기 위한 인자다. 토큰이 없으면 서버가 401 로 거절하고, 그 401 이
        // 화면에 오류 카드로 나오는지까지가 이 인자로 볼 수 있는 범위다.
        // (로그인된 실제 왕복은 감독 계정으로만 확인할 수 있다)
        let forced = ProcessInfo.processInfo.arguments.contains("-arenaWebForceSignedIn")
        // `-arenaWebSkipHandoff`: 핸드오프를 건너뛰고 아레나 주소를 바로 쳐서,
        // 서버의 302 /login 을 앱이 가로채 세션을 다시 잇는 경로를 태운다.
        if ProcessInfo.processInfo.arguments.contains("-arenaWebSkipHandoff") {
            ArenaWebModel.shared.debugAssumeExistingWebSession()
        }
        NSLog("ARENA-WEB 디버그 진입점 실행 · %@ (%@)%@",
              destination.deepLinkKey, destination.path, forced ? " · 로그인 강제" : "")
        ArenaWebPresenter.open(destination, signedIn: forced ? true : nil)
        // 앱이 스플래시·루트 교체 중이면 present 가 조용히 무시될 수 있다(실측).
        // 디버그 진입점은 "떴는지" 가 전부이므로 한 번만 다시 시도한다.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            MainActor.assumeIsolated {
                guard !ArenaWebPresenter.isPresenting else { return }
                NSLog("ARENA-WEB 디버그 진입점 재시도")
                ArenaWebPresenter.open(destination, signedIn: forced ? true : nil)
            }
        }
    }

    /// `-arenaWeb selftest` — 딥링크 주소 → 목적지 → 서버 경로 변환을 기기에서 확인한다.
    /// 딥링크는 앱 진입점(onOpenURL)에 배선되기 전까지 손으로 열어 볼 수 없어서,
    /// 변환 표만이라도 실행 중인 앱에서 증명해 둔다.
    private static func runDeepLinkSelfTest() {
        let cases: [(String, String?)] = [
            ("matths://arena-web", "/goat-arena"),
            ("matths://arena-web/mailbox", "/goat-arena/mailbox"),
            ("matths://arena-web/mailbox/n-42", "/goat-arena/mailbox/n-42"),
            ("matths://arena-web/shop", "/goat-arena/main/shop"),
            ("matths://arena-web/ranked-battle", "/goat-arena/main/battle"),
            ("matths://arena-web/unranked-challenge", "/goat-arena/sub/challenge"),
            ("matths://arena-web/rules-ranked", "/goat-arena/rules/main"),
            ("matths://arena-web/profile", "/goat-arena/profile"),
            ("matths://arena-web/match/m-7", "/goat-arena/matches/m-7"),
            ("matths://arena-web/feature/main/style", "/goat-arena/main/features/style"),
            ("matths://arena-web/없는목적지", nil),
            ("matths://arena/home", nil),                       // 위젯 딥링크는 건드리지 않는다
            ("https://www.matths.kr/goat-arena/main/shop", "/goat-arena/main/shop"),
            ("https://www.matths.kr/goat-arena/matches/x9/supplemental-evidence",
             "/goat-arena/matches/x9/supplemental-evidence"),
            ("https://www.matths.kr/community", nil),           // 아레나 밖은 받지 않는다
            ("https://www.matths.kr/goat-arena-admin", nil),   // 경로 접두사가 같아도 밖이다
            ("https://example.com/goat-arena", nil),            // 다른 호스트도 받지 않는다
        ]
        var failures = 0
        for (raw, expected) in cases {
            guard let url = URL(string: raw) else {
                NSLog("ARENA-WEB 자가진단 실패 · 주소를 만들 수 없음 %@", raw)
                failures += 1
                continue
            }
            let actual = ArenaWebDeepLink.destination(for: url)?.path
            if actual != expected {
                NSLog("ARENA-WEB 자가진단 실패 · %@ → %@ (기대 %@)",
                      raw, actual ?? "nil", expected ?? "nil")
                failures += 1
            }
        }
        NSLog("ARENA-WEB 딥링크 자가진단 %@ · %d/%d",
              failures == 0 ? "통과" : "실패", cases.count - failures, cases.count)
    }
}
#endif
