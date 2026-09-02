import Foundation

@main
struct CheatingDetectionCases {
    static func main() {
        var failures = 0

        let base = CheatingProblemContext(
            statement: "함수의 최댓값을 구하여라.",
            expectedAnswer: "12",
            referenceSteps: ["도함수 f'(x)=0을 푼다", "끝점과 임계점의 함숫값을 비교한다"],
            studentFinalAnswer: "12",
            requiresWork: true)

        check("강한 좌표 근거가 있으면 의심", expected: .suspicious, context: base, raw: """
        {"verdict":"suspicious","confidence":0.91,"reason":"중간식 없이 결론으로 이동했습니다.",
         "evidence":[{"kind":"unexplained-jump","quote":"따라서 최댓값은 12","bbox":[430,520,760,610],"confidence":0.88,"strength":"strong"}]}
        """, failures: &failures)

        check("글씨체 차이만으로는 판정불가", expected: .inconclusive, context: base, raw: """
        {"verdict":"suspicious","confidence":0.96,"reason":"글씨체가 다릅니다.",
         "evidence":[{"kind":"mixed-writing-style","quote":"두 종류의 필기","bbox":[20,40,980,960],"confidence":0.95,"strength":"strong"}]}
        """, failures: &failures)

        check("좌표 없는 근거는 판정불가", expected: .inconclusive, context: base, raw: """
        {"verdict":"suspicious","confidence":0.94,"reason":"답만 있습니다.",
         "evidence":[{"kind":"answer-only","quote":"12","bbox":null,"confidence":0.94,"strength":"strong"}]}
        """, failures: &failures)

        check("정상 고확신", expected: .normal, context: base, raw: """
        {"verdict":"normal","confidence":83,"reason":"미분부터 값 비교까지 이어집니다.","evidence":[]}
        """, failures: &failures)

        let mixedLanguage = CheatingDetectionPolicy.finalize(raw: """
        {"verdict":"suspicious","confidence":0.93,
         "reason":"Ошибка знака. The student copied the final answer.",
         "evidence":[{"kind":"unexplained-jump","quote":"따라서 최댓값은 12","bbox":[430,520,760,610],"confidence":0.9,"strength":"strong"}]}
        """, context: base)
        if mixedLanguage.reason == "중간 연결 없이 결론으로 넘어간 부분이 확인됩니다."
            && !mixedLanguage.reason.contains("Ошибка")
            && !mixedLanguage.reason.contains("student") {
            print("✓ 모델 자유 서술은 학생 화면의 고정 한국어 문구로 치환")
        } else {
            failures += 1
            print("✗ 모델 자유 서술은 학생 화면의 고정 한국어 문구로 치환")
        }

        let normalMixedLanguage = CheatingDetectionPolicy.finalize(raw: """
        {"verdict":"normal","confidence":0.88,"reason":"No issue. Всё хорошо.","evidence":[]}
        """, context: base)
        if normalMixedLanguage.reason == "풀이 단계와 제출 답이 자연스럽게 이어집니다." {
            print("✓ 정상 판정도 모델 자유 서술을 직접 노출하지 않음")
        } else {
            failures += 1
            print("✗ 정상 판정도 모델 자유 서술을 직접 노출하지 않음")
        }

        let optionalWork = CheatingProblemContext(
            statement: "정답을 고르시오.", expectedAnswer: "③", studentFinalAnswer: "③", requiresWork: false)
        check("과정 비필수 문항의 답만 제출은 판정불가", expected: .inconclusive, context: optionalWork, raw: """
        {"verdict":"suspicious","confidence":0.99,"reason":"답만 있습니다.",
         "evidence":[{"kind":"answer-only","quote":"③","bbox":[450,450,550,550],"confidence":0.99,"strength":"strong"}]}
        """, failures: &failures)

        let arenaNoAnswerKey = CheatingProblemContext(
            statement: "문항 1: 값을 구하여라.",
            expectedAnswer: "",
            referenceSteps: [],
            studentFinalAnswer: "문항 1: 42",
            studentSubmittedAnswers: ["42"],
            requiresWork: true)
        check(
            "정답 없는 경기에서 본인 제출답과 같은 answer-only는 후보",
            expected: .suspicious,
            context: arenaNoAnswerKey,
            raw: """
            {"verdict":"suspicious","confidence":0.94,"reason":"답만 있습니다.",
             "evidence":[{"kind":"answer-only","quote":"정답 42","bbox":[100,100,300,200],"confidence":0.92,"strength":"strong"}]}
            """,
            failures: &failures)
        check(
            "정답 없는 경기에서 본인 제출답과 다른 answer-only는 판정불가",
            expected: .inconclusive,
            context: arenaNoAnswerKey,
            raw: """
            {"verdict":"suspicious","confidence":0.94,"reason":"답만 있습니다.",
             "evidence":[{"kind":"answer-only","quote":"43","bbox":[100,100,300,200],"confidence":0.92,"strength":"strong"}]}
            """,
            failures: &failures)

        check("모범 풀이에 없는 문구 일치는 약한 근거", expected: .inconclusive, context: base, raw: """
        {"verdict":"suspicious","confidence":0.89,"reason":"문구가 같습니다.",
         "evidence":[{"kind":"reference-phrase-match","quote":"갑자기 아무 문장","bbox":[100,100,500,200],"confidence":0.88,"strength":"strong"}]}
        """, failures: &failures)

        check("코드펜스 JSON 복구", expected: .normal, context: base, raw: """
        설명
        ```json
        {"verdict":"normal","confidence":0.81,"reason":"풀이 흐름이 보입니다.","evidence":[]}
        ```
        """, failures: &failures)

        check("깨진 출력은 판정불가", expected: .inconclusive, context: base,
              raw: "판독 결과를 만들지 못함", failures: &failures)

        let coordinate = CheatingDetectionPolicy.finalize(raw: """
        {"verdict":"suspicious","confidence":0.9,"reason":"붙여넣기 경계",
         "evidence":[{"kind":"visual-paste-artifact","quote":"직사각형 인쇄 블록","bbox":[100,200,900,800],"confidence":0.85,"strength":"strong"}]}
        """, context: base)
        let box = coordinate.evidence.first?.box
        if box != CheatingEvidenceBox(minX: 0.1, minY: 0.2, maxX: 0.9, maxY: 0.8) {
            failures += 1
            print("✗ 0...1000 좌표 정규화")
        } else {
            print("✓ 0...1000 좌표 정규화")
        }

        var interrupted = CheatingReviewRecord.pending(
            source: .practiceDrawing, problemID: "p-1",
            problemStatement: base.statement, studentFinalAnswer: "12", imageFile: "p-1.jpg")
        interrupted.recoverInterrupted()
        if interrupted.state != .completed || interrupted.result?.verdict != .inconclusive {
            failures += 1
            print("✗ 중단된 pending 기록은 판정불가로 복구")
        } else {
            print("✓ 중단된 pending 기록은 판정불가로 복구")
        }

        var completed = CheatingReviewRecord.pending(
            source: .sheetPhoto, problemID: nil,
            problemStatement: "시험지", studentFinalAnswer: nil, imageFile: nil)
        let normal = CheatingDetectionResult(
            verdict: .normal, confidence: 0.9, reason: "정상", evidence: [])
        completed.finish(normal)
        completed.recoverInterrupted()
        if completed.result != normal {
            failures += 1
            print("✗ 완료 기록은 복구 과정에서 보존")
        } else {
            print("✓ 완료 기록은 복구 과정에서 보존")
        }

        let legacyJSON = """
        {"id":"00000000-0000-0000-0000-000000000001","source":"sheet-photo","problemStatement":"옛 기록","createdAt":0,"state":"pending"}
        """.data(using: .utf8)!
        if let legacy = try? JSONDecoder().decode(CheatingReviewRecord.self, from: legacyJSON),
           legacy.problemContext == nil, legacy.arenaDelivery == nil {
            print("✓ 구버전 검토 기록은 새 복구 필드 없이도 해독")
        } else {
            failures += 1
            print("✗ 구버전 검토 기록은 새 복구 필드 없이도 해독")
        }

        let arenaContext = CheatingProblemContext(
            statement: "Arena 풀이", expectedAnswer: "", requiresWork: true)
        let arenaDelivery = GoatArenaCheatingReviewDelivery(
            matchId: "match-1", evidenceId: "evidence-1", clientBuildVersion: "1(1)")
        let arenaPending = CheatingReviewRecord.pending(
            source: .goatArenaEvidence, problemID: "match-1:1",
            problemStatement: arenaContext.statement, studentFinalAnswer: nil,
            imageFile: "arena.jpg", problemContext: arenaContext,
            arenaDelivery: arenaDelivery)
        if let encoded = try? JSONEncoder().encode(arenaPending),
           let decoded = try? JSONDecoder().decode(CheatingReviewRecord.self, from: encoded),
           decoded.problemContext == arenaContext, decoded.arenaDelivery == arenaDelivery {
            print("✓ GOAT 중단 검토의 이미지 맥락·후속 전송 대상 보존")
        } else {
            failures += 1
            print("✗ GOAT 중단 검토의 이미지 맥락·후속 전송 대상 보존")
        }

        if failures == 0 {
            print("\nLocal cheating detection 계약 전부 통과")
        } else {
            print("\n실패 \(failures)건")
            exit(1)
        }
    }

    private static func check(_ name: String,
                              expected: CheatingDetectionVerdict,
                              context: CheatingProblemContext,
                              raw: String,
                              failures: inout Int) {
        let got = CheatingDetectionPolicy.finalize(raw: raw, context: context)
        if got.verdict == expected {
            print("✓ \(name)")
        } else {
            failures += 1
            print("✗ \(name) — 예상 \(expected.rawValue), 실제 \(got.verdict.rawValue)")
        }
    }
}
