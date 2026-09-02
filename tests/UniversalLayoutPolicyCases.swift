import Foundation

@main
struct UniversalLayoutPolicyCases {
    static func main() {
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
