import Foundation

enum AcademyAssignmentAnswerType: String, Codable, CaseIterable, Identifiable {
    case multipleChoice = "MULTIPLE_CHOICE"
    case shortAnswer = "SHORT_ANSWER"
    var id: String { rawValue }
    var title: String { self == .multipleChoice ? "객관식" : "단답형" }
}

struct AcademyAssignmentSection: Codable, Equatable, Identifiable {
    var startNumber: Int
    var endNumber: Int
    var answerType: AcademyAssignmentAnswerType
    var choiceCount: Int
    var id: Int { startNumber }
}

struct AcademyAssignmentOMR: Codable, Equatable {
    struct Question: Codable, Equatable, Identifiable {
        var number: Int
        var answerType: AcademyAssignmentAnswerType
        var choiceCount: Int
        var answer: String
        var id: Int { number }
    }
    var enabled: Bool
    var questionCount: Int
    var sections: [AcademyAssignmentSection]
    var questions: [Question]
    var configuredAt: String?
    var missedSubmissionsFinalizedAt: String?
    var answerKey: [String]? = nil

    var isValid: Bool {
        guard enabled, (1...100).contains(questionCount), !sections.isEmpty, sections.count <= 100 else { return false }
        var next = 1
        for section in sections.sorted(by: { $0.startNumber < $1.startNumber }) {
            guard section.startNumber == next, section.endNumber >= next, section.endNumber <= questionCount,
                  section.answerType == .shortAnswer || (2...9).contains(section.choiceCount) else { return false }
            next = section.endNumber + 1
        }
        guard next == questionCount + 1 else { return false }
        guard questions.isEmpty || (questions.count == questionCount && Set(questions.map(\.number)) == Set(1...questionCount)) else { return false }
        guard questions.allSatisfy({ question in
            guard let section = section(for: question.number) else { return false }
            return question.answerType == section.answerType &&
                (question.answerType == .shortAnswer || question.choiceCount == section.choiceCount)
        }) else { return false }
        return true
    }
    func section(for number: Int) -> AcademyAssignmentSection? {
        sections.first { $0.startNumber <= number && number <= $0.endNumber }
    }
}

struct AcademyAssignmentSubmission: Codable, Equatable, Identifiable {
    struct Student: Codable, Equatable { var id: String; var name: String; var email: String }
    var id: String
    var weekId: String?
    var answers: [String]
    var answerModes: [AcademyAssignmentAnswerType]
    var answeredCount: Int
    var correctByQuestion: [Bool]
    var correctCount: Int
    var questionCount: Int
    var scorePercent: Double
    var status: String
    var submittedAt: String?
    var gradedAt: String?
    var autoZeroedAt: String?
    var answerKeyConfiguredAt: String?
    var student: Student? = nil
    var isValid: Bool {
        guard !id.isEmpty && (1...100).contains(questionCount) && answers.count == questionCount
            && correctByQuestion.count == questionCount && (0...questionCount).contains(answeredCount)
            && (0...answeredCount).contains(correctCount) && scorePercent.isFinite && (0...100).contains(scorePercent)
            && correctByQuestion.filter({ $0 }).count == correctCount
            && ["SUBMITTED", "MISSED"].contains(status) else { return false }
        let normalized = answers.map(AcademyAssignmentConfiguration.normalizedAnswer)
        guard normalized.filter({ !$0.isEmpty }).count == answeredCount,
              zip(normalized, correctByQuestion).allSatisfy({ !$0.1 || !$0.0.isEmpty }),
              scorePercent == (Double(correctCount) / Double(questionCount) * 100).rounded(.toNearestOrAwayFromZero)
        else { return false }
        // The web regrader may retain the original answerModes when the
        // teacher changes the question count. Grade consistency, not the old
        // mode-array length, is the receipt invariant.
        if status == "MISSED" { return answeredCount == 0 && correctCount == 0 && submittedAt == nil }
        return true
    }
}

struct AcademyAssignmentConfiguration: Codable, Equatable {
    var enabled: Bool
    var questionCount: Int
    var sections: [AcademyAssignmentSection]
    var answerKey: [String]
    static var blank: Self {
        .init(enabled: true, questionCount: 30,
              sections: [.init(startNumber: 1, endNumber: 30, answerType: .multipleChoice, choiceCount: 5)],
              answerKey: Array(repeating: "", count: 30))
    }
    init(enabled: Bool, questionCount: Int, sections: [AcademyAssignmentSection], answerKey: [String]) {
        self.enabled = enabled; self.questionCount = questionCount; self.sections = sections; self.answerKey = answerKey
    }
    init(_ omr: AcademyAssignmentOMR) {
        enabled = omr.enabled; questionCount = omr.questionCount; sections = omr.sections
        answerKey = omr.answerKey ?? Array(repeating: "", count: min(100, max(0, omr.questionCount)))
    }
    var validationMessage: String? {
        if !enabled { return nil }
        let omr = AcademyAssignmentOMR(enabled: enabled, questionCount: questionCount, sections: sections,
            questions: [], configuredAt: nil, missedSubmissionsFinalizedAt: nil)
        guard omr.isValid else { return "문항 구간을 1번부터 빠짐없이 설정해 주세요. 최대 100문항입니다." }
        guard answerKey.count == questionCount else { return "문항 수와 정답 개수가 다릅니다." }
        for (index, raw) in answerKey.enumerated() {
            let answer = Self.normalizedAnswer(raw)
            if answer.isEmpty || answer.utf16.count > 80 { return "\(index + 1)번 정답을 80자 이내로 입력해 주세요." }
            if let section = omr.section(for: index + 1), section.answerType == .multipleChoice,
               !(answer.count == 1 && Int(answer).map { (1...section.choiceCount).contains($0) } == true) {
                return "\(index + 1)번 정답은 1~\(section.choiceCount) 중에서 선택해 주세요."
            }
        }
        return nil
    }
    static func normalizedAnswer(_ raw: String) -> String {
        raw.precomposedStringWithCompatibilityMapping
            .components(separatedBy: .whitespacesAndNewlines).joined().lowercased()
    }
    func jsonString() throws -> String {
        guard validationMessage == nil else { throw CocoaError(.coderInvalidValue) }
        if !enabled { return #"{"enabled":false}"# }
        guard let value = String(data: try JSONEncoder().encode(self), encoding: .utf8) else { throw CocoaError(.coderInvalidValue) }
        return value
    }
    mutating func setQuestionCount(_ count: Int) {
        let count = min(100, max(1, count))
        let previous = sections
        questionCount = count
        answerKey = Array((answerKey + Array(repeating: "", count: count)).prefix(count))
        let rows = (1...count).map { number -> AcademyAssignmentSection in
            let prior = previous.first { $0.startNumber <= number && number <= $0.endNumber }
            return .init(startNumber: number, endNumber: number, answerType: prior?.answerType ?? .multipleChoice, choiceCount: prior?.choiceCount ?? 5)
        }
        sections = Self.compressed(rows)
    }
    mutating func setSection(from start: Int, through end: Int, type: AcademyAssignmentAnswerType, choices: Int) {
        guard start >= 1, end >= start, end <= questionCount, (2...9).contains(choices) else { return }
        let previous = sections
        sections = Self.compressed((1...questionCount).map { number in
            let prior = previous.first { $0.startNumber <= number && number <= $0.endNumber }
            return .init(startNumber: number, endNumber: number,
                answerType: (start...end).contains(number) ? type : (prior?.answerType ?? .multipleChoice),
                choiceCount: (start...end).contains(number) ? choices : (prior?.choiceCount ?? 5))
        })
    }
    private static func compressed(_ rows: [AcademyAssignmentSection]) -> [AcademyAssignmentSection] {
        var result: [AcademyAssignmentSection] = []
        for row in rows {
            if let last = result.last, last.answerType == row.answerType, last.choiceCount == row.choiceCount {
                result[result.count - 1].endNumber = row.endNumber
            } else { result.append(row) }
        }
        return result
    }
}
