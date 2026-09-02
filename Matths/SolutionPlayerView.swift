//  SolutionPlayerView.swift
//  Matths
//
//  풀이 애니메이션 플레이어 — "짚은 단계부터 다시 보기" (solution-player.html).
//  단계 텍스트는 생성기가 그 회차의 실제 수치로 만든 것이라, 시드가 바뀌면
//  숫자만 바뀐 같은 안무가 재생된다. learning-flow 데모(2.6s 리듬)의 실기능화.

import SwiftUI
import WebKit

struct SolutionPlayerView: UIViewRepresentable {
    let steps: [String]
    let startStep: Int          // 1부터. 갈라진 단계 — 그 직전까지는 흐리게 미리 공개
    var autoplay: Bool = true
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
        config.userContentController.add(context.coordinator, name: "playerHeight")

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
        web.configuration.userContentController.removeScriptMessageHandler(forName: "playerHeight")
    }

    static let htmlURL: URL? =
        Bundle.main.url(forResource: "solution-player", withExtension: "html", subdirectory: "LessonWeb")
        ?? Bundle.main.url(forResource: "solution-player", withExtension: "html")

    private func payloadJS() -> String {
        let payload: [String: Any] = ["steps": steps, "startStep": startStep, "autoplay": autoplay]
        let json = (try? JSONSerialization.data(withJSONObject: payload))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        // 모션 스위치를 함께 실어 보낸다 — 페이지가 이걸 보고 애니메이션을 끈다
        return "window.MATTHS_SOLUTION = \(json);"
    }

    final class Coordinator: NSObject, WKScriptMessageHandler {
        @Binding var height: CGFloat
        init(height: Binding<CGFloat>) { _height = height }

        func userContentController(_ controller: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            guard message.name == "playerHeight", let h = message.body as? Double else { return }
            let clamped = max(120, min(CGFloat(h) + 8, 2000))
            if abs(clamped - height) > 8 {
                DispatchQueue.main.async { self.height = clamped }
            }
        }
    }
}
