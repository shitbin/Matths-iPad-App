#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
node - "$ROOT" <<'NODE'
const fs = require('node:fs'), cp = require('node:child_process'), assert = require('node:assert/strict');
const root = process.argv[2];
const manifest = JSON.parse(cp.execFileSync('plutil', ['-convert', 'json', '-o', '-', `${root}/Matths/PrivacyInfo.xcprivacy`], {encoding:'utf8'}));
const source = fs.readFileSync(`${root}/Matths/GoatArenaPaybackAccountSheet.swift`, 'utf8');
const arena = fs.readFileSync(`${root}/Matths/GoatArenaScreen.swift`, 'utf8');
const doc = fs.readFileSync(`${root}/appstore/app-privacy-ko.md`, 'utf8');
const entries = manifest.NSPrivacyCollectedDataTypes;
assert.equal(new Set(entries.map(x => x.NSPrivacyCollectedDataType)).size, entries.length, 'duplicate collected-data type');
assert(source.includes('static func confirmGoatArenaPaybackAccount('));
assert(source.includes('"/api/v1/goat-arena/profile/payback-account/confirm"'));
for (const field of ['bankName', 'accountHolderName', 'accountNumber']) {
  assert(source.includes(`"${field}": ${field}`), `review actual bank payload ${field}`);
  assert(doc.includes(field), `public response instructions omit ${field}`);
}
assert(arena.includes('GoatArenaPaybackAccountSheet()'), 'review the actual native feature entry');
const payment = entries.filter(x => x.NSPrivacyCollectedDataType === 'NSPrivacyCollectedDataTypePaymentInfo');
assert.equal(payment.length, 1, 'native bank-account collection requires PaymentInfo');
assert.equal(payment[0].NSPrivacyCollectedDataTypeLinked, true);
assert.equal(payment[0].NSPrivacyCollectedDataTypeTracking, false);
assert.deepEqual(payment[0].NSPrivacyCollectedDataTypePurposes, ['NSPrivacyCollectedDataTypePurposeAppFunctionality']);
assert.equal(manifest.NSPrivacyTracking, false);
assert.deepEqual(manifest.NSPrivacyTrackingDomains, []);
assert(doc.includes('| 금융 정보 | 결제 정보 |'));
assert(doc.includes('NSPrivacyCollectedDataTypePaymentInfo'));
assert(doc.includes('App Store Connect 게시 완료를 의미하지 않습니다'));
assert(!doc.includes('이 iOS 앱 버전의 입력 경로가\n  아니다'));
console.log('PASS: actual native bank-account route/payload matches linked, non-tracking app-functionality PaymentInfo and publication-pending documentation');
NODE
