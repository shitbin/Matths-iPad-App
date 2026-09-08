#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/matths-assessment-return.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
node - "$ROOT" "$TEST_DIR" <<'NODE'
const fs = require('node:fs');
const [root, out] = process.argv.slice(2);
const source = fs.readFileSync(`${root}/Matths/AssessmentPaperScreen.swift`, 'utf8');
const start = source.indexOf('    private func closePaper()');
const end = source.indexOf('    private func answeredCount(', start);
if (start < 0 || end < start) throw new Error('review production close action boundaries');
fs.writeFileSync(`${out}/ActualClose.swift`,
  'import Foundation\nextension PaperHarness {\n' + source.slice(start, end) +
  'func exerciseClose() { closePaper() }\n}\n');
NODE
xcrun swiftc -swift-version 5 "$ROOT/tests/AssessmentReturnNavigationCases.swift" \
  "$TEST_DIR/ActualClose.swift" -o "$TEST_DIR/cases"
"$TEST_DIR/cases"
