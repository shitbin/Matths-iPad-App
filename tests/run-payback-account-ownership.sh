#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/matths-payback-owner.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
node - "$ROOT" "$TEST_DIR" <<'NODE'
const fs = require('node:fs');
const [root, out] = process.argv.slice(2);
const source = fs.readFileSync(`${root}/Matths/GoatArenaPaybackAccountSheet.swift`, 'utf8');
const apiEnd = source.indexOf('/// 페이백 지급 계좌를 앱 안에서');
const propsStart = source.indexOf('    private var cleanBankName:'), propsEnd = source.indexOf('    var body:', propsStart);
const methodsStart = source.indexOf('    @MainActor\n    private func load'), methodsEnd = source.lastIndexOf('\n}');
if (!(apiEnd > 0 && propsStart > apiEnd && propsEnd > propsStart && methodsStart > propsEnd && methodsEnd > methodsStart)) throw new Error('review payback production boundaries');
if (!source.includes('private func save(_ submission: GoatArenaPaybackAccountSubmission)')) throw new Error('immutable owner-bound confirmation is missing');
if (!source.includes('guard let submission = confirmation, accepts(submission.owner) else { return }')) throw new Error('confirmation must capture owner before Task');
if (!source.includes('form\n                        .disabled(isSaving)')) throw new Error('form must not accept edits that a pending save would erase');
fs.writeFileSync(`${out}/ActualPayback.swift`, source.slice(0,apiEnd).replace('import SwiftUI', 'import Foundation')+
 '\nextension PaybackHarness {\n'+source.slice(propsStart,propsEnd)+source.slice(methodsStart,methodsEnd)+
 '\nfunc prepareConfirmation() { reviewDraft() }\nfunc clearForTest() { clearSensitiveDraft() }\n'+
 'func exerciseSave() async { guard let submission = confirmation else { return }; await save(submission) }\nfunc exerciseLoad() async { guard let owner = mountedOwner else { return }; await load(owner: owner) }\n}\n');
NODE
xcrun swiftc -swift-version 5 "$ROOT/Matths/AccountRequestOwner.swift" \
  "$ROOT/tests/PaybackAccountOwnershipCases.swift" "$TEST_DIR/ActualPayback.swift" -o "$TEST_DIR/cases"
"$TEST_DIR/cases"
