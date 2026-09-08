import Foundation

@main
enum AuthLandingGeometryCases {
    static func main() {
        var count = 0
        for compact in [false, true] {
            for viewport in stride(from: 160.0, through: 1400, by: 40) {
                for brand in [36.0, 60, 96, 140, 220] {
                    for actions in [180.0, 240, 300, 348, 420, 680, 1000] {
                        let p = AuthLandingGeometry.resolve(viewportHeight: viewport,
                            brandHeight: brand, actionsHeight: actions, compact: compact)
                        let gap = compact ? 8.0 : 16.0
                        precondition(p.contentHeight >= viewport)
                        precondition(p.brandCenterY - brand / 2 >= gap)
                        precondition(p.brandCenterY + brand / 2 + gap <= p.actionsTop)
                        precondition(p.actionsTop + actions == p.contentHeight)
                        if viewport / 2 + brand / 2 + gap <= viewport - actions {
                            precondition(p.brandCenterY == viewport / 2, "brand must be centered when it fits")
                        }
                        count += 1
                    }
                }
            }
        }
        let phone = AuthLandingGeometry.resolve(viewportHeight: 781, brandHeight: 96,
            actionsHeight: 348, compact: false)
        precondition(phone.brandCenterY == 369 && phone.contentHeight == 781,
                     "current phone: near-center brand, actions remain bottom-aligned and unobstructed")
        let short = AuthLandingGeometry.resolve(viewportHeight: 200, brandHeight: 60,
            actionsHeight: 300, compact: true)
        precondition(short.contentHeight > 200 && short.actionsTop >= 76, "short view remains scrollable")
        let invalid = AuthLandingGeometry.resolve(viewportHeight: .nan, brandHeight: -.infinity,
            actionsHeight: .infinity, compact: false)
        precondition(invalid.contentHeight.isFinite && invalid.brandCenterY.isFinite)
        print("Auth landing geometry: \(count + 3) cases PASS (center, no overlap, bottom actions, short and large-type scroll)")
    }
}
