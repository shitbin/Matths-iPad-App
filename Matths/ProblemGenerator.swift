//  ProblemGenerator.swift
//  Matths
//
//  동적 문제 생성 엔진 — AI 호출 없이 기기 안에서 돈다.
//
//  웹 데모의 exam-bank.js(69종 생성기)와 같은 원리의 Swift 판이다:
//  유형마다 수치를 파라미터로 두고, 시드 난수로 뽑아서
//  발제문·정답·오답 선지·풀이 단계를 전부 그 자리에서 계산한다.
//
//  왜 시드 난수인가:
//   - 같은 시드 → 같은 문제. 재접속·이의제기 때 그 회차를 그대로 재현할 수 있다.
//   - 다른 시드 → 다른 수치·다른 정답. "새 회차" 버튼이 실제로 새 시험을 만든다.
//   - 서버 없이도, AI 없이도, 비행기 모드에서도 돈다. 비용이 0이다.
//
//  Pro 사진 채점과의 연결:
//   시험지 사진에서 틀린 유형이 나오면 그 유형 키로 이 엔진을 돌려
//   비슷한 문제로만 구성된 새 모의고사를 즉석에서 만든다.

import Foundation

// MARK: - 시드 난수 (SplitMix64)
//
// 시스템 RNG 는 시드를 지정할 수 없어 재현이 안 된다.
// SplitMix64 는 8줄짜리 검증된 알고리즘이고, 이 용도(문제 수치 뽑기)에 충분하다.

struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// 닫힌 구간에서 하나 뽑기
    mutating func pick(_ range: ClosedRange<Int>) -> Int {
        Int.random(in: range, using: &self)
    }

    mutating func choose<T>(_ array: [T]) -> T {
        array[pick(0...(array.count - 1))]
    }
}

// MARK: - 생성된 문제

struct GeneratedProblem: Identifiable {
    let id: String
    let typeKey: String        // 유형 키 — Pro 채점의 "틀린 유형" 과 연결된다
    let typeName: String       // 사람이 읽는 유형 이름
    let unit: String           // 과목 · 단원
    let statement: String      // 발제문 (수치가 매번 다르다)
    let answer: String         // 정답 (수치에서 계산됨). 선지형은 정답 key("a"~"e")
    let steps: [String]        // 모범 풀이 단계 — 채점 결과 화면에 쓴다
    let minutes: Int           // 예상 소요
    // ── 뱅크(exam-bank.js) 문항용 — 네이티브 생성기는 기본값 그대로 ──
    var choices: [String]? = nil   // 5지선다 텍스트 (KaTeX 포함 가능)
    var isTex: Bool = false        // 발제문에 $...$ 수식 → 웹뷰로 렌더
    // ── 웹 로컬 생성기(WebGen) 문항용 — 복습 시각 힌트의 원천 ──
    var hintText: String? = nil            // 힌트 문장 (\( \) 수식 포함 가능)
    var visualizationJSON: String? = nil   // kind별 SVG 작도 파라미터 (원본 JSON)

    var isMultipleChoice: Bool { choices != nil }

    /// 서버의 오래된 오답 행에는 `isTex`가 없거나 false인데 발문은 이미
    /// `\(...\)`/`\[...\]`/`$...$` 수식을 담은 경우가 있다. 저장 플래그만 믿으면
    /// 복습 화면이 LaTeX 원문을 그대로 노출하므로 표시할 때는 내용도 함께 판정한다.
    /// 선지가 있는 문항은 선지 렌더러까지 필요하므로 항상 WebView 경로를 쓴다.
    var needsMathTypesetting: Bool {
        if isTex || isMultipleChoice { return true }
        let candidates = [statement] + steps
        return candidates.contains { text in
            text.contains("\\(") ||
                text.contains("\\[") ||
                text.contains("$")
        }
    }

    /// 학생 입력과 정답 비교.
    ///
    /// **판정은 MathAnswer 한 곳에서만 한다.** 여기 있던 자체 구현은 지웠다 —
    /// 파서가 없어 `sqrt(2)`·`2\pi`·`3^2` 가 전부 오답이었고, 유니코드 마이너스를
    /// 정규화하지 않아 음수 답이 틀렸으며, 분수 비교가 정수 전용이었다.
    /// 게다가 평가(AssessmentV2)와 규칙이 서로 달라 같은 답이 화면마다 다르게 채점됐다.
    func matches(_ input: String) -> Bool {
        if isMultipleChoice {
            // 선지형은 웹도 key 완전 일치다
            return input.trimmingCharacters(in: .whitespaces).lowercased() == answer.lowercased()
        }
        return MathAnswer.answersEquivalent(answer, input)
    }
}

// MARK: - 유형별 생성기

enum ProblemType: String, CaseIterable {
    case extremum    = "calc-extremum"      // 미적분 · 극값
    case logEq       = "alg-log-equation"   // 대수 · 로그방정식
    case counting    = "prob-counting"      // 확통 · 순열과 조합
    case integral    = "calc-integral"      // 미적분 · 정적분
    case seqBlockSum = "seq-block-sum"      // 대수 · 주기 수열의 합
    //  ↑ 실물 시험지 분석(skill/golden/page3)에서 학생이 개념 오류로 틀린
    //    바로 그 유형. 원 문제의 구조(3주기 블록, Σ₁ⁿ = Σ₁³ⁿ)를 그대로
    //    파라미터화했다 — p = 10 이면 원 문제와 동일하고 정답이 29 가 된다.
    case quadDisc    = "alg-quad-disc"      // 공통수학1 · 판별식
    case vieta       = "alg-vieta"          // 공통수학1 · 근과 계수
    case circleDist  = "geo-circle-dist"    // 공통수학2 · 원과 점의 거리
    case diceProb    = "prob-dice"          // 확통 · 확률의 계산
    case expLaw      = "alg-exp-law"        // 대수 · 지수법칙
    case polyExpand  = "alg-poly-expand"    // 공통수학1 · 다항식의 전개
    case complexMul  = "alg-complex-mul"    // 공통수학1 · 복소수의 곱
    case statMean    = "stat-expectation"   // 확통 · 기댓값의 성질
    case statVar     = "stat-variance"      // 확통 · 분산의 성질 (실물 시험지 오류 유형!)
    case statBinom   = "stat-binomial"      // 확통 · 이항분포
    case statNormal  = "stat-standardize"   // 확통 · 정규분포 표준화
    case statSample  = "stat-sample-mean"   // 확통 · 표본평균의 분포

    var name: String {
        switch self {
        case .extremum:    return "삼차함수의 극값"
        case .logEq:       return "로그방정식"
        case .counting:    return "순열과 조합"
        case .integral:    return "정적분 계산"
        case .seqBlockSum: return "주기 수열의 합"
        case .quadDisc:    return "이차방정식의 판별식"
        case .vieta:       return "근과 계수의 관계"
        case .circleDist:  return "원과 점의 거리"
        case .diceProb:    return "확률의 계산"
        case .expLaw:      return "지수법칙"
        case .polyExpand:  return "다항식의 전개"
        case .complexMul:  return "복소수의 곱셈"
        case .statMean:    return "기댓값의 성질"
        case .statVar:     return "분산의 성질"
        case .statBinom:   return "이항분포의 평균과 분산"
        case .statNormal:  return "정규분포의 표준화"
        case .statSample:  return "표본평균의 분포"
        }
    }

    var unit: String {
        switch self {
        case .extremum:    return "미적분Ⅰ · 도함수의 활용"
        case .logEq:       return "대수 · 지수함수와 로그함수"
        case .counting:    return "확률과 통계 · 순열과 조합"
        case .integral:    return "미적분Ⅰ · 정적분"
        case .seqBlockSum: return "대수 · 수열의 합"
        case .quadDisc:    return "공통수학1 · 방정식과 부등식"
        case .vieta:       return "공통수학1 · 방정식과 부등식"
        case .circleDist:  return "공통수학2 · 도형의 방정식"
        case .diceProb:    return "확률과 통계 · 확률"
        case .expLaw:      return "대수 · 지수와 로그"
        case .polyExpand:  return "공통수학1 · 다항식"
        case .complexMul:  return "공통수학1 · 방정식과 부등식"
        case .statMean, .statVar, .statBinom, .statNormal, .statSample:
            return "확률과 통계 · 통계"
        }
    }

    /// 수치를 뽑아 문제 하나를 조립한다. 모든 수치·정답·풀이가 여기서 계산된다.
    func generate(rng: inout SeededRNG, index: Int) -> GeneratedProblem {
        switch self {
        case .extremum:
            // f(x) = x³ + px² + qx 가 x = a 에서 극대, x = b 에서 극소.
            // f'(x) = 3x² + 2px + q 의 두 근이 a, b 이므로
            //   a + b = -2p/3  →  p = -3(a+b)/2   (a+b 를 짝수로 뽑아 p 를 정수로)
            //   ab    = q/3    →  q = 3ab
            // 수치 폭 (2026-08-16): 종전 a ∈ -4...-1, b ∈ 1...4 는 p, q 가 한 자리라
            // 학생이 근과 계수 관계를 세우지 않고 암산으로 답을 찍었다. 실전 난도가 아니다.
            // a, b 를 넓혀도 p = -3(a+b)/2 는 합을 짝수로 맞추므로 정수로 남고,
            // q = 3ab 도 정수다 — 답의 정수성이 깨지지 않는 범위에서만 넓힌다.
            let a = rng.pick((-9)...(-1))
            var b = rng.pick(1...9)
            if (a + b) % 2 != 0 { b += 1 }          // 합을 짝수로
            if b <= a { b = a + 2 }
            let p = -3 * (a + b) / 2
            let q = 3 * a * b
            let answer = p + q
            return GeneratedProblem(
                id: "\(rawValue)-\(index)",
                typeKey: rawValue, typeName: name, unit: unit,
                statement: "함수 f(x) = x³\(term(p, "x²"))\(term(q, "x")) 가 "
                    + "x = \(a) 에서 극대, x = \(b) 에서 극소가 될 때, "
                    + "상수 p, q 에 대하여 p + q 의 값을 구하시오.",
                answer: "\(answer)",
                steps: [
                    "f'(x) = 3x² \(signed(2 * p))x \(signed(q))",
                    "극값 조건에서 f'(\(a)) = 0, f'(\(b)) = 0 이므로 두 근이 \(a), \(b)",
                    "근과 계수: \(a) + \(b) = -2p/3 이므로 p = \(p)",
                    "\(a) × \(b) = q/3 이므로 q = \(q)",
                    "p + q = \(answer)",
                ],
                minutes: 5,
                visualizationJSON: vizJSON(["kind": "swift-cubic-extremum", "p": p, "q": q, "a": a, "b": b, "answer": answer])
            )

        case .logEq:
            // log_b (x - c) = k  →  x = bᵏ + c
            // c 를 두 자리로 넓힌다. 종전 1...9 는 bᵏ 를 계산하고 한 자리를 더하는 것으로
            // 끝나 암산으로 처리됐다. x = bᵏ + c 는 c 가 커져도 정수 그대로다.
            // base·k 는 건드리지 않는다 — 넓히면 진수가 네 자리를 넘어 계산이 아니라
            // 노가다가 된다(난이도가 아니라 피로도만 올라간다).
            let base = rng.choose([2, 3, 5])
            let k = rng.pick(2...4)
            let c = rng.pick(11...49)
            let x = ipow(base, k) + c
            return GeneratedProblem(
                id: "\(rawValue)-\(index)",
                typeKey: rawValue, typeName: name, unit: unit,
                statement: "방정식 log\(sub(base))(x − \(c)) = \(k) 를 만족하는 x 의 값을 구하시오.",
                answer: "\(x)",
                steps: [
                    "로그의 정의: log\(sub(base))A = \(k) ⇔ A = \(base)^\(k)",
                    "진수를 통째로 두면 x − \(c) = \(base)^\(k)",
                    "\(base)^\(k) = \(ipow(base, k))",
                    "x = \(ipow(base, k)) + \(c) = \(x)",
                    "진수 조건 확인: x − \(c) = \(ipow(base, k)) > 0 성립",
                ],
                minutes: 3,
                visualizationJSON: vizJSON(["kind": "swift-log-equation", "base": base, "k": k, "c": c, "x": x])
            )

        case .counting:
            // 서로 다른 n 명 중 r 명을 뽑아 나열(순열) 또는 뽑기만(조합)
            // n 을 두 자리까지 올린다. 종전 5...9 는 nC2 · nC3 가 외워 둔 값이라
            // 학생이 공식을 쓰지 않고 답했다. 상한 10 은 의도적이다 —
            // 10P5 = 30240 까지가 손으로 셈이 되는 한계이고, 그 위는 계산기 문제가 된다.
            let n = rng.pick(6...10)
            let r = rng.pick(2...5)
            let isPerm = rng.pick(0...1) == 1
            let answer = isPerm ? perm(n, r) : comb(n, r)
            let action = isPerm ? "뽑아 일렬로 세우는" : "뽑는"
            let formula = isPerm ? "\(n)P\(r)" : "\(n)C\(r)"
            return GeneratedProblem(
                id: "\(rawValue)-\(index)",
                typeKey: rawValue, typeName: name, unit: unit,
                statement: "서로 다른 \(n)명의 학생 중 \(r)명을 \(action) 경우의 수를 구하시오.",
                answer: "\(answer)",
                steps: isPerm
                    ? [
                        "판별: '일렬로 세운다' → 뽑은 뒤 순서까지 정한다",
                        "순서가 있으므로 순열 \(formula) 을 쓴다",
                        "\(formula) = \(permExpansion(n, r))",
                        "곱하면 \(perm(n, r))",
                        "답: \(answer)가지",
                      ]
                    : [
                        "판별: '뽑는다' 만 있고 순서 언급이 없다 → 순서 무시",
                        "순서가 없으므로 조합 \(formula) 을 쓴다",
                        "\(formula) = \(permExpansion(n, r)) / \(r)!",
                        "분자 \(perm(n, r)), 분모 \(r)! = \((1...r).reduce(1, *))",
                        "나누면 \(answer). 답: \(answer)가지",
                      ],
                minutes: 3,
                visualizationJSON: vizJSON(["kind": "swift-counting", "n": n, "r": r, "isPerm": isPerm, "answer": answer])
            )

        case .integral:
            // ∫₀ᵃ (2x + b) dx = a² + ab
            // 종전 a ∈ 2...5, b ∈ 1...6 은 a² + ab 가 두 자리라 부정적분을 쓰지 않고
            // 답이 보였다. a 를 두 자리로 올리면 위끝 대입을 손으로 써야 한다.
            let a = rng.pick(4...14)
            let b = rng.pick(3...19)
            let answer = a * a + a * b
            return GeneratedProblem(
                id: "\(rawValue)-\(index)",
                typeKey: rawValue, typeName: name, unit: unit,
                statement: "정적분 ∫₀^\(a) (2x + \(b)) dx 의 값을 구하시오.",
                answer: "\(answer)",
                steps: [
                    "항별 적분 규칙: ∫2x dx = x², ∫\(b) dx = \(b)x",
                    "부정적분: ∫(2x + \(b))dx = x² + \(b)x + C",
                    "위끝 대입: x = \(a) 에서 \(a)² + \(b)·\(a) = \(a * a + a * b)",
                    "아래끝 대입: x = 0 에서 0",
                    "차를 구하면 \(a * a + a * b) − 0 = \(answer)",
                ],
                minutes: 3,
                visualizationJSON: vizJSON(["kind": "swift-definite-integral", "a": a, "b": b, "answer": answer])
            )

        case .seqBlockSum:
            // aₙ = p (n 이 3의 배수 아님), −q (3의 배수).  Σ₁ⁿ aₖ = Σ₁³ⁿ aₖ 인 자연수 n.
            //
            // q = 2p−1 로 두면 블록 [p, p, −q] 의 합이 1 → S₃ₙ = n.
            // n = 3k+2 꼴에서 Sₙ = k + 2p 이므로 k + 2p = 3k + 2 → k = p−1 → n = 3p−1.
            // p 를 짝수로 제한해야 n = 3k+1 꼴의 잉여해가 생기지 않는다 (2k = p−1 이 비정수).
            // p = 10 이면 실물 시험지의 원 문제와 완전히 같고 정답 29.
            let p = 2 * rng.pick(3...12)         // 6 ~ 24 (짝수 유지 — q = 2p-1 이 정수)
            let q = 2 * p - 1
            let answer = 3 * p - 1
            return GeneratedProblem(
                id: "\(rawValue)-\(index)",
                typeKey: rawValue, typeName: name, unit: unit,
                statement: "수열 {aₙ}이 모든 자연수 n 에 대하여 aₙ = \(p) (n 이 3의 배수가 아닌 경우), "
                    + "aₙ = −\(q) (n 이 3의 배수인 경우)이다. "
                    + "Σₖ₌₁ⁿ aₖ = Σₖ₌₁³ⁿ aₖ 를 만족시키는 자연수 n 의 값을 구하시오.",
                answer: "\(answer)",
                steps: [
                    "이 수열은 등차가 아니다 — 합 공식 대신 세 항씩 묶는다: [\(p), \(p), −\(q)]",
                    "블록 합 = \(p) + \(p) − \(q) = 1 이므로 S₃ₙ = n",
                    "n = 3k+2 꼴일 때 Sₙ = k + \(2 * p)",
                    "k + \(2 * p) = 3k + 2 → k = \(p - 1)",
                    "n = 3·\(p - 1) + 2 = \(answer)",
                ],
                minutes: 5,
                visualizationJSON: vizJSON(["kind": "swift-block-sum", "p": p, "q": q, "answer": answer])
            )

        case .quadDisc:
            // x² + bx + c = 0 이 서로 다른 두 실근 ⇔ D = b² − 4c > 0.
            // b 를 짝수로 뽑으면 경계 b²/4 가 정수 — 정수 c 의 최댓값은 b²/4 − 1.
            let b = 2 * rng.pick(3...11)         // 6 ~ 22 (짝수 유지 — b²/4 가 정수)
            let answer = (b * b) / 4 - 1
            return GeneratedProblem(
                id: "\(rawValue)-\(index)",
                typeKey: rawValue, typeName: name, unit: unit,
                statement: "이차방정식 x² + \(b)x + c = 0 이 서로 다른 두 실근을 가질 때, "
                    + "정수 c 의 최댓값을 구하시오.",
                answer: "\(answer)",
                steps: [
                    "서로 다른 두 실근 ⇔ 판별식 D > 0",
                    "D = \(b)² − 4c = \(b * b) − 4c",
                    "\(b * b) − 4c > 0 → c < \(b * b)/4 = \((b * b) / 4)",
                    "c 는 정수이므로 최댓값은 \((b * b) / 4) − 1",
                    "답: \(answer)",
                ],
                minutes: 4,
                visualizationJSON: vizJSON(["kind": "swift-quad-disc", "b": b, "bound": (b * b) / 4, "answer": answer])
            )

        case .vieta:
            // x² − Sx + P = 0 의 두 근 α, β 에 대해 α² + β² = S² − 2P
            // 수치 폭 (2026-08-16): 종전 S ∈ 3...7, P ∈ 1...6 은 S² − 2P 가 두 자리라
            // 근과 계수 관계를 세우지 않고 암산으로 답이 나왔다.
            // S 를 두 자리로 올리면 S² 가 세 자리가 되어 손으로 써야 한다.
            // 판별식 S² − 4P ≥ 0 을 지켜 "두 근" 이라는 발제문과 어긋나지 않게 한다.
            let s = rng.pick(7...23)
            let p = rng.pick(3...max(4, (s * s) / 4))
            let answer = s * s - 2 * p
            return GeneratedProblem(
                id: "\(rawValue)-\(index)",
                typeKey: rawValue, typeName: name, unit: unit,
                statement: "이차방정식 x² − \(s)x + \(p) = 0 의 두 근을 α, β 라 할 때, "
                    + "α² + β² 의 값을 구하시오.",
                answer: "\(answer)",
                steps: [
                    "근과 계수: α + β = \(s), αβ = \(p)",
                    "곱셈공식 변형: α² + β² = (α+β)² − 2αβ",
                    "= \(s)² − 2·\(p)",
                    "= \(s * s) − \(2 * p)",
                    "답: \(answer)",
                ],
                minutes: 4,
                visualizationJSON: vizJSON(["kind": "swift-vieta", "s": s, "p": p, "answer": answer])
            )

        case .circleDist:
            // 중심 원점 · 반지름 r 원과 점 (a, b) 의 최단거리 = √(a²+b²) − r.
            // 피타고라스 트리플로 뽑아 거리가 정수가 되게 한다.
            // 큰 트리플을 더한다. 3-4-5 와 6-8-10 만 나오면 학생이 값을 외워 버려
            // 피타고라스를 세우지 않는다. 어느 트리플이든 거리는 정수로 남는다.
            let triple = rng.choose([(3, 4, 5), (6, 8, 10), (5, 12, 13), (9, 12, 15),
                                     (8, 15, 17), (7, 24, 25), (20, 21, 29), (12, 35, 37)])
            let r = rng.pick(1...(triple.2 - 1))
            let answer = triple.2 - r
            return GeneratedProblem(
                id: "\(rawValue)-\(index)",
                typeKey: rawValue, typeName: name, unit: unit,
                statement: "중심이 원점이고 반지름이 \(r) 인 원 위의 점과 "
                    + "점 P(\(triple.0), \(triple.1)) 사이 거리의 최솟값을 구하시오.",
                answer: "\(answer)",
                steps: [
                    "원 위의 점과의 최단거리 = (중심까지 거리) − (반지름)",
                    "중심(원점)에서 P 까지: √(\(triple.0)² + \(triple.1)²)",
                    "= √\(triple.0 * triple.0 + triple.1 * triple.1) = \(triple.2)",
                    "P 는 원 밖(\(triple.2) > \(r))이므로 그대로 뺀다",
                    "최솟값 = \(triple.2) − \(r) = \(answer)",
                ],
                minutes: 4,
                visualizationJSON: vizJSON(["kind": "swift-circle-dist", "px": triple.0, "py": triple.1, "dist": triple.2, "r": r, "answer": answer])
            )

        case .diceProb:
            // 주사위 두 개의 합이 s 가 될 확률 — 분모 36 고정, 분자는 경우의 수
            // 종전 5...9 는 경우의 수가 4,5,6,5,4 뿐이라 표를 외운 학생이 바로 답했다.
            // 2...12 전 구간으로 넓혀도 분모는 36 그대로라 답이 지저분해지지 않는다.
            let s = rng.pick(2...12)
            let count = 6 - abs(7 - s)           // 합 s 의 경우의 수: 7에서 멀수록 준다
            return GeneratedProblem(
                id: "\(rawValue)-\(index)",
                typeKey: rawValue, typeName: name, unit: unit,
                statement: "서로 다른 두 개의 주사위를 동시에 던질 때, "
                    + "나온 눈의 합이 \(s) 가 될 확률을 구하시오. (기약분수가 아니어도 됩니다 — n/36 꼴 가능)",
                answer: "\(count)/36",
                steps: [
                    "전체 경우의 수: 6 × 6 = 36 (같은 확률)",
                    "합이 \(s) 인 순서쌍을 센다",
                    "(\(max(1, s - 6)), \(min(6, s - 1))) 부터 차례로 — 모두 \(count)가지",
                    "확률 = (원하는 경우) / (전체) = \(count)/36",
                    "답: \(count)/36",
                ],
                minutes: 3,
                visualizationJSON: vizJSON(["kind": "swift-dice", "target": s, "count": count])
            )

        case .expLaw:
            // (a^m × a^n) ÷ a^p = a^(m+n−p) — 지수법칙 3종 한 줄에
            let a = rng.pick(2...3)
            let m = rng.pick(2...4)
            let n = rng.pick(2...4)
            let p = rng.pick(1...(m + n - 2))    // 지수가 2 이상 남게
            let e = m + n - p
            let answer = ipow(a, e)
            return GeneratedProblem(
                id: "\(rawValue)-\(index)",
                typeKey: rawValue, typeName: name, unit: unit,
                statement: "(\(a)^\(m) × \(a)^\(n)) ÷ \(a)^\(p) 의 값을 구하시오.",
                answer: "\(answer)",
                steps: [
                    "곱은 지수의 합: \(a)^\(m) × \(a)^\(n) = \(a)^\(m + n)",
                    "나눗셈은 지수의 차: \(a)^\(m + n) ÷ \(a)^\(p) = \(a)^\(m + n)⁻\(p)",
                    "지수 정리: \(m + n) − \(p) = \(e)",
                    "\(a)^\(e) 을 계산한다",
                    "답: \(answer)",
                ],
                minutes: 3,
                visualizationJSON: vizJSON(["kind": "swift-exp-law", "a": a, "m": m, "n": n, "p": p, "e": e, "answer": answer])
            )

        case .polyExpand:
            // (x + a)(x + b) 전개 — 강의 플레이그라운드(넓이 모델)와 같은 구조의 연습
            // 종전 1...6 은 곱이 구구단 범위라 전개하지 않고 답했다.
            let a = rng.pick(3...19)
            let b = rng.pick(3...19)
            let askLinear = rng.pick(0...1) == 1
            let answer = askLinear ? a + b : a * b
            return GeneratedProblem(
                id: "\(rawValue)-\(index)",
                typeKey: rawValue, typeName: name, unit: unit,
                statement: "(x + \(a))(x + \(b)) 를 전개했을 때 "
                    + (askLinear ? "x 의 계수를" : "상수항을") + " 구하시오.",
                answer: "\(answer)",
                steps: [
                    "전개는 넓이 4조각: x², \(a)x, \(b)x, \(a * b)",
                    "(x + \(a))(x + \(b)) = x² + (\(a) + \(b))x + \(a)·\(b)",
                    "x 의 계수 = 두 수의 합 = \(a + b)",
                    "상수항 = 두 수의 곱 = \(a * b)",
                    "답: \(answer)",
                ],
                minutes: 2,
                visualizationJSON: vizJSON(["kind": "swift-poly-expand", "a": a, "b": b, "askLinear": askLinear, "answer": answer])
            )

        case .complexMul:
            // (a + bi)(c + di) = (ac − bd) + (ad + bc)i — 실수부/허수부만 물어
            // 답이 정수가 되게 한다 (문자 답 입력 부담 제거)
            // 종전 1...4 는 네 곱이 전부 한 자리라 암산으로 끝났다.
            let a = rng.pick(3...14), b = rng.pick(3...14)
            let c = rng.pick(3...14), d = rng.pick(3...14)
            let re = a * c - b * d
            let im = a * d + b * c
            let askReal = rng.pick(0...1) == 1
            let answer = askReal ? re : im
            return GeneratedProblem(
                id: "\(rawValue)-\(index)",
                typeKey: rawValue, typeName: name, unit: unit,
                statement: "(\(a) + \(b)i)(\(c) + \(d)i) 를 계산했을 때 "
                    + (askReal ? "실수부를" : "허수부를") + " 구하시오.",
                answer: "\(answer)",
                steps: [
                    "전개: \(a * c) + \(a * d)i + \(b * c)i + \(b * d)i²",
                    "i² = −1 이므로 \(b * d)i² = −\(b * d)",
                    "실수부: \(a * c) − \(b * d) = \(re)",
                    "허수부: \(a * d) + \(b * c) = \(im)",
                    "답: \(answer)",
                ],
                minutes: 3,
                visualizationJSON: vizJSON(["kind": "swift-complex-mul", "a": a, "b": b, "c": c, "d": d, "re": re, "im": im, "askReal": askReal])
            )

        case .statMean:
            // E(aX + b) = aE(X) + b — 기댓값의 선형성
            // 종전 값은 곱이 한 자리라 선형성을 쓰지 않고 답이 보였다.
            let m = rng.pick(8...24)
            let a = rng.pick(3...12)
            let b = rng.pick(7...39)
            let answer = a * m + b
            return GeneratedProblem(
                id: "\(rawValue)-\(index)",
                typeKey: rawValue, typeName: name, unit: unit,
                statement: "확률변수 X 의 평균이 E(X) = \(m) 일 때, E(\(a)X + \(b)) 의 값을 구하시오.",
                answer: "\(answer)",
                steps: [
                    "기댓값은 선형이다: E(aX + b) = aE(X) + b",
                    "곱한 만큼 곱해지고, 더한 만큼 더해진다",
                    "E(\(a)X + \(b)) = \(a)·E(X) + \(b)",
                    "= \(a)·\(m) + \(b)",
                    "답: \(answer)",
                ],
                minutes: 3,
                visualizationJSON: vizJSON(["kind": "swift-stat-linear", "mode": "mean", "base": m, "a": a, "b": b, "answer": answer])
            )

        case .statVar:
            // V(aX + b) = a²V(X) — 실물 시험지에서 학생이 V(3X+1) 을 틀렸던 그 성질.
            // b 는 흩어짐을 바꾸지 않는다 — 이게 이 유형의 급소다.
            // b 를 같이 키우는 이유: b 는 답에 안 들어가는 미끼인데 한 자리로 두면
            // 눈에 안 띄어 "b 를 더하지 않는다" 는 이 유형의 급소가 시험되지 않는다.
            let v = rng.pick(6...24)
            let a = rng.pick(3...11)
            let b = rng.pick(7...39)
            let answer = a * a * v
            return GeneratedProblem(
                id: "\(rawValue)-\(index)",
                typeKey: rawValue, typeName: name, unit: unit,
                statement: "확률변수 X 의 분산이 V(X) = \(v) 일 때, V(\(a)X + \(b)) 의 값을 구하시오.",
                answer: "\(answer)",
                steps: [
                    "분산은 흩어짐이다 — 상수를 더해도(+\(b)) 흩어짐은 그대로",
                    "상수배는 제곱으로 커진다: V(aX + b) = a²V(X)",
                    "V(\(a)X + \(b)) = \(a)² · V(X)",
                    "= \(a * a) · \(v)",
                    "답: \(answer) (b 가 사라진 것을 확인하라)",
                ],
                minutes: 3,
                visualizationJSON: vizJSON(["kind": "swift-stat-linear", "mode": "variance", "base": v, "a": a, "b": b, "answer": answer])
            )

        case .statBinom:
            // X ~ B(n, num/den): E = n·num/den, V = n·num(den−num)/den².
            // n = den²·m 으로 뽑아 둘 다 정수가 되게 한다.
            let (num, den) = rng.choose([(1, 2), (1, 3), (2, 3), (1, 4)])
            // m 을 키워도 n = den²·m 이라 E = n·num/den, V = n·num(den−num)/den² 가
            // 둘 다 정수로 남는다. 종전 1...3 은 n 이 최대 48 이라 암산 범위였다.
            let m = rng.pick(2...6)
            let n = den * den * m
            let askMean = rng.pick(0...1) == 1
            let mean = n * num / den
            let variance = m * num * (den - num)
            let answer = askMean ? mean : variance
            return GeneratedProblem(
                id: "\(rawValue)-\(index)",
                typeKey: rawValue, typeName: name, unit: unit,
                statement: "확률변수 X 가 이항분포 B(\(n), \(num)/\(den)) 을 따를 때, "
                    + (askMean ? "E(X)" : "V(X)") + " 의 값을 구하시오.",
                answer: "\(answer)",
                steps: [
                    "이항분포 B(n, p): E(X) = np, V(X) = np(1−p)",
                    "n = \(n), p = \(num)/\(den), 1−p = \(den - num)/\(den)",
                    "E(X) = \(n)·\(num)/\(den) = \(mean)",
                    "V(X) = \(n)·\(num)/\(den)·\(den - num)/\(den) = \(variance)",
                    "답: \(answer)",
                ],
                minutes: 4,
                visualizationJSON: vizJSON(["kind": "swift-binomial", "n": n, "num": num, "den": den, "mean": mean, "variance": variance, "askMean": askMean])
            )

        case .statNormal:
            // X ~ N(m, σ²) 의 표준화: Z = (X − m)/σ. x₀ = m + kσ → Z = k.
            let mMean = rng.choose([50, 60, 64, 70])
            let sigma = rng.choose([4, 5, 8, 10])
            let k = rng.pick(1...3) * (rng.pick(0...1) == 1 ? 1 : -1)
            let x0 = mMean + k * sigma
            return GeneratedProblem(
                id: "\(rawValue)-\(index)",
                typeKey: rawValue, typeName: name, unit: unit,
                statement: "확률변수 X 가 정규분포 N(\(mMean), \(sigma)²) 을 따를 때, "
                    + "X = \(x0) 을 표준화한 Z 의 값을 구하시오.",
                answer: "\(k)",
                steps: [
                    "표준화: Z = (X − m)/σ — 평균을 빼고 표준편차로 나눈다",
                    "m = \(mMean), σ = \(sigma)",
                    "Z = (\(x0) − \(mMean)) / \(sigma)",
                    "= \(x0 - mMean) / \(sigma)",
                    "답: \(k) (X 가 평균에서 표준편차 \(abs(k))개만큼 \(k > 0 ? "위" : "아래"))",
                ],
                minutes: 3,
                visualizationJSON: vizJSON(["kind": "swift-normal", "mean": mMean, "sigma": sigma, "x0": x0, "z": k])
            )

        case .statSample:
            // 표본평균 X̄: E(X̄) = m, V(X̄) = σ²/n. n 을 σ² 의 약수 제곱수로.
            let (sigma, n) = rng.choose([(6, 4), (6, 9), (8, 16), (10, 4), (12, 9), (12, 16)])
            let mMean = rng.pick(40...60)
            let askMean = rng.pick(0...2) == 0        // 1/3 은 평균, 2/3 는 분산을 묻는다
            let variance = sigma * sigma / n
            let answer = askMean ? mMean : variance
            return GeneratedProblem(
                id: "\(rawValue)-\(index)",
                typeKey: rawValue, typeName: name, unit: unit,
                statement: "모평균 \(mMean), 모표준편차 \(sigma) 인 모집단에서 크기 \(n) 인 표본을 "
                    + "임의추출할 때, 표본평균 X̄ 의 " + (askMean ? "평균 E(X̄)" : "분산 V(X̄)")
                    + " 을 구하시오.",
                answer: "\(answer)",
                steps: [
                    "표본평균의 분포: E(X̄) = m (모평균 그대로)",
                    "V(X̄) = σ²/n — 많이 뽑을수록 흩어짐이 준다",
                    "E(X̄) = \(mMean)",
                    "V(X̄) = \(sigma)²/\(n) = \(sigma * sigma)/\(n) = \(variance)",
                    "답: \(answer)",
                ],
                minutes: 4,
                visualizationJSON: vizJSON(["kind": "swift-sample-mean", "mean": mMean, "sigma": sigma, "n": n, "variance": variance, "askMean": askMean])
            )
        }
    }
}

// MARK: - 시험 조립

enum ExamFactory {
    /// 유형 목록으로 모의고사 한 벌을 만든다. 같은 seed 는 항상 같은 시험을 만든다.
    static func make(types: [ProblemType], count: Int, seed: UInt64) -> [GeneratedProblem] {
        var rng = SeededRNG(seed: seed)
        return (0..<count).map { i in
            var t = types[i % types.count]
            // 유형 순서도 시드로 섞는다 — 항상 같은 순서로 나오면 유형을 외운다
            if types.count > 1 && rng.pick(0...2) == 0 { t = rng.choose(types) }
            return t.generate(rng: &rng, index: i)
        }
    }

    /// Pro 사진 채점 결과의 "틀린 유형" 으로 유사 문제 시험을 만든다.
    /// 시드는 호출 시점 기반 — 만들 때마다 새 수치가 나온다.
    static func similarExam(wrongTypes: [String], count: Int = 4,
                            seed: UInt64 = UInt64(Date().timeIntervalSince1970)) -> [GeneratedProblem] {
        let types = wrongTypes.compactMap(ProblemType.init(rawValue:))
        let fallback: [ProblemType] = types.isEmpty ? [.extremum, .logEq] : types
        return make(types: fallback, count: count, seed: seed)
    }
}

/// 유형별 풀이 안무 파라미터 — solution-scenes.js 가 이 값으로 같은 안무를 그린다.
/// 시드가 바뀌면 수치만 바뀌고 연출은 그대로다.
private func vizJSON(_ dict: [String: Any]) -> String? {
    (try? JSONSerialization.data(withJSONObject: dict))
        .flatMap { String(data: $0, encoding: .utf8) }
}

// MARK: - 계산 도우미

private func signed(_ n: Int) -> String { n < 0 ? "− \(-n)" : "+ \(n)" }

/// 다항식 항 표기 — 계수 0 은 항을 지우고, ±1 은 숫자를 지운다
private func term(_ c: Int, _ sym: String) -> String {
    switch c {
    case 0:  return ""
    case 1:  return " + \(sym)"
    case -1: return " − \(sym)"
    default: return c < 0 ? " − \(-c)\(sym)" : " + \(c)\(sym)"
    }
}

private func ipow(_ base: Int, _ exp: Int) -> Int {
    (0..<exp).reduce(1) { acc, _ in acc * base }
}

private func perm(_ n: Int, _ r: Int) -> Int {
    ((n - r + 1)...n).reduce(1, *)
}

private func comb(_ n: Int, _ r: Int) -> Int {
    perm(n, r) / (1...r).reduce(1, *)
}

private func permExpansion(_ n: Int, _ r: Int) -> String {
    ((n - r + 1)...n).reversed().map(String.init).joined(separator: " × ")
}

private func sub(_ n: Int) -> String {
    // 로그 밑 표기용 아래첨자
    let map: [Character: Character] = ["0": "₀", "1": "₁", "2": "₂", "3": "₃", "4": "₄",
                                       "5": "₅", "6": "₆", "7": "₇", "8": "₈", "9": "₉"]
    return String("\(n)".map { map[$0] ?? $0 })
}
