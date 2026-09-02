#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SELECTOR="$ROOT/Matths/DebugLocalModelSelector.swift"
LOCAL_LLM="$ROOT/Matths/LocalLLM.swift"
PROFILE="$ROOT/Matths/ProfileScreen.swift"
PRO="$ROOT/Matths/ProScreen.swift"

grep -Fq '#if DEBUG' "$SELECTOR"
grep -Fq 'Ling 3.0 tiny Q3' "$SELECTOR"
grep -Fq '사진 판독은 Qwen VL 3B로 고정' "$SELECTOR"
grep -Fq 'frame(minHeight: 44)' "$SELECTOR"
grep -Fq 'ModelDownloader.shared.startForTierSwitch()' "$SELECTOR"
grep -Fq 'DebugLocalModelSelector(selection: $debugTier' "$PROFILE"
grep -Fq 'DebugLocalModelSelector(selection: $debugTier' "$PRO"
grep -Fq 'if let tier = debugForcedTier { return spec(forTier: tier) }' "$LOCAL_LLM"
grep -Fq 'case "ling3-q3": return specLing3Q3' "$LOCAL_LLM"

# Release Pro 화면은 사진 분석을 시작할 때 전용 VLM으로 순차 전환한다. 현재 열린
# 텍스트 모델의 visionReady=false를 실패로 오인하거나 DEBUG 메뉴를 안내하지 않는다.
grep -Fq 'if ModelDownloader.visionOffForCurrentModel {' "$PRO"
if grep -Fq "분석 모델 (디버그)" "$PRO"; then
  echo "Pro release copy must not point users to a DEBUG-only control" >&2
  exit 1
fi

echo "DEBUG local model selector contract passed"
