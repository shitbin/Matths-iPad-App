#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/matths-first-success-lease.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT HUP INT TERM
node - "$ROOT" "$TEST_DIR" <<'JS'
const fs=require('node:fs');const [root,out]=process.argv.slice(2);
function between(s,a,b){const i=s.indexOf(a),j=s.indexOf(b,i);if(i<0||j<i)throw Error('Boundary changed '+a);return s.slice(i,j);}
const source=fs.readFileSync(root+'/Matths/FirstLearningJourneyScreen.swift','utf8');
const app=fs.readFileSync(root+'/Matths/MatthsApp.swift','utf8');
const lease=between(app,'    @Published var isTutorialPresentationActive = false {','    /// 마지막 라우트').replace('@Published ','');
const start=between(source,'            .task(id: ownerTrigger) {','                paused = false;').replace('            .task(id: ownerTrigger) {','func ownerTaskStarted() {')+'}\n';
const mayShow=between(source,'    private var mayShow: Bool {','    var body: some View {');
const helper=source.includes('    private func endOwnedPresentation() {')
 ? between(source,'    private func endOwnedPresentation() {','    private var content: some View {'):'';
fs.writeFileSync(out+'/flow.swift',`import Foundation
@MainActor final class Store {
var authProvider:String? = "server"
struct Profile {var role:String? = "student"}
var serverProfile:Profile? = .init()
var isSessionMode=false,hasPendingAssessmentAuthentication=false,requestedDashboardTutorial=false
${lease}
}
@MainActor final class Harness {
let store:Store
var presented=false,paused=false
var work:Task<Void,Never>?
init(_ store:Store){self.store=store}
${start}${mayShow}${helper}
var canShow:Bool{mayShow}
}
`);
JS
xcrun swiftc -swift-version 5 "$TEST_DIR/flow.swift" "$ROOT/tests/OnboardingPresentationLeaseCases.swift" -o "$TEST_DIR/cases"
"$TEST_DIR/cases"
