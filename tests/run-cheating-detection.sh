#!/bin/bash
# 로컬 부정행위 판정의 JSON·좌표·강한 근거 승격 규칙을 앱 밖에서 빠르게 검증한다.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
APP="$HERE/.."
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

cp "$APP/Matths/CheatingDetectionModels.swift" "$WORK/"
cp "$APP/Matths/CheatingReviewModels.swift" "$WORK/"
cp "$HERE/CheatingDetectionCases.swift" "$WORK/main.swift"
swiftc -parse-as-library -O \
  "$WORK/CheatingDetectionModels.swift" "$WORK/CheatingReviewModels.swift" "$WORK/main.swift" \
  -o "$WORK/check"
"$WORK/check"

grep -Fq '로컬 사진 판독을 마치지 못했습니다. 제출된 원본은 그대로 보관됩니다.' \
  "$APP/Matths/LocalCheatingDetector.swift"
grep -Fq '제출된 원본은 그대로 보관되며 다음 실행에서 다시 확인합니다.' \
  "$APP/Matths/MatthsApp.swift"
