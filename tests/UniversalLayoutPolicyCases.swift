import Foundation

@main
struct UniversalLayoutPolicyCases {
    static func main() {
        for usable in stride(from: 524, through: 1340, by: 12) {
            let written = UniversalLayoutPolicy.problemPaneWidth(usableWidth: CGFloat(usable), height: 300, hasChoices: false)
            let choice = UniversalLayoutPolicy.problemPaneWidth(usableWidth: CGFloat(usable), height: 300, hasChoices: true)
            expect(choice >= written, "Short choice problem receives at least the normal problem width")
            expect(choice >= 240 && choice <= 560 && CGFloat(usable) - choice >= 280, "Both problem and note retain usable minimum widths")
            expect(UniversalLayoutPolicy.problemPaneWidth(usableWidth: CGFloat(usable), height: 420, hasChoices: true) == written,
                   "Tall tablet keeps normal writing-first proportions")
        }
        for (width, height, compact) in [(852, 305, true), (740, 260, true), (560, 419, true),
                                         (559, 305, false), (1024, 420, false), (390, 740, false),
                                         (1366, 900, false), (852, 0, false)] {
            expect(UniversalLayoutPolicy.usesCompactOnboardingChoices(width: CGFloat(width), height: CGFloat(height), accessibilityText: false) == compact,
                   "Onboarding goal and diagnostic grid adapts to actual container \(width)x\(height)")
            expect(!UniversalLayoutPolicy.usesCompactOnboardingChoices(width: CGFloat(width), height: CGFloat(height), accessibilityText: true),
                   "Onboarding large text does not squeeze choices into columns")
        }
        for width in stride(from: 320, through: 1366, by: 20) {
            for height in [180, 239, 240, 320, 744, 1024] {
                let actual = UniversalLayoutPolicy.usesProblemSplit(width: CGFloat(width), height: CGFloat(height), accessibilityText: false)
                expect(actual == (width >= 560 && height >= 240), "Container split boundary \(width)x\(height)")
                expect(!UniversalLayoutPolicy.usesProblemSplit(width: CGFloat(width), height: CGFloat(height), accessibilityText: true), "Large text retains stacked option")
            }
        }
        expect(UniversalLayoutPolicy.defaultsToFingerDrawing(on: .phone),
               "iPhone finger input defaults on")
        expect(!UniversalLayoutPolicy.defaultsToFingerDrawing(on: .pad),
               "iPad keeps Pencil-first input")

        expect(UniversalLayoutPolicy.usesCompactTopChrome(on: .phone, vertical: .regular),
               "iPhone portrait uses compact top chrome")
        expect(UniversalLayoutPolicy.usesCompactTopChrome(on: .pad, vertical: .compact),
               "short landscape uses compact top chrome")
        expect(!UniversalLayoutPolicy.usesCompactTopChrome(on: .pad, vertical: .regular),
               "regular iPad keeps full identity")
        expect(UniversalLayoutPolicy.solutionCanvasMinimumHeight(
            on: .phone, horizontal: .compact, vertical: .regular) == 360,
            "iPhone portrait canvas height")
        expect(UniversalLayoutPolicy.solutionCanvasMinimumHeight(
            on: .phone, horizontal: .compact, vertical: .compact) == 220,
            "iPhone landscape canvas height")
        expect(UniversalLayoutPolicy.solutionCanvasMinimumHeight(
            on: .pad, horizontal: .compact, vertical: .regular) == 420,
            "iPad compact-width canvas remains Pencil-sized")
        expect(UniversalLayoutPolicy.solutionCanvasMinimumHeight(
            on: .pad, horizontal: .regular, vertical: .regular) == 620,
            "iPad regular canvas remains full-sized")

        expect(UniversalLayoutPolicy.topBarMinimumHeight(
            on: .phone, vertical: .compact, accessibilityText: false) >= 44,
            "compact top bar keeps 44pt target")
        expect(UniversalLayoutPolicy.tabMinimumHeight(vertical: .compact) >= 44,
               "compact tab keeps 44pt target")

        print("Universal iPhone/iPad layout policy cases passed")
    }

    private static func expect(
        _ condition: @autoclosure () -> Bool,
        _ label: String
    ) {
        guard condition() else {
            fputs("FAIL: \(label)\n", stderr)
            exit(1)
        }
    }
}
