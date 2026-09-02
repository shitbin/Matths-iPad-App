#!/usr/bin/env bash
set -euo pipefail

# 스크린샷 보호 — 실제로 지켜야 할 것 (2026-08-17 개정)
#
# 경위:
#   범위를 전 화면으로 넓혔더니 앱이 망가졌다. 제어센터를 내리기만 해도 화면이
#   통째로 검게 덮였고, **정작 스크린샷은 막지 못했다**(실기 확인).
#   secure canvas(isSecureTextEntry 컨테이너 트릭)는 Apple DTS 가 의도된 용도가
#   아니라고 명시했고 App Review 2.5.1 위험도 있다. 그래서 껐다.
#
# 이 검사가 지키는 것은 이제 두 가지다:
#   (1) 그 우회가 조용히 다시 켜지지 않을 것
#   (2) 정식 경로(AAC)가 코드베이스에 남아 있을 것
# "전 화면 보호" 를 요구하던 종전 검사는 삭제한다 — 그건 잘못된 결론이었다.

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GUARD="$ROOT/Matths/ScreenshotGuard.swift"
CANVAS="$ROOT/Matths/SecureCaptureCanvas.swift"
AAC="$ROOT/Matths/AssessmentSecurityCoordinator.swift"

for f in "$GUARD" "$CANVAS" "$AAC"; do test -f "$f"; done

# (1) secure canvas 는 꺼져 있어야 한다.
grep -Fq '.secureCaptureCanvas(isActive: false)' "$GUARD"
if grep -Fq '.secureCaptureCanvas(isActive: guardModel.protectionEnabled)' "$GUARD"; then
  echo "secure canvas 가 다시 켜졌습니다 — 스크린샷을 막지 못하면서 화면만 덮습니다" >&2
  exit 1
fi

# (2) 정식 경로가 남아 있어야 한다. entitlement 승인 후 여기에 배선한다.
grep -Fq 'AEAssessmentSession' "$AAC"
grep -Fq 'AssessmentSecurityCoordinator' "$AAC"

# 화면 녹화·미러링 차단은 계속 살아 있어야 한다 — 이건 공개 API 로 되는 일이다.
grep -Fq 'isCaptured' "$GUARD"

echo "스크린샷 보호 계약 통과 (우회 꺼짐 · AAC 준비 · 녹화 차단 유지)"
