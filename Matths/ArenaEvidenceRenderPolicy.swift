import Foundation
import CoreGraphics

enum ArenaEvidenceRenderPolicy {
    struct Plan {
        let source: CGRect
        let pixels: CGSize
        let scale: CGFloat
    }
    static func plan(bounds: CGRect, isEmpty: Bool) -> Plan? {
        let base = CGRect(x: 0, y: 0, width: 1200, height: 900)
        let source: CGRect
        if isEmpty { source = base }
        else {
            guard !bounds.isNull, !bounds.isInfinite,
                  [bounds.minX, bounds.minY, bounds.maxX, bounds.maxY].allSatisfy(\.isFinite) else { return nil }
            source = base.union(bounds.insetBy(dx: -32, dy: -32))
        }
        guard [source.minX, source.minY, source.width, source.height].allSatisfy(\.isFinite),
              source.width > 0, source.height > 0 else { return nil }
        // The vector original is preserved separately. Only the preview is
        // scaled, including negative-origin strokes instead of cropping them.
        let scale = min(1, 2048 / source.width, 2048 / source.height)
        let pixels = CGSize(width: max(1, ceil(source.width * scale)), height: max(1, ceil(source.height * scale)))
        guard scale.isFinite, scale > 0, pixels.width <= 2048, pixels.height <= 2048 else { return nil }
        return Plan(source: source, pixels: pixels, scale: scale)
    }
}
