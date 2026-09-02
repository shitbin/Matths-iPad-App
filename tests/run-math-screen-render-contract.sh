#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
shop="$root/Matths/ArenaShopScreen.swift"
work=$(mktemp -d "${TMPDIR:-/tmp}/matths-typesetting.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM

for field in 'question.prompt' 'question.solution' 'step.explanation'; do
  if grep -Eq "Text\\($field\\)" "$shop"; then
    echo "경기 상세 분석에서 $field 수식을 일반 Text로 표시하면 안 됩니다." >&2
    exit 1
  fi
done

# 줄번호는 기능 코드가 앞에 추가될 때마다 밀린다. 분석 화면 타입의 실제 본문만
# 잘라 검사해 unrelated MathInline이 통과시키거나 정상 리팩터링이 깨지지 않게 한다.
analysis_body=$(sed -n \
  '/private struct ArenaShopAnalysisScreen: View {/,/private struct ArenaShopAnalysisPreview: View {/p' \
  "$shop")
math_inline_count=$(printf '%s\n' "$analysis_body" | grep -c 'MathInline(')
if [ "$math_inline_count" -lt 4 ]; then
  echo "경기 문제·답·정답·해설·단계의 수식 조판 경계가 빠졌습니다." >&2
  exit 1
fi

grep -Fq 'MathText.containsMath(text)' "$root/Matths/MathLabel.swift"
grep -Fq 'WebContentAccessibility.configure(web)' "$root/Matths/MathLabel.swift"
# 콜드 WebKit/KaTeX 초기화 동안 시험 발문을 빈칸으로 두지 않는다. 첫 높이 메시지가
# 오기 전에는 같은 원문의 평문 근사를 보여주고, 조판 완료 후에만 웹뷰를 드러낸다.
grep -Fq '@State private var rendered = false' "$root/Matths/MathLabel.swift"
grep -Fq 'Text(MathText.plain(text))' "$root/Matths/MathLabel.swift"
grep -Fq '.opacity(rendered ? 1 : 0)' "$root/Matths/MathLabel.swift"
grep -Fq 'rendered = true' "$root/Matths/MathLabel.swift"
grep -Fq '.accessibilityLabel(MathText.plain(text))' "$root/Matths/MathLabel.swift"

# 오래된 서버 오답에 isTex가 빠져도 발문의 TeX 구분자와 선지 유무로 조판 경로를
# 복구해야 한다. 실제 GeneratedProblem 구현을 컴파일·실행해 문자열 예시를 검증한다.
xcrun swiftc \
  "$root/Matths/MathAnswer.swift" \
  "$root/Matths/ProblemGenerator.swift" \
  "$root/Tests/ProblemTypesettingCases.swift" \
  -o "$work/problem-typesetting"
"$work/problem-typesetting"

echo "student-facing Arena analysis math rendering contract passed"
