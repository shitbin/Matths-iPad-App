#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
CACHE="${TMPDIR:-/tmp}/matths-local-ai-recovery-module-cache"
mkdir -p "$CACHE"

xcrun swiftc \
  -module-cache-path "$CACHE" \
  "$ROOT/Matths/ProtectedFileWriter.swift" \
  "$ROOT/Matths/DataScope.swift" \
  "$ROOT/Matths/LocalAIJobRecovery.swift" \
  "$ROOT/tests/LocalAIJobRecoveryCases.swift" \
  -o "${TMPDIR:-/tmp}/matths-local-ai-recovery-tests"

"${TMPDIR:-/tmp}/matths-local-ai-recovery-tests"

grep -Fq '운영체제가 허용하는 짧은 시간 동안만 이어집니다.' "$ROOT/Matths/ProScreen.swift"
grep -Fq '같은 사진·모델의 완료 기록이 있으면 재사용' "$ROOT/Matths/ProScreen.swift"
grep -Fq 'LocalAIAnalysisJournal(image:' "$ROOT/Matths/SheetGrader.swift"
# The shared language/output policy now wraps every stage schema. Require both
# that policy and its actual use at the original/repair/cache boundaries.
grep -Fq 'guard LocalModelOutputPolicy.isStudentFacingObjectAcceptable(object) else { return false }' "$ROOT/Matths/SheetGraderStageSchema.swift"
grep -Fq 'return LocalModelOutputPolicy.isProblemAnalysisObjectAcceptable(object)' "$ROOT/Matths/SheetGraderStageSchema.swift"
node - "$ROOT/Matths/SheetGrader.swift" <<'NODE'
const fs = require('node:fs'), assert = require('node:assert/strict');
const source = fs.readFileSync(process.argv[2], 'utf8');
function section(name, next) {
  const start = source.indexOf(`private func ${name}(`);
  const end = source.indexOf(next, start + 1);
  assert(start >= 0 && end > start, `missing ${name} boundary`);
  return source.slice(start, end);
}
for (const [name, next] of [['visionJSON', 'private func textJSON('], ['textJSON', 'private func restoreCheckpoint(']]) {
  const body = section(name, next);
  assert(body.includes('schema.accepts(obj)'), `${name}: original response validation removed`);
  assert(body.includes('restoreCheckpoint(key: checkpointKey, schema: schema)'), `${name}: restore lost schema`);
  assert(body.includes('saveCheckpoint(obj, key: checkpointKey, schema: schema)'), `${name}: original save lost schema`);
  assert(body.includes('saveCheckpoint(repaired, key: checkpointKey, schema: schema)'), `${name}: repaired save lost schema`);
}
const restore = section('restoreCheckpoint', 'private func saveCheckpoint(');
assert(restore.indexOf('guard schema.accepts(object)') < restore.indexOf('resumedCheckpointCount += 1'));
assert(restore.includes('guard schema.accepts(object)'));
const save = section('saveCheckpoint', 'private func repair(');
assert(save.includes('schema.accepts(object)') && save.indexOf('schema.accepts(object)') < save.indexOf('analysisJournal?.save'));
const repair = section('repair', 'private static func modelPrompt(');
assert(repair.includes('schema.requiredShapeDescription'));
assert(repair.includes('schema.accepts(obj)') && repair.includes('throw SheetError('));
console.log('Recovery keeps generic output policy plus explicit stage schema on original, repair, restored and persisted objects');
NODE
grep -Fq 'params.shouldCancel = { callCancel.isSet }' "$ROOT/Matths/SheetGrader.swift"
grep -Fq 'UIApplication.didReceiveMemoryWarningNotification' "$ROOT/Matths/LocalAIBackgroundExecution.swift"
grep -Fq 'self?.interruptWork(.backgroundExpired)' "$ROOT/Matths/LocalAIBackgroundExecution.swift"
grep -Fq 'beginBackgroundTask' "$ROOT/Matths/LocalAIBackgroundExecution.swift"
grep -Fq 'LocalAIRecoverySelfTest.runIfRequested()' "$ROOT/Matths/MatthsApp.swift"
grep -Fq 'MATTHS_LOCAL_AI_RECOVERY_DEVICE_QA_V1' "$ROOT/Matths/LocalAIRecoverySelfTest.swift"
grep -Fq 'LocalAIJobRecovery.restore(in: recovery)' "$ROOT/Matths/LocalAIRecoverySelfTest.swift"
grep -Fq 'LocalAIJobRecovery.clear(in: recovery)' "$ROOT/Matths/LocalAIRecoverySelfTest.swift"
grep -Fq 'LocalAIBackgroundSelfTest.startIfRequested()' "$ROOT/Matths/MatthsApp.swift"
grep -Fq 'LocalAIBackgroundSelfTest.recordBackgroundIfRequested()' "$ROOT/Matths/MatthsApp.swift"
grep -Fq 'MATTHS_LOCAL_AI_BACKGROUND_DEVICE_QA_V1' "$ROOT/Matths/LocalAIBackgroundSelfTest.swift"
grep -Fq 'backgroundTaskActive' "$ROOT/Matths/LocalAIBackgroundSelfTest.swift"
grep -Fq 'NotificationCenter.default.post(name: didSwitchNotification' "$ROOT/Matths/DataScope.swift"
grep -Fq 'DataScope.didSwitchNotification' "$ROOT/Matths/ProScreen.swift"
grep -Fq 'analysisOwnerSlot == DataScope.slot' "$ROOT/Matths/ProScreen.swift"
grep -Fq 'guard self.activeRunID == runID else' "$ROOT/Matths/SheetGrader.swift"
grep -Fq 'activeRunID = nil' "$ROOT/Matths/SheetGrader.swift"
grep -Fq 'private static func userFacingFailure(_ error: Error) -> String' "$ROOT/Matths/SheetGrader.swift"
grep -Fq 'self.error = Self.userFacingFailure(error)' "$ROOT/Matths/SheetGrader.swift"
grep -Fq '보존된 사진으로 다시 시도해 주세요.' "$ROOT/Matths/SheetGrader.swift"
grep -Fq 'case "multi-page":' "$ROOT/Matths/SheetGrader.swift"
if grep -Fq 'self.error = (error as? SheetError)?.message ?? "\(error)"' "$ROOT/Matths/SheetGrader.swift" ||
   grep -Fq '수학 시험지 사진이 아닙니다 (\(pageKind))' "$ROOT/Matths/SheetGrader.swift" ||
   grep -Fq 's1["note"] as? String' "$ROOT/Matths/SheetGrader.swift"; then
  echo 'SheetGrader raw engine or model-authored error can reach the Pro screen.' >&2
  exit 1
fi
