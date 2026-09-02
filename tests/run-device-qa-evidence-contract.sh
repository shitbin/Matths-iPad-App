#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
work="$(mktemp -d /tmp/matths-device-evidence.XXXXXX)"
trap 'rm -rf "$work"' EXIT

node - "$root" "$work" <<'NODE'
const crypto = require("node:crypto");
const fs = require("node:fs");
const path = require("node:path");
const root = process.argv[2];
const work = process.argv[3];
const { template } = require(path.join(root, "scripts/verifyDeviceQaSession"));
const evidence = Buffer.from("physical device evidence fixture");
fs.writeFileSync(path.join(work, "proof.bin"), evidence);
const digest = crypto.createHash("sha256").update(evidence).digest("hex");
const session = template();
Object.assign(session, {
  deviceModel: "iPad Pro 11-inch (4th generation)",
  osVersion: "iPadOS test",
  appVersion: "1.0",
  appBuild: "1",
  observedAt: "2026-08-11T20:00:00+09:00",
  reviewer: "contract test",
});
for (const row of session.scenarios) {
  row.result = "PASS";
  row.notes = "계약 fixture 관찰";
  row.artifacts = row.artifacts.map((artifact) => ({
    type: artifact.type,
    file: "proof.bin",
    sha256: digest,
  }));
}
fs.writeFileSync(path.join(work, "session.json"), JSON.stringify(session, null, 2));
NODE

node "$root/scripts/verifyDeviceQaSession.js" "$work/session.json" --output "$work/device-evidence.json"
grep -Fq '"schemaVersion": "MATTHS_IPAD_DEVICE_QA_EVIDENCE_V1"' "$work/device-evidence.json"
grep -Fq '"scenarioCount": 22' "$work/device-evidence.json"

node - "$work/session.json" <<'NODE'
const fs = require("node:fs");
const file = process.argv[2];
const value = JSON.parse(fs.readFileSync(file, "utf8"));
value.scenarios.find((row) => row.id === "voiceover-order").result = "PENDING";
fs.writeFileSync(file, JSON.stringify(value));
NODE
if node "$root/scripts/verifyDeviceQaSession.js" "$work/session.json" --output "$work/fail.json" >/dev/null 2>&1; then
  echo "PENDING 실기 시나리오가 통과했습니다." >&2
  exit 1
fi

echo "iPad device QA evidence contract passed"
