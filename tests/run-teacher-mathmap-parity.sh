#!/bin/bash
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
scratch=$(mktemp -d /tmp/matths-map-parity.XXXXXX)
node - "$root" "$scratch" <<'JS'
const fs=require('node:fs'),assert=require('node:assert/strict');
const [root,out]=process.argv.slice(2);
function section(source,a,b) { const i=source.indexOf(a),j=source.indexOf(b,i);assert(i>=0&&j>i);return source.slice(i,j); }
const api=fs.readFileSync(root+'/Matths/ServerAPI.swift','utf8');
const demo=fs.readFileSync(root+'/Matths/DemoFixtures/DemoFixturesAccount.swift','utf8');
const view=fs.readFileSync(root+'/Matths/TeacherStudentManagementPanel.swift','utf8');
assert(!view.includes('.filter { $0.status != "UNKNOWN" }'));
assert(!view.includes('ForEach(concepts.prefix(12))'));
assert(view.includes('conceptLimit += 24') && view.includes('conceptEvidence(concept)'));
assert(view.includes('ShareLink(item: statistics.summary.bullets'));
fs.writeFileSync(out+'/main.swift','import Foundation\nenum ServerAPI {\n'+section(api,'    struct TeacherStudentMathMap:','    struct TeacherStudentDetail:')+'}\nenum DemoAccountFixtures {\n'+section(demo,'    static let teacherStudentDetail =','    static let teacherAttendanceRoster =')+`\n}
func decode(_ raw: String) throws -> ServerAPI.TeacherStudentMathMap {
 let body = try JSONSerialization.jsonObject(with: Data(raw.utf8)) as! [String:Any]
 let data = try JSONSerialization.data(withJSONObject: body["mathMap"]!)
 return try JSONDecoder().decode(ServerAPI.TeacherStudentMathMap.self, from:data)
}
let old = try decode(DemoAccountFixtures.teacherStudentDetail)
precondition(old.recommendation == nil && old.concepts.count == 3)
let full = try decode(DemoAccountFixtures.teacherStudentFullMapDetail)
precondition(full.concepts.count == 220)
precondition(full.concepts.filter { $0.status == "UNKNOWN" }.count == 120)
precondition(full.concepts[0].evidence.lowDifficulty?.correct == 3)
precondition(full.concepts[0].prerequisiteCount == 1)
precondition(full.recommendation?.difficulties.count == 2)
var limit = 24
while limit < full.concepts.count { limit += 24 }
precondition(Array(full.concepts.prefix(limit)).count == 220)
print("PASS actual native math-map DTO: legacy compatibility, 220 concepts, unknown data, full evidence and recommendations; incremental reveal reaches all")
`);
JS
swiftc "$scratch/main.swift" -o "$scratch/cases"
"$scratch/cases"
