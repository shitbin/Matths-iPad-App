//  InlineMathText.swift
//  Matths
//
//  커리큘럼 원문에 섞인 `$...$` LaTeX 를 사람이 읽을 글자로 바꾼다.
//
//  왜 필요한가:
//    curriculum-v2.json 의 summary·achievementStandard 는 LaTeX 를 그대로 담고 있다.
//    개념 화면은 KatexText(WebView)로 조판하지만, 홈 카드·목록·미리보기처럼
//    작고 많이 그려지는 자리는 WebView 를 띄울 수 없다. 그래서 그 자리들에서
//    `$-1$`, `$i^2$`, `$a+bi$` 가 달러 기호째로 노출됐다 — 사용자가 두 번 지적한 것이다.
//
//  KaTeX 를 대신하려는 게 아니다. **짧은 인라인 수식만** 유니코드로 옮기고,
//  감당 못 하는 것은 달러만 벗겨 원문을 남긴다. 반쪽짜리 조판보다 읽히는 평문이 낫다.
//  분수·적분처럼 2차원 배치가 필요한 식은 애초에 이 자리에 오면 안 되고,
//  오면 KatexText 를 쓰는 화면으로 보내야 한다.

import Foundation

enum InlineMath {
    /// `$...$` 구간을 유니코드로 바꾼 평문을 돌려준다.
    /// 수식이 없으면 원문을 그대로 돌려준다(비용 0).
    static func plain(_ source: String) -> String {
        guard source.contains("$") else { return source }
        var out = ""
        var inMath = false
        var buffer = ""
        for ch in source {
            if ch == "$" {
                if inMath { out += convert(buffer); buffer = "" }
                inMath.toggle()
                continue
            }
            if inMath { buffer.append(ch) } else { out.append(ch) }
        }
        // 달러가 홀수 개면 마지막 구간은 수식이 아니다. 버리지 말고 되살린다.
        if !buffer.isEmpty { out += buffer }
        return out
    }

    /// 위첨자로 옮길 수 있는 글자. 여기 없는 것은 옮기지 않는다 —
    /// 반만 올라간 첨자는 안 올린 것보다 읽기 나쁘다.
    private static let superscripts: [Character: Character] = [
        "0": "⁰", "1": "¹", "2": "²", "3": "³", "4": "⁴",
        "5": "⁵", "6": "⁶", "7": "⁷", "8": "⁸", "9": "⁹",
        "n": "ⁿ", "i": "ⁱ", "+": "⁺", "-": "⁻",
    ]

    private static let commands: [(String, String)] = [
        ("\\times", "×"), ("\\div", "÷"), ("\\pm", "±"), ("\\mp", "∓"),
        ("\\le", "≤"), ("\\leq", "≤"), ("\\ge", "≥"), ("\\geq", "≥"),
        ("\\ne", "≠"), ("\\neq", "≠"), ("\\approx", "≈"), ("\\equiv", "≡"),
        ("\\cdot", "·"), ("\\infty", "∞"), ("\\pi", "π"), ("\\theta", "θ"),
        ("\\alpha", "α"), ("\\beta", "β"), ("\\gamma", "γ"), ("\\Delta", "Δ"),
        ("\\in", "∈"), ("\\subset", "⊂"), ("\\cup", "∪"), ("\\cap", "∩"),
        ("\\Longleftrightarrow", "⟺"), ("\\Leftrightarrow", "⟺"),
        ("\\Longrightarrow", "⟹"), ("\\Rightarrow", "⟹"),
        ("\\rightarrow", "→"), ("\\to", "→"),
        ("\\sqrt", "√"), ("\\left", ""), ("\\right", ""),
    ]

    private static func convert(_ math: String) -> String {
        var s = math

        // \text{...} 는 수식이 아니라 설명이다. 중괄호만 벗긴다.
        s = unwrap(s, command: "\\text")
        s = unwrap(s, command: "\\mathrm")

        // 긴 명령부터 바꾼다 — \le 를 먼저 바꾸면 \leq 가 "≤q" 가 된다.
        for (cmd, glyph) in commands.sorted(by: { $0.0.count > $1.0.count }) {
            s = s.replacingOccurrences(of: cmd, with: glyph)
        }

        s = applySuperscripts(s)
        // 남은 중괄호는 배치용이라 평문에서는 뜻이 없다.
        s = s.replacingOccurrences(of: "{", with: "").replacingOccurrences(of: "}", with: "")
        return s.trimmingCharacters(in: .whitespaces)
    }

    /// `\text{의 x절편}` → `의 x절편`
    private static func unwrap(_ source: String, command: String) -> String {
        var s = source
        while let r = s.range(of: command + "{") {
            var depth = 1
            var idx = r.upperBound
            var inner = ""
            while idx < s.endIndex, depth > 0 {
                let c = s[idx]
                if c == "{" { depth += 1 } else if c == "}" { depth -= 1 }
                if depth > 0 { inner.append(c) }
                idx = s.index(after: idx)
            }
            s.replaceSubrange(r.lowerBound..<idx, with: inner)
        }
        return s
    }

    /// `x^2` → `x²`, `x^{10}` → `x¹⁰`. 옮길 수 없는 글자가 하나라도 있으면
    /// 그 첨자는 건드리지 않는다.
    private static func applySuperscripts(_ source: String) -> String {
        var out = ""
        var i = source.startIndex
        while i < source.endIndex {
            guard source[i] == "^" else { out.append(source[i]); i = source.index(after: i); continue }
            var j = source.index(after: i)
            var body = ""
            if j < source.endIndex, source[j] == "{" {
                j = source.index(after: j)
                while j < source.endIndex, source[j] != "}" { body.append(source[j]); j = source.index(after: j) }
                if j < source.endIndex { j = source.index(after: j) }
            } else if j < source.endIndex {
                body.append(source[j]); j = source.index(after: j)
            }
            let mapped = body.compactMap { superscripts[$0] }
            if mapped.count == body.count, !body.isEmpty {
                out += String(mapped)
            } else {
                out += "^" + body      // 못 옮기면 원문 그대로 — 반쪽 조판을 만들지 않는다
            }
            i = j
        }
        return out
    }
}
