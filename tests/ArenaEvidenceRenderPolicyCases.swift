import Foundation
import CoreGraphics

@main enum ArenaEvidenceRenderPolicyCases {
    static func main() {
        let empty = ArenaEvidenceRenderPolicy.plan(bounds: .null, isEmpty: true)!
        precondition(empty.pixels == CGSize(width: 1200, height: 900))
        for size in [1.0, 900, 2048, 10_000, 1_000_000] {
            let original = CGRect(x: -120, y: -80, width: size, height: size * 2)
            let plan = ArenaEvidenceRenderPolicy.plan(bounds: original, isEmpty: false)!
            precondition(plan.pixels.width <= 2048 && plan.pixels.height <= 2048)
            precondition(plan.pixels.width * plan.pixels.height <= 4_194_304)
            precondition(plan.source.contains(original))
            precondition(plan.scale > 0 && plan.scale <= 1)
        }
        precondition(ArenaEvidenceRenderPolicy.plan(bounds: .null, isEmpty: false) == nil)
        precondition(ArenaEvidenceRenderPolicy.plan(bounds: .infinite, isEmpty: false) == nil)
        print("Arena PNG preview: bounded pixels, preserved negative strokes and malformed geometry rejection passed")
    }
}
