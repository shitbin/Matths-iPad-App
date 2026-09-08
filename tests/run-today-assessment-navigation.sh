#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/matths-today-navigation.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
node - "$ROOT" "$TEST_DIR" <<'NODE'
const fs = require('node:fs'), assert = require('node:assert/strict');
const [root, out] = process.argv.slice(2);
const source = fs.readFileSync(`${root}/Matths/LearningFlowScreens.swift`, 'utf8');
const start = source.indexOf('struct TodayLearningScreen: View'), end = source.indexOf('struct LearningHubScreen: View', start);
assert(start >= 0 && end > start, 'review production Today view boundaries');
const today = source.slice(start, end);
function bodyAfter(marker) {
  const start = today.indexOf(marker);
  assert(start >= 0, `missing actual production marker ${marker}`);
  const opening = today.indexOf('{', start + marker.length);
  let depth = 1, ending = opening + 1;
  while (depth && ending < today.length) {
    if (today[ending] === '{') depth++;
    if (today[ending] === '}') depth--;
    ending++;
  }
  assert(depth === 0, `unclosed production body ${marker}`);
  return today.slice(opening + 1, ending - 1);
}
const perform = bodyAfter('private func perform(_ action: TodayActionCandidate)');
const change = bodyAfter('.onChange(of: store.route)').replace(/^\s*_, _ in/, '');
assert(today.includes('.disabled(actionBusy)'), 'main CTA must expose pending state');
fs.writeFileSync(`${out}/ActualTodayNavigation.swift`, 'import Foundation\nextension TodayNavigationHarness {\n'+
  'private func perform(_ action: TodayActionCandidate) {\n'+perform+'\n}\n'+
  'func exercisePerform(_ action: TodayActionCandidate) { perform(action) }\n'+
  'func exerciseRouteChange() {\n'+change+'\n}\n}\n');
NODE
xcrun swiftc -swift-version 5 "$ROOT/Matths/StudentFlowDomain.swift" \
  "$ROOT/tests/TodayAssessmentNavigationCases.swift" "$TEST_DIR/ActualTodayNavigation.swift" -o "$TEST_DIR/cases"
"$TEST_DIR/cases"
