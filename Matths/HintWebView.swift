//  HintWebView.swift
//  Matths
//
//  복습 시각 힌트 — 힌트 문장(KaTeX) + kind별 SVG 그래프 (웹 wrong-note-review 이식).
//  hint.html + hint-core.js(웹 작도 코어 추출본) 를 재생한다.
//  힌트는 복습 트랙에서만 노출된다 — 첫 풀이에서 그래프를 보여주면 문제가 쉬워진다.

import SwiftUI
import WebKit

struct HintWebView: UIViewRepresentable {
    let hintText: String?
    let visualizationJSON: String?
    @Binding var height: CGFloat
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(WebMotion.preferenceKey) private var userMotionEnabled = true

    func makeCoordinator() -> Coordinator { Coordinator(height: $height) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.addUserScript(WKUserScript(
            source: payloadJS(), injectionTime: .atDocumentStart, forMainFrameOnly: true))
        config.userContentController.addUserScript(WKUserScript(
            source: WebContentAccessibility.bootstrapScript(
                size: dynamicTypeSize,
                reduceMotion: reduceMotion,
                userMotionEnabled: userMotionEnabled),
            injectionTime: .atDocumentStart, forMainFrameOnly: true))
        config.userContentController.add(context.coordinator, name: "hintHeight")

        let web = WKWebView(frame: .zero, configuration: config)
        web.isOpaque = false
        web.backgroundColor = .clear
        WebContentAccessibility.configure(web)
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

    static func dismantleUIView(_ web: WKWebView, coordinator: Coordinator) {
        web.stopLoading()
        web.configuration.userContentController.removeScriptMessageHandler(forName: "hintHeight")
    }

    static let htmlURL: URL? =
        Bundle.main.url(forResource: "hint", withExtension: "html", subdirectory: "LessonWeb")
        ?? Bundle.main.url(forResource: "hint", withExtension: "html")

    private func payloadJS() -> String {
        var payload: [String: Any] = [:]
        if let hintText { payload["hintText"] = hintText }
        // visualization 은 원본 JSON 문자열 — 파싱해 객체로 주입
        if let vizJSON = visualizationJSON,
           let data = vizJSON.data(using: .utf8),
           let obj = try? JSONSerialization.jsonObject(with: data) {
            payload["visualization"] = obj
        }
        let json = (try? JSONSerialization.data(withJSONObject: payload))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        // 모션 스위치를 함께 실어 보낸다 — 페이지가 이걸 보고 애니메이션을 끈다
        return "window.MATTHS_HINT = \(json);"
    }

    final class Coordinator: NSObject, WKScriptMessageHandler {
        @Binding var height: CGFloat
        init(height: Binding<CGFloat>) { _height = height }

        func userContentController(_ controller: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            guard message.name == "hintHeight", let h = message.body as? Double else { return }
            let clamped = max(40, min(CGFloat(h) + 6, 900))
            if abs(clamped - height) > 6 {
                DispatchQueue.main.async { self.height = clamped }
            }
        }
    }
}
