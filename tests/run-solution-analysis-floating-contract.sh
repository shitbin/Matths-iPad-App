#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCREEN="$ROOT/Matths/Screens.swift"
CARD="$ROOT/Matths/StudentSolutionAnalysisFloatingCard.swift"

grep -Fq 'grading.overall != .correct' "$SCREEN"
grep -Fq 'source: .practiceDrawing' "$SCREEN"
grep -Fq 'review.state == .pending' "$SCREEN"
grep -Fq 'review.imageFile != nil' "$SCREEN"
grep -Fq 'StudentSolutionAnalysisFloatingCard(record: review)' "$SCREEN"
grep -Fq 'CheatingReviewDisk.imageURL(for: record)' "$CARD"
grep -Fq 'Text("내 풀이를 읽는 중")' "$CARD"
grep -Fq 'Text("방금 쓴 식을 보면서 잠시 기다려 주세요.")' "$CARD"
grep -Fq 'Image(uiImage: solutionImage)' "$CARD"
grep -Fq '.accessibilityLabel("방금 작성한 풀이 크게 보기")' "$CARD"
grep -Fq '.compactHeightSheet(isPresented: $showExpanded)' "$CARD"
grep -Fq '이미지 분석은 이 기기 안에서 진행됩니다.' "$CARD"

if grep -Fq '#if DEBUG' "$CARD"; then
  echo '학생 풀이 플로팅 카드가 DEBUG 전용입니다.' >&2
  exit 1
fi

echo 'Student solution analysis floating contract PASS'
