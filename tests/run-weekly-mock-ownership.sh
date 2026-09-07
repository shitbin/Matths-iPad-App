#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/matths-weekly-owner.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
xcrun swiftc -swift-version 5 "$ROOT/Matths/AccountRequestOwner.swift" \
  "$ROOT/Matths/WeeklyMockOperationGate.swift" "$ROOT/Matths/WeeklyMockAPI.swift" \
  "$ROOT/tests/WeeklyMockOwnershipCases.swift" -o "$TEST_DIR/cases"
"$TEST_DIR/cases"
node - "$ROOT/Matths/WeeklyMockScreen.swift" <<'NODE'
const fs = require('node:fs');
const source = fs.readFileSync(process.argv[2], 'utf8');
const assert = require('node:assert/strict');
assert(source.includes('@State private var owner: AccountRequestOwner?'));
assert(source.includes('.id(owner?.id)'));
assert((source.match(/requests\.retire\(\)/g) || []).length === 5);
assert((source.match(/private func revokeAccess\(\)/g) || []).length === 4);
assert(!source.includes('if !silent { attempt = nil }'));
assert((source.match(/requests\.accepts\(request\)/g) || []).length >= 20);
let calls = 0;
for (const call of source.matchAll(/ServerAPI\.(?:weeklyMock|startWeekly|saveWeekly|submitWeekly|expireWeekly|selectWeekly|createWeekly|downloadWeekly)\w*\(/g)) {
  let end = call.index + call[0].length, depth = 1;
  while (end < source.length && depth) {
    const c = source[end++];
    if (c === '(') depth++;
    if (c === ')') depth--;
  }
  const expression = source.slice(call.index, end);
  assert(depth === 0 && expression.includes('authorization: owner.authorization'), `missing frozen authorization: ${expression}`);
  calls++;
}
assert(calls >= 14, 'weekly requests disappeared from the wiring audit');
console.log('Weekly mock screen lifetime, protected-state eviction and frozen API wiring checks passed');
NODE
