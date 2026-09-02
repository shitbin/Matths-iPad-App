#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

cat > "$work/vision-selftest.jsonl" <<'JSONL'
{"availableBytes":5000000000,"event":"launch","model":"vision-model.gguf","recordedAt":"2026-08-11T00:00:00Z","residentBytes":100000000,"tier":"vision3B"}
{"availableBytes":2000000000,"elapsedMs":12000,"event":"load-complete","maximumResidentBytes":3200000000,"minimumAvailableBytes":1200000000,"model":"vision-model.gguf","recordedAt":"2026-08-11T00:00:12Z","tier":"vision3B","visionReady":true}
{"elapsedMs":18000,"event":"vision-complete","firstTokenMs":7000,"generatedTokens":80,"maximumResidentBytes":3500000000,"minimumAvailableBytes":900000000,"model":"vision-model.gguf","recordedAt":"2026-08-11T00:00:30Z","tier":"vision3B","tokensPerSecond":4.4}
JSONL

node "$root/scripts/verifyVisionEvidence.js" \
  "$work/vision-selftest.jsonl" --output "$work/vision-evidence.json"
grep -Fq '"schema": "MATTHS_VISION_DEVICE_EVIDENCE_V1"' "$work/vision-evidence.json"
grep -Fq '"result": "PASS"' "$work/vision-evidence.json"
grep -Fq '"tier": "vision3B"' "$work/vision-evidence.json"

cat > "$work/failed.jsonl" <<'JSONL'
{"event":"launch","model":"failed.gguf","tier":"deepseek7B"}
{"elapsedMs":180000,"event":"load-failed","maximumResidentBytes":7000000000,"minimumAvailableBytes":1,"model":"failed.gguf","tier":"deepseek7B"}
JSONL
if node "$root/scripts/verifyVisionEvidence.js" "$work/failed.jsonl" >/dev/null 2>&1; then
  echo "load-failed evidence must not pass" >&2
  exit 1
fi

grep -Fq 'verifyVisionEvidence.js' "$root/device-qa.sh"
grep -Fq 'vision-evidence.json' "$root/device-qa.sh"
grep -Fq '"$BUNDLE_ID" -- -visionSelfTest "$tier"' "$root/device-qa.sh"
grep -Fq '9B-lite-text' "$root/device-qa.sh"
grep -Fq 'debugForcedTier == "9B-lite-text"' "$root/Matths/LocalLLM.swift"
grep -Fq '9B-iq3-text' "$root/device-qa.sh"
grep -Fq 'debugForcedTier == "9B-lite-text" || debugForcedTier == "9B-iq3-text"' "$root/Matths/LocalLLM.swift"
grep -Fq 'force9BOnSmallDevice ? spec9BLiteText : specDeepSeek7B' "$root/Matths/LocalLLM.swift"
grep -Fq 'Qwen3.5-9B-UD-IQ3_XXS.gguf' "$root/Matths/LocalLLM.swift"
grep -Fq '40d0f32cd3030b04f0784139a589fb63e876cfbf8667d56311b79783c74fd149' "$root/Matths/LocalAIModelPack.swift"
echo "Vision device evidence contracts passed"
