//  SecureCaptureCanvas.swift
//  Matths
//
//  문제를 푸는 동안 "찍히더라도 저장되지 않게" 만드는 사전 차단 계층.
//
//  iOS 는 스크린샷을 막는 공개 API 를 주지 않지만, `UITextField(isSecureTextEntry: true)`
//  가 내부에 만드는 secure canvas 는 스크린샷·화면녹화·미러링·앱 전환기 스냅샷의
//  픽셀에서 제외된다. 보호할 콘텐츠를 그 canvas 아래로 옮기면 화면에는 정상으로
//  보이지만 캡처 결과물에는 검게 남는다 — 사용자가 요구한 넷플릭스식 동작이다.
//
//  ## "레이어만 옮기면 안전하다"는 틀렸다 — 측정해서 알았다
//  뷰를 canvas 의 subview 로 넣으면 UIView 트리가 바뀌어 접근성 트리·hit testing·
//  SwiftUI 레이아웃이 끌려간다. 그래서 여기서는 CALayer 만 재부모화한다. 다만 그것이
//  "UIKit 이 보는 트리는 그대로" 를 뜻하지는 **않는다.** UIKit 은 `subviews` 를
//  `layer.sublayers` 의 delegate 에서 되읽으므로, 레이어만 옮겨도 터치 전달과 포커스
//  순회는 새 경로를 탄다. iPadOS 26 시뮬레이터에서 실제로 확인한 것:
//   - 숨은 필드를 보호 대상 **안**에 두면 필드가 자기 조상의 자손이 되어 SwiftUI
//     포커스 순회가 무한 재귀에 빠지고 스택 오버플로로 죽는다. → 필드는 형제로 둔다.
//   - 형제로 둔 뒤에도 `window.hitTest` 가 콘텐츠에 닿지 못해 화면 전체가 터치를
//     잃었다. 그래서 재부모화 직후 **실제로 만져지는지** 확인하고, 아니면 되돌린다.
//
//  ## 그래서 프로브와 런타임 가드 없이는 쓰지 않는다
//  이 기법의 위험은 두 가지다.
//   1. **조용히 풀린다.** iOS 메이저 업데이트에서 캡처 제외만 사라지고 화면은 멀쩡해
//      보호되는 줄 알고 계속 쓰게 된다(Apple Developer Forums 767320: iOS 18 보고).
//      → `SecureCanvasProbe` 가 마커 픽셀로 캡처 제외를 계측한다.
//   2. **앱을 망가뜨린다.** 위에서 본 재귀·터치 상실이 그것이다.
//      → 재부모화 직후 좌표·hit test·윈도우 소속을 확인하고 하나라도 어긋나면
//        즉시 되돌린 뒤 `.degraded` 로 내려 이번 OS/빌드에서는 다시 시도하지 않는다.
//  둘 중 하나라도 통과하지 못하면 아무것도 재부모화하지 않고 기존 보호(녹화·미러링
//  검정 덮개 + 앱 전환 덮개 + 워터마크 + 사후 감사 이벤트)로 폴백한다.
//  **학생의 시험 화면이 보호보다 먼저다.**

import SwiftUI
import UIKit

/// canvas 만 빌려주는 투명 필드.
///
/// **왜 hitTest 를 다시 써야 하는가.** UIKit 은 `subviews` 를 `layer.sublayers` 의
/// delegate 에서 되읽는다. 즉 "레이어만 옮겼다"고 해도 UIKit 이 보는 뷰 트리는 바뀐다 —
/// 재부모화 뒤 앱 콘텐츠는 이 필드의 자손이 되고, 윈도우의 터치 전달은 이 필드를 먼저
/// 지나간다. 필드가 상호작용을 막으면 화면 전체가 터치를 잃는다(실제로 그렇게 죽었다).
/// 그래서 이 필드는 자기 영역을 무한대로 열어 두고, 히트는 전부 아래로 넘긴다.
final class SecureCanvasField: UITextField {
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool { true }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard !isHidden, alpha > 0.01 else { return nil }
        for subview in subviews.reversed() {
            let converted = convert(point, to: subview)
            if let hit = subview.hitTest(converted, with: event) { return hit }
        }
        // 필드 자신은 절대 터치를 삼키지 않는다.
        return nil
    }

    override func becomeFirstResponder() -> Bool { false }
    override var canBecomeFirstResponder: Bool { false }
}

/// 숨은 secure text field 의 canvas 레이어를 찾아 콘텐츠 레이어를 그 아래로 옮긴다.
@MainActor
enum SecureCanvasBinder {
    /// 되돌리기에 필요한 원래 위치를 전부 들고 있는다. 하나라도 빠지면 보호를 끌 때
    /// 화면이 사라지거나 어긋난 채로 남는다.
    struct Attachment {
        let field: UITextField
        let canvasLayer: CALayer
        let content: CALayer
        let originalContentSuperlayer: CALayer
        let originalContentIndex: Int
        let originalFieldSuperlayer: CALayer?
    }

    /// 화면에 아무것도 그리지 않는 canvas 공급용 필드.
    static func makeSecureField() -> SecureCanvasField {
        let field = SecureCanvasField(frame: .zero)
        field.isSecureTextEntry = true
        field.backgroundColor = .clear
        field.textColor = .clear
        field.tintColor = .clear
        field.borderStyle = .none
        // 자기 자신은 접근성 요소가 아니다. 단 `accessibilityElementsHidden` 은
        // **절대 켜지 않는다** — 재부모화 뒤에는 앱 콘텐츠가 이 필드의 자손으로
        // 읽히므로, 그 값을 켜면 화면 전체가 VoiceOver 에서 사라진다.
        field.isAccessibilityElement = false
        return field
    }

    /// canvas 레이어 탐색. iOS 버전마다 내부 뷰 구성이 달라 경로를 나눈다.
    ///
    /// - iOS 17 이하: 필드의 subview 중 `_UITextLayoutCanvasView` 이름 매칭이 안정적이었다.
    /// - iOS 18 이상: 이름 매칭 실패 보고가 있어 구조 탐색(공개 UIKit 타입이 아닌
    ///   마지막 subview)을 먼저 시도한다.
    ///
    /// 어느 쪽으로 찾았든 그 레이어가 실제로 캡처에서 빠지는지는 프로브가 따로 잰다.
    static func canvasLayer(of field: UITextField) -> CALayer? {
        field.setNeedsLayout()
        field.layoutIfNeeded()
        if #available(iOS 18.0, *) {
            return structuralCanvasLayer(of: field) ?? namedCanvasLayer(of: field)
        } else {
            return namedCanvasLayer(of: field) ?? structuralCanvasLayer(of: field)
        }
    }

    private static func namedCanvasLayer(of field: UITextField) -> CALayer? {
        field.subviews.first {
            String(describing: type(of: $0)).contains("CanvasView")
        }?.layer
    }

    private static func structuralCanvasLayer(of field: UITextField) -> CALayer? {
        let excluded: [AnyClass] = [
            UILabel.self, UIImageView.self, UIControl.self, UIScrollView.self, UIVisualEffectView.self,
        ]
        return field.subviews.last { view in
            !excluded.contains { view.isKind(of: $0) }
        }?.layer
    }

    /// `content` 를 secure canvas 아래로 옮긴다. 실패하면 아무것도 바꾸지 않고 nil.
    static func attach(content: CALayer, using field: UITextField) -> Attachment? {
        guard let contentParent = content.superlayer,
              let index = contentParent.sublayers?.firstIndex(where: { $0 === content }),
              let canvas = canvasLayer(of: field) else { return nil }
        // canvas 는 field.layer 의 자손이다. field.layer 가 content 안에 남아 있으면
        // content 를 canvas 밑으로 넣는 순간 레이어 사이클이 된다. 먼저 밖으로 뺀다.
        let originalFieldSuperlayer = field.layer.superlayer
        contentParent.insertSublayer(field.layer, at: UInt32(index))
        normalizeGeometry(field.layer)
        normalizeGeometry(canvas)
        canvas.addSublayer(content)
        guard content.superlayer === canvas else {
            // 실패했다면 원상복구하고 포기한다.
            content.removeFromSuperlayer()
            contentParent.insertSublayer(content, at: UInt32(min(index, contentParent.sublayers?.count ?? 0)))
            field.layer.removeFromSuperlayer()
            originalFieldSuperlayer?.addSublayer(field.layer)
            return nil
        }
        let attachment = Attachment(
            field: field,
            canvasLayer: canvas,
            content: content,
            originalContentSuperlayer: contentParent,
            originalContentIndex: index,
            originalFieldSuperlayer: originalFieldSuperlayer)
        renormalize(attachment)
        return attachment
    }

    /// 레이아웃이 돌면 UITextField 가 canvas 레이어의 위치를 자기 기준으로 되돌린다.
    /// 그대로 두면 보호 콘텐츠가 통째로 밀리므로 매 레이아웃마다 다시 0 으로 맞춘다.
    static func renormalize(_ attachment: Attachment) {
        normalizeGeometry(attachment.field.layer)
        normalizeGeometry(attachment.canvasLayer)
        // 두 중간 뷰의 hit test 영역이 콘텐츠보다 작으면 그 바깥 터치가 통째로 사라진다.
        // UIKit 이 subviews 를 layer.sublayers 에서 되읽는 이상 이들은 실제 조상이다.
        let size = attachment.content.bounds.size
        attachment.field.layer.bounds.size = size
        attachment.canvasLayer.bounds.size = size
        (attachment.canvasLayer.delegate as? UIView)?.isUserInteractionEnabled = true
    }

    /// 이 레이어가 자식 좌표계에 어떤 이동·클리핑도 더하지 않게 만든다.
    static func normalizeGeometry(_ layer: CALayer) {
        layer.anchorPoint = .zero
        layer.position = .zero
        layer.bounds.origin = .zero
        layer.transform = CATransform3DIdentity
        layer.masksToBounds = false
        layer.opacity = 1
        layer.isHidden = false
    }

    /// 원래 자리로 되돌린다. 보호를 끄는 경로는 반드시 여기를 지나야 한다.
    static func detach(_ attachment: Attachment) {
        attachment.content.removeFromSuperlayer()
        let parent = attachment.originalContentSuperlayer
        let index = min(attachment.originalContentIndex, parent.sublayers?.count ?? 0)
        parent.insertSublayer(attachment.content, at: UInt32(index))
        attachment.field.layer.removeFromSuperlayer()
        attachment.originalFieldSuperlayer?.addSublayer(attachment.field.layer)
    }
}

/// 보호 대상 SwiftUI 하위 트리 뒤에 붙는 0×0 표식. 이 뷰가 자기 조상의 레이어를
/// secure canvas 아래로 옮긴다.
struct SecureCaptureCanvas: UIViewRepresentable {
    /// "문제 푸는 동안" 에만 true 여야 한다. 앱 전체에 켜면 안 된다.
    var isActive: Bool

    func makeUIView(context: Context) -> SecureCaptureCanvasView {
        SecureCaptureCanvasView()
    }

    func updateUIView(_ uiView: SecureCaptureCanvasView, context: Context) {
        uiView.setActive(isActive)
    }

    static func dismantleUIView(_ uiView: SecureCaptureCanvasView, coordinator: ()) {
        // 화면이 사라질 때 레이어를 원위치시키지 않으면 다음 화면이 남의 canvas 안에서
        // 렌더된다. 해제는 선택이 아니라 필수다.
        uiView.setActive(false)
    }
}

final class SecureCaptureCanvasView: UIView {
    /// 이미 보호 중인 대상. 루트와 fullScreenCover 가 둘 다 켜지면 같은 최상위 뷰를
    /// 가리키게 되는데, 그때 두 번 재부모화하면 secure canvas 가 중첩되고 해제 순서에
    /// 따라 화면이 통째로 사라진다. 대상 하나당 한 번만 건다 — 어차피 화면 전체가
    /// 대상이므로 한 번으로 충분하다.
    private static let securedTargets = NSHashTable<UIView>.weakObjects()

    private let field = SecureCanvasBinder.makeSecureField()
    private var attachment: SecureCanvasBinder.Attachment?
    private var securedTarget: UIView?
    private var wantsProtection = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        isAccessibilityElement = false
        accessibilityElementsHidden = true
        // field 는 **여기에 붙이지 않는다.** UIKit 은 `subviews` 를 `layer.sublayers` 의
        // delegate 에서 되읽으므로, 숨은 필드가 보호 대상 안에 있으면 재부모화 후
        // "필드가 자기 조상의 자손" 이 되어 뷰 트리에 사이클이 생긴다. 실제로 SwiftUI 의
        // 포커스 순회(_UIHostingView.canBecomeFirstResponder → firstFocusableDescendant)가
        // 무한 재귀에 빠져 스택 오버플로로 죽었다. 필드는 보호 대상의 **형제**여야 한다.
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }

    func setActive(_ active: Bool) {
        guard wantsProtection != active else { return }
        wantsProtection = active
        applyState()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        applyState()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if let attachment { SecureCanvasBinder.renormalize(attachment) }
    }

    /// 해제 지점은 여기와 `dismantleUIView` 둘뿐이다. deinit 에서는 메인 액터 격리가
    /// 보장되지 않아 레이어를 되돌릴 수 없으므로, 윈도우를 떠나는 순간 반드시 푼다.
    override func willMove(toWindow newWindow: UIWindow?) {
        super.willMove(toWindow: newWindow)
        if newWindow == nil { deactivate() }
    }

    private func applyState() {
        guard wantsProtection,
              window != nil,
              SecureCanvasProbe.allowsSecureCanvas else {
            deactivate()
            return
        }
        activate()
    }

    private func activate() {
        guard attachment == nil, let window else { return }
        guard let target = protectionTarget() else {
            logSelfTest("skipped=no-target")
            return
        }
        guard !Self.securedTargets.contains(target) else {
            logSelfTest("skipped=already-secured")
            return
        }
        // 필드는 보호 대상의 형제로 둔다(윈도우 직속). 대상 안에 두면 재부모화 후
        // 뷰 트리가 자기 자신을 참조해 포커스 순회가 무한 재귀에 빠진다.
        field.frame = .zero
        window.addSubview(field)
        window.layoutIfNeeded()

        let windowLayer = window.layer
        let before = target.layer.convert(CGPoint.zero, to: windowLayer)
        guard let attached = SecureCanvasBinder.attach(content: target.layer, using: field) else {
            field.removeFromSuperview()
            SecureCanvasProbe.reportRuntimeFailure("runtime-canvas-not-found")
            logSelfTest("failed=canvas-not-found")
            return
        }
        let after = target.layer.convert(CGPoint.zero, to: windowLayer)
        guard abs(after.x - before.x) < 0.5, abs(after.y - before.y) < 0.5 else {
            // 보호는 되지만 화면이 밀린다면 학생 쪽이 더 손해다. 즉시 되돌리고 포기한다.
            SecureCanvasBinder.detach(attached)
            field.removeFromSuperview()
            SecureCanvasProbe.reportRuntimeFailure("runtime-geometry-shift")
            logSelfTest("failed=geometry-shift dx=\(after.x - before.x) dy=\(after.y - before.y)")
            return
        }
        // 재부모화는 UIKit 이 보는 뷰 트리도 바꾼다(subviews 는 layer.sublayers 에서
        // 되읽힌다). 그래서 화면이 여전히 **만져지는지**, 그리고 콘텐츠가 여전히 윈도우의
        // 자손으로 읽히는지 — 즉 접근성·포커스 순회가 도달할 수 있는지 — 를 직접 확인한다.
        // 실패하면 보호보다 앱이 먼저다. 되돌리고 이번 OS/빌드에서는 다시 시도하지 않는다.
        let probePoint = CGPoint(x: target.bounds.midX, y: target.bounds.midY)
        let hit = window.hitTest(window.convert(probePoint, from: target), with: nil)
        let reachable = hit.map { $0 === target || $0.isDescendant(of: target) } ?? false
        guard reachable, target.isDescendant(of: window) else {
            SecureCanvasBinder.detach(attached)
            field.removeFromSuperview()
            SecureCanvasProbe.reportRuntimeFailure("runtime-input-tree-broken")
            logSelfTest("failed=input-tree-broken hit=\(hit.map { "\(type(of: $0))" } ?? "nil") "
                        + "canvas=\(attached.canvasLayer.delegate.map { "\(type(of: $0))" } ?? "nil")")
            return
        }
        attachment = attached
        securedTarget = target
        Self.securedTargets.add(target)
        logSelfTest("attached target=\(type(of: target)) bounds=\(target.bounds.size) "
                    + "hit=\(hit.map { "\(type(of: $0))" } ?? "nil")")
    }

    /// `-secureCanvasProbeSelfTest` 로 실행할 때만 재부모화 결과를 남긴다. 시뮬레이터에서
    /// 프로브가 `.unavailable` 이라 이 경로가 꺼지므로, 렌더링 확인은 이 로그로만 한다.
    /// `@autoclosure` 라서 릴리스 빌드에서는 메시지 문자열을 만들지도 않는다.
    private func logSelfTest(_ message: @autoclosure () -> String) {
        #if DEBUG
        guard ProcessInfo.processInfo.arguments.contains("-secureCanvasProbeSelfTest") else { return }
        print("MATTHS_SECURE_CANVAS_ATTACH_V1 \(message())")
        #endif
    }

    private func deactivate() {
        if let securedTarget {
            Self.securedTargets.remove(securedTarget)
            self.securedTarget = nil
        }
        guard let attachment else { return }
        SecureCanvasBinder.detach(attachment)
        field.removeFromSuperview()
        self.attachment = nil
    }

    /// 윈도우 바로 아래의 최상위 조상 — SwiftUI 호스팅 뷰 — 을 보호 대상으로 삼는다.
    /// 비공개 클래스 이름을 찾지 않고 구조로만 정한다. 이 화면 전체가 보호 대상이므로
    /// 부분만 고르려다 어긋나는 것보다 이쪽이 예측 가능하다.
    private func protectionTarget() -> UIView? {
        var result: UIView?
        var candidate = superview
        while let view = candidate, !(view is UIWindow) {
            result = view
            candidate = view.superview
        }
        guard let target = result,
              target !== self,
              candidate is UIWindow,
              target.layer.superlayer != nil else { return nil }
        return target
    }
}

private struct SecureCaptureCanvasModifier: ViewModifier {
    let isActive: Bool

    func body(content: Content) -> some View {
        content.background(
            SecureCaptureCanvas(isActive: isActive)
                .frame(width: 0, height: 0)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        )
    }
}

extension View {
    /// 보호 화면에만 붙인다. `isActive` 는 "문제 푸는 동안" 신호여야 한다.
    func secureCaptureCanvas(isActive: Bool) -> some View {
        modifier(SecureCaptureCanvasModifier(isActive: isActive))
    }
}
