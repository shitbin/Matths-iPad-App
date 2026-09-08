#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/matths-teacher-classwork-owner.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
node - "$ROOT" "$TEST_DIR" <<'JS'
const fs=require('node:fs'),assert=require('node:assert/strict');const[root,out]=process.argv.slice(2);
function slice(s,a,b){const i=s.indexOf(a),j=s.indexOf(b,i);assert(i>=0&&j>i,'review source boundary '+a);return s.slice(i,j)}
const source=fs.readFileSync(root+'/Matths/TeacherClassworkPanel.swift','utf8');
const api=fs.readFileSync(root+'/Matths/ServerAPI.swift','utf8');
fs.writeFileSync(out+'/model.swift','import Foundation\nimport Combine\n'+slice(source,'@MainActor\nfinal class TeacherClassworkPanelModel:','/// 교사가 휴대전화'));
fs.writeFileSync(out+'/dto.swift','import Foundation\nextension ServerAPI {\n'+slice(api,'    struct AcademyWeek:','    struct AcademyAttendanceDashboard:')+slice(api,'    struct TeacherClassworkCatalogConcept:','    struct AdminAcademyApplicant:')+'}\n');
assert(source.includes('.disabled(model.actionID != nil)'));
assert(source.includes('pickerOwner.isCurrent(in: store), model.actionID == nil'));
assert(source.includes('DisclosureGroup("개념 선택·변경", isExpanded: $showsConceptPicker)'));
assert(source.includes('showsConceptPicker = model.selectedConceptKeys.isEmpty'));
assert(source.includes('let concepts = model.allConcepts.filter(model.matchesSearch)'));
assert(source.includes('Array(concepts.prefix(visibleConceptLimit))'));
assert(source.includes('visibleConceptLimit += 24'));
assert((source.match(/action: requestSave/g)||[]).length===2,'toolbar and footer must share one guarded save confirmation');
assert(source.includes('private func requestSave()'));
JS
xcrun swiftc -swift-version 5 "$ROOT/Matths/AccountRequestOwner.swift" "$ROOT/Matths/AcademyAssignmentDomain.swift" \
  "$TEST_DIR/dto.swift" "$TEST_DIR/model.swift" "$ROOT/tests/TeacherClassworkOwnerCases.swift" -o "$TEST_DIR/cases"
"$TEST_DIR/cases"
