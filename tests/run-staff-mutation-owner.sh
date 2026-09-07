#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/matths-staff-mutation-owner.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
node - "$ROOT" "$TEST_DIR" <<'JS'
const fs=require('node:fs');const[root,out]=process.argv.slice(2);
function slice(s,a,b){const i=s.indexOf(a),j=s.indexOf(b,i);if(i<0||j<i)throw Error('Review boundary '+a);return s.slice(i,j)}
const teacher=fs.readFileSync(root+'/Matths/TeacherAcademyScreen.swift','utf8');
const admin=fs.readFileSync(root+'/Matths/AdminUsersScreen.swift','utf8');
function owner(s){return s.includes('    // Immutable mounted-account owner')?slice(s,'    // Immutable mounted-account owner','    // End mounted-account owner'):'init(store:AppStore) {}\n'}
const operations=slice(teacher,'    @discardableResult private func perform(','    private func install(');
fs.writeFileSync(out+'/teacher.swift',`import Foundation
@MainActor final class TeacherHarness {
var generation=UUID();var actionID:String?;var errorMessage:String?;var noticeMessage:String?
var setup:ServerAPI.TeacherAcademySetup?
var dashboard:ServerAPI.TeacherAcademyDashboard?
${owner(teacher)}
${operations}
${slice(teacher,'    func createAcademy(name:','    func requestAcademyJoin(')}
${slice(teacher,'    func review(_ membership:','    func assign(')}
func install(_ value:ServerAPI.TeacherAcademyDashboard){dashboard=value}
func readable(_ error:Error)->String{"controlled-error"}
}
`);
const adminTypes=slice(admin,'private enum AdminUserActionKind:','@MainActor\nfinal class AdminUsersScreenModel:').replaceAll('private ','');
fs.writeFileSync(out+'/admin.swift',`import Foundation
${adminTypes}
@MainActor final class AdminHarness {
var generation=UUID();var actionID:String?;var errorMessage:String?;var noticeMessage:String?
var users:ServerAPI.AdminUserList?
var detail:ServerAPI.AdminUserDetail?
${owner(admin)}
${slice(admin,'    fileprivate func perform(','    private func readable(').replace('fileprivate func perform','func perform')}
func readable(_ error:Error)->String{"controlled-error"}
}
`);
const api=fs.readFileSync(root+'/Matths/AdminUsersAPI.swift','utf8');
fs.writeFileSync(out+'/admin-api.swift','import Foundation\nextension ServerAPI {\n'+slice(api,'    static func requestAdminNicknameChange(','    private static func validateAdminUsersSchema(')+'private static func validateAdminUsersSchema(_ value:String)throws{}\n}\n');
JS
xcrun swiftc -swift-version 5 "$ROOT/Matths/AccountRequestOwner.swift" "$TEST_DIR/teacher.swift" "$TEST_DIR/admin.swift" "$TEST_DIR/admin-api.swift" \
  "$ROOT/tests/StaffMutationOwnerCases.swift" -o "$TEST_DIR/cases"
"$TEST_DIR/cases" "$@"
if [ "${1:-}" != "--demonstrate-before-fix" ]; then
node - "$ROOT" <<'JS'
const fs=require('node:fs'),assert=require('node:assert/strict');const[root]=process.argv.slice(2);
let count=0;
for(const name of ['TeacherAcademyScreen.swift','AdminUsersScreen.swift']) {
 const text=fs.readFileSync(root+'/Matths/'+name,'utf8');
 assert(text.includes('private let accountOwner: AccountRequestOwner?'));
 assert(text.includes('.id(String(describing: store.captureAccountSessionBoundary()) + "#" + (store.serverProfile?.role ?? ""))'));
 const start=text.indexOf(name.startsWith('Teacher')?'    func createAcademy(name:':'    fileprivate func perform(');
 const end=text.indexOf(name.startsWith('Teacher')?'    @discardableResult private func perform(':'    private func reload(',start);
 const section=text.slice(start,end);
 for(const call of section.matchAll(/ServerAPI\.(?:create|request|cancel|update|remove|review|assign|revoke|archive|restore|add|transfer|save|regenerate|send|withdraw|unlink)\w*\(/g)) {
  let i=call.index+call[0].length,depth=1;while(i<section.length&&depth){if(section[i]==='(')depth++;if(section[i]===')')depth--;i++}
  const expression=section.slice(call.index,i);assert(depth===0&&expression.includes('authorization: authorization'),expression);count++;
 }
}
assert(count>=30,'A mutation wrapper disappeared from the audit');
console.log('Mounted account/role view identity + '+count+' explicit mutation-authorization wiring checks passed');
JS
fi
