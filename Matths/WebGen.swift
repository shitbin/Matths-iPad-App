//  WebGen.swift
//  Matths
//
//  웹 심화 템플릿 180종 + 개념별 로컬 생성기 브리지 (webgen-bundle.js).
//  JSBank 와 같은 방식: JavaScriptCore 에 IIFE 번들을 싣고 Math.random 을
//  mulberry32 시드로 교체해 결정론을 확보한다 (같은 시드 = 같은 문항).
//
//  이 브리지로 평가 v2 의 "심화 몫 = 뱅크 4점 근사" 편차가 사라진다 —
//  기말·종합의 심화 문항은 진짜 심화 템플릿(학습 개념 스테이지 선택)에서 나온다.

import Foundation
import JavaScriptCore

enum WebGen {
    static let context: JSContext? = {
        guard let url = Bundle.main.url(forResource: "webgen-bundle", withExtension: "js",
                                        subdirectory: "LessonWeb")
                ?? Bundle.main.url(forResource: "webgen-bundle", withExtension: "js"),
              let src = try? String(contentsOf: url, encoding: .utf8),
              let ctx = JSContext() else { return nil }
        ctx.exceptionHandler = { _, exc in
            #if DEBUG
            print("WebGen JS 예외:", exc?.toString() ?? "?")
            #endif
        }
        // mulberry32 — JSBank 와 동일한 시드 주입 규약
        ctx.evaluateScript("""
        var __wg_state = 1;
        function __seed(s) { __wg_state = s >>> 0; }
        Math.random = function () {
          var t = __wg_state += 0x6D2B79F5;
          t = Math.imul(t ^ t >>> 15, t | 1);
          t ^= t + Math.imul(t ^ t >>> 7, t | 61);
          return ((t ^ t >>> 14) >>> 0) / 4294967296;
        };
        """)
        ctx.evaluateScript(src)
        return ctx
    }()

    private static func seeded(_ seed: UInt64) {
        context?.evaluateScript("__seed(\(seed % 0xFFFF_FFFF))")
    }

    // MARK: 심화 템플릿

    /// 심화 문항 출제 — learned 는 완료 개념 id (스테이지 선택 근거)
    static func drawAdvanced(courseId: String, unitId: String, learned: [String],
                             count: Int, seed: UInt64) -> [GeneratedProblem] {
        guard let ctx = context, count > 0 else { return [] }
        seeded(seed)
        let learnedJSON = (try? JSONSerialization.data(withJSONObject: learned))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        guard let raw = ctx.evaluateScript(
            "MatthsWebGen.drawAdvanced('\(courseId)', '\(unitId)', \(learnedJSON), \(count))")?
            .toArray() else { return [] }
        return raw.enumerated().compactMap { i, item in
            problem(from: item, index: i, keyPrefix: "adv", unitLabel: "심화")
        }
    }

    // MARK: 개념 로컬 생성기 (연습 풀)

    struct ConceptGenInfo {
        let requiredDistinctTypes: Int
        let typeIds: [String]
    }

    private static var infoCache: [String: ConceptGenInfo] = [:]
    private static var infoMisses: Set<String> = []

    static func conceptInfo(courseId: String, unitId: String, conceptId: String,
                            includeCurriculumChecks: Bool = false) -> ConceptGenInfo? {
        let cacheKey = [courseId, unitId, conceptId].joined(separator: "/")
        if let cached = infoCache[cacheKey] { return cached }
        var result: ConceptGenInfo?
        if !infoMisses.contains(cacheKey),
           let ctx = context,
           let dict = ctx.evaluateScript(
            "MatthsWebGen.conceptGeneratorInfo('\(courseId)', '\(unitId)', '\(conceptId)')")?
            .toObject() as? [String: Any],
           let types = dict["types"] as? [[String: Any]] {
            result = ConceptGenInfo(
                requiredDistinctTypes: dict["requiredDistinctTypes"] as? Int ?? 5,
                typeIds: types.compactMap { $0["id"] as? String })
        }
        if let result {
            infoCache[cacheKey] = result
            return result
        }
        infoMisses.insert(cacheKey)
        guard includeCurriculumChecks,
              CurriculumConceptCheckGenerator.supports(
                courseId: courseId, unitId: unitId, conceptId: conceptId) else { return nil }
        return ConceptGenInfo(
            requiredDistinctTypes: CurriculumConceptCheckGenerator.typeIds.count,
            typeIds: CurriculumConceptCheckGenerator.typeIds)
    }

    static func practiceProblems(courseId: String, unitId: String, conceptId: String,
                                 count: Int, seed: UInt64,
                                 includeCurriculumChecks: Bool = false) -> [GeneratedProblem] {
        if conceptInfo(courseId: courseId, unitId: unitId, conceptId: conceptId) != nil,
           let ctx = context {
            seeded(seed)
            if let raw = ctx.evaluateScript(
                "MatthsWebGen.generateLocal('\(courseId)', '\(unitId)', '\(conceptId)', null, \(count))")?
                .toArray() {
                let generated = raw.enumerated().compactMap { i, item in
                    problem(from: item, index: i, keyPrefix: "web", unitLabel: "연습")
                }
                if !generated.isEmpty { return generated }
            }
        }
        guard includeCurriculumChecks else { return [] }
        return CurriculumConceptCheckGenerator.generate(
            courseId: courseId, unitId: unitId, conceptId: conceptId,
            count: count, seed: seed)
    }

    // MARK: 공통 변환

    private static func problem(from raw: Any, index: Int,
                                keyPrefix: String, unitLabel: String) -> GeneratedProblem? {
        guard let d = raw as? [String: Any],
              let rawPrompt = d["prompt"] as? String,
              let answer = d["answer"] as? String else { return nil }
        // 웹 생성기의 \( \) 수식 표기를 앱 $ 규약으로 — 저장·검색·렌더 전부 일관되게
        let prompt = MathText.normalizeDelimiters(rawPrompt)
        let typeId = (d["typeId"] as? String) ?? (d["templateId"] as? String) ?? keyPrefix
        // 선지 두 형태를 다 받는다. 뱅크(exam-bank)는 문자열 배열이지만 웹 로컬 생성기는
        // {key,text} 객체 배열을 주고 answer 에 그 key("sqrt","positive"…)를 넣는다.
        // 문자열로만 캐스팅하던 시절엔 객체형이 통째로 nil 이 되어 선지가 사라졌고,
        // isMultipleChoice 가 거짓이 되는 바람에 학생이 내부 키 문자열을 손으로
        // 입력해야만 정답 처리되는 주관식으로 둔갑했다 — 유형 게이트가 영영 안 올랐다.
        var choiceKeys: [String]?
        var choiceTexts: [String]?
        if let strings = d["choices"] as? [String] {
            choiceTexts = strings.map(MathText.normalizeDelimiters)
        } else if let objects = d["choices"] as? [[String: Any]] {
            choiceTexts = objects.map { MathText.normalizeDelimiters(($0["text"] as? String) ?? "") }
            choiceKeys = objects.map { ($0["key"] as? String) ?? "" }
        }
        // 선다면 정답이 선지 값과 일치하는 위치의 키(a~e)로 변환.
        // 객체형은 answer 가 선지 key 와 짝이므로 key 로 먼저 찾고, 없으면 텍스트로 찾는다.
        var mappedAnswer = answer
        if let keys = choiceKeys, let idx = keys.firstIndex(of: answer) {
            mappedAnswer = ["a", "b", "c", "d", "e"][min(idx, 4)]
        } else if let choices = choiceTexts,
                  let idx = choices.firstIndex(where: { $0 == answer }) {
            mappedAnswer = ["a", "b", "c", "d", "e"][min(idx, 4)]
        }
        var solution = MathText.normalizeDelimiters((d["solution"] as? String) ?? "")
        if let source = d["sourcePattern"] as? String, !source.isEmpty {
            solution += solution.isEmpty ? "출제 근거: \(source)" : "\n출제 근거: \(source)"
        }
        // 시각 힌트 파라미터 — 원본 JSON 그대로 보존 (hint-core 가 소비)
        var vizJSON: String?
        if let viz = d["visualization"], !(viz is NSNull),
           let data = try? JSONSerialization.data(withJSONObject: viz) {
            vizJSON = String(data: data, encoding: .utf8)
        }
        // 서버와 앱이 같은 전문 유형을 서로 다른 진도로 세지 않도록
        // WebGen 유형은 서버 정본(typeId) 그대로 적립한다. adv-* 는 별도 연습군이다.
        let progressTypeKey = keyPrefix == "web" ? typeId : "\(keyPrefix)-\(typeId)"
        return GeneratedProblem(
            id: "\(keyPrefix)-\(typeId)-\(index)",
            typeKey: progressTypeKey,
            typeName: (d["label"] as? String) ?? (d["title"] as? String) ?? unitLabel,
            unit: unitLabel,
            statement: prompt,
            answer: mappedAnswer,
            steps: WebGenSolution.split(solution),
            minutes: d["estimatedMinutes"] as? Int ?? 5,
            choices: choiceTexts,
            isTex: true,
            hintText: (d["hintText"] as? String)
                .flatMap { $0.isEmpty ? nil : MathText.normalizeDelimiters($0) },
            visualizationJSON: vizJSON)
    }
}

/// 웹 생성기 풀이를 단계로 쪼갠다.
///
/// 웹은 풀이를 **한 문단 문자열**로 준다. 예전엔 그걸 통째로 `steps: [solution]` 에
/// 넣었는데, 그러면 단계가 항상 1개라 앱의 두 기능이 통째로 죽는다:
///   · 복습 화면의 "N단계(갈라진 곳)부터 풀이 다시 보기" 는 `steps.count >= 2` 조건
///   · 어느 단계에서 갈라졌는지 짚는 진단도 단계가 있어야 성립
/// 실제로 웹 시드 문항은 전부 단계 1개였다(2026-07-29 시뮬 확인 — 재생 버튼이 안 떴다).
///
/// 문장 경계로 자르되 **수식 안의 마침표는 건드리지 않는다**. `$1.5$`, `$f(x).$`
/// 같은 게 흔해서, `$` 안팎을 세지 않고 자르면 수식이 두 동강 난다.
enum WebGenSolution {
    static func split(_ solution: String) -> [String] {
        let text = solution.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return [] }

        // 웹 생성기의 일부 해설은 계산 두 번과 결론을 두 장문 문장에 합쳐 둔다.
        // 마침표만 자르면 화면에는 "2단계"로 보이지만 학생이 실제로 짚어야 할 곳은
        // 곱할 대상 → 중간 결과 → 다음 대상 → 최종 식 → 요구한 항의 판독, 다섯 곳이다.
        // 유형 id나 출제 패턴을 보지 않고 해설 자체의 정규형만 구조화하므로 같은 문장
        // 계약을 쓰는 다른 생성기도 함께 안전해진다. 캡처한 식은 다시 계산하지 않는다.
        if let structured = splitProductChainNormalForm(text) { return structured }

        var parts: [String] = []
        var buf = ""
        var inMath = false
        let chars = Array(text)
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if c == "$" { inMath.toggle() }
            buf.append(c)

            if !inMath {
                // 줄바꿈은 그 자체로 경계다 ("출제 근거: …" 가 여기 해당)
                if c == "\n" { flush(&parts, &buf); i += 1; continue }
                // 마침표 뒤에 공백/줄끝이 오면 문장이 끝난 것으로 본다
                if c == "." {
                    let next = i + 1 < chars.count ? chars[i + 1] : " "
                    if next == " " || next == "\n" {
                        flush(&parts, &buf)
                        i += 2   // 뒤따르는 공백은 버린다
                        continue
                    }
                }
            }
            i += 1
        }
        flush(&parts, &buf)

        if parts.count >= 2 { return parts }

        // 한 조각뿐이면 **한국어 연결어**로 한 번 더 갈라 본다.
        //
        // 웹 생성기 해설은 대부분 마침표가 문장 끝에만 있는 한 줄이라
        // (예: "$5^{3}=125$ 이므로 $\\sqrt[3]{125}=5$.") 위 규칙으로는 못 자른다.
        // 실측: 로컬 생성기가 있는 54개념 2160문항 중 단계 2개 이상은 4.5% 뿐이었다.
        // 그러면 "갈라진 단계 짚기"·"풀이 다시 보기"·오답노트 재생이 전부
        // `steps.count >= 2` 조건에 걸려 그 경로에서만 통째로 사라진다(감사 적발).
        let joiners = ["이므로 ", "그러므로 ", "따라서 ", "so ", "즉 ", "→ ", "⇒ "]
        let one = parts.first ?? text
        for j in joiners where one.contains(j) {
            let split = one.components(separatedBy: j)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            // 연결어를 남겨야 문장이 말이 된다 — 뒤 조각 앞에 붙여 준다
            if split.count >= 2 {
                var out = [split[0]]
                out += split.dropFirst().map { j.trimmingCharacters(in: .whitespaces) + " " + $0 }
                return out
            }
        }
        return [one]
    }

    /// `앞의 두 식을 곱하면 R1 입니다. 여기에 F 를 곱하면 R2 이므로
    /// 상수항은 C 입니다.` 꼴을 원문 수식 그대로 다섯 의미 단계로 펼친다.
    private static func splitProductChainNormalForm(_ text: String) -> [String]? {
        let pattern = #"^앞의 두 식을 곱하면\s+(.+?)\s+입니다\.\s*여기에\s+(.+?)\s+를 곱하면\s+(.+?)\s+이므로\s+상수항은\s+(.+?)\s+입니다\.?$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(
                in: text,
                range: NSRange(text.startIndex..., in: text)
              ),
              match.numberOfRanges == 5 else { return nil }

        let captures = (1..<5).compactMap { index -> String? in
            guard let range = Range(match.range(at: index), in: text) else { return nil }
            return String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard captures.count == 4, captures.allSatisfy({ !$0.isEmpty }) else { return nil }

        return [
            "앞의 두 식을 곱합니다.",
            "첫 번째 곱의 결과는 \(captures[0]) 입니다.",
            "여기에 \(captures[1]) 를 곱합니다.",
            "두 번째 곱의 결과는 \(captures[2]) 입니다.",
            "따라서 상수항은 \(captures[3]) 입니다.",
        ]
    }

    private static func flush(_ parts: inout [String], _ buf: inout String) {
        let piece = buf.trimmingCharacters(in: .whitespacesAndNewlines)
        if !piece.isEmpty { parts.append(piece) }
        buf = ""
    }
}
