#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/matths-student-academy.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
# Compile the exact Foundation-compatible model prefix, replacing only SwiftUI's
# umbrella import. No model method is mocked or translated for the host test.
node - "$ROOT/Matths/AcademyScreen.swift" "$TEST_DIR/AcademyModel.swift" <<'NODE'
const fs = require('node:fs');
const source = fs.readFileSync(process.argv[2], 'utf8');
const boundary = source.indexOf('/// 학생이 웹 로그인을');
if (boundary < 0) throw new Error('missing model/view boundary');
fs.writeFileSync(process.argv[3], source.slice(0, boundary).replace('import SwiftUI', 'import Foundation\nimport Combine'));
NODE
xcrun swiftc -swift-version 5 "$ROOT/Matths/AccountRequestOwner.swift" \
  "$TEST_DIR/AcademyModel.swift" "$ROOT/tests/StudentAcademyOwnershipCases.swift" -o "$TEST_DIR/cases"
"$TEST_DIR/cases"
node - "$ROOT/Matths/AcademyScreen.swift" "$ROOT/Matths/ServerAPI.swift" <<'NODE'
const fs = require('node:fs'), assert = require('node:assert/strict');
const source = fs.readFileSync(process.argv[2], 'utf8');
const api = fs.readFileSync(process.argv[3], 'utf8');
assert(source.includes('private func run(_ operation: @escaping (AccountRequestOwner) async -> Void)'));
assert(source.includes('guard let owner = leavingOwner, owner.isCurrent(in: store)'));
assert(source.includes('.onDisappear { model.retire();'));
assert(!source.includes('await model.load()'));
const student = api.slice(api.indexOf('static func academyDashboard('), api.indexOf('static func teacherAcademyDashboard('));
assert.equal((student.match(/authorization: authorization/g) || []).length, 6);
assert.equal((student.match(/AuthorizationSnapshot = authorizationForCurrentRequest\(\)/g) || []).length, 6);
console.log('Student academy UI owner-before-Task and all six API snapshot forwarding paths checked');
NODE
