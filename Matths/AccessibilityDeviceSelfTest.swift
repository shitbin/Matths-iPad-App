#if DEBUG
import Foundation
import SwiftUI
import UIKit
import WebKit

/// 실제 iPad WebKit에서 Dynamic Type, pinch 확대, 동작 줄이기와 앱 모션 설정의
/// 공통 브리지가 함께 작동하는지 확인한다. 제품 화면이나 계정 데이터는 건드리지 않고
/// `-accessibilityDeviceSelfTest`로 명시 실행한 경우에만 Documents에 보고서를 쓴다.
@MainActor
enum AccessibilityDeviceSelfTest {
    private struct Report: Codable {
        let schemaVersion: String
        let result: String
        let observedAt: String
        let deviceModel: String
        let osVersion: String
        let dynamicTypeScale: Double
        let computedFontSize: Double
        let scrollEnabled: Bool
        let pinchEnabled: Bool
        let minimumZoomScale: Double
        let maximumZoomScale: Double
        let reduceMotionClassApplied: Bool
        let systemReduceMotionStoppedMotion: Bool
        let userMotionPreferenceStoppedMotion: Bool
        let checks: [String: Bool]
    }

    private final class NavigationProbe: NSObject, WKNavigationDelegate {
        private var continuation: CheckedContinuation<Bool, Never>?

        func load(_ html: String, in webView: WKWebView) async -> Bool {
            await withCheckedContinuation { continuation in
                self.continuation = continuation
                webView.navigationDelegate = self
                webView.loadHTMLString(html, baseURL: nil)
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            finish(true)
        }

        func webView(
            _ webView: WKWebView,
            didFail navigation: WKNavigation!,
            withError error: Error
        ) {
            finish(false)
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            finish(false)
        }

        private func finish(_ succeeded: Bool) {
            continuation?.resume(returning: succeeded)
            continuation = nil
        }
    }

    static func runIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains("-accessibilityDeviceSelfTest") else {
            return
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(700))
            await run()
        }
    }

    private static func run() async {
        let scale = WebContentAccessibility.scale(for: .accessibility5)
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.addUserScript(WKUserScript(
            source: WebContentAccessibility.bootstrapScript(
                size: .accessibility5,
                reduceMotion: true,
                userMotionEnabled: true
            ),
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        ))
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 640, height: 480),
                                configuration: configuration)
        WebContentAccessibility.configure(webView)
        let probe = NavigationProbe()
        let loaded = await probe.load(
            """
            <!doctype html>
            <html><head><meta name="viewport" content="width=device-width, initial-scale=1">
            <style>
              :root { --content-scale: 1; }
              #sample { font-size: calc(16px * var(--content-scale)); }
              #moving { animation: move 20s linear infinite; }
              @keyframes move { from { transform: translateX(0); } to { transform: translateX(50px); } }
            </style></head>
            <body><p id="sample">이차방정식 풀이</p><div id="moving">motion</div></body></html>
            """,
            in: webView
        )

        let initial = await javascriptState(in: webView)
        WebContentAccessibility.update(
            webView,
            size: .accessibility5,
            reduceMotion: false,
            userMotionEnabled: false
        )
        try? await Task.sleep(for: .milliseconds(80))
        let userDisabled = await javascriptState(in: webView)

        let scrollView = webView.scrollView
        let checks: [String: Bool] = [
            "documentLoaded": loaded,
            "ax5ScaleApplied": approximately(initial.scale, scale),
            "ax5ComputedFontApplied": approximately(initial.fontSize, 16 * scale, tolerance: 0.3),
            "scrollEnabled": scrollView.isScrollEnabled,
            "pinchEnabled": scrollView.pinchGestureRecognizer?.isEnabled == true,
            "zoomSupports200Percent": scrollView.maximumZoomScale >= 2,
            "reduceMotionClassApplied": initial.reduceMotion,
            "systemReduceMotionStopsMotion": initial.motionAllowed == false,
            "userMotionPreferenceStopsMotion": userDisabled.motionAllowed == false,
            "userPreferenceDoesNotFakeSystemSetting": userDisabled.reduceMotion == false,
        ]
        let passed = checks.values.allSatisfy { $0 }
        let report = Report(
            schemaVersion: "MATTHS_ACCESSIBILITY_DEVICE_SELFTEST_V1",
            result: passed ? "PASS" : "FAIL",
            observedAt: ISO8601DateFormatter().string(from: Date()),
            deviceModel: UIDevice.current.model,
            osVersion: UIDevice.current.systemVersion,
            dynamicTypeScale: initial.scale,
            computedFontSize: initial.fontSize,
            scrollEnabled: scrollView.isScrollEnabled,
            pinchEnabled: scrollView.pinchGestureRecognizer?.isEnabled == true,
            minimumZoomScale: scrollView.minimumZoomScale,
            maximumZoomScale: scrollView.maximumZoomScale,
            reduceMotionClassApplied: initial.reduceMotion,
            systemReduceMotionStoppedMotion: initial.motionAllowed == false,
            userMotionPreferenceStoppedMotion: userDisabled.motionAllowed == false,
            checks: checks
        )
        write(report)
    }

    private struct JavaScriptState {
        let scale: Double
        let fontSize: Double
        let reduceMotion: Bool
        let motionAllowed: Bool
    }

    private static func javascriptState(in webView: WKWebView) async -> JavaScriptState {
        let script = """
        ({
          scale: Number(getComputedStyle(document.documentElement).getPropertyValue('--content-scale')),
          fontSize: parseFloat(getComputedStyle(document.getElementById('sample')).fontSize),
          reduceMotion: document.documentElement.classList.contains('reduce-motion'),
          motionAllowed: window.MATTHS_MOTION !== false
        })
        """
        guard let value = try? await webView.evaluateJavaScript(script),
              let dictionary = value as? [String: Any] else {
            return JavaScriptState(scale: 0, fontSize: 0, reduceMotion: false, motionAllowed: true)
        }
        return JavaScriptState(
            scale: (dictionary["scale"] as? NSNumber)?.doubleValue ?? 0,
            fontSize: (dictionary["fontSize"] as? NSNumber)?.doubleValue ?? 0,
            reduceMotion: (dictionary["reduceMotion"] as? NSNumber)?.boolValue ?? false,
            motionAllowed: (dictionary["motionAllowed"] as? NSNumber)?.boolValue ?? true
        )
    }

    private static func approximately(
        _ lhs: Double,
        _ rhs: Double,
        tolerance: Double = 0.01
    ) -> Bool {
        abs(lhs - rhs) <= tolerance
    }

    private static func write(_ report: Report) {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(report)
            let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("accessibility-device-selftest.json")
            try data.write(to: url, options: .atomic)
        } catch {
            NSLog("AccessibilityDeviceSelfTest report write failed: %@", String(describing: error))
        }
    }
}
#endif
