#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/matths-assessment-conflict.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
# Match the app target's SWIFT_VERSION = 5.0 while compiling the actual DataScope.
xcrun swiftc -swift-version 5 \
  "$ROOT/Matths/DataScope.swift" \
  "$ROOT/Matths/AssessmentDraftRecovery.swift" \
  "$ROOT/Matths/AssessmentStartJournal.swift" \
  "$ROOT/Matths/AssessmentSubmissionState.swift" \
  "$ROOT/tests/AssessmentConflictPolicyCases.swift" -o "$TEST_DIR/cases"
"$TEST_DIR/cases"
# Compile the exact production start implementation against a controlled HTTP
# boundary. Do not replace its catch/ownership/persistence logic with a test copy.
node - "$ROOT" "$TEST_DIR" <<'JS'
const fs = require('node:fs');
const [root, out] = process.argv.slice(2);
const source = fs.readFileSync(root+'/Matths/AssessmentV2.swift','utf8');
const a=source.indexOf('enum AssessTimeLimit {'), b=source.indexOf('struct PaperMix:');
const c=source.indexOf('enum PaperScope:'), d=source.indexOf('// MARK: - 시험지 조립');
if(!(a>=0&&b>a&&c>b&&d>c)) throw Error('Review production model boundaries');
fs.writeFileSync(out+'/model.swift','import Foundation\n'+source.slice(a,b)+source.slice(c,d));
const app=fs.readFileSync(root+'/Matths/MatthsApp.swift','utf8');
const start=app.indexOf('    private func startServerPaper('), end=app.indexOf('    func pullServerAssessments()',start);
if(!(start>=0&&end>start)) throw Error('Review production start boundaries');
fs.writeFileSync(out+'/start.swift','import Foundation\nextension AppStore {\n'+app.slice(start,end)+
  'func exerciseAssessmentStart() async { await startServerPaper(scope: .subunit, course: AssessCourse(courseId: "common-math-1"), unit: AssessUnit(unitId: "u"), subunit: AssessSubunit(id: "s"), generation: assessmentStartGeneration, account: account) }\n}\n');
JS
xcrun swiftc -swift-version 5 \
  "$ROOT/Matths/AssessmentDraftRecovery.swift" "$ROOT/Matths/AssessmentStartJournal.swift" \
  "$TEST_DIR/model.swift" "$ROOT/Matths/AssessmentSyncAPI.swift" "$TEST_DIR/start.swift" \
  "$ROOT/tests/AssessmentStartCompatibilityCases.swift" -o "$TEST_DIR/start-cases"
"$TEST_DIR/start-cases"
# Integration wiring checks supplement (not replace) the runtime model/journal tests.
grep -Fq 'AssessmentStartJournal.shared.acknowledgeAbandoned(' "$ROOT/Matths/MatthsApp.swift"
grep -Fq 'sentStartTicket = clientStartID' "$ROOT/Matths/MatthsApp.swift"
grep -Fq 'holdPendingDraftForReview(id: id)' "$ROOT/Matths/MatthsApp.swift"
grep -Fq 'assessmentSubmissionState = .recovery(attemptID: id, retryAfter: nil)' "$ROOT/Matths/MatthsApp.swift"
grep -Fq 'let payload = current.pendingDraft?.pending ?? [:]' "$ROOT/Matths/MatthsApp.swift"
grep -Fq 'let payload = latestLocal.pendingDraft?.pending ?? [:]' "$ROOT/Matths/MatthsApp.swift"
grep -Fq 'a.legacyDraftEvidence?[questionID] = value' "$ROOT/Matths/MatthsApp.swift"
grep -Fq 'if await handleAssessmentConflict(error, id: attempt.id,' "$ROOT/Matths/MatthsApp.swift"
grep -Fq '보관된 기기 답안 확인' "$ROOT/Matths/AssessmentPaperScreen.swift"
echo 'Assessment conflict app integration guards: PASS'
