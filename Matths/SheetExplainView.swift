//  SheetExplainView.swift
//  Matths
//
//  시험지 분석 뒤의 "설명" 화면 (explain.html).
//
//  채점표는 어디서 틀렸는지까지다. 학생에게 정작 필요한 것은
//  "그래서 내가 뭘 몰랐고, 다음에 뭘 보면 되는가" 이고, 그건 글이 아니라
//  **수식과 대조**로 보여야 머리에 남는다. 그래서 별도 화면으로 뺐다.
//
//  입력은 SheetGrader 의 S6 가 만든 JSON 문자열 그대로다.

import SwiftUI
import WebKit

struct SheetExplainView: UIViewRepresentable {
    /// SheetGrader.explainJSON — {"cards":[…]}
    let json: String
    @Binding var height: CGFloat
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(WebMotion.preferenceKey) private var userMotionEnabled = true

    func makeCoordinator() -> Coordinator { Coordinator(height: $height) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        // JSON 을 **base64 로** 실어 보낸다.
        // JS 객체 리터럴로 그대로 박으면, LaTeX 의 백슬래시가 JS 이스케이프로
        // 해석돼 한 겹씩 사라진다(\quad → quad, \frac → rac). 수식이 주인공인
        // 화면에서 이건 치명적이라, 아예 인코딩해 넘기고 페이지에서 디코드한다.
        let b64 = Data((json.isEmpty ? "{}" : json).utf8).base64EncodedString()
        config.userContentController.addUserScript(WKUserScript(
            source: "window.MATTHS_EXPLAIN_B64 = \"\(b64)\";",
            injectionTime: .atDocumentStart, forMainFrameOnly: true))
        config.userContentController.addUserScript(WKUserScript(
            source: WebContentAccessibility.bootstrapScript(
                size: dynamicTypeSize,
                reduceMotion: reduceMotion,
                userMotionEnabled: userMotionEnabled),
            injectionTime: .atDocumentStart, forMainFrameOnly: true))
        config.userContentController.add(context.coordinator, name: "explainHeight")

        let web = WKWebView(frame: .zero, configuration: config)
        web.isOpaque = false
        web.backgroundColor = .clear
        WebContentAccessibility.configure(web)
        web.scrollView.bounces = false
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
        web.configuration.userContentController.removeScriptMessageHandler(forName: "explainHeight")
    }

    static let htmlURL: URL? =
        Bundle.main.url(forResource: "explain", withExtension: "html", subdirectory: "LessonWeb")
        ?? Bundle.main.url(forResource: "explain", withExtension: "html")

    final class Coordinator: NSObject, WKScriptMessageHandler {
        @Binding var height: CGFloat
        init(height: Binding<CGFloat>) { _height = height }

        func userContentController(_ c: WKUserContentController, didReceive m: WKScriptMessage) {
            guard let h = m.body as? Double, h > 0 else { return }
            // 위쪽 한계를 넉넉히 — 카드 두 장이 들어가고도 잘리지 않아야 한다
            let next = CGFloat(min(max(h, 200), 2600))
            if abs(next - height) > 1 { height = next }
        }
    }
}
