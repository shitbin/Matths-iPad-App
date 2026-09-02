#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(mktemp -d /tmp/matths-local-ai-eval.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

node "$HERE/evaluation/evaluate-local-ai.mjs" \
  "$HERE/evaluation/fixtures/demo-labeled.jsonl" \
  --json "$WORK/report.json" \
  --markdown "$WORK/report.md"

node - "$WORK/report.json" <<'NODE'
const fs = require("node:fs");
const report = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
function same(actual, expected, label) {
  if (actual !== expected) throw new Error(`${label}: expected ${expected}, got ${actual}`);
}
same(report.schemaVersion, "MATTHS_LOCAL_AI_EVAL_V1", "schema");
same(report.dataset.uniqueSamples, 8, "unique samples");
same(report.dataset.fixtureLike, true, "demo fixture marker");
same(report.dataset.sourceHashesValid, 0, "demo has no source evidence");
same(report.dataset.independentlyReviewed, 0, "demo has no independent labels");
same(report.handwriting.problemRecall, 1, "handwriting recall");
same(report.handwriting.finalAnswerAccuracy, 0.5, "answer accuracy");
same(report.handwriting.stepCoverage, 0.75, "step coverage");
same(report.handwriting.unreadableRate, 0.5, "unreadable rate");
same(report.cheating.suspiciousPrecision, 0.5, "cheating precision");
same(report.cheating.suspiciousRecall, 0.5, "cheating recall");
same(report.cheating.suspiciousF1, 0.5, "cheating F1");
same(report.cheating.normalFalsePositiveRate, 0.5, "normal false positive");
same(report.cheating.inconclusiveRate, 0.25, "inconclusive rate");
same(report.gradingTutor.verdictAccuracy, 0.5, "verdict accuracy");
same(report.gradingTutor.finalAnswerAccuracy, 0.5, "grader answer accuracy");
same(report.gradingTutor.requiredConceptCoverage, 0.6667, "concept coverage");
same(report.gradingTutor.hallucinatedClaimCount, 1, "hallucination count");
same(report.gradingTutor.unsafeClaimRate, 0.5, "unsafe rate");
NODE

grep -q "제품 정확도 증거로 쓰면 안 된다" "$HERE/evaluation/README.md"
grep -q "Matths 로컬 AI 라벨 평가 결과" "$WORK/report.md"

printf '%s\n%s\n' \
  '{"kind":"cheating","sampleId":"DUP","expected":{"verdict":"normal"},"observed":{"verdict":"normal"}}' \
  '{"kind":"cheating","sampleId":"DUP","expected":{"verdict":"normal"},"observed":{"verdict":"normal"}}' \
  > "$WORK/duplicate.jsonl"
if node "$HERE/evaluation/evaluate-local-ai.mjs" "$WORK/duplicate.jsonl" > /dev/null 2>&1; then
  echo "duplicate sampleId must fail" >&2
  exit 1
fi
echo "Local AI 라벨 평가 계약 통과"
