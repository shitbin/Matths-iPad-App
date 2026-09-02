//  LottieWebView.swift
//  Matths
//
//  Lottie 피드백 재생 — 번들 lottie_light.min.js(SVG 렌더러) + lottie.html.
//  SPM 의존성 없이 WKWebView 로 돌린다 (손으로 쓴 pbxproj 에 패키지를 붙이는
//  위험을 지지 않기 위해). 애니메이션 JSON 은 WKUserScript 로 직접 주입한다 —
//  file:// 오리진에서는 fetch 가 막힌다 (ProblemWebView 와 같은 함정).
//
//  쓰는 곳: 채점 결과 판정 아이콘과 GOAT Arena 랭크 휘장 장식, 모션 켬일 때만.

import SwiftUI
import WebKit

struct LottieWebView: UIViewRepresentable {
    /// 번들 애니메이션 파일명 (확장자 제외).
    let name: String
    var loop: Bool = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(WebMotion.preferenceKey) private var userMotionEnabled = true

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.addUserScript(WKUserScript(
            source: Self.payloadJS(name: name, loop: loop),
            injectionTime: .atDocumentStart, forMainFrameOnly: true))
        config.userContentController.addUserScript(WKUserScript(
            source: WebContentAccessibility.bootstrapScript(
                size: dynamicTypeSize,
                reduceMotion: reduceMotion,
                userMotionEnabled: userMotionEnabled),
            injectionTime: .atDocumentStart, forMainFrameOnly: true))

        let web = WKWebView(frame: .zero, configuration: config)
        web.isOpaque = false
        web.backgroundColor = .clear
        WebContentAccessibility.configure(web)
        web.isUserInteractionEnabled = false     // 장식이다 — 터치를 먹으면 안 된다
        if let url = Self.htmlURL {
            web.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
        return web
    }

    func updateUIView(_ web: WKWebView, context: Context) {
        WebContentAccessibility.update(
            web,
            size: dynamicTypeSize,
            reduceMotion: reduceMotion,
            userMotionEnabled: userMotionEnabled)
    }

    static let htmlURL: URL? =
        Bundle.main.url(forResource: "lottie", withExtension: "html", subdirectory: "LessonWeb")
        ?? Bundle.main.url(forResource: "lottie", withExtension: "html")

    /// 번들 애니메이션 JSON 을 읽어 그대로 주입한다. 없으면 빈 주입(웹이 침묵).
    private static func payloadJS(name: String, loop: Bool) -> String {
        let url = Bundle.main.url(forResource: name, withExtension: "json", subdirectory: "RankBadges")
            ?? Bundle.main.url(forResource: name, withExtension: "json", subdirectory: "LessonWeb")
            ?? Bundle.main.url(forResource: name, withExtension: "json")
        guard let url, let json = try? String(contentsOf: url, encoding: .utf8) else {
            return "window.MATTHS_LOTTIE = {};"
        }
        return "window.MATTHS_LOTTIE = { data: \(json), loop: \(loop) };"
    }
}
