#!/bin/sh
# 수식 줄(KaTeX 웹뷰)의 글자색이 화면 외관을 따라가는지 지킨다.
#
# 막으려는 사고 (2026-08-21, 아이패드 아레나 대국 화면):
#   발문이 어두운 카드(#141a2e) 위에 #111425 로 찍혀 대비 1.05:1 이었다. 학생이
#   문제를 읽을 수 없는 화면이 심사 직전까지 남아 있었다. 같은 화면의 선택지는
#   SwiftUI Text 라 #eef1fa 로 멀쩡했다 — 같은 `Tokens.ink` 토큰인데 결과가 갈렸다.
#
#   원인은 색을 웹에 넘기려고 hex 로 구울 때다. 토큰은 `UIColor { traits in … }` 인
#   동적 색이고 `getRed` 는 그 자리에서 값을 확정하는데, 확정 기준인
#   `UITraitCollection.current` 가 SwiftUI body 안에서는 뷰의 외관을 따라간다는
#   보장이 없다. 미지정이면 라이트로 떨어진다.
#
#   발문·선택지·해설·채팅·오답노트가 전부 MathInline 한 곳을 지난다. 그래서
#   이 파일 하나가 무너지면 앱 전체의 수식이 다크 모드에서 안 보인다.
#
# 실행: sh tests/run-math-color-scheme-contract.sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
label="$root/Matths/MathLabel.swift"
html="$root/Matths/LessonWeb/mathline.html"
tokens="$root/Matths/DesignTokens.swift"

fail() { echo "FAIL: $1" >&2; exit 1; }

# ── 1. 색을 구울 때 외관을 인자로 받는다 ────────────────────────────────────
# 인자 없는 계산 프로퍼티 형태(`var tokenHexForWeb: String`)로 되돌아가면
# 다시 UITraitCollection.current 에 기대게 된다.
grep -q 'func tokenHexForWeb(_ scheme: ColorScheme) -> String' "$label" \
  || fail "tokenHexForWeb 가 ColorScheme 을 받지 않습니다. 외관 없이 구우면 라이트로 떨어집니다."
grep -q 'var tokenHexForWeb: String' "$label" \
  && fail "인자 없는 tokenHexForWeb 이 남아 있습니다."

# ── 2. MathInline 이 실제 외관을 읽는다 ─────────────────────────────────────
grep -q '@Environment(\\.colorScheme)' "$label" \
  || fail "MathInline 이 colorScheme 을 읽지 않습니다. 인자를 받아도 넘길 값이 없습니다."
grep -q 'color.tokenHexForWeb(colorScheme)' "$label" \
  || fail "구운 hex 가 colorScheme 에서 나오지 않습니다."

# ── 3. 확정을 두 겹으로 막는다 ──────────────────────────────────────────────
# performAsCurrent 는 `UIColor(self)` 가 생성 시점에 값을 확정해 버리는 경우를,
# resolvedColor 는 동적 색으로 남아 오는 경우를 막는다. 어느 한쪽만으로는
# UIColor(Color) 의 동작에 기대게 된다.
# 주석에도 이 낱말이 나온다. 호출부 형태로 붙잡아야 주석만 남기고 코드를 지운
# 변경을 잡을 수 있다(과거에 같은 방식으로 새어 나간 계약 테스트가 있었다).
grep -q 'traits.performAsCurrent {' "$label" \
  || fail "traits.performAsCurrent 호출이 없습니다. UIColor(Color) 가 즉시 확정하면 다시 라이트가 나옵니다."
grep -q 'resolvedColor(with: traits)' "$label" \
  || fail "resolvedColor(with:) 가 없습니다. 동적 색으로 남아 오면 확정되지 않습니다."

# ── 4. 실패했을 때의 기본값도 외관을 따라간다 ───────────────────────────────
# 예전에는 getRed 가 실패하면 #17171f 를 돌려줬다. 실패 경로에서도 검정이었다.
grep -q 'scheme == .dark ? "#eef1fa" : "#17171f"' "$label" \
  || fail "getRed 실패 시 기본 hex 가 외관을 따라가지 않습니다."

# ── 5. 색 변화가 웹뷰에 실제로 반영된다 ─────────────────────────────────────
# 색은 makeUIView 의 atDocumentStart 스크립트로만 들어간다. id 가 그대로면
# 다크↔라이트 전환에서 웹뷰가 재생성되지 않아 옛 색이 남는다.
grep -q '\.id("math-\\(text.hashValue)-\\(Int(pixelSize))-\\(hex)")' "$label" \
  || fail "KaTeXLabel 의 id 에 hex 가 없습니다. 외관을 바꿔도 옛 색이 남습니다."

# ── 6. 웹 쪽 기본값도 외관을 따라간다 ───────────────────────────────────────
grep -q '@media (prefers-color-scheme: dark) { #line { color: #eef1fa; } }' "$html" \
  || fail "mathline.html 에 다크 모드 기본 글자색이 없습니다."
grep -q 'if (data.color) el.style.color = data.color;' "$html" \
  || fail "mathline.html 이 payload 없이도 색을 덮어씁니다. CSS 기본값이 무력화됩니다."
grep -q 'el.style.color = data.color || "#111426"' "$html" \
  && fail "mathline.html 에 고정 라이트 잉크 대체값이 남아 있습니다."

# ── 7. 하드코딩한 값이 토큰과 어긋나지 않는다 ───────────────────────────────
# 위 검사들은 문자열 #eef1fa / #111426 에 기대고 있다. 토큰이 바뀌면 이 파일이
# 조용히 거짓말을 하게 되므로, 두 값이 아직 Tokens.ink 인지 확인한다.
python3 - "$tokens" <<'PY'
import pathlib, re, sys

source = pathlib.Path(sys.argv[1]).read_text()
m = re.search(r'static let ink\s*=\s*adaptive\(light:\s*0x([0-9A-Fa-f]{6}),\s*dark:\s*0x([0-9A-Fa-f]{6})\)', source)
if not m:
    raise SystemExit("FAIL: DesignTokens.swift 에서 Tokens.ink 를 읽지 못했습니다.")
light, dark = m.group(1).lower(), m.group(2).lower()
if (light, dark) != ("111426", "eef1fa"):
    raise SystemExit(
        "FAIL: Tokens.ink 가 바뀌었습니다 (light=#%s dark=#%s). "
        "run-math-color-scheme-contract.sh 와 mathline.html 의 대체값도 함께 고치십시오." % (light, dark))
PY

echo "PASS: 수식 글자색이 외관을 따라갑니다."
