import Foundation
import CoreGraphics

@main struct TutorialFocusCases {
    @MainActor static func main() {
        var count = 0
        func check(_ condition: @autoclosure () -> Bool, _ label: String) {
            precondition(condition(), label); count += 1
        }
        typealias G = TutorialFocusGeometry
        let phone = CGRect(x: 0, y: 0, width: 393, height: 852)
        let body = CGRect(x: 0, y: 104, width: 393, height: 654)
        let button = CGRect(x: 20, y: 180, width: 353, height: 52)
        let coach = CGRect(x: 20, y: 520, width: 353, height: 240)
        func resolve(_ targets: [CGRect], viewport: CGRect = CGRect(x: 0, y: 0, width: 393, height: 852),
                     clips: [CGRect] = [], coach: CGRect? = nil) -> G.Resolution {
            G.resolve(targets: targets, clippingRects: clips, viewport: viewport, coach: coach)
        }
        check(resolve([]) == .missing, "Absent match button never falls back to profile geometry")
        check(resolve([button, button]) == .ambiguous, "Duplicate real anchors fail closed")
        check(resolve([.zero]) == .offscreen, "Unlaid-out target is not a spotlight")
        check(resolve([.null]) == .offscreen, "Null bounds rejected")
        check(resolve([.infinite]) == .offscreen, "Infinite bounds rejected")
        check(resolve([CGRect(x: CGFloat.nan, y: 1, width: 2, height: 3)]) == .offscreen, "NaN rejected")
        check(resolve([button], clips: [body], coach: coach).frame == button.insetBy(dx: -6, dy: -6),
              "Portrait spotlight uses exact real bounds plus 6pt padding")
        check(resolve([button], coach: button) == .obscured, "Coach-covered target not highlighted")
        check(resolve([button], coach: CGRect(x: 373, y: 180, width: 20, height: 52)).frame != nil,
              "A touching edge alone is not an overlap")
        check(resolve([button], clips: [CGRect(x: 0, y: 210, width: 393, height: 500)]) == .offscreen,
              "Partially scrolled target cannot become a fake viewport-sized box")
        check(resolve([CGRect(x: 20, y: 780, width: 353, height: 52)], clips: [body]) == .offscreen,
              "Content under tab bar is clipped")
        check(resolve([CGRect(x: 20, y: 100, width: 353, height: 700)], clips: [body]) == .offscreen,
              "Oversized card is not treated as a fully visible target")
        check(resolve([button], clips: [body, CGRect(x: 10, y: 100, width: 370, height: 90)]) == .offscreen,
              "Nested scroll view clip is retained")
        check(resolve([button], clips: [.zero]) == .offscreen, "Unavailable viewport fails closed")
        check(resolve([CGRect(x: -1, y: 180, width: 394, height: 52)]).frame?.minX == 0,
              "Subpixel boundary tolerance never draws outside viewport")
        check(!G.placeCoachAbove(target: button, viewport: phone), "Top target gets bottom coach")
        check(G.placeCoachAbove(target: CGRect(x: 20, y: 740, width: 353, height: 52), viewport: phone),
              "Bottom target gets top coach")
        for viewport in [
            CGRect(x: 0, y: 0, width: 852, height: 393),
            CGRect(x: 0, y: 0, width: 667, height: 375),
            CGRect(x: 0, y: 0, width: 1024, height: 1366),
            CGRect(x: 0, y: 0, width: 1366, height: 1024),
            CGRect(x: 40, y: 20, width: 768, height: 1024)
        ] {
            let measured = CGRect(x: viewport.minX + 24, y: viewport.minY + 84, width: 260, height: 48)
            let actual = resolve([measured], viewport: viewport).frame
            check(actual == measured.insetBy(dx: -6, dy: -6), "Rotation/Split View preserves supplied measured bounds")
        }
        let landscape = CGRect(x: 0, y: 0, width: 852, height: 393)
        check(G.coachPlacement(target: CGRect(x: 20, y: 80, width: 260, height: 48), viewport: landscape) == .right,
              "Use real right-side space for landscape coach")
        check(G.coachPlacement(target: CGRect(x: 600, y: 80, width: 220, height: 48), viewport: landscape) == .left,
              "Use real left-side space for landscape coach")
        check(G.coachPlacement(target: CGRect(x: 20, y: 80, width: 810, height: 48), viewport: landscape) == .bottom,
              "Full-width target has no invented side space")
        check(G.coachPlacement(target: nil, viewport: landscape) == .bottom, "Missing anchor has stable coach fallback")
        let ownerA = UUID(), ownerB = UUID()
        TutorialFocusRequestCenter.request(.arenaMatchmaking, ownerID: ownerA, animated: true)
        let first = TutorialFocusRequestCenter.current!
        check(TutorialFocusRequestCenter.accepts(first.id, target: .arenaMatchmaking), "Current target scroll accepted")
        check(!TutorialFocusRequestCenter.accepts(first.id, target: .arenaProfile), "Wrong element cannot consume request")
        TutorialFocusRequestCenter.request(.arenaRecords, ownerID: ownerA, animated: false)
        let next = TutorialFocusRequestCenter.current!
        check(!TutorialFocusRequestCenter.accepts(first.id, target: .arenaMatchmaking), "Late previous step cannot scroll")
        check(next.id != first.id && !next.animated, "New step gets fresh ID and respects reduced motion")
        TutorialFocusRequestCenter.cancel(ownerID: ownerB)
        check(TutorialFocusRequestCenter.current?.id == next.id, "Stale owner's cleanup cannot clear current tutorial")
        TutorialFocusRequestCenter.cancel(ownerID: ownerA)
        check(TutorialFocusRequestCenter.current == nil, "Finish/account cleanup cancels pending scroll")
        check(!TutorialFocusRequestCenter.accepts(next.id, target: .arenaRecords), "Queued scroll rejected after finish")
        TutorialFocusRequestCenter.request(.todayPrimaryAction, ownerID: ownerB, animated: false)
        let ownedByB = TutorialFocusRequestCenter.current!
        TutorialFocusRequestCenter.cancel(ownerID: ownerA)
        check(TutorialFocusRequestCenter.current?.id == ownedByB.id, "New account request survives old cleanup")
        TutorialFocusRequestCenter.cancel(ownerID: ownerB)
        print("Tutorial focus real-bounds, clipping, adaptive coach and owner lifecycle: PASS (\(count) cases)")
    }
}
