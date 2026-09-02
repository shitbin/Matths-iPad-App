import Foundation
import SwiftUI
import WebKit

/// 서버가 문제와 함께 봉인한 그래프·도형 JSON만 그리는 격리된 뷰입니다.
/// 정답·풀이·생성 seed는 이 뷰의 입력 계약에 포함되지 않습니다.
struct ArenaProblemVisualizationView: UIViewRepresentable {
    let visualizationJSON: String

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(WebMotion.preferenceKey) private var userMotionEnabled = true

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.userContentController.addUserScript(WKUserScript(
            source: payloadScript(),
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        ))
        configuration.userContentController.addUserScript(WKUserScript(
            source: WebContentAccessibility.bootstrapScript(
                size: dynamicTypeSize,
                reduceMotion: reduceMotion,
                userMotionEnabled: userMotionEnabled
            ),
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        ))

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        WebContentAccessibility.configure(webView)
        webView.scrollView.bounces = false
        context.coordinator.loadedVisualizationJSON = visualizationJSON
        if let url = Self.htmlURL {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        WebContentAccessibility.update(
            webView,
            size: dynamicTypeSize,
            reduceMotion: reduceMotion,
            userMotionEnabled: userMotionEnabled
        )
        guard context.coordinator.loadedVisualizationJSON != visualizationJSON else {
            return
        }
        context.coordinator.loadedVisualizationJSON = visualizationJSON
        webView.evaluateJavaScript(
            "window.renderArenaVisualization && window.renderArenaVisualization(\(safeJSONObject()));"
        )
    }

    private static let htmlURL: URL? =
        Bundle.main.url(
            forResource: "arena-problem",
            withExtension: "html",
            subdirectory: "LessonWeb"
        ) ?? Bundle.main.url(forResource: "arena-problem", withExtension: "html")

    private func payloadScript() -> String {
        "window.MATTHS_ARENA_VISUALIZATION = \(safeJSONObject());"
    }

    /// 임의 문자열을 JavaScript 소스로 이어 붙이지 않고 JSON parser를 한 번 더
    /// 통과시킨 객체만 주입합니다. 깨진 payload는 빈 객체로 fail-closed 합니다.
    private func safeJSONObject() -> String {
        guard let data = visualizationJSON.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              JSONSerialization.isValidJSONObject(object),
              let normalized = try? JSONSerialization.data(withJSONObject: object),
              let text = String(data: normalized, encoding: .utf8) else {
            return "{}"
        }
        return text
    }

    final class Coordinator {
        var loadedVisualizationJSON: String?
    }
}
