#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
api="$root/Matths/AdminDataAnalysisAPI.swift"
screen="$root/Matths/AdminDataAnalysisScreen.swift"
fixture="$root/Matths/DemoAdminDataAnalysisFixtures.swift"
demo="$root/Matths/DemoMode.swift"
admin="$root/Matths/AdminAcademyScreen.swift"
for file in "$api" "$screen" "$fixture" "$demo" "$admin"; do [ -f "$file" ] || { echo "FAIL missing $file" >&2; exit 1; }; done
for value in ADMIN_DATA_ANALYSIS_NATIVE_V1 adminDataAnalysis rebuildAdminDataAnalysis '/api/v1/admin/data-analysis'; do grep -Fq "$value" "$api" || { echo "FAIL missing API $value" >&2; exit 1; }; done
for value in '운영 지표' '원본 기록에서 다시 집계' 'verticalSizeClass == .compact' '출시 전 가정 비교' '분자' '분모' '표본'; do grep -Fq "$value" "$screen" || { echo "FAIL missing UI $value" >&2; exit 1; }; done
node - "$screen" <<'NODE'
const fs = require('node:fs'), assert = require('node:assert/strict');
const source = fs.readFileSync(process.argv[2], 'utf8');
function verify(source) {
  const modelStart = source.indexOf('func rebuild() async {');
  const modelEnd = source.indexOf('private func readable(', modelStart);
  assert(modelStart >= 0 && modelEnd > modelStart, 'rebuild model handler removed');
  const model = source.slice(modelStart, modelEnd);
  assert(model.includes('guard let period = value?.period.periodKey, !rebuilding else'), 'rebuild period/busy guard removed');
  const send = model.indexOf('try await ServerAPI.rebuildAdminDataAnalysis(period: period)');
  const reload = model.indexOf('value = try await ServerAPI.adminDataAnalysis(period: period)');
  assert(send >= 0 && reload > send, 'rebuild must call the canonical API then reload the same period');
  const dialogStart = source.indexOf('.confirmationDialog('), headerStart = source.indexOf('private var header:');
  assert(dialogStart >= 0 && headerStart > dialogStart, 'rebuild confirmation dialog missing');
  const dialog = source.slice(dialogStart, headerStart);
  assert(dialog.includes('isPresented: $confirmsRebuild'), 'rebuild confirmation state disconnected');
  assert(dialog.includes('Button("다시 집계") { Task { await model.rebuild() } }'), 'confirmed rebuild action disconnected');
  assert(dialog.includes('Button("취소", role: .cancel)'), 'rebuild cancellation removed');
  const header = source.slice(headerStart, source.indexOf('@ViewBuilder private func content(', headerStart));
  assert(header.includes('confirmsRebuild = true'), 'header bypasses confirmation');
  assert(header.includes('.disabled(model.rebuilding || model.value == nil)'), 'rebuild readiness/busy control removed');
}
verify(source);
assert.throws(() => verify(source.replace('await model.rebuild()', '')), /confirmed rebuild action/);
assert.throws(() => verify(source.replace('try await ServerAPI.rebuildAdminDataAnalysis(period: period)', '')), /canonical API/);
assert.throws(() => verify(source.replace('.disabled(model.rebuilding || model.value == nil)', '')), /readiness\/busy/);
console.log('Admin rebuild confirmation, canonical handler, same-period reload and mutation guards passed');
NODE
grep -Fq 'GET /api/v1/admin/data-analysis' "$demo"
grep -Fq '"월별 운영 지표"' "$root/Matths/StaffWorkspaceState.swift"
echo "native admin data analysis contract passed"
