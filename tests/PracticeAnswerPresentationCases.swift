import Foundation

@main enum PracticeAnswerPresentationCases {
    static func main() {
        for count in 1...5 {
            for (index, key) in ["a", "b", "c", "d", "e"].enumerated() {
                let number = PracticeAnswerPresentation.choiceNumber(" \(key.uppercased())\n", count: count)
                precondition(number == (index < count ? index + 1 : nil))
            }
        }
        for invalid in [nil, "", "3", "f", "ab"] {
            precondition(PracticeAnswerPresentation.choiceNumber(invalid, count: 5) == nil)
            precondition(PracticeAnswerPresentation.label(invalid, choiceCount: 5) == "선택 정보 없음")
        }
        precondition(PracticeAnswerPresentation.choiceNumber("a", count: 0) == nil)
        precondition(PracticeAnswerPresentation.choiceNumber("a", count: 6) == nil)
        precondition(PracticeAnswerPresentation.label("-75", choiceCount: nil) == "-75")
        precondition(PracticeAnswerPresentation.label("\\frac{1}{2}", choiceCount: nil) == "\\frac{1}{2}")
        precondition(PracticeAnswerPresentation.label(nil, choiceCount: nil) == "입력 없음")
        print("Practice answer presentation: 40 checks passed")
    }
}
