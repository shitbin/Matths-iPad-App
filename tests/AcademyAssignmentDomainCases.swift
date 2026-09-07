import Foundation

@main
struct AcademyAssignmentDomainCases {
    static var checks = 0
    static var failures: [String] = []

    static func check(_ value: @autoclosure () -> Bool, _ message: String) {
        checks += 1
        if !value() { failures.append(message) }
    }

    static func configuration(_ count: Int = 3, choices: Int = 5) -> AcademyAssignmentConfiguration {
        .init(enabled: true, questionCount: count,
              sections: [.init(startNumber: 1, endNumber: count, answerType: .multipleChoice, choiceCount: choices)],
              answerKey: Array(repeating: "1", count: count))
    }

    static func omr(_ config: AcademyAssignmentConfiguration, includeQuestions: Bool = true) -> AcademyAssignmentOMR {
        var result = AcademyAssignmentOMR(enabled: config.enabled, questionCount: config.questionCount,
            sections: config.sections, questions: [], configuredAt: "2026-09-07T00:00:00Z",
            missedSubmissionsFinalizedAt: nil, answerKey: config.answerKey)
        if includeQuestions, (1...100).contains(config.questionCount) {
            result.questions = (1...config.questionCount).compactMap { number in
                guard let section = result.section(for: number) else { return nil }
                return .init(number: number, answerType: section.answerType, choiceCount: section.choiceCount,
                             answer: config.answerKey.indices.contains(number - 1) ? config.answerKey[number - 1] : "")
            }
        }
        return result
    }

    static func receipt(_ count: Int = 3) -> AcademyAssignmentSubmission {
        .init(id: "submission-1", weekId: "week-1", answers: Array(repeating: "1", count: count),
              answerModes: Array(repeating: .multipleChoice, count: count), answeredCount: count,
              correctByQuestion: Array(repeating: true, count: count), correctCount: count,
              questionCount: count, scorePercent: 100, status: "SUBMITTED",
              submittedAt: "2026-09-07T00:00:00Z", gradedAt: "2026-09-07T00:00:00Z",
              autoZeroedAt: nil, answerKeyConfiguredAt: "2026-09-06T00:00:00Z")
    }

    static func invalidReceipt(_ label: String, _ mutate: (inout AcademyAssignmentSubmission) -> Void) {
        var value = receipt()
        mutate(&value)
        check(!value.isValid, "receipt rejects \(label)")
    }

    static func main() throws {
        // Execute every supported question count and choice count, not only endpoint samples.
        for count in 1...100 {
            for choices in 2...9 {
                var value = configuration(count, choices: choices)
                value.answerKey = (1...count).map { String(($0 - 1) % choices + 1) }
                check(value.validationMessage == nil, "valid configuration \(count)x\(choices)")
                let document = omr(value)
                check(document.isValid, "valid full OMR \(count)x\(choices)")
                check(omr(value, includeQuestions: false).isValid, "configuration-only OMR \(count)x\(choices)")
                let decoded = try JSONDecoder().decode(AcademyAssignmentConfiguration.self, from: Data(try value.jsonString().utf8))
                check(decoded == value, "configuration JSON round trip \(count)x\(choices)")
                check(AcademyAssignmentConfiguration(document) == value, "teacher answer key retained \(count)x\(choices)")
            }
            check(receipt(count).isValid, "valid submitted receipt \(count)")
        }
        for choices in 2...9 {
            for answer in 1...choices {
                var value = configuration(1, choices: choices)
                value.answerKey = [String(answer)]
                check(value.validationMessage == nil, "choice \(answer) allowed in \(choices)")
            }
            for answer in ["0", "-1", String(choices + 1), "1.0", "01", "A", ""] {
                var value = configuration(1, choices: choices)
                value.answerKey = [answer]
                check(value.validationMessage != nil, "choice \(answer.debugDescription) rejected in \(choices)")
            }
        }

        for count in [Int.min, -1, 0, 101, Int.max] {
            var value = configuration()
            value.questionCount = count
            check(value.validationMessage != nil, "invalid count \(count) rejected without allocation")
        }
        for choices in [Int.min, -1, 0, 1, 10, Int.max] {
            var value = configuration()
            value.sections[0].choiceCount = choices
            check(value.validationMessage != nil, "invalid choice count \(choices)")
        }
        let malformedSections: [[AcademyAssignmentSection]] = [
            [],
            [.init(startNumber: 2, endNumber: 3, answerType: .multipleChoice, choiceCount: 5)],
            [.init(startNumber: 1, endNumber: 2, answerType: .multipleChoice, choiceCount: 5)],
            [.init(startNumber: 0, endNumber: 3, answerType: .multipleChoice, choiceCount: 5)],
            [.init(startNumber: 1, endNumber: 4, answerType: .multipleChoice, choiceCount: 5)],
            [.init(startNumber: 1, endNumber: 0, answerType: .multipleChoice, choiceCount: 5)],
            [.init(startNumber: 1, endNumber: 1, answerType: .multipleChoice, choiceCount: 5),
             .init(startNumber: 3, endNumber: 3, answerType: .shortAnswer, choiceCount: 5)],
            [.init(startNumber: 1, endNumber: 2, answerType: .multipleChoice, choiceCount: 5),
             .init(startNumber: 2, endNumber: 3, answerType: .shortAnswer, choiceCount: 5)],
            Array(repeating: .init(startNumber: 1, endNumber: 3, answerType: .multipleChoice, choiceCount: 5), count: 101)
        ]
        for (index, sections) in malformedSections.enumerated() {
            var value = configuration()
            value.sections = sections
            check(value.validationMessage != nil, "gap/overlap/omission/range case \(index)")
        }

        var mixed = configuration(10)
        mixed.setSection(from: 1, through: 3, type: .multipleChoice, choices: 2)
        mixed.setSection(from: 4, through: 6, type: .shortAnswer, choices: 5)
        mixed.setSection(from: 7, through: 10, type: .multipleChoice, choices: 9)
        mixed.answerKey = ["1", "2", "1", "x=2", "1/2", "가", "9", "8", "7", "6"]
        check(mixed.validationMessage == nil && mixed.sections.count == 3, "mixed 2-choice/short-answer/9-choice configuration")
        var mixedDocument = omr(mixed)
        mixedDocument.sections.reverse()
        mixedDocument.questions.reverse()
        check(mixedDocument.isValid, "complete unsorted sections and questions remain valid")
        check(mixedDocument.section(for: 0) == nil && mixedDocument.section(for: 11) == nil, "outside section lookup returns nil")
        for number in 1...10 {
            let section = mixedDocument.section(for: number)
            check(section?.answerType == ((4...6).contains(number) ? .shortAnswer : .multipleChoice), "mixed mode mapping \(number)")
        }
        var missingKey = mixedDocument
        missingKey.answerKey = nil
        let editingMissingKey = AcademyAssignmentConfiguration(missingKey)
        check(editingMissingKey.answerKey == Array(repeating: "", count: 10), "student OMR does not invent missing teacher answers")
        check(editingMissingKey.validationMessage != nil, "missing answer key must be supplied before enabling")

        for mutation in 0..<7 {
            var value = omr(configuration())
            switch mutation {
            case 0: value.questions.removeLast()
            case 1: value.questions[1].number = 1
            case 2: value.questions[0].number = 0
            case 3: value.questions[2].number = 4
            case 4: value.questions[0].answerType = .shortAnswer
            case 5: value.questions[0].choiceCount = 9
            default: value.enabled = false
            }
            check(!value.isValid, "malformed OMR question/mode/choice/enabled case \(mutation)")
        }

        var keyCount = configuration()
        keyCount.answerKey.removeLast()
        check(keyCount.validationMessage != nil, "missing answer key slot")
        keyCount.answerKey += ["1", "1"]
        check(keyCount.validationMessage != nil, "extra answer key slot")
        var single = configuration(1)
        single.answerKey = [" １\n"]
        check(single.validationMessage == nil, "compatibility normalization accepts fullwidth numeric answer")
        check(AcademyAssignmentConfiguration.normalizedAnswer(" Ｘ \n = ２\t") == "x=2", "normalization is NFKC, whitespace-free, lowercase")
        single.setSection(from: 1, through: 1, type: .shortAnswer, choices: 5)
        for (answer, valid) in [(" \n\t", false), (String(repeating: "a", count: 80), true),
                                (String(repeating: "a", count: 81), false),
                                (String(repeating: "😀", count: 40), true),
                                (String(repeating: "😀", count: 41), false)] {
            single.answerKey = [answer]
            check((single.validationMessage == nil) == valid, "80 UTF16-unit short answer boundary \(answer.utf16.count)")
        }
        do {
            _ = try single.jsonString()
            check(false, "invalid enabled configuration must throw on serialization")
        } catch { check(true, "invalid enabled configuration throws") }
        check(AcademyAssignmentConfiguration.blank.questionCount == 30, "new blank editor starts at 30 questions")
        check(AcademyAssignmentConfiguration.blank.validationMessage != nil, "blank enabled editor is not silently submittable")

        let mixedBeforeNoOps = mixed
        for (start, end, choices) in [(0, 1, 5), (2, 1, 5), (1, 11, 5), (1, 2, 1), (1, 2, 10)] {
            mixed.setSection(from: start, through: end, type: .multipleChoice, choices: choices)
            check(mixed == mixedBeforeNoOps, "invalid edit \(start)...\(end) x \(choices) is a no-op")
        }
        mixed.setSection(from: 7, through: 8, type: .multipleChoice, choices: 2)
        mixed.setSection(from: 9, through: 10, type: .multipleChoice, choices: 2)
        check(mixed.sections.count == 3 && mixed.sections[2].startNumber == 7 && mixed.sections[2].endNumber == 10,
              "equal adjacent edited ranges merge without disturbing short answers")
        mixed.setQuestionCount(5)
        check(mixed.answerKey == ["1", "2", "1", "x=2", "1/2"], "shrinking preserves retained answers in order")
        check(mixed.sections.last?.endNumber == 5 && mixed.sections.last?.answerType == .shortAnswer, "shrinking trims mixed sections")
        mixed.setQuestionCount(8)
        check(mixed.answerKey.suffix(3) == ["", "", ""], "growing does not resurrect truncated answers")
        check(mixed.sections.last?.startNumber == 6 && mixed.sections.last?.endNumber == 8 && mixed.sections.last?.choiceCount == 5,
              "growing uses a bounded default section")
        mixed.setQuestionCount(Int.min)
        check(mixed.questionCount == 1 && mixed.answerKey.count == 1 && mixed.sections.count == 1, "editor clamps minimum without overflow")
        mixed.setQuestionCount(Int.max)
        check(mixed.questionCount == 100 && mixed.answerKey.count == 100 && omr(mixed).isValid, "editor clamps maximum without giant allocation")

        // Disable is an explicit command, not an enabled draft with hidden stale answers.
        var disabled = AcademyAssignmentConfiguration.blank
        disabled.enabled = false
        disabled.questionCount = Int.min
        disabled.sections = []
        disabled.answerKey = [String(repeating: "sensitive-old-answer", count: 10)]
        check(disabled.validationMessage == nil, "disable does not require an old answer key")
        let disabledJSON = try disabled.jsonString()
        let disabledObject = try JSONSerialization.jsonObject(with: Data(disabledJSON.utf8)) as? [String: Bool]
        check(disabledObject == ["enabled": false], "disable sends only enabled=false, never stale keys/ranges")
        disabled.enabled = true
        check(disabled.validationMessage != nil, "re-enable restores all validation requirements")

        invalidReceipt("empty ID") { $0.id = "" }
        invalidReceipt("zero questions") { $0.questionCount = 0 }
        invalidReceipt("101 questions") { $0.questionCount = 101 }
        invalidReceipt("missing answer") { $0.answers.removeLast() }
        invalidReceipt("extra answer") { $0.answers.append("1") }
        invalidReceipt("missing result bit") { $0.correctByQuestion.removeLast() }
        invalidReceipt("negative answered count") { $0.answeredCount = -1 }
        invalidReceipt("too many answered questions") { $0.answeredCount = 4 }
        invalidReceipt("negative correct count") { $0.correctCount = -1 }
        invalidReceipt("more correct than answered") { $0.answeredCount = 2 }
        invalidReceipt("correct bit total mismatch") { $0.correctByQuestion[0] = false }
        invalidReceipt("NaN score") { $0.scorePercent = .nan }
        invalidReceipt("infinite score") { $0.scorePercent = .infinity }
        invalidReceipt("negative score") { $0.scorePercent = -1 }
        invalidReceipt("score over 100") { $0.scorePercent = 101 }
        invalidReceipt("unknown status") { $0.status = "DRAFT" }
        invalidReceipt("all correct but score zero") { $0.scorePercent = 0 }
        invalidReceipt("blank answer counted as answered/correct") { $0.answers[0] = " \n\t" }
        invalidReceipt("blank question marked correct despite consistent aggregate counts") {
            $0.answers = ["", "1", "1"]
            $0.answeredCount = 2
            $0.correctByQuestion = [true, false, true]
            $0.correctCount = 2
            $0.scorePercent = 67
        }
        invalidReceipt("MISSED carrying submitted answers") { $0.status = "MISSED" }

        // Server regradeAssignmentSubmissions recomputes answers/grade but retains the
        // original answerModes. MISSED rows have []. Array equality is NOT a valid
        // invariant for those server-generated receipts, unlike grade consistency.
        var regraded = receipt()
        regraded.answerModes = [.shortAnswer]
        check(regraded.isValid, "legacy regraded receipt may retain fewer original answer modes")
        regraded.answerModes = Array(repeating: .multipleChoice, count: 4)
        check(regraded.isValid, "legacy regraded receipt may retain more original answer modes")
        var missed = receipt()
        missed.answers = ["", "", ""]
        missed.answerModes = []
        missed.answeredCount = 0
        missed.correctByQuestion = [false, false, false]
        missed.correctCount = 0
        missed.scorePercent = 0
        missed.status = "MISSED"
        missed.submittedAt = nil
        missed.autoZeroedAt = "2026-09-07T00:00:00Z"
        check(missed.isValid, "server missedAssignmentGrade with empty modes and zero score remains valid")
        var expanded = receipt()
        expanded.answers = ["1", "", ""]
        expanded.answerModes = [.multipleChoice]
        expanded.answeredCount = 1
        expanded.correctByQuestion = [true, false, false]
        expanded.correctCount = 1
        expanded.scorePercent = 33
        check(expanded.isValid, "regrade to a larger assignment may append blank unanswered questions")

        // AcademyClassworkService.gradeAssignmentAnswers uses Math.round, not an
        // unrounded percentage. Exercise every possible score for 1...100 questions.
        for total in 1...100 {
            for correct in 0...total {
                var value = receipt(total)
                value.correctByQuestion = (0..<total).map { $0 < correct }
                value.correctCount = correct
                value.scorePercent = (Double(correct) / Double(total) * 100).rounded()
                check(value.isValid, "server rounded score \(correct)/\(total) accepted")
            }
        }
        for (correct, total, rounded) in [(1, 3, 33.0), (2, 3, 67.0), (1, 8, 13.0), (7, 8, 88.0)] {
            var value = receipt(total)
            value.correctByQuestion = (0..<total).map { $0 < correct }
            value.correctCount = correct
            value.scorePercent = rounded
            check(value.isValid, "golden JS Math.round \(correct)/\(total) = \(rounded)")
            value.scorePercent = rounded - 0.5
            check(!value.isValid, "fractional non-server score rejected \(correct)/\(total)")
        }

        let validReceipt = receipt()
        let decodedReceipt = try JSONDecoder().decode(AcademyAssignmentSubmission.self, from: JSONEncoder().encode(validReceipt))
        check(decodedReceipt == validReceipt, "valid receipt Codable round trip")
        var malformedWire = try JSONSerialization.jsonObject(with: JSONEncoder().encode(validReceipt)) as! [String: Any]
        malformedWire.removeValue(forKey: "answerModes")
        do {
            _ = try JSONDecoder().decode(AcademyAssignmentSubmission.self, from: JSONSerialization.data(withJSONObject: malformedWire))
            check(false, "missing required answerModes must fail decoding")
        } catch { check(true, "missing required answerModes rejected by Codable") }
        malformedWire["answerModes"] = ["MULTIPLE_CHOICE", "UNKNOWN", "SHORT_ANSWER"]
        do {
            _ = try JSONDecoder().decode(AcademyAssignmentSubmission.self, from: JSONSerialization.data(withJSONObject: malformedWire))
            check(false, "unknown mode must fail decoding")
        } catch { check(true, "unknown answer mode rejected by Codable") }

        if !failures.isEmpty {
            for failure in failures { fputs("FAIL: \(failure)\n", stderr) }
            fputs("Academy assignment domain: \(failures.count) failures / \(checks) checks\n", stderr)
            exit(1)
        }
        print("Academy assignment domain: \(checks) checks passed (100 question counts, 8 choice counts, mixed ranges, keys, receipts, explicit disable)")
    }
}
