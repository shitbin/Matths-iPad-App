#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/matths-sheet-schema.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
xcrun swiftc "$ROOT/Matths/LocalModelPrompt.swift" "$ROOT/Matths/SheetGraderStageSchema.swift" \
  "$ROOT/tests/SheetGraderStageSchemaCases.swift" -o "$TEST_DIR/cases"
"$TEST_DIR/cases"
node - "$ROOT/Matths/SheetGrader.swift" <<'NODE'
const fs = require('node:fs'), assert = require('node:assert/strict');
const source = fs.readFileSync(process.argv[2], 'utf8');
assert.equal((source.match(/maxTokens: \d+, schema: \./g) || []).length, 9);
assert.equal((source.match(/schema\.accepts\(/g) || []).length, 5);
assert(source.includes('schema.requiredShapeDescription'));
assert(source.includes('debugRejectedCheckpointObserver?(stage ?? .inventory)'));
assert(!source.includes('valid는 풀이 전체가 모두 맞을 때만 true'));
console.log('SheetGrader initial, repaired, restored and saved JSON all use the explicit stage schema');
NODE
