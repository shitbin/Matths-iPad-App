#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

cat > "$work/reasoning-selftest.jsonl" <<'JSONL'
{"availableBytes":5000000000,"event":"launch","model":"DeepSeek-R1-Distill-Qwen-7B-Q3_K_M.gguf","residentBytes":100000000,"tier":"deepseek7B"}
{"availableBytes":2100000000,"elapsedMs":9000,"event":"load-complete","maximumResidentBytes":3000000000,"minimumAvailableBytes":1900000000,"model":"DeepSeek-R1-Distill-Qwen-7B-Q3_K_M.gguf","tier":"deepseek7B","visionReady":false}
{"elapsedMs":14000,"event":"reasoning-complete","firstTokenMs":900,"generatedTokens":120,"maximumResidentBytes":3200000000,"minimumAvailableBytes":1700000000,"model":"DeepSeek-R1-Distill-Qwen-7B-Q3_K_M.gguf","tier":"deepseek7B","tokensPerSecond":8.5}
{"event":"reasoning-language","koreanOutputClean":true}
JSONL

node "$root/scripts/verifyReasoningEvidence.js" \
  "$work/reasoning-selftest.jsonl" --output "$work/reasoning-evidence.json"
grep -Fq '"schema": "MATTHS_REASONING_DEVICE_EVIDENCE_V1"' "$work/reasoning-evidence.json"
grep -Fq '"result": "PASS"' "$work/reasoning-evidence.json"
grep -Fq '"koreanOutputClean": true' "$work/reasoning-evidence.json"

cat > "$work/ling-reasoning-selftest.jsonl" <<'JSON'
{"availableBytes":5000000000,"event":"launch","model":"Ling-3.0-tiny-Q3_K_M.gguf","residentBytes":100000000,"tier":"ling3-q3"}
{"availableBytes":2100000000,"elapsedMs":12000,"event":"load-complete","maximumResidentBytes":3400000000,"minimumAvailableBytes":1600000000,"model":"Ling-3.0-tiny-Q3_K_M.gguf","tier":"ling3-q3","visionReady":false}
{"elapsedMs":18000,"event":"reasoning-complete","firstTokenMs":1100,"generatedTokens":128,"maximumResidentBytes":3600000000,"minimumAvailableBytes":1400000000,"model":"Ling-3.0-tiny-Q3_K_M.gguf","tier":"ling3-q3","tokensPerSecond":7.1}
{"event":"reasoning-language","koreanOutputClean":true,"model":"Ling-3.0-tiny-Q3_K_M.gguf","tier":"ling3-q3"}
JSON
node "$root/scripts/verifyReasoningEvidence.js" \
  "$work/ling-reasoning-selftest.jsonl" --output "$work/ling-reasoning-evidence.json"
grep -Fq '"tier": "ling3-q3"' "$work/ling-reasoning-evidence.json"
grep -Fq '"model": "Ling-3.0-tiny-Q3_K_M.gguf"' "$work/ling-reasoning-evidence.json"

cat > "$work/unclean.jsonl" <<'JSONL'
{"event":"launch","model":"DeepSeek-R1-Distill-Qwen-7B-Q3_K_M.gguf","tier":"deepseek7B"}
{"elapsedMs":1,"event":"load-complete","maximumResidentBytes":1,"minimumAvailableBytes":1,"model":"DeepSeek-R1-Distill-Qwen-7B-Q3_K_M.gguf","tier":"deepseek7B"}
{"elapsedMs":1,"event":"reasoning-complete","firstTokenMs":1,"generatedTokens":1,"maximumResidentBytes":1,"minimumAvailableBytes":1,"model":"DeepSeek-R1-Distill-Qwen-7B-Q3_K_M.gguf","tier":"deepseek7B","tokensPerSecond":1}
{"event":"reasoning-language","koreanOutputClean":false}
JSONL
if node "$root/scripts/verifyReasoningEvidence.js" "$work/unclean.jsonl" >/dev/null 2>&1; then
  echo "reasoning evidence must reject unsafe student-facing language" >&2
  exit 1
fi

cat > "$work/private.jsonl" <<'JSONL'
{"event":"launch","model":"DeepSeek-R1-Distill-Qwen-7B-Q3_K_M.gguf","tier":"deepseek7B"}
{"elapsedMs":1,"event":"load-complete","maximumResidentBytes":1,"minimumAvailableBytes":1,"model":"DeepSeek-R1-Distill-Qwen-7B-Q3_K_M.gguf","tier":"deepseek7B"}
{"elapsedMs":1,"event":"reasoning-complete","firstTokenMs":1,"generatedTokens":1,"maximumResidentBytes":1,"minimumAvailableBytes":1,"model":"DeepSeek-R1-Distill-Qwen-7B-Q3_K_M.gguf","tier":"deepseek7B","tokensPerSecond":1,"prompt":"private"}
{"event":"reasoning-language","koreanOutputClean":true}
JSONL
if node "$root/scripts/verifyReasoningEvidence.js" "$work/private.jsonl" >/dev/null 2>&1; then
  echo "reasoning evidence must reject prompt/output fields" >&2
  exit 1
fi

grep -Fq 'verifyReasoningEvidence.js' "$root/device-qa.sh"
echo "Reasoning device evidence contracts passed"
