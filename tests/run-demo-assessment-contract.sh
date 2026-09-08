#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/matths-demo-assessment.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
node - "$ROOT" "$TEST_DIR" <<'NODE'
const fs = require('node:fs');
const [root, out] = process.argv.slice(2);
const model = fs.readFileSync(root+'/Matths/AssessmentV2.swift', 'utf8');
const a = model.indexOf('enum AssessTimeLimit {'), b = model.indexOf('struct PaperMix:');
const c = model.indexOf('enum PaperScope:'), d = model.indexOf('// MARK: - 시험지 조립');
if (!(a >= 0 && b > a && c > b && d > c)) throw new Error('review production model boundaries');
fs.writeFileSync(out+'/Model.swift', 'import Foundation\n'+model.slice(a,b)+model.slice(c,d));
const demo = fs.readFileSync(root+'/Matths/DemoMode.swift', 'utf8');
const start = demo.indexOf('enum DemoTemplate {'), end = demo.indexOf('// MARK: - 경로 → 픽스처 라우터', start);
const escapeStart = demo.indexOf('    static func escaped('), escapeEnd = demo.indexOf('    private static func syncedListEcho(', escapeStart);
if (!(start >= 0 && end > start && escapeStart >= 0 && escapeEnd > escapeStart)) throw new Error('review production demo utility boundaries');
fs.writeFileSync(out+'/DemoTemplate.swift', 'import Foundation\n'+demo.slice(start,end)+
  '\nenum DemoRouter {\n'+demo.slice(escapeStart,escapeEnd)+'\n}\n');
NODE
xcrun swiftc -swift-version 5 -D DEBUG \
  "$ROOT/Matths/AssessmentDraftRecovery.swift" "$TEST_DIR/Model.swift" \
  "$ROOT/Matths/AssessmentSyncAPI.swift" "$TEST_DIR/DemoTemplate.swift" \
  "$ROOT/Matths/DemoFixtures/DemoFixturesAssessment.swift" \
  "$ROOT/tests/DemoAssessmentContractCases.swift" -o "$TEST_DIR/cases"
"$TEST_DIR/cases" "$@"
