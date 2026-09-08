import Foundation

/// Keep the brand near the middle of the visible login screen, but never
/// overlap the measured sign-in actions. Short/large-type screens can scroll.
enum AuthLandingGeometry {
    struct Placement: Equatable {
        let contentHeight: CGFloat
        let brandCenterY: CGFloat
        let actionsTop: CGFloat
    }

    static func resolve(viewportHeight: CGFloat, brandHeight: CGFloat,
                        actionsHeight: CGFloat, compact: Bool) -> Placement {
        let viewport = viewportHeight.isFinite ? max(0, viewportHeight) : 0
        let brand = brandHeight.isFinite ? max(0, brandHeight) : 0
        let actions = actionsHeight.isFinite ? max(0, actionsHeight) : 0
        let spacing: CGFloat = compact ? 8 : 16
        let top: CGFloat = compact ? 8 : 16
        let height = max(viewport, top + brand + spacing + actions)
        let actionsTop = height - actions
        let brandCenter = max(top + brand / 2,
                              min(viewport / 2, actionsTop - spacing - brand / 2))
        return .init(contentHeight: height, brandCenterY: brandCenter, actionsTop: actionsTop)
    }
}
