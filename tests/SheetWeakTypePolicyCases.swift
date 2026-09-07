import Foundation

@main enum SheetWeakTypePolicyCases {
    static func evidence(_ status: String, type: ProblemType? = .logEq, topic: String = "로그방정식",
                         statement: String = "로그방정식의 해를 구하시오.", uncertain: Bool = false,
                         stuck: String? = nil, why: String? = "진수 조건을 확인하지 않았습니다.") -> SheetWeakTypePolicy.Evidence {
        .init(type: type, status: status, topic: topic, statement: statement,
              statementUncertain: uncertain, stuckAt: stuck, errorWhy: why)
    }
    static func main() {
        // Exact observed v13c classification: final answer correct, topic linear,
        // but a valid-yet-unrelated quadratic key. Old compactMap emitted it.
        let observed = evidence("correct", type: .quadDisc, topic: "선형방정식",
                                statement: "방정식 2x+3=7을 푸시오.", why: "")
        precondition([observed].compactMap(\.type) == [.quadDisc])
        precondition(SheetWeakTypePolicy.resolve(items: [observed], summaryTypes: []) == [])
        for status in ["correct", "self-corrected", "blank", "unknown", "almost-correct"] {
            precondition(SheetWeakTypePolicy.resolve(items: [evidence(status)], summaryTypes: [.logEq]) == [], "\(status) is not a grounded weakness")
        }
        for status in ["calc-slip", "concept-error", "strategy-stuck"] {
            precondition(SheetWeakTypePolicy.resolve(items: [evidence(status)], summaryTypes: []) == [.logEq])
            precondition(SheetWeakTypePolicy.resolve(items: [evidence(status, uncertain: true)], summaryTypes: [.logEq]) == [])
            precondition(SheetWeakTypePolicy.resolve(items: [evidence(status, statement: "")], summaryTypes: [.logEq]) == [])
            precondition(SheetWeakTypePolicy.resolve(items: [evidence(status, type: nil)], summaryTypes: [.logEq]) == [])
        }
        for absent in [nil, "", "  ", "unknown", "unknown.", "없음", "해당 없음", "판독 불확실", "판독불가", "분석보류", "확인필요", "분석 보류 · 확인 필요"] {
            precondition(SheetWeakTypePolicy.resolve(items: [evidence("concept-error", why: absent)], summaryTypes: [.logEq]) == [])
        }
        precondition(SheetWeakTypePolicy.resolve(items: [evidence("strategy-stuck", stuck: "밑을 바꾼 다음 단계에서 막혔습니다.", why: nil)], summaryTypes: []) == [.logEq])
        precondition(SheetWeakTypePolicy.resolve(items: [], summaryTypes: [.logEq, .quadDisc]) == [])
        let mixed = [observed, evidence("concept-error"), evidence("calc-slip", type: .integral, topic: "정적분", statement: "정적분의 값을 구하시오.")]
        precondition(SheetWeakTypePolicy.resolve(items: mixed, summaryTypes: [.quadDisc, .integral, .integral, .logEq]) == [.integral, .logEq])
        precondition(SheetWeakTypePolicy.resolve(items: [evidence("calc-slip", type: .quadDisc, topic: "일차방정식")], summaryTypes: [.quadDisc]) == [], "known contradictory type must not be assigned another guessed key")
        precondition(SheetWeakTypePolicy.resolve(items: [evidence("concept-error", type: .quadDisc, topic: "이차방정식의 판별식", statement: "x²+bx+c=0의 판별식을 구하시오.")], summaryTypes: []) == [.quadDisc])
        print("Sheet weak-type policy: observed correct/linear→quadratic regression, correct/self-corrected/blank/unknown exclusion, evidence and uncertainty gates, summary grounding, stable order/dedup and real-error retention passed")
    }
}
