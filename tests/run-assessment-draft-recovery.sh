#!/bin/bash
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
scratch=$(mktemp -d /tmp/matths-assessment-recovery.XXXXXX)
swiftc "$root/Matths/AssessmentDraftRecovery.swift" "$root/Matths/AssessmentSubmissionState.swift" "$root/tests/AssessmentDraftRecoveryCases.swift" -o "$scratch/cases"
"$scratch/cases"
swiftc "$root/Matths/DataScope.swift" "$root/Matths/AssessmentDraftRecovery.swift" "$root/Matths/AssessmentStartJournal.swift" "$root/tests/AssessmentStartJournalCases.swift" -o "$scratch/start-cases"
"$scratch/start-cases"
# Compile the actual production model declarations without the unrelated JSBank
# generator. No model implementation is copied into a test substitute.
node - "$root" "$scratch/model.swift" <<'JS'
const fs = require('fs');
const source = fs.readFileSync(process.argv[2]+'/Matths/AssessmentV2.swift','utf8');
const a = source.indexOf('enum AssessTimeLimit {'), b = source.indexOf('struct PaperMix:');
const c = source.indexOf('enum PaperScope:'), d = source.indexOf('// MARK: - 시험지 조립');
if (!(a>=0 && b>a && c>b && d>c)) throw Error('Production model boundaries changed: review this harness');
fs.writeFileSync(process.argv[3], 'import Foundation\n'+source.slice(a,b)+source.slice(c,d));
JS
swiftc "$root/Matths/DataScope.swift" "$root/Matths/AssessmentDraftRecovery.swift" "$scratch/model.swift" \
  "$root/Matths/AssessmentSyncAPI.swift" "$root/tests/AssessmentStoreMergeCases.swift" -o "$scratch/merge-cases"
"$scratch/merge-cases"
swiftc "$root/Matths/DataScope.swift" "$root/Matths/AssessmentDraftRecovery.swift" "$scratch/model.swift" \
  "$root/Matths/AssessmentSyncAPI.swift" "$root/tests/AssessmentRevisionAPICases.swift" -o "$scratch/revision-cases"
"$scratch/revision-cases"
if [ "${1:-}" = "--http-fixture" ]; then
  test -n "${2:-}"
  swiftc "$root/Matths/DataScope.swift" "$root/Matths/AssessmentDraftRecovery.swift" "$scratch/model.swift" \
    "$root/Matths/AssessmentSyncAPI.swift" "$root/tests/AssessmentRevisionHTTPFixtureCases.swift" -o "$scratch/http-cases"
  "$scratch/http-cases" "$2"
fi
