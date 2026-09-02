//  JSBank.swift
//  Matths
//
//  웹 데모의 심화 모의고사 뱅크(exam-bank.js, 생성기 69종)를
//  **JavaScriptCore 로 그대로 실행**하는 브리지.
//
//  Swift 로 하나씩 재이식하는 대신 원본 JS 를 돌린다 — 사용자의 지적이 맞았다.
//  뱅크가 커버하는 과목: 공통수학Ⅰ·Ⅱ, 대수, 미적분Ⅰ, 확률과 통계.
//
//  결정론: 뱅크는 Math.random 을 쓰므로, 호출 직전에 시드 PRNG(mulberry32)로
//  Math.random 을 갈아끼운다. 같은 시드 = 같은 시험 (Node 에서 실측 검증됨).
//
//  문항 형식 (item.p):
//    prompt        $...$ KaTeX 인라인 — 네이티브에서는 ProblemWebView 로 렌더
//    inputMode     "multiple-choice" | "short-answer"
//    choices       [{key: "a"..."e", text}] (선지형만)
//    answer        선지형 = 정답 key / 단답형 = "정수" 또는 "p/q"
//    solution      해설 (KaTeX)

import Foundation
import JavaScriptCore

enum JSBank {
    /// 커리큘럼 과목명 → 뱅크 과목 id
    static let courseMap: [String: String] = [
        "공통수학Ⅰ": "common-math-1",
        "공통수학Ⅱ": "common-math-2",
        "대수": "algebra",
        "미적분Ⅰ": "calculus",
        "확률과 통계": "probstat",
    ]

    private static let context: JSContext? = {
        guard let ctx = JSContext() else { return nil }
        ctx.exceptionHandler = { _, exc in
            NSLog("JSBANK-ERROR %@", exc?.toString() ?? "?")
        }
        // 시드 PRNG — 호출 때마다 Math.random 을 교체한다
        ctx.evaluateScript("""
        function __mulberry32(a){return function(){a|=0;a=a+0x6D2B79F5|0;
          var t=Math.imul(a^a>>>15,1|a);t=t+Math.imul(t^t>>>7,61|t)^t;
          return((t^t>>>14)>>>0)/4294967296}}
        function __seed(s){ Math.random = __mulberry32(s); }
        """)
        guard let url = Bundle.main.url(forResource: "exam-bank", withExtension: "js")
                ?? Bundle.main.url(forResource: "exam-bank", withExtension: "js", subdirectory: "LessonWeb"),
              let src = try? String(contentsOf: url, encoding: .utf8) else {
            NSLog("JSBANK-ERROR exam-bank.js 번들 누락")
            return nil
        }
        ctx.evaluateScript(src)
        return ctx
    }()

    /// 뱅크 과목의 단원 id 목록 (순서 = 커리큘럼 단원 순서와 개념적으로 대응)
    static func unitIDs(course bankCourse: String) -> [String] {
        guard let ctx = context,
              let arr = ctx.evaluateScript("""
              (EXAM_COURSES.find(c => c.id === '\(bankCourse)') || {units: []})
                .units.map(u => u.id)
              """).toArray() as? [String] else { return [] }
        return arr
    }

    /// 소단원 집중 4문항 — 평가 v2 의 출제 풀 생성에 반복 호출된다
    static func subExam(course: String, unit: String, sub: String, seed: UInt64) -> [GeneratedProblem] {
        build("buildSubExam('\(course)', '\(unit)', '\(sub)')", seed: seed)
    }

    /// 대단원 모의고사 8문항 / 과목 전범위 12문항 / 3과목 통합 15문항
    static func unitExam(course: String, unit: String, seed: UInt64) -> [GeneratedProblem] {
        build("buildUnitExam('\(course)', '\(unit)')", seed: seed)
    }
    static func courseExam(course: String, seed: UInt64) -> [GeneratedProblem] {
        build("buildCourseExam('\(course)')", seed: seed)
    }
    static func integratedExam(seed: UInt64) -> [GeneratedProblem] {
        build("buildIntegratedExam()", seed: seed)
    }

    private static func build(_ call: String, seed: UInt64) -> [GeneratedProblem] {
        guard let ctx = context else { return [] }
        // 32비트 시드로 접어 넣는다 (mulberry32)
        ctx.evaluateScript("__seed(\(seed % 0xFFFF_FFFF))")
        guard let items = ctx.evaluateScript("(\(call)).items")?.toArray() else { return [] }

        return items.enumerated().compactMap { index, raw in
            guard let item = raw as? [String: Any],
                  let p = item["p"] as? [String: Any],
                  let prompt = p["prompt"] as? String else { return nil }

            let choiceDicts = p["choices"] as? [[String: Any]]
            let choices = choiceDicts?.compactMap { $0["text"] as? String }
            let answer = "\(p["answer"] ?? "")"
            let solution = (p["solution"] as? String) ?? ""
            let genID = (item["genId"] as? String) ?? "bank"

            return GeneratedProblem(
                id: "bank-\(genID)-\(index)",
                typeKey: "bank-\(genID)",
                typeName: (item["subLabel"] as? String) ?? "모의고사",
                unit: [(item["courseLabel"] as? String), (item["unitLabel"] as? String)]
                    .compactMap { $0 }.joined(separator: " · "),
                statement: prompt,
                answer: answer,
                // 뱅크 해설은 한 덩어리 — 단계 분해는 서버 채점의 몫이라 1단계로 담는다
                steps: [solution],
                minutes: ((item["points"] as? Int) ?? 4) >= 4 ? 5 : 3,
                choices: choices,
                isTex: true
            )
        }
    }
}
