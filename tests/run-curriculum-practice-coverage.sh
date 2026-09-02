#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
node "$root/tests/CurriculumPracticeCoverage.js"

screen="$root/Matths/CurriculumV2MapScreen.swift"
grep -Fq '모든 개념은 바로 학습할 수 있습니다' "$screen"
grep -Fq '개념 학습에는 잠금이 없고, 평가 응시 조건만 별도로 적용됩니다.' "$screen"
grep -Fq '권장 선수 과목' "$screen"
grep -Fq 'concept.lesson?.estimatedMinutes ?? 15' "$screen"
ax_branches=$(grep -c 'dynamicTypeSize.isAccessibilitySize' "$screen")
if [ "$ax_branches" -lt 6 ]; then
  echo "커리큘럼의 긴 제목·진도·예상 시간 AX 세로 배치 계약이 빠졌습니다." >&2
  exit 1
fi
if grep -Fq 'Text("UNIT ' "$screen"; then
  echo "학생 화면에 영문 UNIT 표기가 남아 있습니다." >&2
  exit 1
fi
