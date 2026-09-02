#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(mktemp -d /tmp/matths-local-ai-pilot.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

node - "$WORK/pilot-labeled.jsonl" <<'NODE'
const fs = require("node:fs");
const crypto = require("node:crypto");
const out = [];
const source = (id) => crypto.createHash("sha256").update(`source-${id}`).digest("hex");
const review = {primaryLabeler:"reviewer-a",secondaryLabeler:"reviewer-b",agreed:true};
for (let i = 1; i <= 100; i += 1) {
  const id = `H-${String(i).padStart(3, "0")}`;
  out.push({kind:"handwriting",sampleId:id,sourceSha256:source(id),review,
    expected:{problems:[{problemId:"1",finalAnswer:"12",requiredSteps:["미분"]}]},
    observed:{unreadable:false,problems:[{problemId:"1",finalAnswer:"12",recognizedSteps:["미분"]}]}});
}
for (let i = 1; i <= 200; i += 1) {
  const id = `C-${String(i).padStart(3, "0")}`;
  const verdict = i <= 100 ? "suspicious" : "normal";
  out.push({kind:"cheating",sampleId:id,sourceSha256:source(id),review,
    expected:{verdict},observed:{verdict}});
}
for (let i = 1; i <= 100; i += 1) {
  const id = `G-${String(i).padStart(3, "0")}`;
  out.push({kind:"grading-tutor",sampleId:id,sourceSha256:source(id),review,
    expected:{verdict:"correct",finalAnswer:"12",requiredConcepts:["미분"],forbiddenClaims:["항상 증가"]},
    observed:{verdict:"correct",finalAnswer:"12",mentionedConcepts:["미분"],tutorAnswer:"임계점을 확인합니다.",unsafeClaim:false}});
}
fs.writeFileSync(process.argv[2], out.map((row) => JSON.stringify(row)).join("\n") + "\n");
NODE

node "$HERE/evaluation/evaluate-local-ai.mjs" \
  "$WORK/pilot-labeled.jsonl" --json "$WORK/report.json"
node - "$WORK/report.json" "$WORK/metadata.json" <<'NODE'
const fs = require("node:fs");
const report = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
fs.writeFileSync(process.argv[3], JSON.stringify({
  deviceModel:"iPad Pro 11-inch (4th generation)", osVersion:"iPadOS test",
  modelFileSha256:"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  quantization:"Q2_K", datasetVersion:"pilot-v1",
  datasetSourceSha256:report.dataset.sourceSha256,
  reviewerProtocol:"two independent reviewers, disagreement to adjudication",
}));
NODE

node "$HERE/evaluation/gate-local-ai.mjs" \
  "$WORK/report.json" "$WORK/metadata.json" --dataset "$WORK/pilot-labeled.jsonl" --output "$WORK/gate.json"
grep -Fq '"result": "PASS"' "$WORK/gate.json"

cp "$WORK/metadata.json" "$WORK/metadata.original.json"
node - "$WORK/metadata.json" <<'NODE'
const fs = require("node:fs");
const file = process.argv[2];
const value = JSON.parse(fs.readFileSync(file, "utf8"));
value.datasetSourceSha256 = "dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd";
fs.writeFileSync(file, JSON.stringify(value));
NODE
if node "$HERE/evaluation/gate-local-ai.mjs" \
    "$WORK/report.json" "$WORK/metadata.json" --dataset "$WORK/pilot-labeled.jsonl" --output "$WORK/mismatch-gate.json"; then
  echo "dataset hash mismatch must fail" >&2
  exit 1
fi
grep -Fq '"name": "dataset.sourceBinding"' "$WORK/mismatch-gate.json"

mv "$WORK/metadata.original.json" "$WORK/metadata.json"

node "$HERE/evaluation/evaluate-local-ai.mjs" \
  "$HERE/evaluation/fixtures/demo-labeled.jsonl" --json "$WORK/demo.json"
if node "$HERE/evaluation/gate-local-ai.mjs" \
    "$WORK/demo.json" "$WORK/metadata.json" --dataset "$HERE/evaluation/fixtures/demo-labeled.jsonl" --output "$WORK/demo-gate.json"; then
  echo "demo fixture must not pass the pilot gate" >&2
  exit 1
fi
grep -Fq '"result": "FAIL"' "$WORK/demo-gate.json"
echo "Local AI pilot quality gate contracts passed"
