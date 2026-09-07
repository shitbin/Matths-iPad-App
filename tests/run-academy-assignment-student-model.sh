#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/matths-academy-assignment-model.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
# The model, authorization owner, Domain and API wrapper compile unchanged.
# Extract only the real draft value and week DTO; replace their external disk
# and HTTP dependencies with deterministic failure/barrier fixtures.
node - "$ROOT" "$WORK" <<'JS'
const fs=require('node:fs'); const [root,work]=process.argv.slice(2);
const draft=fs.readFileSync(root+'/Matths/NativeServiceDraft.swift','utf8');
const end=draft.indexOf('\nenum NativeServiceDraftDisk {');
if(end<0) throw Error('Missing real draft/disk boundary');
fs.writeFileSync(work+'/Draft.swift',draft.slice(0,end));
const api=fs.readFileSync(root+'/Matths/ServerAPI.swift','utf8');
const start=api.indexOf('    struct AcademyWeek:');
const stop=api.indexOf('\n    struct AcademyAttendanceDashboard:',start);
if(start<0||stop<start)throw Error('Missing real week DTO boundaries');
fs.writeFileSync(work+'/Week.swift','import Foundation\nextension ServerAPI {\n'+api.slice(start,stop)+'\n}\n');
JS
xcrun swiftc -swift-version 5 "$ROOT/Matths/AccountRequestOwner.swift" \
  "$ROOT/Matths/AcademyAssignmentDomain.swift" "$ROOT/Matths/AcademyAssignmentAPI.swift" \
  "$ROOT/Matths/AcademyAssignmentStudentModel.swift" "$WORK/Draft.swift" "$WORK/Week.swift" \
  "$ROOT/tests/AcademyAssignmentStudentModelCases.swift" -o "$WORK/cases"
"$WORK/cases"
