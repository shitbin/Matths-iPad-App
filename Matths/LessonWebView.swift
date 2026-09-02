//  LessonWebView.swift
//  Matths
//
//  데모의 강의 코드(ScenarioPlayer 시각 강의 + 인터랙티브 플레이그라운드)를
//  그대로 재생하는 WKWebView. 번들 LessonWeb/lesson.html 을 연다.
//
//  개념 id 는 쿼리가 아니라 WKUserScript 로 주입한다 —
//  file URL 의 쿼리는 환경에 따라 벗겨질 수 있어 믿을 수 없다 (프리뷰에서 실증).
//  높이는 웹이 lessonHeight 메시지로 보고하고 네이티브 프레임이 따라간다.

import SwiftUI
import WebKit

struct LessonWebView: UIViewRepresentable {
    let conceptID: String
    @Binding var height: CGFloat
    /// 확인 문제 통과 여부 — 웹의 quizResult 메시지가 세운다.
    /// (퀴즈가 없는 개념은 웹이 로드 직후 바로 true 를 보낸다)
    @Binding var quizPassed: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(WebMotion.preferenceKey) private var userMotionEnabled = true

    /// 이 개념에 재생할 시각 강의가 있는가 — 번들 시나리오 키를 한 번만 읽어 캐시한다.
    /// (레거시 웹 모듈이 없어도 시나리오만 있으면 강의를 띄운다)
    static func hasLesson(conceptID: String) -> Bool { sceneKeys.contains(conceptID) }

    private static let sceneKeys: Set<String> = {
        guard let url = Bundle.main.url(forResource: "scenarios-data", withExtension: "js",
                                        subdirectory: "LessonWeb")
                ?? Bundle.main.url(forResource: "scenarios-data", withExtension: "js"),
              let src = try? String(contentsOf: url, encoding: .utf8),
              let start = src.range(of: "const SCENARIO_META = ") else { return [] }
        // SCENARIO_META 는 개념 id 를 키로 갖는 평평한 객체 — 키만 훑는다.
        let tail = src[start.upperBound...]
        guard let end = tail.range(of: "\n") else { return [] }
        let json = String(tail[..<end.lowerBound]).trimmingCharacters(in: CharacterSet(charactersIn: ";"))
        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [] }
        return Set(obj.keys)
    }()

    func makeCoordinator() -> Coordinator { Coordinator(height: $height, quizPassed: $quizPassed) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()

        // 개념 id 주입 — 문서 시작 시점, 메인 프레임만
        let inject = WKUserScript(
            source: "window.MATTHS_CONCEPT = \(jsString(conceptID));",
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        config.userContentController.addUserScript(inject)
        config.userContentController.addUserScript(WKUserScript(
            source: WebContentAccessibility.bootstrapScript(
                size: dynamicTypeSize,
                reduceMotion: reduceMotion,
                userMotionEnabled: userMotionEnabled),
            injectionTime: .atDocumentStart, forMainFrameOnly: true))
        config.userContentController.add(context.coordinator, name: "lessonHeight")
        config.userContentController.add(context.coordinator, name: "lessonDebug")
        config.userContentController.add(context.coordinator, name: "quizResult")

        let web = WKWebView(frame: .zero, configuration: config)
        web.isOpaque = false
        web.backgroundColor = .clear
        WebContentAccessibility.configure(web)

        if let html = Self.lessonURL {
            web.loadFileURL(html, allowingReadAccessTo: html.deletingLastPathComponent())
        }
        return web
    }

    func updateUIView(_ web: WKWebView, context: Context) {
        // 개념이 바뀌면 새 주입이 필요하므로 다시 로드
        if context.coordinator.loadedConcept != conceptID, let html = Self.lessonURL {
            context.coordinator.loadedConcept = conceptID
            web.configuration.userContentController.removeAllUserScripts()
            web.configuration.userContentController.addUserScript(WKUserScript(
                source: "window.MATTHS_CONCEPT = \(jsString(conceptID));",
                injectionTime: .atDocumentStart, forMainFrameOnly: true))
            web.configuration.userContentController.addUserScript(WKUserScript(
                source: WebContentAccessibility.bootstrapScript(
                    size: dynamicTypeSize,
                    reduceMotion: reduceMotion,
                    userMotionEnabled: userMotionEnabled),
                injectionTime: .atDocumentStart, forMainFrameOnly: true))
            web.loadFileURL(html, allowingReadAccessTo: html.deletingLastPathComponent())
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
        controller.removeScriptMessageHandler(forName: "lessonHeight")
        controller.removeScriptMessageHandler(forName: "lessonDebug")
        controller.removeScriptMessageHandler(forName: "quizResult")
    }

    static let lessonURL: URL? =
        Bundle.main.url(forResource: "lesson", withExtension: "html", subdirectory: "LessonWeb")
        ?? Bundle.main.url(forResource: "lesson", withExtension: "html")

    private func jsString(_ s: String) -> String {
        // id 는 우리 데이터의 [a-z0-9-] 이지만, 관성적으로라도 안전하게 감싼다
        "\"" + s.replacingOccurrences(of: "\\", with: "\\\\")
               .replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }

    final class Coordinator: NSObject, WKScriptMessageHandler {
        @Binding var height: CGFloat
        @Binding var quizPassed: Bool
        var loadedConcept: String?
        init(height: Binding<CGFloat>, quizPassed: Binding<Bool>) {
            _height = height
            _quizPassed = quizPassed
        }

        func userContentController(_ controller: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            if message.name == "quizResult" {
                let ok = (message.body as? Bool) ?? false
                DispatchQueue.main.async { self.quizPassed = ok }
                return
            }
            if message.name == "lessonDebug" {
                #if DEBUG
                NSLog("LESSON-DEBUG %@", String(describing: message.body))
                #endif
                return
            }
            guard message.name == "lessonHeight", let h = message.body as? Double else { return }
            let clamped = max(240, min(CGFloat(h), 2400))
            if abs(clamped - height) > 4 {
                DispatchQueue.main.async { self.height = clamped }
            }
        }
    }
}
