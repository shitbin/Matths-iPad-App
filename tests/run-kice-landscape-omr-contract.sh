#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
screen="$root/Matths/KiceExamScreen.swift"
grep -Fq '.safeAreaInset(edge: .bottom, spacing: 0)' "$screen"
grep -Fq 'proxy.scrollTo("kice-result-summary", anchor: .top)' "$screen"

# 852pt iPhone 가로에서도 문제지와 답안지를 한 화면에 둔다. 접근성 큰 글자는
# 답안지 잘림을 피하려고 세그먼트 전환형을 유지한다.
grep -Fq '@Environment(\.verticalSizeClass) private var verticalSizeClass' "$screen"
grep -Fq '@Environment(\.dynamicTypeSize) private var dynamicTypeSize' "$screen"
grep -Fq 'private var usesLandscapeSplitWorkspace: Bool' "$screen"
grep -Fq 'verticalSizeClass == .compact && !dynamicTypeSize.isAccessibilitySize' "$screen"
grep -Fq 'UniversalLayoutPolicy.usesProblemSplit(width: geo.size.width, height: geo.size.height' "$screen"

# 352pt = compact OMR 행 292 + 카드 좌우 24 + 스크롤 좌우 32 + 여유 4.
# 더 좁히면 다섯 44pt 선택 영역 중 하나가 잘리거나 겹친다.
grep -Fq 'let omrWidth = min(max(geo.size.width * 0.36, 300), min(420, geo.size.width * 0.52))' "$screen"
grep -Fq 'ViewThatFits(in: .horizontal)' "$screen"
grep -Fq 'horizontalSizeClass == .compact || verticalSizeClass == .compact' "$screen"
grep -Fq 'private var bubbleHitWidth: CGFloat { 44 }' "$screen"
grep -Fq '.frame(width: 92, height: usesCompactMetrics ? 44 : 34)' "$screen"

echo 'KICE landscape split OMR contract passed'
