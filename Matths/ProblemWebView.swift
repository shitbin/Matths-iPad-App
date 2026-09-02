//  ProblemWebView.swift
//  Matths
//
//  뱅크(exam-bank.js) 문항 렌더러 — $...$ KaTeX 발제문과 5지선다를
//  problem.html 에 주입해 그린다. 선택은 choicePick 메시지로 돌아온다.
//  (한글 웹폰트·평탄화 규칙은 LessonWebView 와 동일한 이유로 동일하게 적용)

import SwiftUI
import WebKit

struct ProblemWebView: UIViewRepresentable {
    let problem: GeneratedProblem
    @Binding var height: CGFloat
    @Binding var pickedKey: String?
    var usesCompactLandscapeLayout = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(WebMotion.preferenceKey) private var userMotionEnabled = true

    private static let keys = ["a", "b", "c", "d", "e"]

    func makeCoordinator() -> Coordinator { Coordinator(height: $height, pickedKey: $pickedKey) }

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
        config.userContentController.add(context.coordinator, name: "problemHeight")
        config.userContentController.add(context.coordinator, name: "choicePick")

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
        let renderID = "\(problem.id)|compact:\(usesCompactLandscapeLayout)"
        if context.coordinator.loadedID != renderID, let url = Self.htmlURL {
            context.coordinator.loadedID = renderID
            web.configuration.userContentController.removeAllUserScripts()
            web.configuration.userContentController.addUserScript(WKUserScript(
                source: payloadJS(), injectionTime: .atDocumentStart, forMainFrameOnly: true))
            web.configuration.userContentController.addUserScript(WKUserScript(
                source: WebContentAccessibility.bootstrapScript(
                    size: dynamicTypeSize,
                    reduceMotion: reduceMotion,
                    userMotionEnabled: userMotionEnabled),
                injectionTime: .atDocumentStart, forMainFrameOnly: true))
            web.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        } else {
            WebContentAccessibility.update(
                web,
                size: dynamicTypeSize,
                reduceMotion: reduceMotion,
                userMotionEnabled: userMotionEnabled)
        }
    }

    static func dismantleUIView(_ web: WKWebView, coordinator: Coordinator) {
        web.stopLoading()
        let controller = web.configuration.userContentController
        controller.removeScriptMessageHandler(forName: "problemHeight")
        controller.removeScriptMessageHandler(forName: "choicePick")
    }

    static let htmlURL: URL? =
        Bundle.main.url(forResource: "problem", withExtension: "html", subdirectory: "LessonWeb")
        ?? Bundle.main.url(forResource: "problem", withExtension: "html")

    private func payloadJS() -> String {
        var payload: [String: Any] = ["prompt": problem.statement]
        payload["compactLandscape"] = usesCompactLandscapeLayout
        if let choices = problem.choices {
            payload["choices"] = choices.enumerated().map { i, text in
                ["key": Self.keys[min(i, 4)], "text": text]
            }
        }
        if let picked = pickedKey { payload["picked"] = picked }
        let json = (try? JSONSerialization.data(withJSONObject: payload))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        return "window.MATTHS_PROBLEM = \(json);"
    }

    final class Coordinator: NSObject, WKScriptMessageHandler {
        @Binding var height: CGFloat
        @Binding var pickedKey: String?
        var loadedID: String?
        init(height: Binding<CGFloat>, pickedKey: Binding<String?>) {
            _height = height
            _pickedKey = pickedKey
        }

        func userContentController(_ controller: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            switch message.name {
            case "choicePick":
                if let key = message.body as? String {
                    DispatchQueue.main.async { self.pickedKey = key }
                }
            case "problemHeight":
                if let h = message.body as? Double {
                    let clamped = max(60, min(CGFloat(h) + 4, 1200))
                    if abs(clamped - height) > 4 {
                        DispatchQueue.main.async { self.height = clamped }
                    }
                }
            default: break
            }
        }
    }
}
