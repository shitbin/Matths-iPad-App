//  MathLabel.swift
//  Matths
//
//  한 줄짜리 수식 라벨 — 채점 리포트처럼 "짧은 문장 + 수식" 이 섞인 자리에 쓴다.
//
//  왜 필요한가: 리포트의 모든 칸이 SwiftUI Text 라 모델이 낸 LaTeX 가 그대로 나왔다.
//  `3^(2/4) x 3^(2/1)`, `a^m × a^n = a^(m+n)`, `√(3^9)` 처럼 ASCII 로 뭉갠 글이
//  화면에 그대로 보였다("코드 수식 또 깨졌어", 2026-07-29 사용자 리포트).
//  강의·해설은 KaTeX 로 조판되는데 정작 채점 결과만 소스가 보이는 상태였다.
//
//  설계 선택: 행마다 WKWebView 를 띄우면 리포트 한 장에 수십 개가 생긴다.
//  그래서 **수식이 든 줄에만** 웹뷰를 붙이고(MathText.containsMath), 나머지는
//  그냥 Text 로 둔다. 판단은 MathInline 이 알아서 한다 — 호출부는 그냥 쓰면 된다.

import SwiftUI
import WebKit

/// 수식이 있으면 KaTeX 로, 없으면 평범한 Text 로 그린다.
struct MathInline: View {
    let text: String
    var font: Font = .mCallout
    var color: Color = Tokens.text1
    /// 조판 크기(pt) — SwiftUI Font 는 크기를 못 읽으므로 호출부가 짝을 맞춰 준다
    var pixelSize: CGFloat = 17

    /// 색을 웹에 넘길 hex 로 구울 때 기준이 된다. 이게 없으면 라이트 값이 구워진다
    /// — 파일 아래 `tokenHexForWeb(_:)` 주석 참조.
    @Environment(\.colorScheme) private var colorScheme
    @State private var height: CGFloat = 20
    /// WKWebView가 콜드 부트될 때 KaTeX와 로컬 폰트를 준비하는 동안 1~2초간
    /// 투명한 면만 보일 수 있다. 첫 높이 메시지가 오기 전에는 평문 근사를 보여
    /// 시험 발문 자체가 빈칸으로 보이지 않게 한다.
    @State private var rendered = false

    var body: some View {
        if MathText.containsMath(text) {
            let hex = color.tokenHexForWeb(colorScheme)
            ZStack(alignment: .leading) {
                if !rendered {
                    Text(MathText.plain(text))
                        .font(font)
                        .foregroundStyle(color)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityHidden(true)
                }

                KaTeXLabel(text: text, pixelSize: pixelSize,
                           hex: hex, height: $height, rendered: $rendered)
                    // 투명 상태에서도 WKWebView는 로드·조판을 계속한다. 높이 메시지가
                    // 도착한 한 프레임 뒤 폴백과 교체해 빈 화면을 만들지 않는다.
                    .opacity(rendered ? 1 : 0)
            }
                .frame(height: rendered ? height : max(height, 44), alignment: .leading)
                // hex 도 id 에 넣는다. 색은 makeUIView 의 atDocumentStart 스크립트로만
                // 들어가므로, 다크↔라이트 전환 때 뷰를 새로 만들지 않으면 옛 색이 남는다.
                .id("math-\(text.hashValue)-\(Int(pixelSize))-\(hex)")
                .onChange(of: "\(text)|\(pixelSize)|\(hex)") { _, _ in
                    rendered = false
                }
                // 웹뷰가 준비되기 전후 모두 같은 네이티브 라벨을 노출한다. 폴백 Text와
                // WebKit MathML이 교체되면서 VoiceOver 포커스가 두 번 생기는 것도 막는다.
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(MathText.plain(text))
        } else {
            Text(text).font(font).foregroundStyle(color)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// `$…$` 가 섞인 한 줄을 KaTeX 로 조판한다. 높이는 스스로 보고한다.
private struct KaTeXLabel: UIViewRepresentable {
    let text: String
    let pixelSize: CGFloat
    let hex: String
    @Binding var height: CGFloat
    @Binding var rendered: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(WebMotion.preferenceKey) private var userMotionEnabled = true

    func makeCoordinator() -> Coordinator {
        Coordinator(height: $height, rendered: $rendered)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        // base64 로 싣는다 — JS 리터럴로 박으면 LaTeX 백슬래시가 한 겹 사라진다
        // (\frac → rac). explain.html 과 같은 이유, 같은 방식이다.
        let payload = [
            "text": text,
            "size": "\(pixelSize)",
            "color": hex,
            "accessibility": "수식 \(MathText.plain(text))"
        ]
        let json = (try? JSONSerialization.data(withJSONObject: payload)) ?? Data("{}".utf8)
        config.userContentController.addUserScript(WKUserScript(
            source: "window.MATTHS_MATH_B64 = \"\(json.base64EncodedString())\";",
            injectionTime: .atDocumentStart, forMainFrameOnly: true))
        config.userContentController.addUserScript(WKUserScript(
            source: WebContentAccessibility.bootstrapScript(
                size: dynamicTypeSize,
                reduceMotion: reduceMotion,
                userMotionEnabled: userMotionEnabled),
            injectionTime: .atDocumentStart, forMainFrameOnly: true))
        config.userContentController.add(context.coordinator, name: "mathHeight")

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
        web.configuration.userContentController.removeScriptMessageHandler(forName: "mathHeight")
    }

    static let htmlURL: URL? =
        Bundle.main.url(forResource: "mathline", withExtension: "html", subdirectory: "LessonWeb")
        ?? Bundle.main.url(forResource: "mathline", withExtension: "html")

    final class Coordinator: NSObject, WKScriptMessageHandler {
        @Binding var height: CGFloat
        @Binding var rendered: Bool
        init(height: Binding<CGFloat>, rendered: Binding<Bool>) {
            _height = height
            _rendered = rendered
        }
        func userContentController(_ c: WKUserContentController, didReceive m: WKScriptMessage) {
            guard let h = m.body as? Double, h > 0 else { return }
            // 미세한 떨림으로 레이아웃이 계속 돌지 않게 1pt 미만 변화는 무시한다
            if abs(height - CGFloat(h)) > 1 { height = CGFloat(h) }
            rendered = true
        }
    }
}

private extension Color {
    /// 다크/라이트를 UIKit 으로 해석해 웹에 넘길 hex 를 만든다.
    /// 웹뷰는 SwiftUI 의 색 토큰을 모르므로 여기서 한 번 굽는다.
    ///
    /// **scheme 을 반드시 받아야 한다.** 토큰은 `UIColor { traits in … }` 로 만든 동적
    /// 색이고 `getRed` 는 그 자리에서 값을 확정한다. 확정 기준은 `UITraitCollection.current`
    /// 인데, SwiftUI body 안에서는 이게 그 뷰의 외관을 따라간다는 보장이 없다.
    /// 미지정이면 **라이트로 떨어진다.**
    ///
    /// 그래서 다크 모드에서 `Tokens.ink` 가 #111426(거의 검정)으로 구워졌다. 같은 화면의
    /// 선택지는 SwiftUI Text 라 #eef1fa 로 제대로 나오는데, `$…$` 가 든 발문만 어두운
    /// 카드(#141a2e) 위에 검정으로 찍혀 대비 1.05:1 — 글자가 아예 안 보였다.
    /// (2026-08-21, 아이패드 아레나 대국 화면. 배치고사·오답노트·채팅도 같은 경로였다.)
    ///
    /// performAsCurrent 와 resolvedColor 를 함께 쓴다. 앞은 `UIColor(self)` 가 생성 시점에
    /// 값을 확정해 버리는 경우를, 뒤는 동적 색으로 남아 오는 경우를 막는다. 둘 중 어느
    /// 쪽으로 동작하든 결과가 같아야 한다.
    func tokenHexForWeb(_ scheme: ColorScheme) -> String {
        let traits = UITraitCollection(
            userInterfaceStyle: scheme == .dark ? .dark : .light)
        // 못 읽었을 때의 기본값도 외관을 따라간다. 예전에는 여기서 #17171f 를 돌려줘,
        // 실패했을 때조차 다크 모드에서 검정이 나왔다.
        var hex = scheme == .dark ? "#eef1fa" : "#17171f"
        traits.performAsCurrent {
            let ui = UIColor(self).resolvedColor(with: traits)
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            guard ui.getRed(&r, green: &g, blue: &b, alpha: &a) else { return }
            hex = String(format: "#%02x%02x%02x",
                         Int(r * 255), Int(g * 255), Int(b * 255))
        }
        return hex
    }
}
