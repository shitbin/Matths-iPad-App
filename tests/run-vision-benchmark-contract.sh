#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
source="$root/Matths/VisionSelfTest.swift"
engine="$root/Matths/LocalLLM.swift"
grader="$root/Matths/SheetGrader.swift"

grep -Fq 'selftest-metrics.jsonl' "$source"
grep -Fq 'private static func residentBytes()' "$source"
grep -Fq 'minimumAvailableBytes' "$source"
grep -Fq 'maximumResidentBytes' "$source"
grep -Fq 'firstTokenMs' "$source"
grep -Fq 'tokensPerSecond' "$source"
grep -Fq 'metric("load-complete"' "$source"
grep -Fq 'metric("preflight-complete"' "$source"
grep -Fq 'metric("vision-complete"' "$source"
grep -Fq 'metric("vision-failed"' "$source"
grep -Fq 'LocalAIModelPack.verifyExistingArtifact(spec.file)' "$source"
grep -Fq 'LocalModelPrompt.oneShot(' "$source"
grep -Fq 'mp.image_min_tokens = isQwen25VL ? 1_024 : 0' "$engine"
grep -Fq 'mp.image_max_tokens = isQwen25VL ? 1_024 : 768' "$engine"
grep -Fq 'mparams.n_gpu_layers = (tightVisionMemory || willTryVision) ? 0 : 99' "$engine"
grep -Fq 'let cpuOnly = tightVisionMemory || willTryVision' "$engine"
grep -Fq 'DataScope.url("grader-runs")' "$source"
grep -Fq 'DataScope.url("cheating-reviews/images")' "$source"
cheating_line=$(grep -nF 'DataScope.url("cheating-reviews/images")' "$source" | head -n 1 | cut -d: -f1)
grader_line=$(grep -nF 'DataScope.url("grader-runs")' "$source" | head -n 1 | cut -d: -f1)
if [ "$cheating_line" -ge "$grader_line" ]; then
  echo "Vision benchmark must prefer normalized work images over camera test photos" >&2
  exit 1
fi
grep -Fq 'DataScope.url("selftest-metrics.jsonl")' "$source"
grep -Fq 'restoreForcedTierIfNeeded' "$source"
grep -Fq 'MatthsDiagnostics' "$source"
grep -Fq 'allowedKeys' "$source"
if grep -Fq '"image", "error"' "$source"; then
  echo "Diagnostic export must not include the source image or raw error path" >&2
  exit 1
fi
if grep -Fq 'slots/guest/grader-runs' "$source"; then
  echo "Vision benchmark must use the active account slot" >&2
  exit 1
fi
grep -Fq 'nonisolated static func parseJSON' "$grader"
grep -Fq 'nonisolated static func repairLatexEscapes' "$grader"
grep -Fq 'nonisolated private static func closeTruncated' "$grader"

echo "Vision load, first-token, throughput, and peak-memory benchmark contracts passed"
