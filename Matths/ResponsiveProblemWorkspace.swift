import SwiftUI

/// Shared two-pane allocator. It never owns answers, timer, selection or drawing;
/// changing the proposed size repositions the same child views.
struct ResponsiveProblemWorkspace: Layout {
    var spacing: CGFloat = 12
    var leadingWidth: CGFloat? = nil
    var trailingWidth: CGFloat? = nil
    var leadingFraction: CGFloat = 0.42

    private func widths(_ total: CGFloat) -> (CGFloat, CGFloat) {
        let usable = max(0, total - spacing)
        let first = leadingWidth ?? trailingWidth.map { usable - $0 } ?? usable * leadingFraction
        let left = min(usable, max(0, first))
        return (left, max(0, usable - left))
    }
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard subviews.count == 2 else { return .zero }
        // ViewThatFits must be able to reject the split at narrow widths. Merely
        // echoing every proposed width squeezed two panels even on phone portrait.
        let minimumWidth = max(520, (leadingWidth ?? 240) + (trailingWidth ?? 280) + spacing)
        let width = max(minimumWidth, proposal.width ?? minimumWidth)
        let (left, right) = widths(width)
        let a = subviews[0].sizeThatFits(.init(width: left, height: proposal.height))
        let b = subviews[1].sizeThatFits(.init(width: right, height: proposal.height))
        let height = proposal.height ?? max(a.height, b.height)
        return CGSize(width: width, height: height.isFinite ? height : max(a.height, b.height))
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 2 else { return }
        let (left, right) = widths(bounds.width)
        subviews[0].place(at: bounds.origin, anchor: .topLeading, proposal: .init(width: left, height: bounds.height))
        subviews[1].place(at: CGPoint(x: bounds.minX + left + spacing, y: bounds.minY), anchor: .topLeading,
                          proposal: .init(width: right, height: bounds.height))
    }
}
