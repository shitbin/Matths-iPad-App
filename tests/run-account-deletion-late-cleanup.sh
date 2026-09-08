#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/matths-deletion-cleanup.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
node - "$ROOT" "$TEST_DIR" <<'NODE'
const fs = require('node:fs');
const [root, out] = process.argv.slice(2);
const source = fs.readFileSync(`${root}/Matths/ProfileScreen.swift`, 'utf8');
const start = source.indexOf('    private func submit()');
const end = source.indexOf('    private static func withdrawalFailureMessage(', start);
if (start < 0 || end < start) throw new Error('review withdrawal source boundaries');
fs.writeFileSync(`${out}/ActualSubmit.swift`, 'import Foundation\nextension DeletionHarness {\n'+source.slice(start,end)+
  'func exerciseSubmit() { submit() }\n}\n');
NODE
xcrun swiftc -swift-version 5 "$ROOT/Matths/AccountRequestOwner.swift" \
  "$ROOT/tests/AccountDeletionLateCleanupCases.swift" "$TEST_DIR/ActualSubmit.swift" -o "$TEST_DIR/cases"
"$TEST_DIR/cases"
