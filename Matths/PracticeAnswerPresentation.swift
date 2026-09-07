import Foundation

enum PracticeAnswerPresentation {
    static func choiceNumber(_ answer: String?, count: Int) -> Int? {
        guard (1...5).contains(count), let answer else { return nil }
        let normalized = answer.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let index = ["a", "b", "c", "d", "e"].prefix(count).firstIndex(of: normalized) else { return nil }
        return index + 1
    }
    static func label(_ answer: String?, choiceCount: Int?) -> String {
        if let choiceCount {
            return choiceNumber(answer, count: choiceCount).map { "\($0)번" } ?? "선택 정보 없음"
        }
        let text = answer?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return text.isEmpty ? "입력 없음" : text
    }
}
