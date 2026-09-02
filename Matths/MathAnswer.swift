//  MathAnswer.swift
//  Matths
//
//  수학 답안 동치 판정 — **레포 `services/mathAnswerService.js` 의 1:1 포팅**이다.
//
//  왜 옮겨 왔나: 앱은 여기 없던 시절 두 곳에서 각자 채점했다.
//    · ProblemGenerator.matchesFreeform — 공백 제거 + '=' 뒤만 남기기 + 정수 분수 비교
//    · AssessmentV2.isCorrect          — 쉼표 목록 + scalarEqual
//  둘 다 파서가 없어서 `sqrt(2)`, `2\pi`, `3^2`, `(1+2)/3`, `2√3` 같은 답이
//  전부 오답으로 처리됐다. **같은 학생 답이 웹에서는 정답, 앱에서는 오답**이 됐다.
//  게다가 두 곳의 규칙이 서로 달라서, 개념연습과 평가가 서로 다른 판정을 했다.
//
//  그래서 판정은 이 파일 하나로 모은다. 규칙을 바꿔야 하면 **레포를 먼저 바꾸고**
//  여기로 옮겨 온다. 여기서 먼저 고치면 또 갈라진다.
//
//  포팅 시 주의한 것:
//   · 쉼표 구분자는 `[;，]` 두 문자 모두 — 앱은 전각 세미콜론(U+FF1B)을 쓰고 있어
//     웹의 ASCII ';' 와 어긋나 있었다.
//   · 허용오차는 **상대 오차** max(1e-7, |기대값|×1e-7). 절대 1e-9 가 아니다.
//   · 유니코드 마이너스(U+2212)를 반드시 ASCII '-' 로 바꾼다.

import Foundation

enum MathAnswer {

    // MARK: - 1) 표현 정규화 (normalizeExpressionSource)

    /// LaTeX·유니코드 수식 표기를 계산 가능한 ASCII 표현으로 바꾼다.
    static func normalizeExpressionSource(_ value: String) -> String {
        var s = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        // \( … \) 와 $ … $ 껍데기를 벗긴다
        s = regexReplace(s, #"^\s*\\\((.*)\\\)\s*$"#, "$1")
        s = regexReplace(s, #"^\s*\$(.*)\$\s*$"#, "$1")

        s = s.replacingOccurrences(of: "−", with: "-")     // U+2212
        s = regexReplace(s, "[×·]", "*")
        s = s.replacingOccurrences(of: "÷", with: "/")
        s = regexReplace(s, #"\\(?:times|cdot)"#, "*")
        s = s.replacingOccurrences(of: "\\div", with: "/")
        s = s.replacingOccurrences(of: "\\pi", with: "pi")
        s = s.replacingOccurrences(of: "π", with: "pi")
        s = regexReplace(s, #"\s+"#, "")

        // 안쪽부터 유한 횟수로 정리한다 (중첩이 깊은 식은 답안 형식으로 쓰지 않는다)
        for _ in 0..<6 {
            var next = s
            next = regexReplace(next, #"\\frac\{([^{}]+)\}\{([^{}]+)\}"#, "(($1)/($2))")
            next = regexReplace(next, #"\\sqrt\{([^{}]+)\}"#, "sqrt($1)")
            next = regexReplace(next, #"\\sqrt\[3\]\{([^{}]+)\}"#, "cbrt($1)")
            if next == s { break }
            s = next
        }

        s = regexReplace(s, #"∛\(([^()]*)\)"#, "cbrt($1)")
        s = regexReplace(s, #"√\(([^()]*)\)"#, "sqrt($1)")
        s = regexReplace(s, #"∛(-?\d+(?:\.\d+)?)"#, "cbrt($1)")
        s = regexReplace(s, #"√(-?\d+(?:\.\d+)?)"#, "sqrt($1)")
        s = regexReplace(s, #"\bsqrt\{([^{}]+)\}"#, "sqrt($1)")
        s = regexReplace(s, #"\bcbrt\{([^{}]+)\}"#, "cbrt($1)")
        // 숫자 사이의 x 는 곱셈 기호로 (2x3 → 2*3)
        s = regexReplace(s, #"(?<=[0-9.)])x(?=[0-9.(+-])"#, "*")

        return s
    }

    // MARK: - 2) 토크나이저

    private enum Token: Equatable {
        case number(Double)
        case name(String)      // sqrt · cbrt · pi
        case op(Character)     // + - * / ^
        case paren(Character)  // ( )
    }

    private static func tokenize(_ source: String) -> [Token]? {
        var tokens: [Token] = []
        let chars = Array(source)
        var i = 0

        while i < chars.count {
            let rest = String(chars[i...])

            if let m = firstMatch(rest, #"^(?:\d+(?:\.\d*)?|\.\d+)(?:e[+-]?\d+)?"#),
               let v = Double(m) {
                tokens.append(.number(v))
                i += m.count
                continue
            }
            if let m = firstMatch(rest, #"^(sqrt|cbrt|pi)"#) {
                tokens.append(.name(m))
                i += m.count
                continue
            }

            let c = chars[i]
            if "+-*/^".contains(c) { tokens.append(.op(c)); i += 1; continue }
            if "()".contains(c)    { tokens.append(.paren(c)); i += 1; continue }

            return nil     // 아는 글자가 아니다 → 수식으로 못 읽는다
        }
        return tokens
    }

    // MARK: - 3) 재귀 하강 파서

    /// 문자열을 수로 계산한다. 계산할 수 없으면 nil.
    /// 우선순위: 단항 ± → 거듭제곱(우결합) → 곱·나눗셈(암시적 곱 포함) → 덧·뺄셈
    static func parseNumericExpression(_ value: String) -> Double? {
        guard let tokens = tokenize(normalizeExpressionSource(value)), !tokens.isEmpty
        else { return nil }

        var cursor = 0
        func peek() -> Token? { cursor < tokens.count ? tokens[cursor] : nil }
        func consume() -> Token? {
            guard cursor < tokens.count else { return nil }
            defer { cursor += 1 }
            return tokens[cursor]
        }
        /// 다음 토큰이 새 항의 시작인가 — 암시적 곱(2pi, 3(x+1)) 판정에 쓴다
        func startsPrimary(_ t: Token?) -> Bool {
            switch t {
            case .number, .name:     return true
            case .paren(let c):      return c == "("
            default:                 return false
            }
        }

        struct ParseError: Error {}

        func parseExpression() throws -> Double {
            var left = try parseTerm()
            while case .op(let c)? = peek(), c == "+" || c == "-" {
                _ = consume()
                let right = try parseTerm()
                left = (c == "+") ? left + right : left - right
            }
            return left
        }

        func parseTerm() throws -> Double {
            var left = try parsePower()
            while true {
                let t = peek()
                var explicit = false
                var opChar: Character = "*"
                if case .op(let c)? = t, c == "*" || c == "/" { explicit = true; opChar = c }
                let implicit = startsPrimary(t)
                if !explicit && !implicit { break }
                if explicit { _ = consume() }
                let right = try parsePower()
                left = (explicit && opChar == "/") ? left / right : left * right
            }
            return left
        }

        func parsePower() throws -> Double {
            let left = try parseUnary()
            if case .op(let c)? = peek(), c == "^" {
                _ = consume()
                return pow(left, try parsePower())   // 우결합
            }
            return left
        }

        func parseUnary() throws -> Double {
            if case .op(let c)? = peek(), c == "+" || c == "-" {
                _ = consume()
                let v = try parseUnary()
                return c == "-" ? -v : v
            }
            return try parsePrimary()
        }

        func parsePrimary() throws -> Double {
            guard let token = consume() else { throw ParseError() }
            switch token {
            case .number(let v):
                return v
            case .name(let n) where n == "pi":
                return Double.pi
            case .name(let n) where n == "sqrt" || n == "cbrt":
                guard case .paren("(")? = consume() else { throw ParseError() }
                let inner = try parseExpression()
                guard case .paren(")")? = consume() else { throw ParseError() }
                if n == "sqrt" {
                    guard inner >= 0 else { throw ParseError() }   // 실수 범위 밖
                    return inner.squareRoot()
                }
                return cbrt(inner)
            case .paren("("):
                let inner = try parseExpression()
                guard case .paren(")")? = consume() else { throw ParseError() }
                return inner
            default:
                throw ParseError()
            }
        }

        do {
            let result = try parseExpression()
            // 토큰을 다 쓰지 않았거나 값이 유한하지 않으면 실패로 본다
            guard cursor == tokens.count, result.isFinite else { return nil }
            return result
        } catch {
            return nil
        }
    }

    // MARK: - 4) 문자열 정규화 · 동치 판정

    static func normalizeAnswerText(_ value: String) -> String {
        var s = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        s = s.replacingOccurrences(of: "−", with: "-")
        // **두 종류의 구분자를 모두 쉼표로.** 앱은 전각 세미콜론만 처리해
        // 웹(ASCII ';')과 어긋나 있었다.
        s = regexReplace(s, "[;，]", ",")
        s = regexReplace(s, #"\s+"#, "")
        return s
    }

    /// 기대 답과 제출 답이 같은가. 채점은 **여기 한 곳**에서만 한다.
    static func answersEquivalent(_ expected: String, _ submitted: String) -> Bool {
        let e = normalizeAnswerText(expected)
        let s = normalizeAnswerText(submitted)

        // 쉼표 목록이면 원소별로 재귀 비교 (개수까지 같아야 한다)
        if e.contains(",") || s.contains(",") {
            let ep = e.components(separatedBy: ",")
            let sp = s.components(separatedBy: ",")
            guard ep.count == sp.count else { return false }
            return zip(ep, sp).allSatisfy { answersEquivalent($0, $1) }
        }

        if let en = parseNumericExpression(e), let sn = parseNumericExpression(s) {
            // **상대 오차**다. 절대 오차로 두면 큰 수에서 정답이 오답이 된다.
            return abs(en - sn) <= max(1e-7, abs(en) * 1e-7)
        }

        return e == s
    }

    // MARK: - 정규식 도우미

    private static var cache: [String: NSRegularExpression] = [:]
    private static let lock = NSLock()

    private static func regex(_ pattern: String) -> NSRegularExpression? {
        lock.lock(); defer { lock.unlock() }
        if let r = cache[pattern] { return r }
        guard let r = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators])
        else { return nil }
        cache[pattern] = r
        return r
    }

    private static func regexReplace(_ s: String, _ pattern: String, _ template: String) -> String {
        guard let r = regex(pattern) else { return s }
        return r.stringByReplacingMatches(
            in: s, range: NSRange(s.startIndex..., in: s), withTemplate: template)
    }

    private static func firstMatch(_ s: String, _ pattern: String) -> String? {
        guard let r = regex(pattern),
              let m = r.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)),
              let range = Range(m.range, in: s)
        else { return nil }
        return String(s[range])
    }
}
