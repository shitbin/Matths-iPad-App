//  MathTextCases.swift — 수식 표시 경로 회귀 검사
//
//  실행:
//    cd ipad-app && ./tests/run-mathtext.sh
//
//  왜 있나: 모델이 뱉는 LaTeX 을 화면용 평문으로 바꾸는 MathText.plain 에서
//  **짧은 명령이 긴 명령의 앞부분을 먹는** 버그가 있었다.
//    "x \\leq 3" → "x ≤q 3",  "a \\neq b" → "a ≠q b"
//  그리고 \, 같은 간격 명령이 그대로 남아 "|v(t)|\,dt" 로 보였다.
//  학생 눈에는 그냥 깨진 글자다. 실기 화면을 보기 전엔 아무도 몰랐다(2026-07-29).
//
//  여기 사례는 전부 **실제 모델 출력에서 가져온 모양**이다. 늘리면 늘렸지 줄이지 마라.

// 모델이 실제로 뱉는 수식들을 화면 경로(MathText.plain)에 그대로 태운다.
import Foundation

let cases: [(String, String)] = [
    ("x \\leq 3", "≤ 로만"),
    ("x \\geq 3", "≥ 로만"),
    ("a \\neq b", "≠ 로만"),
    ("$10^{\\frac{3}{2}}$", "지수·분수"),
    ("$\\lim_{x \\to -2} f(x) = 0$", "극한"),
    ("$\\sqrt{3}$", "루트"),
    ("$9^{\\frac{1}{4}} \\times 3^{-\\frac{1}{2}}$", "곱셈"),
    ("$\\int_0^2 |v(t)|\\,dt$", "적분"),
    ("$a_{n+1} = a_n + 2$", "수열"),
    ("$f(x)=\\begin{cases}2x+1,&x<-1\\\\2x+3,&x\\geq-1\\end{cases}$", "케이스"),
    ("$\\log_2 8 = 3$", "로그"),
    ("$\\frac{1}{2}\\left(x+1\\right)$", "left/right"),
]
var failed = 0
for (src, label) in cases {
    let out = MathText.plain(src)
    // 남아 있으면 안 되는 것: 백슬래시, 중괄호, 그리고 잘려 나간 명령의 꼬리
    let bad = out.contains("\\") || out.contains("{") || out.contains("}")
        || out.contains("≤q") || out.contains("≥q") || out.contains("≠q")
    if bad { failed += 1 }
    print("\(bad ? "✗" : "✓") \(label.padding(toLength: 10, withPad: " ", startingAt: 0)) \(src)\n     → \(out)")
}
for src in ["x^2 + 1", "sqrt(2)", "a^m × a^n = a^(m+n)", "f(x)=3"] {
    if !MathText.containsMath(src) {
        failed += 1
        print("✗ ASCII 수식 감지  \(src)")
    }
}
for src in ["2026/8/11", "Ranked 경기", "13과목 220개념"] {
    if MathText.containsMath(src) {
        failed += 1
        print("✗ 일반 문장 오인  \(src)")
    }
}
print(failed == 0 ? "\n전부 통과 (\(cases.count)건)" : "\n실패 \(failed)건")
exit(failed == 0 ? 0 : 1)
