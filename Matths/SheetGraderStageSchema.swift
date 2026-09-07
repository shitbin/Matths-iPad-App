import CoreFoundation
import Foundation

/// JSON syntax and language safety are necessary but not sufficient: a repaired
/// object for another task must never become a successful stage/checkpoint.
enum SheetGraderStageSchema: String, CaseIterable {
    case inventory, formulaRecheck, transcription, solve, matching, analysis, summary, explanation

    func accepts(_ object: [String: Any]) -> Bool {
        guard LocalModelOutputPolicy.isStudentFacingObjectAcceptable(object) else { return false }
        switch self {
        case .inventory:
            guard let kind = object["page_kind"] as? String,
                  ["math-exam", "other-subject", "not-an-exam", "multi-page"].contains(kind),
                  nullableText(object["note"], maximum: 2_000, optional: true),
                  let problems = objects(object["problems"], maximum: 30) else { return false }
            return problems.allSatisfy {
                number($0["no"], in: 1...30) && number($0["points"], in: 0...100)
                    && text($0["statement"], maximum: 4_000, empty: false)
                    && texts($0["choices"], count: 20, length: 2_000)
            }
        case .formulaRecheck:
            guard let rows = objects(object["formulas"], maximum: 30) else { return false }
            return rows.allSatisfy { number($0["no"], in: 1...30) && nullableText($0["formula"], maximum: 3_000) }
        case .transcription:
            guard let rows = objects(object["lines"], maximum: 256) else { return false }
            return rows.allSatisfy {
                number($0["id"], in: 1...10_000) && text($0["text"], maximum: 4_000, empty: false)
                    && text($0["region"], maximum: 200) && boolean($0["cancelled"])
            }
        case .solve:
            return number(object["no"], in: 1...30)
                && nullableText(object["answer"], maximum: 2_000)
                && texts(object["steps"], count: 12, length: 2_000)
                && text(object["topic"], maximum: 200)
        case .matching:
            guard let rows = objects(object["assignments"], maximum: 30),
                  let unassigned = object["unassigned"] as? [Any], unassigned.count <= 256,
                  unassigned.allSatisfy({ number($0, in: 1...10_000) }) else { return false }
            return rows.allSatisfy { row in
                guard number(row["no"], in: 1...30), let ids = row["line_ids"] as? [Any], ids.count <= 256 else { return false }
                return ids.allSatisfy { number($0, in: 1...10_000) }
                    && text(row["evidence"], maximum: 2_000) && boolean(row["sketch"])
            }
        case .analysis:
            // Reuse the same accepted-status/optional-field rules as item(from:).
            return LocalModelOutputPolicy.isProblemAnalysisObjectAcceptable(object)
        case .summary:
            guard text(object["page_result"], maximum: 2_000),
                  texts(object["strengths"], count: 20, length: 2_000),
                  text(object["recommendation"], maximum: 2_000),
                  let rows = objects(object["weak_types"], maximum: 30) else { return false }
            return rows.allSatisfy {
                nullableText($0["type_key"], maximum: 200) && text($0["label"], maximum: 200)
                    && text($0["reason"], maximum: 2_000)
            }
        case .explanation:
            guard let rows = objects(object["cards"], maximum: 2) else { return false }
            return rows.allSatisfy { row in
                guard number(row["no"], in: 1...30),
                      ["concept", "headline", "keyFormula", "why", "nextStep"].allSatisfy({ text(row[$0], maximum: 4_000) }),
                      let contrast = row["contrast"] as? [String: Any],
                      text(contrast["wrong"], maximum: 2_000), text(contrast["right"], maximum: 2_000),
                      let steps = objects(row["steps"], maximum: 8) else { return false }
                return steps.allSatisfy { text($0["say"], maximum: 2_000) && text($0["tex"], maximum: 2_000) }
            }
        }
    }

    var requiredShapeDescription: String {
        switch self {
        case .inventory: "page_kind 문자열, note 문자열 또는 null, problems 배열. 각 문항은 no 정수, points 정수, statement 문자열, choices 문자열 배열."
        case .formulaRecheck: "formulas 배열. 각 항목은 no 정수와 formula 문자열 또는 null."
        case .transcription: "lines 배열. 각 줄은 id 정수, text 문자열, region 문자열, cancelled Boolean."
        case .solve: "no 정수, answer 문자열 또는 null, steps 문자열 배열, topic 문자열."
        case .matching: "assignments 배열과 unassigned 정수 배열. 각 배정은 no 정수, line_ids 정수 배열, evidence 문자열, sketch Boolean. 문항 번호를 최상위 키로 쓰지 않는다."
        case .analysis: "status는 correct/self-corrected/calc-slip/concept-error/strategy-stuck/blank 중 기존 값, topic 문자열, did_well 문자열 배열, coach_note 문자열. 기존 type_key/stuck_at/error/final_answer의 구조와 값을 유지한다."
        case .summary: "page_result 문자열, strengths 문자열 배열, recommendation 문자열, weak_types 배열. 각 약점은 type_key 문자열 또는 null, label 문자열, reason 문자열."
        case .explanation: "cards 배열. 각 카드는 no 정수, concept/headline/keyFormula/why/nextStep 문자열, contrast 객체(wrong/right 문자열), steps 배열(say/tex 문자열 객체)."
        }
    }

    private func objects(_ value: Any?, maximum: Int) -> [[String: Any]]? {
        guard let array = value as? [[String: Any]], array.count <= maximum else { return nil }
        return array
    }
    private func text(_ value: Any?, maximum: Int, empty: Bool = true) -> Bool {
        guard let value = value as? String else { return false }
        return value.count <= maximum && (empty || !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
    private func nullableText(_ value: Any?, maximum: Int, optional: Bool = false) -> Bool {
        if value == nil { return optional }
        return value is NSNull || text(value, maximum: maximum)
    }
    private func texts(_ value: Any?, count: Int, length: Int) -> Bool {
        guard let values = value as? [String], values.count <= count else { return false }
        return values.allSatisfy { $0.count <= length }
    }
    private func boolean(_ value: Any?) -> Bool {
        guard let value = value as? NSNumber else { return false }
        return CFGetTypeID(value) == CFBooleanGetTypeID()
    }
    private func number(_ value: Any?, in range: ClosedRange<Int>) -> Bool {
        guard let value = value as? NSNumber, CFGetTypeID(value) != CFBooleanGetTypeID() else { return false }
        let number = value.doubleValue
        return number.isFinite && number.rounded() == number && number >= Double(range.lowerBound) && number <= Double(range.upperBound)
    }
}
