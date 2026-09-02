import Foundation
import SwiftUI
import WebKit

/// SwiftUI 접근성 설정을 번들 HTML로 전달하는 공통 브리지.
/// WKWebView 안의 px 글꼴은 Dynamic Type을 자동으로 따르지 않으므로 문서 루트의
/// 배율과 동작 줄이기 클래스를 네이티브 환경값에서 직접 갱신한다.
enum WebContentAccessibility {
    /// 교육 콘텐츠는 바깥 SwiftUI ScrollView 안에 놓이더라도 확대 제스처를
    /// 자체적으로 받아야 한다. 바깥 스크롤을 대신하지 않도록 bounce는 끄되,
    /// scroll 자체를 끄지 않아 200% 이상 pinch와 확대 뒤 pan을 보존한다.
    static func configure(_ webView: WKWebView) {
        let scrollView = webView.scrollView
        scrollView.isScrollEnabled = true
        scrollView.alwaysBounceVertical = false
        scrollView.alwaysBounceHorizontal = false
        scrollView.bounces = false
        scrollView.isDirectionalLockEnabled = true
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 4
        scrollView.pinchGestureRecognizer?.isEnabled = true
    }

    /// 서버가 그리는 반응형 페이지는 번들 HTML처럼 `--content-scale`을 알지 못한다.
    /// WKWebView의 문서 배율을 Dynamic Type과 같은 값으로 맞추면 CSS를 복제하지 않고도
    /// 게시판·Arena의 본문, 폼, 버튼을 함께 키우고 반응형 레이아웃이 다시 흐르게 된다.
    /// pageZoom은 새 문서로 이동해도 유지되므로 로그인 핸드오프와 뒤로가기도 같은 크기다.
    static func configureHostedPage(
        _ webView: WKWebView,
        size: DynamicTypeSize
    ) {
        // 서버 페이지의 두 셸은 UIRefreshControl을 쓰므로 번들 HTML용 `configure`의
        // bounce 비활성화를 적용하면 안 된다. 확대·이동만 보장하고 당겨 새로고침은
        // 기존처럼 유지한다.
        let scrollView = webView.scrollView
        scrollView.isScrollEnabled = true
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 4
        scrollView.pinchGestureRecognizer?.isEnabled = true
        webView.pageZoom = scale(for: size)
    }

    static func scale(for size: DynamicTypeSize) -> Double {
        switch size {
        case .xSmall: return 0.88
        case .small: return 0.94
        case .medium: return 0.98
        case .large: return 1.0
        case .xLarge: return 1.12
        case .xxLarge: return 1.24
        case .xxxLarge: return 1.36
        case .accessibility1: return 1.5
        case .accessibility2: return 1.65
        case .accessibility3: return 1.8
        case .accessibility4: return 1.95
        case .accessibility5: return 2.1
        @unknown default: return 1.0
        }
    }

    static func bootstrapScript(
        size: DynamicTypeSize,
        reduceMotion: Bool,
        userMotionEnabled: Bool
    ) -> String {
        let scale = jsNumber(scale(for: size))
        let motion = reduceMotion ? "true" : "false"
        let userMotion = userMotionEnabled ? "true" : "false"
        return """
        (function () {
          window.MATTHS_ACCESSIBILITY = {
            scale: \(scale),
            reduceMotion: \(motion),
            userMotionEnabled: \(userMotion)
          };
          window.MATTHS_APPLY_ACCESSIBILITY = function (next) {
            if (next) {
              window.MATTHS_ACCESSIBILITY = Object.assign(
                {}, window.MATTHS_ACCESSIBILITY || {}, next
              );
            }
            var root = document.documentElement;
            if (!root) return;
            window.MATTHS_MOTION =
              window.MATTHS_ACCESSIBILITY.userMotionEnabled !== false &&
              !window.MATTHS_ACCESSIBILITY.reduceMotion;
            root.style.setProperty('--content-scale', String(window.MATTHS_ACCESSIBILITY.scale || 1));
            root.classList.toggle('reduce-motion', !!window.MATTHS_ACCESSIBILITY.reduceMotion);
            if (window.MATTHS_MOTION === false) {
              document.getAnimations().forEach(function (animation) {
                try { animation.finish(); } catch (_) { animation.cancel(); }
              });
              document.querySelectorAll('video, audio').forEach(function (media) {
                try { media.pause(); } catch (_) {}
              });
            }
            window.dispatchEvent(new CustomEvent('matthsAccessibilityChanged', {
              detail: window.MATTHS_ACCESSIBILITY
            }));
            window.requestAnimationFrame(function () {
              window.dispatchEvent(new Event('resize'));
            });
          };
          window.MATTHS_APPLY_ACCESSIBILITY();
          document.addEventListener('DOMContentLoaded', function () {
            window.MATTHS_APPLY_ACCESSIBILITY();
          }, { once: true });
        })();
        """
    }

    static func update(
        _ webView: WKWebView,
        size: DynamicTypeSize,
        reduceMotion: Bool,
        userMotionEnabled: Bool
    ) {
        let scale = jsNumber(scale(for: size))
        let motion = reduceMotion ? "true" : "false"
        let userMotion = userMotionEnabled ? "true" : "false"
        webView.evaluateJavaScript(
            "window.MATTHS_APPLY_ACCESSIBILITY && window.MATTHS_APPLY_ACCESSIBILITY({scale:\(scale),reduceMotion:\(motion),userMotionEnabled:\(userMotion)});"
        )
    }

    private static func jsNumber(_ value: Double) -> String {
        String(format: "%.3f", locale: Locale(identifier: "en_US_POSIX"), value)
    }
}
