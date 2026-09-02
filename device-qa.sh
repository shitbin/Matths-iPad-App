#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h}"
DEVICE="${MATTHS_DEVICE:-}"
BUNDLE_ID="kr.matths.app"
DERIVED="${MATTHS_DERIVED_DATA:-/tmp/matths-device-qa}"
APP="$DERIVED/Build/Products/Debug-iphoneos/Matths.app"
EVIDENCE="${MATTHS_EVIDENCE_DIR:-$ROOT/../evidence/ipad-$(date +%Y%m%d-%H%M%S)}"

usage() {
  print "사용법: MATTHS_DEVICE=<기기 이름 또는 UDID> $0 build-install|smoke|vision <tier>|collect|session-template|verify-session <session.json>"
  print "tier: vision3B, deepseek7B, ling3-q3, 4B, 9B-lite, 9B-lite-text, 9B-iq3-text, 9B"
}

need_device() {
  if [[ -z "$DEVICE" ]]; then
    print -u2 "MATTHS_DEVICE에 iPad 이름 또는 UDID를 지정하세요."
    exit 2
  fi
}

case "${1:-}" in
  build-install)
    need_device
    xcodebuild -project "$ROOT/Matths.xcodeproj" -scheme Matths -configuration Debug \
      -destination 'generic/platform=iOS' -derivedDataPath "$DERIVED" \
      -allowProvisioningUpdates build
    xcrun devicectl device install app --device "$DEVICE" "$APP"
    print "설치 완료. 다음: MATTHS_DEVICE=... $0 smoke"
    ;;
  smoke)
    need_device
    xcrun devicectl device process launch --terminate-existing --device "$DEVICE" "$BUNDLE_ID"
    print "앱을 열었습니다. 로그인·Google 복귀·커리큘럼·평가·Arena를 실기에서 확인하세요."
    ;;
  vision)
    need_device
    tier="${2:-}"
    case "$tier" in
      vision3B|deepseek7B|ling3-q3|4B|9B-lite|9B-lite-text|9B-iq3-text|9B) ;;
      *) usage; exit 2 ;;
    esac
    xcrun devicectl device process launch --terminate-existing --device "$DEVICE" \
      "$BUNDLE_ID" -- -visionSelfTest "$tier"
    print "로컬 AI 자가진단을 시작했습니다. 앱이 결과를 쓸 때까지 종료하지 말고, 완료 뒤 collect를 실행하세요."
    ;;
  collect)
    need_device
    mkdir -p "$EVIDENCE"
    xcrun devicectl device copy from --device "$DEVICE" \
      --domain-type appDataContainer --domain-identifier "$BUNDLE_ID" \
      --source "Documents/MatthsDiagnostics/vision-selftest.jsonl" \
      --destination "$EVIDENCE/vision-selftest.jsonl"
    if grep -Fq '"event":"reasoning-complete"' "$EVIDENCE/vision-selftest.jsonl"; then
      node "$ROOT/scripts/verifyReasoningEvidence.js" \
        "$EVIDENCE/vision-selftest.jsonl" \
        --output "$EVIDENCE/reasoning-evidence.json"
      manifest="$EVIDENCE/reasoning-evidence.json"
    else
      node "$ROOT/scripts/verifyVisionEvidence.js" \
        "$EVIDENCE/vision-selftest.jsonl" \
        --output "$EVIDENCE/vision-evidence.json"
      manifest="$EVIDENCE/vision-evidence.json"
    fi
    print "비식별 성능 자료: $EVIDENCE/vision-selftest.jsonl"
    print "검증 manifest: $manifest"
    ;;
  session-template)
    mkdir -p "$EVIDENCE"
    node "$ROOT/scripts/verifyDeviceQaSession.js" --write-template "$EVIDENCE/session.json"
    ;;
  verify-session)
    session="${2:-}"
    if [[ -z "$session" ]]; then usage; exit 2; fi
    node "$ROOT/scripts/verifyDeviceQaSession.js" "$session" \
      --output "${session:h}/device-evidence.json"
    ;;
  *) usage; exit 2 ;;
esac
