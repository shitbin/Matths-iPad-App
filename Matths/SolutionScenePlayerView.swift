//  SolutionScenePlayerView.swift
//  Matths
//
//  유형별 풀이 안무 플레이어 (solution-scene.html).
//
//  SolutionPlayerView 는 풀이 "식" 이 항 단위로 변형되는 것을 보여준다.
//  이쪽은 그 문제의 "그림" 을 강의와 같은 무대(ScenarioPlayer)에서 다시 그린다 —
//  포물선이 실제로 움직이고, 넓이가 채워지고, 분포가 좁아진다.
//
//  핵심은 시드 독립성이다. 생성기가 문항과 함께 내보낸 visualization 파라미터를
//  그대로 넘기면, 같은 유형은 값만 바뀐 같은 안무가 재생된다.
//  (파라미터가 없는 문항은 solution-scenes.js 의 범용 안무로 떨어진다)

import SwiftUI
import WebKit

struct SolutionScenePlayerView: UIViewRepresentable {
    /// 생성기가 준 visualization JSON (없으면 단계 텍스트만으로 범용 안무)
    let visualizationJSON: String?
    let steps: [String]
    var answer: String? = nil
    var statement: String? = nil
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
        config.userContentController.add(context.coordinator, name: "sceneHeight")

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
        web.configuration.userContentController.removeScriptMessageHandler(forName: "sceneHeight")
    }

    static let htmlURL: URL? =
        Bundle.main.url(forResource: "solution-scene", withExtension: "html", subdirectory: "LessonWeb")
        ?? Bundle.main.url(forResource: "solution-scene", withExtension: "html")

    /// 이 문제에 재생할 안무가 있는가 — 버튼을 띄울지 판단할 때 쓴다.
    /// 단계가 하나라도 있으면 범용 안무가 나오므로 항상 재생 가능하다.
    static func canPlay(visualizationJSON: String?, steps: [String]) -> Bool {
        if visualizationJSON?.isEmpty == false { return true }
        return steps.contains { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    private func payloadJS() -> String {
        var payload: [String: Any] = ["steps": steps]
        if let answer { payload["answer"] = answer }
        if let statement { payload["statement"] = statement }
        if let json = visualizationJSON, let data = json.data(using: .utf8),
           let viz = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            payload["viz"] = viz
            payload["kind"] = viz["kind"]
        }
        let json = (try? JSONSerialization.data(withJSONObject: payload))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        // 모션 스위치를 함께 실어 보낸다 — 페이지가 이걸 보고 애니메이션을 끈다
        return "window.MATTHS_SOLUTION_SCENE = \(json);"
    }

    final class Coordinator: NSObject, WKScriptMessageHandler {
        @Binding var height: CGFloat
        init(height: Binding<CGFloat>) { _height = height }

        func userContentController(_ c: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let h = message.body as? Double, h > 0 else { return }
            let next = CGFloat(min(max(h, 220), 900))
            if abs(next - height) > 1 { height = next }
        }
    }
}
