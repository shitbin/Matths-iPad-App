#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d /tmp/matths-ling3-candidate.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

xcrun swiftc \
  "$ROOT/Matths/ExperimentalLocalModelCatalog.swift" \
  "$ROOT/tests/Ling3CandidateCases.swift" \
  -o "$WORK/ling3-candidate-cases"
"$WORK/ling3-candidate-cases"

FRAMEWORK="$ROOT/Frameworks/llama.xcframework/ios-arm64/llama.framework/llama"
strings "$FRAMEWORK" > "$WORK/llama-strings.txt"
grep -Fq 'bailingmoe3' "$WORK/llama-strings.txt"

grep -Fq 'debugUserSelectable: true' "$ROOT/Matths/ExperimentalLocalModelCatalog.swift"
grep -Fq 'shippingEligible: false' "$ROOT/Matths/ExperimentalLocalModelCatalog.swift"
grep -Fq 'case "ling3-q3": return specLing3Q3' "$ROOT/Matths/LocalLLM.swift"
grep -Fq '#if DEBUG' "$ROOT/Matths/DebugLocalModelSelector.swift"
grep -Fq 'Ling 3.0 tiny Q3' "$ROOT/Matths/DebugLocalModelSelector.swift"
grep -Fq 'Release에는 노출되지 않습니다.' "$ROOT/Matths/DebugLocalModelSelector.swift"
grep -Fq 'tier: vision3B, deepseek7B, ling3-q3' "$ROOT/device-qa.sh"
echo "Ling 3.0 tiny DEBUG selection/runtime isolation contract passed"
