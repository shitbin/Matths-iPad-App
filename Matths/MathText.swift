//  MathText.swift
//  Matths
//
//  LaTeX 섞인 문자열의 두 가지 표현을 책임진다.
//   1. normalizeDelimiters — 웹 생성기(\( \) 표기)를 앱 KaTeX 규약($ $)으로.
//   2. plain — 목록 미리보기용 평문 근사. 완전한 수식 렌더는 KatexText(웹뷰)가 하고,
//      목록처럼 웹뷰를 줄줄이 못 까는 곳은 이 근사로 "깨진 백슬래시 원문" 노출을 막는다.

import Foundation

enum MathText {
    /// \( \) → $ $, \[ \] → $$ $$ (웹 MathJax 표기 → 앱 KaTeX 규약)
    ///
    /// 디스플레이 구분자 `\[ \]` 가 빠져 있어서, 웹 생성기 문항이 오답노트 목록에
    /// LaTeX 원문 그대로 노출됐다 — 18차에 고쳤던 증상의 남은 절반이다(감사 적발).
    /// 주의: replacingOccurrences 의 치환 문자열에서 "$$" 는 달러 한 개로 해석되지
    /// 않는다(그건 정규식 치환 이야기다) — 여기서는 리터럴 그대로 들어간다.
    static func normalizeDelimiters(_ s: String) -> String {
        s.replacingOccurrences(of: "\\(", with: "$")
         .replacingOccurrences(of: "\\)", with: "$")
         .replacingOccurrences(of: "\\[", with: "$$")
         .replacingOccurrences(of: "\\]", with: "$$")
    }

    /// 목록 미리보기용 평문 — LaTeX 명령을 읽을 수 있는 근사로 치환한다.
    /// 완벽할 필요 없다: 목적은 렌더가 아니라 "무슨 문제였는지 알아보게" 하는 것.
    static func plain(_ s: String) -> String {
        var t = normalizeDelimiters(s)
        // 수식 구분자는 지우지 않고 공백으로 바꾼다 — 붙여 지우면 절 경계가 사라져
        // "x≥ -1lim…", "3.10표를 보고" 처럼 조건식·표와 뒷문장이 한 덩어리가 된다
        // (감사 0354). 겹공백은 아래 정리 단계가 걷는다.
        t = t.replacingOccurrences(of: "$", with: " ")
        t = t.replacingOccurrences(of: "\\displaystyle", with: "")
        t = t.replacingOccurrences(of: "\\left", with: "")
        t = t.replacingOccurrences(of: "\\right", with: "")

        // ── 명령 치환은 **경계를 지켜서** 한다 ──────────────────────────
        //
        // 예전엔 문자열 치환이라 짧은 명령이 긴 명령의 앞부분을 먹었다:
        //   "x \\leq 3" → "x ≤q 3"      (\le 가 \leq 의 앞을 잘랐다)
        //   "a \\neq b"  → "a ≠q b"
        // 화면에 그대로 나오므로 학생 눈에는 그냥 깨진 글자다(2026-07-29 재현).
        // 뒤에 알파벳이 더 붙어 있으면 다른 명령이라는 뜻이니 건드리지 않는다.
        for (cmd, sym) in Self.symbolTable {
            t = regexReplace(t, "\\\\" + cmd + "(?![a-zA-Z])", with: sym)
        }
        // 간격 명령(\, \; \: \! \quad …)은 **지운다.** 알파벳이 아니라서
        // 아래 "백슬래시만 벗기기" 규칙에 안 걸리고 `|v(t)|\,dt` 처럼 남아 있었다.
        t = regexReplace(t, #"\\(quad|qquad|,|;|:|!|\s)"#, with: " ")
        // \begin{cases}…\end{cases}, \begin{array}{…}…\end{array} 같은 환경.
        //
        // 이걸 그냥 두면 백슬래시·중괄호를 벗기는 아래 규칙에 걸려
        // `f(x)=begincases2x+1,&x<-1\\2x+3…endcases` 처럼 읽을 수 없는 글이 된다
        // (2026-07-29 오답노트 목록에서 확인). 행·열 구분자를 사람이 읽는 기호로 바꾼다.
        t = regexReplace(t, #"\\begin\{array\}\{[^{}]*\}"#, with: "")
        t = regexReplace(t, #"\\begin\{(cases|array|matrix|pmatrix|bmatrix)\}"#, with: "")
        t = regexReplace(t, #"\\end\{(cases|array|matrix|pmatrix|bmatrix)\}"#, with: "")
        t = t.replacingOccurrences(of: "\\\\", with: " / ")   // 행 구분 \\ → /
        t = t.replacingOccurrences(of: "&", with: " ")            // 열 구분 & → 공백

        // \frac{a}{b} → a/b. 단순한 항끼리면 괄호를 안 씌운다 —
        // 첨자 안에 들어가면 (1)/(4) 같은 꼴이 오히려 읽기 어렵다.
        t = regexReplace(t, #"\\frac\{([0-9a-zA-Z]+)\}\{([0-9a-zA-Z]+)\}"#, with: "$1/$2")
        t = regexReplace(t, #"\\frac\{([^{}]*)\}\{([^{}]*)\}"#, with: "($1)/($2)")
        // 첨자를 살린다. 예전엔 중괄호를 통째로 지워서 $\lim_{x\to-2}f(x)$ 가
        // "lim x→-2f(x)" 로 뭉갰다 — 어디까지가 첨자인지 사라져 식이 달라 보인다.
        // 유니코드로 옮길 수 있으면 옮기고, 못 옮기면 괄호로 묶어 경계라도 남긴다.
        t = scripted(t, marker: "^", map: superscripts)
        t = scripted(t, marker: "_", map: subscripts)
        // 첨자를 유니코드로 못 옮기면 `_(…)` 꼴로 남는데, lim 뒤의 밑줄 잔재는
        // 걷어낸다 — "lim_(x→ -1⁻)" 보다 "lim(x→ -1⁻)" 가 읽는 글이다 (감사 0354)
        t = t.replacingOccurrences(of: "lim_(", with: "lim(")
        // \log_{2} → log_2 같은 잔여 명령: 백슬래시만 벗긴다
        t = regexReplace(t, #"\\([a-zA-Z]+)"#, with: "$1")
        // 남은 중괄호 제거, 공백 정리
        t = t.replacingOccurrences(of: "{", with: "")
             .replacingOccurrences(of: "}", with: "")
        while t.contains("  ") { t = t.replacingOccurrences(of: "  ", with: " ") }
        return t.trimmingCharacters(in: .whitespaces)
    }

    /// 수식이 들어 있는가 — 들어 있으면 펼침에서 KaTeX 완전 렌더를 붙인다
    static func containsMath(_ s: String) -> Bool {
        s.contains("$") || s.contains("\\(") || s.contains("\\[")
            || s.contains("\\frac") || s.contains("\\lim")
            || s.range(of: asciiMathPattern, options: .regularExpression) != nil
    }

    /// 모델이 수식 구분자 없이 보내는 `x^2`, `sqrt(2)`, `f(x)=3`도 수식으로 본다.
    /// 날짜(2026/8/11)나 일반 슬래시는 수식으로 오인하지 않도록 `/`만 있는 패턴은 제외한다.
    private static let asciiMathPattern = #"(?:sqrt\([^\)\n]+\)|√[A-Za-z0-9()\[\]{}+\-*/^]+|[A-Za-z0-9()\[\]{}]+\s*\^\s*(?:\([^\)\n]+\)|[-+A-Za-z0-9.]+)(?:\s*(?:<=|>=|!=|[+\-*×÷=<>≤≥≠])\s*[A-Za-z0-9()\[\]{}]+(?:\s*\^\s*(?:\([^\)\n]+\)|[-+A-Za-z0-9.]+))?)*|[A-Za-z][A-Za-z0-9()]*\s*(?:<=|>=|!=|[=<>≤≥≠])\s*[-+A-Za-z0-9()\.]+)"#

    /// LaTeX 명령 → 사람이 읽는 기호.
    /// **긴 것이 먼저 오도록 정렬해 둘 필요가 없다** — 치환이 경계를 보기 때문이다.
    /// (\\cdots 와 \\cdot 처럼 한쪽이 다른 쪽의 접두사여도 안전하다)
    private static let symbolTable: [(String, String)] = [
        ("lim_", "lim_"),       // 밑줄을 남겨야 아래 첨자 변환이 잡는다
        ("to", "→"), ("infty", "∞"), ("int", "∫"), ("sum", "Σ"), ("prod", "Π"),
        ("approx", "≈"), ("ldots", "…"), ("cdots", "⋯"), ("cdot", "·"),
        ("times", "×"), ("div", "÷"), ("pm", "±"), ("mp", "∓"),
        ("leq", "≤"), ("geq", "≥"), ("neq", "≠"),
        ("le", "≤"), ("ge", "≥"), ("ne", "≠"),
        ("sqrt", "√"), ("pi", "π"), ("alpha", "α"), ("beta", "β"), ("theta", "θ"),
        ("in", "∈"), ("cup", "∪"), ("cap", "∩"), ("subset", "⊂"),
        ("Rightarrow", "⇒"), ("Leftrightarrow", "⇔"),
    ]

    private static let superscripts: [Character: Character] = [
        "0": "\u{2070}", "1": "\u{00B9}", "2": "\u{00B2}", "3": "\u{00B3}", "4": "\u{2074}",
        "5": "\u{2075}", "6": "\u{2076}", "7": "\u{2077}", "8": "\u{2078}", "9": "\u{2079}",
        "+": "\u{207A}", "-": "\u{207B}", "\u{2212}": "\u{207B}", "=": "\u{207C}",
        "(": "\u{207D}", ")": "\u{207E}", "n": "\u{207F}", "i": "\u{2071}",
    ]
    private static let subscripts: [Character: Character] = [
        "0": "\u{2080}", "1": "\u{2081}", "2": "\u{2082}", "3": "\u{2083}", "4": "\u{2084}",
        "5": "\u{2085}", "6": "\u{2086}", "7": "\u{2087}", "8": "\u{2088}", "9": "\u{2089}",
        "+": "\u{208A}", "-": "\u{208B}", "\u{2212}": "\u{208B}", "=": "\u{208C}",
        "(": "\u{208D}", ")": "\u{208E}",
        "a": "\u{2090}", "e": "\u{2091}", "o": "\u{2092}", "x": "\u{2093}",
        "h": "\u{2095}", "k": "\u{2096}", "l": "\u{2097}", "m": "\u{2098}",
        "n": "\u{2099}", "p": "\u{209A}", "s": "\u{209B}", "t": "\u{209C}",
        "\u{2192}": "\u{2192}",   // 화살표는 그대로 둔다 (lim 첨자에 흔하다)
    ]

    /// `^{…}` · `_{…}` (중괄호 없는 한 글자도 포함) 을 유니코드 첨자로 옮긴다.
    /// 전부 옮길 수 있을 때만 옮기고, 하나라도 표가 없으면 `^(…)` 꼴로 남긴다 —
    /// 반만 옮기면 오히려 읽기 어렵다.
    private static func scripted(_ s: String, marker: Character,
                                 map: [Character: Character]) -> String {
        var out = ""
        var i = s.startIndex
        while i < s.endIndex {
            guard s[i] == marker else { out.append(s[i]); i = s.index(after: i); continue }
            var j = s.index(after: i)
            guard j < s.endIndex else { out.append(s[i]); break }
            var body = ""
            if s[j] == "{" {
                j = s.index(after: j)
                var depth = 1
                while j < s.endIndex, depth > 0 {
                    if s[j] == "{" { depth += 1 }
                    else if s[j] == "}" { depth -= 1; if depth == 0 { break } }
                    if depth > 0 { body.append(s[j]) }
                    j = s.index(after: j)
                }
                if j < s.endIndex { j = s.index(after: j) }   // 닫는 }
            } else {
                body = String(s[j]); j = s.index(after: j)
            }
            // 첨자 안 공백은 지우고 본다 — "x \\to -2" 처럼 띄어 쓴 것도 살리기 위해
            let trimmed = body.trimmingCharacters(in: .whitespaces)
            let compact = trimmed.filter { !$0.isWhitespace }
            if !compact.isEmpty, compact.allSatisfy({ map[$0] != nil }) {
                out += String(compact.map { map[$0]! })
            } else if trimmed.isEmpty {
                // 빈 첨자는 버린다
            } else {
                out += "\(marker)(\(trimmed))"
            }
            i = j
        }
        return out
    }

    private static func regexReplace(_ s: String, _ pattern: String, with template: String) -> String {
        guard let re = try? NSRegularExpression(pattern: pattern) else { return s }
        return re.stringByReplacingMatches(
            in: s, range: NSRange(s.startIndex..., in: s), withTemplate: template)
    }
}
