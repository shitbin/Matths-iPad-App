#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
screen="$root/Matths/Screens.swift"

# iPhone 가로에서 평가 상세가 page sheet의 닫기 제스처와 스크롤을 경쟁하지 않는다.
grep -Fq '.compactHeightSheet(isPresented: $showSystemInfo)' "$screen"
grep -Fq '.compactHeightSheet(item: $lockDetail)' "$screen"

# 평가 체계는 보통 글자 크기에서 가로 폭을 두 열로 쓰고, 접근성 글자 크기에서는
# CompactHeightColumns가 한 열로 돌아간 뒤 전체 문서를 스크롤할 수 있어야 한다.
grep -Fq 'assessmentSheetHeader(title: "평가 체계"' "$screen"
grep -Fq 'CompactHeightColumns(' "$screen"
grep -Fq 'ScrollView {' "$screen"

# fullScreenCover에서도 탈출할 수 있는 명시적 닫기 동선을 두 상세가 공유한다.
grep -Fq 'private func assessmentSheetHeader(' "$screen"
grep -Fq 'Button("닫기", action: close)' "$screen"
grep -Fq 'lockDetail = nil' "$screen"

echo 'assessment landscape sheet contract passed'
