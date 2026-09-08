import SwiftUI
import UIKit

struct TutorialTargetAnchor {
    let bounds: Anchor<CGRect>
    var clippingBounds: [Anchor<CGRect>] = []
}
typealias TutorialTargetAnchors = [TutorialTargetID: [TutorialTargetAnchor]]

struct TutorialTargetPreferenceKey: PreferenceKey {
    static var defaultValue: TutorialTargetAnchors = [:]
    static func reduce(value: inout TutorialTargetAnchors, nextValue: () -> TutorialTargetAnchors) {
        for (id, anchors) in nextValue() { value[id, default: []].append(contentsOf: anchors) }
    }
}

extension View {
    /// Add this to the actual button/card described by a tutorial, not its
    /// screen's generic top/middle/bottom wrapper. It does not change view IDs.
    func tutorialTarget(_ id: TutorialTargetID, when isEnabled: Bool = true) -> some View {
        anchorPreference(key: TutorialTargetPreferenceKey.self, value: .bounds) {
            isEnabled ? [id: [TutorialTargetAnchor(bounds: $0)]] : [:]
        }
        .background {
            if isEnabled { TutorialScrollProbe(target: id).allowsHitTesting(false) }
        }
    }
    /// Propagate the real clipping region of a scroll viewport to its anchors.
    /// Nested scroll views retain every clip, so hidden content never highlights.
    func tutorialViewport() -> some View {
        transformAnchorPreference(key: TutorialTargetPreferenceKey.self, value: .bounds) { targets, viewport in
            for id in Array(targets.keys) {
                targets[id] = targets[id]?.map { entry in
                    var entry = entry; entry.clippingBounds.append(viewport); return entry
                }
            }
        }
    }
}

/// The actual target view can reveal itself through its enclosing UIScrollView.
/// No screen coordinates, fixed offsets, guessed sections or private APIs are
/// used. A retired tutorial request cannot move a new account's screen.
private struct TutorialScrollProbe: UIViewRepresentable {
    let target: TutorialTargetID
    func makeUIView(context: Context) -> TutorialScrollProbeView { TutorialScrollProbeView(target: target) }
    func updateUIView(_ view: TutorialScrollProbeView, context: Context) { view.update(target: target) }
}

private final class TutorialScrollProbeView: UIView {
    private var target: TutorialTargetID
    private var observer: NSObjectProtocol?
    private var pendingRequestID: UUID?
    private var appliedRequestID: UUID?

    init(target: TutorialTargetID) {
        self.target = target
        super.init(frame: .zero)
        backgroundColor = .clear; isUserInteractionEnabled = false
        observer = NotificationCenter.default.addObserver(forName: TutorialFocusRequestCenter.notification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.scheduleFocus() }
        }
    }
    required init?(coder: NSCoder) { return nil }
    deinit { if let observer { NotificationCenter.default.removeObserver(observer) } }
    func update(target: TutorialTargetID) {
        if self.target != target { self.target = target; appliedRequestID = nil }
        scheduleFocus()
    }
    override func didMoveToWindow() { super.didMoveToWindow(); scheduleFocus() }
    override func layoutSubviews() { super.layoutSubviews(); scheduleFocus() }

    private func scheduleFocus() {
        guard window != nil, let request = TutorialFocusRequestCenter.current,
              request.target == target, appliedRequestID != request.id, pendingRequestID != request.id else { return }
        pendingRequestID = request.id
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.pendingRequestID = nil
            self.reveal(request)
        }
    }
    private func reveal(_ request: TutorialFocusRequestCenter.Request) {
        guard window != nil, !isHidden, bounds.width > 0, bounds.height > 0,
              TutorialFocusRequestCenter.accepts(request.id, target: target) else { return }
        var ancestor = superview
        var scrollViews: [UIScrollView] = []
        while let view = ancestor {
            if view.isHidden { return }
            if let scroll = view as? UIScrollView { scrollViews.append(scroll) }
            ancestor = view.superview
        }
        for scroll in scrollViews {
            guard scroll.bounds.height > 0, scroll.contentSize.height > 0 else { return }
            let rect = convert(bounds, to: scroll)
            let inset = scroll.adjustedContentInset
            let minY = -inset.top
            let maxY = max(minY, scroll.contentSize.height - scroll.bounds.height + inset.bottom)
            let y = min(maxY, max(minY, rect.minY - inset.top - 12))
            var x = scroll.contentOffset.x
            if rect.minX < scroll.bounds.minX + inset.left || rect.maxX > scroll.bounds.maxX - inset.right {
                let minX = -inset.left
                let maxX = max(minX, scroll.contentSize.width - scroll.bounds.width + inset.right)
                x = min(maxX, max(minX, rect.minX - inset.left - 12))
            }
            scroll.setContentOffset(CGPoint(x: x, y: y), animated: request.animated && !UIAccessibility.isReduceMotionEnabled)
        }
        appliedRequestID = request.id
    }
}
