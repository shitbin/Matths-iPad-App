import Foundation

struct LLMGenParams {
    var maxTokens = 1024
    var temperature: Float = 0.7
    var topP: Float = 0.8
    var topK: Int32 = 20
    var minP: Float = 0
    var presencePenalty: Float = 1.5
}

@main enum SheetGraderStageSchemaCases {
    static func main() throws {
        let observed: [String: Any] = ["1번": [String: Any]()]
        precondition(LocalModelOutputPolicy.isStudentFacingObjectAcceptable(observed), "baseline must reproduce generic-object acceptance")
        for schema in SheetGraderStageSchema.allCases {
            precondition(!schema.accepts(observed), "real malformed matching checkpoint must not pass another stage")
            precondition(!schema.accepts([:]))
            precondition(!schema.requiredShapeDescription.isEmpty)
        }
        let fixtures: [(SheetGraderStageSchema, [String: Any])] = [
            (.inventory, ["page_kind": "math-exam", "note": NSNull(), "problems": [["no": 1, "points": 3, "statement": "방정식 2x+3=7을 푸시오.", "choices": []]]]),
            (.formulaRecheck, ["formulas": [["no": 1, "formula": "2x+3=7"]]]),
            (.transcription, ["lines": [["id": 1, "text": "2x=4", "region": "아래", "cancelled": false]]]),
            (.solve, ["no": 1, "answer": "2", "steps": ["양변에서 3을 뺍니다.", "2로 나눕니다."], "topic": "일차방정식"]),
            (.matching, ["assignments": [["no": 1, "line_ids": [1], "evidence": "일차식이 같습니다.", "sketch": false]], "unassigned": []]),
            (.analysis, ["status": "correct", "topic": "일차방정식", "did_well": ["양변을 2로 나눴습니다."], "coach_note": "풀이가 맞습니다."]),
            (.summary, ["page_result": "일차방정식을 풀었습니다.", "strengths": ["계산이 정확합니다."], "weak_types": [], "recommendation": "다음 개념을 학습하세요."]),
            (.explanation, ["cards": [[
                "no": 1, "concept": "일차방정식", "headline": "양변에 같은 연산", "keyFormula": "2x=4",
                "why": "등식의 성질입니다.", "nextStep": "같은 수로 나눠보세요.",
                "contrast": ["wrong": "한쪽만 나눔", "right": "양변을 나눔"],
                "steps": [["say": "양변에서 뺍니다.", "tex": "2x=4"]]
            ]]])
        ]
        var checked = 0
        for (schema, fixture) in fixtures {
            precondition(schema.accepts(fixture), "valid \(schema) rejected")
            let encoded = try JSONSerialization.data(withJSONObject: fixture)
            let decoded = try JSONSerialization.jsonObject(with: encoded) as! [String: Any]
            precondition(schema.accepts(decoded), "wire JSON must pass the same schema")
            for key in fixture.keys where key != "note" {
                var missing = fixture; missing.removeValue(forKey: key)
                precondition(!schema.accepts(missing), "missing \(schema).\(key) accepted")
                checked += 1
            }
        }
        precondition(!SheetGraderStageSchema.matching.accepts(["assignments": [], "unassigned": [true]]))
        precondition(!SheetGraderStageSchema.matching.accepts(["assignments": [], "unassigned": [1.5]]))
        precondition(!SheetGraderStageSchema.matching.accepts(["assignments": [], "unassigned": ["1"]]))
        precondition(!SheetGraderStageSchema.transcription.accepts(["lines": [["id": true, "text": "x=2", "region": "아래", "cancelled": false]]]))
        precondition(!SheetGraderStageSchema.transcription.accepts(["lines": [["id": 1, "text": "x=2", "region": "아래", "cancelled": 0]]]))
        precondition(!SheetGraderStageSchema.inventory.accepts(["page_kind": "unknown", "problems": []]))
        precondition(!SheetGraderStageSchema.solve.accepts(["no": 1, "answer": ["2"], "steps": [], "topic": "방정식"]))
        precondition(!SheetGraderStageSchema.analysis.accepts(["status": "almost-correct", "topic": "방정식", "did_well": [], "coach_note": "확인이 필요합니다."]))
        precondition(SheetGraderStageSchema.matching.accepts(["assignments": [], "unassigned": []]), "no handwriting can legitimately produce empty arrays")
        let observedV12: [String: Any] = [
            "page_kind": "math-exam", "note": NSNull(),
            "problems": [["no": 1, "points": 3, "statement": "방정식의 값을 구하시오.",
                           "choices": [["text": "2x = 7 - 3"], ["text": "2x = 4"], ["text": "x = 2"]]]]
        ]
        precondition(LocalModelOutputPolicy.isStudentFacingObjectAcceptable(observedV12))
        precondition(!SheetGraderStageSchema.inventory.accepts(observedV12), "actual v12 wrong choice objects must not silently become an empty or successful choice list")
        precondition(!SheetGraderStageSchema.transcription.accepts(["lines": Array(repeating: ["id": 1, "text": "x=2", "region": "아래", "cancelled": false] as [String: Any], count: 257)]))
        print("Sheet stage schema: real v11 malformed checkpoint rejected, 8 valid typed/wire fixtures, \(checked) missing-key cases, wrong stage/value/Boolean/number bounds passed")
    }
}
