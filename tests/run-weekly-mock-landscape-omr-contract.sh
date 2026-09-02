#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
screen="$root/Matths/WeeklyMockScreen.swift"

grep -Fq '@Environment(\.verticalSizeClass) private var verticalSizeClass' "$screen"
grep -Fq '@Environment(\.dynamicTypeSize) private var dynamicTypeSize' "$screen"
grep -Fq 'verticalSizeClass == .compact && !dynamicTypeSize.isAccessibilitySize' "$screen"
grep -Fq 'private var usesLandscapeSplitWorkspace: Bool' "$screen"
grep -Fq 'geometry.size.width >= 900 || usesLandscapeSplitWorkspace' "$screen"
grep -Fq 'omrPane(value)' "$screen"
grep -Fq '.frame(width: min(390, max(300, geometry.size.width * 0.36)))' "$screen"
grep -Fq 'guard dynamicTypeSize.isAccessibilitySize else { return attempt.exam.title }' "$screen"
grep -Fq 'return "\(attempt.exam.formCode)형 \(attempt.exam.attemptNumber)회차"' "$screen"
grep -Fq '.accessibilityLabel(attempt?.exam.title ?? "주간 공식 모의고사")' "$screen"
if grep -Fq 'let columnCount = 3' "$screen"; then
  echo 'Split workspace 전환 뒤 도달할 수 없는 3열 OMR 코드가 남아 있습니다' >&2
  exit 1
fi
grep -Fq 'CompactHeightColumns(spacing: Tokens.Space.s5, stackedSpacing: Tokens.Space.s6)' "$screen"
grep -Fq '.accessibilityLabel("추가 설명")' "$screen"
grep -Fq 'HStack(spacing: Tokens.Space.s2) { evidenceActionButtons(item) }' "$screen"
grep -Fq 'CompactHeightColumns(spacing: Tokens.Space.s5, stackedSpacing: Tokens.Space.s4)' "$screen"
grep -Fq '.frame(minHeight: usesLandscapeForm ? 82 : 150)' "$screen"
grep -Fq '.accessibilityLabel("이의제기 내용")' "$screen"
grep -Fq '센터의 풀이과정 소명에서 제출 기한과 내용을 확인할 수 있습니다' "$screen"
if grep -Fq '.accessibilityHint("요청 번호 ' "$screen"; then
  echo 'Weekly mock 소명 안내가 VoiceOver 사용자에게만 내부 요청 번호를 노출합니다' >&2
  exit 1
fi

echo 'Weekly mock landscape OMR contract passed'
